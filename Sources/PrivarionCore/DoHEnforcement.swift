import Foundation
import Network
import Logging

public class DoHEnforcement {
    
    public static let shared = DoHEnforcement()
    
    private let logger = Logger(label: "privarion.doh.enforcement")
    
    private var config: DoHEnforcementConfig
    private var isRunning = false
    private var dohServerConnections: [String: NWConnection] = [:]
    private let queue = DispatchQueue(label: "privarion.doh.enforcement", qos: .userInitiated)
    
    private init() {
        self.config = ConfigurationManager.shared.getCurrentConfiguration().modules.networkFilter.dohEnforcement
    }
    
    public func updateConfig(_ newConfig: DoHEnforcementConfig) {
        self.config = newConfig
    }
    
    public func start() throws {
        guard config.enabled else {
            logger.info("DoH enforcement is disabled in configuration")
            return
        }
        
        guard !isRunning else {
            logger.warning("DoH enforcement is already running")
            return
        }
        
        logger.info("Starting DoH enforcement...")
        
        if config.enforceDoH {
            try initializeDoHServers()
        }
        
        isRunning = true
        logger.info("DoH enforcement started successfully")
    }
    
    public func stop() {
        guard isRunning else { return }
        
        logger.info("Stopping DoH enforcement...")
        
        for (_, connection) in dohServerConnections {
            connection.cancel()
        }
        
        dohServerConnections.removeAll()
        
        isRunning = false
        logger.info("DoH enforcement stopped")
    }
    
    public var running: Bool {
        return isRunning
    }
    
    public func resetForTesting() {
        if isRunning {
            stop()
        }
        config = DoHEnforcementConfig()
        isRunning = false
    }
    
    public func shouldUseDoH(for domain: String) -> Bool {
        guard isRunning, config.enforceDoH else {
            return false
        }
        
        if config.trustedDomains.contains(where: { domain.hasSuffix($0) }) {
            return false
        }
        
        return true
    }
    
    public func shouldBlockPlainDNS() -> Bool {
        return config.enabled && config.blockPlainDNS
    }
    
    public func getDoHServer(for domain: String) -> String? {
        guard shouldUseDoH(for: domain) else {
            return nil
        }
        
        return config.dohServers.first
    }
    
    public func resolveDoH(query: Data, serverURL: String) async throws -> Data {
        guard let url = URL(string: serverURL) else {
            throw DoHError.invalidServerURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = query
        request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        request.timeoutInterval = config.enabled ? 10.0 : 5.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DoHError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DoHError.serverError(httpResponse.statusCode)
        }
        
        return data
    }
    
    public func getBlockedPlainDNSClients() -> [String] {
        guard config.enabled && config.blockPlainDNS else {
            return []
        }
        
        return []
    }
    
    public func addDoHServer(_ serverURL: String) {
        guard !config.dohServers.contains(serverURL) else {
            logger.warning("DoH server already configured: \(serverURL)")
            return
        }
        
        var newConfig = config
        newConfig.dohServers.append(serverURL)
        config = newConfig
        
        var currentConfig = ConfigurationManager.shared.getCurrentConfiguration()
        currentConfig.modules.networkFilter.dohEnforcement = newConfig
        try? ConfigurationManager.shared.updateConfiguration(currentConfig)
        
        logger.info("Added DoH server: \(serverURL)")
    }
    
    public func removeDoHServer(_ serverURL: String) {
        guard let index = config.dohServers.firstIndex(of: serverURL) else {
            logger.warning("DoH server not found: \(serverURL)")
            return
        }
        
        var newConfig = config
        newConfig.dohServers.remove(at: index)
        config = newConfig
        
        var currentConfig = ConfigurationManager.shared.getCurrentConfiguration()
        currentConfig.modules.networkFilter.dohEnforcement = newConfig
        try? ConfigurationManager.shared.updateConfiguration(currentConfig)
        
        logger.info("Removed DoH server: \(serverURL)")
    }
    
    public func addTrustedDomain(_ domain: String) {
        guard !config.trustedDomains.contains(domain) else {
            return
        }
        
        var newConfig = config
        newConfig.trustedDomains.append(domain)
        config = newConfig
        
        var currentConfig = ConfigurationManager.shared.getCurrentConfiguration()
        currentConfig.modules.networkFilter.dohEnforcement = newConfig
        try? ConfigurationManager.shared.updateConfiguration(currentConfig)
        
        logger.info("Added trusted domain for DoH bypass: \(domain)")
    }
    
    public func removeTrustedDomain(_ domain: String) {
        guard let index = config.trustedDomains.firstIndex(of: domain) else {
            return
        }
        
        var newConfig = config
        newConfig.trustedDomains.remove(at: index)
        config = newConfig
        
        var currentConfig = ConfigurationManager.shared.getCurrentConfiguration()
        currentConfig.modules.networkFilter.dohEnforcement = newConfig
        try? ConfigurationManager.shared.updateConfiguration(currentConfig)
        
        logger.info("Removed trusted domain: \(domain)")
    }
    
    public func getCurrentConfig() -> DoHEnforcementConfig {
        return config
    }
    
    private func initializeDoHServers() throws {
        for serverURL in config.dohServers {
            guard let url = URL(string: serverURL) else {
                logger.warning("Invalid DoH server URL: \(serverURL)")
                continue
            }
            
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(url.host ?? ""),
                port: NWEndpoint.Port(integerLiteral: url.scheme == "https" ? 443 : 80)
            )
            
            let connection = NWConnection(to: endpoint, using: .tcp)
            
            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.logger.debug("DoH server connection ready: \(serverURL)")
                case .failed(let error):
                    self?.logger.error("DoH server connection failed: \(serverURL) - \(error)")
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
            dohServerConnections[serverURL] = connection
        }
    }
}

public enum DoHError: Error, LocalizedError {
    case invalidServerURL
    case invalidResponse
    case serverError(Int)
    case queryTimeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Invalid DoH server URL"
        case .invalidResponse:
            return "Invalid response from DoH server"
        case .serverError(let code):
            return "DoH server returned error: \(code)"
        case .queryTimeout:
            return "DoH query timed out"
        }
    }
}

extension DoHEnforcement: @unchecked Sendable {}
