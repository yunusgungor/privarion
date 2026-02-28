import Foundation
import Logging

/// DNS Proxy Server Factory - provides backward compatibility while enabling SwiftNIO modernization
/// Implements migration strategy from STORY-2025-012
@available(macOS 10.14, *)
internal class DNSProxyServerFactory {
    private let logger: Logger
    
    internal init() {
        self.logger = Logger(label: "privarion.dns.proxy.factory")
    }
    
    /// Create DNS proxy server with automatic backend selection
    /// - Parameters:
    ///   - port: DNS server port (default: 53)
    ///   - upstreamServers: List of upstream DNS servers
    ///   - queryTimeout: Query timeout in seconds
    ///   - useSwiftNIO: Force SwiftNIO backend (nil for auto-detection)
    ///   - enableDoH: Enable DNS over HTTPS for upstream queries
    /// - Returns: DNS proxy server instance
    internal func createDNSProxyServer(
        port: Int = 53,
        upstreamServers: [String] = ["8.8.8.8", "1.1.1.1"],
        queryTimeout: Double = 5.0,
        useSwiftNIO: Bool? = nil,
        enableDoH: Bool = false
    ) -> DNSProxyServerProtocol {
        
        let shouldUseSwiftNIO = useSwiftNIO ?? determineOptimalBackend()
        
        if shouldUseSwiftNIO && Foundation.ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 11 {
            logger.info("Creating SwiftNIO DNS proxy server for high-performance networking (DoH: \(enableDoH))")
            if #available(macOS 10.15, *) {
                let swiftNIOServer = SwiftNIODNSProxyServer(
                    port: port,
                    upstreamServers: upstreamServers,
                    queryTimeout: queryTimeout,
                    enableDoH: enableDoH
                )
                return DNSProxyServerAdapter(swiftNIOServer: swiftNIOServer)
            }
        }
        
        logger.info("Creating legacy DNS proxy server for compatibility (DoH: \(enableDoH))")
        return DNSProxyServerAdapter(legacyServer: DNSProxyServer(
            port: port,
            upstreamServers: upstreamServers,
            queryTimeout: queryTimeout,
            enableDoH: enableDoH
        ))
    }
    
    /// Determine the optimal backend based on system capabilities and configuration
    private func determineOptimalBackend() -> Bool {
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        
        // Check if SwiftNIO is explicitly enabled in configuration
        if config.modules.networkFilter.enableHighPerformanceMode {
            return true
        }
        
        // Auto-detect based on system capabilities
        let systemInfo = Foundation.ProcessInfo.processInfo
        
        // Use SwiftNIO for:
        // - macOS 11+ (where Swift Concurrency is fully supported)
        // - Systems with multiple CPU cores (better EventLoop utilization)
        // - High-memory systems (SwiftNIO has higher memory overhead but better performance)
        let isMacOS11OrLater = systemInfo.operatingSystemVersion.majorVersion >= 11
        let hasMultipleCores = systemInfo.processorCount > 1
        let hasHighMemory = systemInfo.physicalMemory > 4 * 1024 * 1024 * 1024 // > 4GB
        
        let shouldUseSwiftNIO = isMacOS11OrLater && (hasMultipleCores || hasHighMemory)
        
        logger.info("Auto-detected backend: \(shouldUseSwiftNIO ? "SwiftNIO" : "Legacy") (macOS \(systemInfo.operatingSystemVersion.majorVersion)+, \(systemInfo.processorCount) cores, \(systemInfo.physicalMemory / 1024 / 1024 / 1024)GB RAM)")
        
        return shouldUseSwiftNIO
    }
}

/// Protocol for DNS proxy server implementations
internal protocol DNSProxyServerProtocol: AnyObject {
    var delegate: DNSProxyServerDelegate? { get set }
    
    func start() throws
    func stop()
}

