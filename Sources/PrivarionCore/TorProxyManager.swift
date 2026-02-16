import Foundation
import Network
import Logging

public class TorProxyManager {
    
    public static let shared = TorProxyManager()
    
    private let logger = Logger(label: "privarion.tor.proxy")
    
    private var config: TorProxyConfig
    private var isRunning = false
    private var controlConnection: NWConnection?
    private let queue = DispatchQueue(label: "privarion.tor.proxy", qos: .userInitiated)
    
    private init() {
        self.config = ConfigurationManager.shared.getCurrentConfiguration().modules.networkFilter.torProxy
    }
    
    public func updateConfig(_ newConfig: TorProxyConfig) {
        self.config = newConfig
    }
    
    public func start() throws {
        guard config.enabled else {
            logger.info("Tor proxy is disabled in configuration")
            return
        }
        
        guard !isRunning else {
            logger.warning("Tor proxy is already running")
            return
        }
        
        logger.info("Starting Tor proxy manager...")
        
        if let customProxy = config.customSocksProxy {
            try connectToSocksProxy(customProxy)
        } else if config.useTorBrowser {
            try connectToTorBrowser()
        } else {
            try connectToSystemTor()
        }
        
        isRunning = true
        logger.info("Tor proxy manager started successfully")
    }
    
    public func stop() {
        guard isRunning else { return }
        
        logger.info("Stopping Tor proxy manager...")
        
        controlConnection?.cancel()
        controlConnection = nil
        
        isRunning = false
        logger.info("Tor proxy manager stopped")
    }
    
    public var running: Bool {
        return isRunning
    }
    
    public func getNewNym() async throws {
        guard isRunning else {
            throw TorProxyError.notRunning
        }
        
        try await sendTorControlCommand("GETINFO status/circuit-change")
    }
    
    public func getCircuitInfo() async throws -> [String] {
        guard isRunning else {
            throw TorProxyError.notRunning
        }
        
        let response = try await sendTorControlCommand("GETINFO circuit-info")
        return parseCircuitInfo(response)
    }
    
    public func getBandwidthStats() async throws -> (read: Int64, written: Int64) {
        guard isRunning else {
            throw TorProxyError.notRunning
        }
        
        let response = try await sendTorControlCommand("GETINFO stats/bytes")
        return parseBandwidthStats(response)
    }
    
    private func connectToSocksProxy(_ proxyString: String) throws {
        let components = proxyString.split(separator: ":")
        guard components.count >= 2,
              let port = Int(components.last ?? "") else {
            throw TorProxyError.invalidProxyString
        }
        
        let host = String(components.dropLast().joined(separator: ":"))
        
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )
        
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.logger.info("Connected to SOCKS proxy at \(proxyString)")
            case .failed(let error):
                self?.logger.error("SOCKS proxy connection failed: \(error)")
            default:
                break
            }
        }
        
        connection.start(queue: queue)
        self.controlConnection = connection
    }
    
    private func connectToTorBrowser() throws {
        let torPath = config.torBinaryPath ?? "/Applications/Tor Browser.app/Contents/Resources/Tor/tor"
        
        guard FileManager.default.fileExists(atPath: torPath) else {
            throw TorProxyError.torNotFound(torPath)
        }
        
        try connectToSocksProxy("127.0.0.1:\(config.socksPort)")
    }
    
    private func connectToSystemTor() throws {
        try connectToSocksProxy("127.0.0.1:\(config.socksPort)")
    }
    
    private func sendTorControlCommand(_ command: String) async throws -> String {
        guard let connection = controlConnection else {
            throw TorProxyError.notConnected
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let commandData = (command + "\r\n").data(using: .utf8)!
            
            connection.send(content: commandData, completion: .contentProcessed { [weak self] error in
                if let error = error {
                    continuation.resume(throwing: TorProxyError.sendFailed(error.localizedDescription))
                    return
                }
                
                connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
                    if let error = error {
                        continuation.resume(throwing: TorProxyError.receiveFailed(error.localizedDescription))
                        return
                    }
                    
                    if let data = data, let response = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: response)
                    } else {
                        continuation.resume(throwing: TorProxyError.invalidResponse)
                    }
                }
            })
        }
    }
    
    private func parseCircuitInfo(_ response: String) -> [String] {
        return response.components(separatedBy: "\n").filter { !$0.isEmpty }
    }
    
    private func parseBandwidthStats(_ response: String) -> (read: Int64, written: Int64) {
        var readBytes: Int64 = 0
        var writtenBytes: Int64 = 0
        
        let lines = response.components(separatedBy: "\n")
        for line in lines {
            if line.contains("bytes-read=") {
                let value = line.split(separator: "=").last ?? ""
                readBytes = Int64(value) ?? 0
            } else if line.contains("bytes-written=") {
                let value = line.split(separator: "=").last ?? ""
                writtenBytes = Int64(value) ?? 0
            }
        }
        
        return (readBytes, writtenBytes)
    }
    
    public func createSocks5Connection(to host: String, port: UInt16) -> NWConnection? {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port)
        )
        
        let socksEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: NWEndpoint.Port(integerLiteral: UInt16(config.socksPort))
        )
        
        let connection = NWConnection(to: socksEndpoint, using: .tcp)
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.logger.debug("SOCKS5 connection ready to \(host):\(port)")
            case .failed(let error):
                self?.logger.error("SOCKS5 connection failed: \(error)")
            default:
                break
            }
        }
        
        return connection
    }
}

public enum TorProxyError: Error, LocalizedError {
    case notRunning
    case notConnected
    case invalidProxyString
    case torNotFound(String)
    case sendFailed(String)
    case receiveFailed(String)
    case invalidResponse
    
    public var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Tor proxy is not running"
        case .notConnected:
            return "Not connected to Tor network"
        case .invalidProxyString:
            return "Invalid SOCKS proxy string format"
        case .torNotFound(let path):
            return "Tor binary not found at: \(path)"
        case .sendFailed(let reason):
            return "Failed to send command: \(reason)"
        case .receiveFailed(let reason):
            return "Failed to receive response: \(reason)"
        case .invalidResponse:
            return "Invalid response from Tor control port"
        }
    }
}

extension TorProxyManager: @unchecked Sendable {}
