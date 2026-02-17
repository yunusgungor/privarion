import Foundation
import Network
import Logging

public class ProxyChainManager {
    
    public static let shared = ProxyChainManager()
    
    private let logger = Logger(label: "privarion.proxy.chain")
    
    private var config: ProxyChainConfig
    private var isRunning = false
    private var activeConnections: [UUID: ChainConnection] = [:]
    private let queue = DispatchQueue(label: "privarion.proxy.chain", qos: .userInitiated)
    
    private init() {
        self.config = ConfigurationManager.shared.getCurrentConfiguration().modules.networkFilter.proxyChain
    }
    
    public func updateConfig(_ newConfig: ProxyChainConfig) {
        self.config = newConfig
    }
    
    public func start() throws {
        guard config.enabled else {
            logger.info("Proxy chain is disabled in configuration")
            return
        }
        
        guard !config.proxies.isEmpty else {
            throw ProxyChainError.noProxiesConfigured
        }
        
        guard !isRunning else {
            logger.warning("Proxy chain manager is already running")
            return
        }
        
        logger.info("Starting proxy chain manager with \(config.proxies.count) proxies")
        
        validateProxies()
        
        isRunning = true
        logger.info("Proxy chain manager started successfully")
    }
    
    public func stop() {
        guard isRunning else { return }
        
        logger.info("Stopping proxy chain manager...")
        
        for (_, connection) in activeConnections {
            for link in connection.links {
                link.cancel()
            }
        }
        
        activeConnections.removeAll()
        
        isRunning = false
        logger.info("Proxy chain manager stopped")
    }
    
    public var running: Bool {
        return isRunning
    }
    
    public func resetForTesting() {
        if isRunning {
            stop()
        }
        config = ProxyChainConfig()
        isRunning = false
        activeConnections.removeAll()
    }
    
    public func createChainedConnection(to host: String, port: UInt16) -> NWConnection? {
        guard isRunning else {
            logger.warning("Cannot create chained connection - manager not running")
            return nil
        }
        
        let chainId = UUID()
        var links: [NWConnection] = []
        
        let proxies = selectProxies()
        
        for (index, proxy) in proxies.enumerated() {
            let isLast = index == proxies.count - 1
            let targetHost = isLast ? host : proxies[index + 1].host
            let targetPort = isLast ? port : UInt16(proxies[index + 1].port)
            
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(proxy.host),
                port: NWEndpoint.Port(integerLiteral: UInt16(proxy.port))
            )
            
            let connection: NWConnection
            
            switch proxy.type {
            case .socks5:
                connection = NWConnection(to: endpoint, using: .tcp)
                if !isLast || (isLast && index == proxies.count - 1) {
                }
            case .socks4:
                connection = NWConnection(to: endpoint, using: .tcp)
            case .http, .https:
                connection = NWConnection(to: endpoint, using: .tcp)
            }
            
            links.append(connection)
        }
        
        let chainConnection = ChainConnection(
            id: chainId,
            targetHost: host,
            targetPort: port,
            links: links,
            createdAt: Date()
        )
        
        activeConnections[chainId] = chainConnection
        
        return links.first
    }
    
    public func closeChainedConnection(_ connectionId: UUID) {
        queue.async(flags: .barrier) {
            if let connection = self.activeConnections[connectionId] {
                for link in connection.links {
                    link.cancel()
                }
                self.activeConnections.removeValue(forKey: connectionId)
                self.logger.debug("Closed chained connection \(connectionId)")
            }
        }
    }
    
    public func getActiveConnections() -> [ProxyChainConnectionInfo] {
        return activeConnections.values.map { connection in
            ProxyChainConnectionInfo(
                id: connection.id,
                targetHost: connection.targetHost,
                targetPort: connection.targetPort,
                linkCount: connection.links.count,
                createdAt: connection.createdAt
            )
        }
    }
    
    public func testProxies() async -> [ProxyTestResult] {
        var results: [ProxyTestResult] = []
        
        for proxy in config.proxies {
            let result = await testProxy(proxy)
            results.append(result)
        }
        
        return results
    }
    
    private func selectProxies() -> [ProxyConfig] {
        switch config.chainMode {
        case .sequential:
            return config.proxies
        case .random:
            return config.proxies.shuffled()
        case .failover:
            return config.proxies
        }
    }
    
    private func validateProxies() {
        for proxy in config.proxies {
            if proxy.host.isEmpty || proxy.port <= 0 {
                logger.warning("Invalid proxy configuration: \(proxy.host):\(proxy.port)")
            }
        }
    }
    
    private func testProxy(_ proxy: ProxyConfig) async -> ProxyTestResult {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(proxy.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(proxy.port))
        )
        
        let connection = NWConnection(to: endpoint, using: .tcp)
        let startTime = Date()
        
        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let latency = Date().timeIntervalSince(startTime)
                    connection.cancel()
                    continuation.resume(returning: ProxyTestResult(
                        proxy: proxy,
                        success: true,
                        latency: latency,
                        error: nil
                    ))
                case .failed(let error):
                    connection.cancel()
                    continuation.resume(returning: ProxyTestResult(
                        proxy: proxy,
                        success: false,
                        latency: nil,
                        error: error.localizedDescription
                    ))
                case .cancelled:
                    break
                default:
                    break
                }
            }
            
            connection.start(queue: queue)
            
            queue.asyncAfter(deadline: .now() + 10) {
                if connection.state != .ready {
                    connection.cancel()
                    continuation.resume(returning: ProxyTestResult(
                        proxy: proxy,
                        success: false,
                        latency: nil,
                        error: "Connection timeout"
                    ))
                }
            }
        }
    }
}

private struct ChainConnection {
    let id: UUID
    let targetHost: String
    let targetPort: UInt16
    let links: [NWConnection]
    let createdAt: Date
}

public struct ProxyChainConnectionInfo {
    public let id: UUID
    public let targetHost: String
    public let targetPort: UInt16
    public let linkCount: Int
    public let createdAt: Date
}

public struct ProxyTestResult {
    public let proxy: ProxyConfig
    public let success: Bool
    public let latency: TimeInterval?
    public let error: String?
}

public enum ProxyChainError: Error, LocalizedError {
    case noProxiesConfigured
    case invalidProxyConfiguration
    case connectionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .noProxiesConfigured:
            return "No proxies configured in proxy chain"
        case .invalidProxyConfiguration:
            return "Invalid proxy configuration"
        case .connectionFailed(let reason):
            return "Proxy chain connection failed: \(reason)"
        }
    }
}

extension ProxyChainManager: @unchecked Sendable {}