/// Adapter to provide unified interface for both legacy and SwiftNIO implementations
@available(macOS 10.14, *)
internal class DNSProxyServerAdapter: DNSProxyServerProtocol {
    private let legacyServer: DNSProxyServer?
    private let swiftNIOServer: SwiftNIODNSProxyServer?
    private let logger: Logger
    
    internal weak var delegate: DNSProxyServerDelegate? {
        get {
            return legacyServer?.delegate ?? swiftNIOServer?.delegate
        }
        set {
            legacyServer?.delegate = newValue
            swiftNIOServer?.delegate = newValue
        }
    }
    
    // Legacy server adapter
    internal init(legacyServer: DNSProxyServer) {
        self.legacyServer = legacyServer
        self.swiftNIOServer = nil
        self.logger = Logger(label: "privarion.dns.proxy.adapter.legacy")
    }
    
    // SwiftNIO server adapter
    @available(macOS 10.15, *)
    internal init(swiftNIOServer: SwiftNIODNSProxyServer) {
        self.legacyServer = nil
        self.swiftNIOServer = swiftNIOServer
        self.logger = Logger(label: "privarion.dns.proxy.adapter.swiftnio")
    }
    
    internal func start() throws {
        if let legacyServer = legacyServer {
            logger.info("Starting legacy DNS proxy server")
            try legacyServer.start()
        } else if let swiftNIOServer = swiftNIOServer {
            if #available(macOS 10.15, *) {
                logger.info("Starting SwiftNIO DNS proxy server")
                try swiftNIOServer.startLegacy()
            }
        }
    }
    
    internal func stop() {
        if let legacyServer = legacyServer {
            logger.info("Stopping legacy DNS proxy server")
            legacyServer.stop()
        } else if let swiftNIOServer = swiftNIOServer {
            if #available(macOS 10.15, *) {
                logger.info("Stopping SwiftNIO DNS proxy server")
                swiftNIOServer.stopLegacy()
            }
        }
    }
}

// MARK: - Configuration Extensions

extension NetworkFilterConfig {
    /// Enable high-performance mode (SwiftNIO backend)
    internal var enableHighPerformanceMode: Bool {
        // This would be read from configuration file
        // For now, return false to maintain backward compatibility
        return false
    }
}

// MARK: - Migration Utilities

@available(macOS 10.14, *)
internal class DNSProxyMigrationHelper {
    private let logger: Logger
    
    internal init() {
        self.logger = Logger(label: "privarion.dns.proxy.migration")
    }
    
    /// Migrate configuration from legacy to SwiftNIO format
    internal func migrateConfiguration() -> Bool {
        logger.info("Checking DNS proxy configuration for migration...")
        
        // Check if migration is needed
        _ = ConfigurationManager.shared.getCurrentConfiguration()
        
        // Migrate any legacy settings that are incompatible with SwiftNIO
        // Example migration: convert old timeout values
        // Note: dnsQueryTimeout would be added to NetworkFilterConfig if needed
        // if config.modules.networkFilter.dnsQueryTimeout < 1.0 {
        //     logger.warning("DNS query timeout too low for SwiftNIO, using minimum 1.0 seconds")
        //     return true
        // }
        
        // Future migration logic would go here
        
        logger.info("No configuration migration needed")
        return false
    }
    
    /// Validate SwiftNIO compatibility
    internal func validateSwiftNIOCompatibility() -> Bool {
        let systemInfo = Foundation.ProcessInfo.processInfo
        
        // Check macOS version
        guard systemInfo.operatingSystemVersion.majorVersion >= 10 else {
            logger.error("SwiftNIO requires macOS 10.14 or later")
            return false
        }
        
        // Check available memory
        let availableMemory = systemInfo.physicalMemory
        let minimumMemory: UInt64 = 2 * 1024 * 1024 * 1024 // 2GB
        
        guard availableMemory >= minimumMemory else {
            logger.warning("SwiftNIO may have reduced performance with less than 2GB RAM")
            return true // Still compatible, but with warning
        }
        
        logger.info("SwiftNIO compatibility validated successfully")
        return true
    }
}
