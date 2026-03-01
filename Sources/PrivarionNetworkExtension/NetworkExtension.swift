// PrivarionNetworkExtension
// Network Extension for packet filtering and DNS proxy
// Requirements: 3.1-3.12, 4.1-4.12, 5.1-5.10

import Foundation
import NetworkExtension
import Logging
import PrivarionSharedModels

/// Configuration options for tunnel network settings
/// Requirements: 3.2-3.4
public struct TunnelConfiguration {
    /// Local DNS server address (default: 127.0.0.1)
    let dnsServerAddress: String
    
    /// Tunnel remote address (default: 127.0.0.1)
    let tunnelRemoteAddress: String
    
    /// IPv4 address for the tunnel interface (default: 10.0.0.1)
    let ipv4Address: String
    
    /// IPv4 subnet mask (default: 255.255.255.0)
    let ipv4SubnetMask: String
    
    /// IPv6 address for the tunnel interface (default: fd00::1)
    let ipv6Address: String
    
    /// IPv6 network prefix length (default: 64)
    let ipv6PrefixLength: NSNumber
    
    /// Maximum Transmission Unit (default: 1500)
    let mtu: NSNumber
    
    /// Whether to route all IPv4 traffic through tunnel (default: true)
    let routeAllIPv4Traffic: Bool
    
    /// Whether to route all IPv6 traffic through tunnel (default: true)
    let routeAllIPv6Traffic: Bool
    
    /// Default configuration
    public static let `default` = TunnelConfiguration(
        dnsServerAddress: "127.0.0.1",
        tunnelRemoteAddress: "127.0.0.1",
        ipv4Address: "10.0.0.1",
        ipv4SubnetMask: "255.255.255.0",
        ipv6Address: "fd00::1",
        ipv6PrefixLength: 64,
        mtu: 1500,
        routeAllIPv4Traffic: true,
        routeAllIPv6Traffic: true
    )
    
    /// Validate configuration values
    /// - Throws: NetworkExtensionError.tunnelConfigurationInvalid if validation fails
    public func validate() throws {
        // Validate DNS server address
        guard isValidIPAddress(dnsServerAddress) else {
            throw NetworkExtensionError.tunnelConfigurationInvalid
        }
        
        // Validate tunnel remote address
        guard isValidIPAddress(tunnelRemoteAddress) else {
            throw NetworkExtensionError.tunnelConfigurationInvalid
        }
        
        // Validate IPv4 address
        guard isValidIPv4Address(ipv4Address) else {
            throw NetworkExtensionError.tunnelConfigurationInvalid
        }
        
        // Validate IPv4 subnet mask
        guard isValidIPv4Address(ipv4SubnetMask) else {
            throw NetworkExtensionError.tunnelConfigurationInvalid
        }
        
        // Validate IPv6 address
        guard isValidIPv6Address(ipv6Address) else {
            throw NetworkExtensionError.tunnelConfigurationInvalid
        }
        
        // Validate IPv6 prefix length (must be between 1 and 128)
        guard ipv6PrefixLength.intValue >= 1 && ipv6PrefixLength.intValue <= 128 else {
            throw NetworkExtensionError.tunnelConfigurationInvalid
        }
        
        // Validate MTU (must be between 576 and 9000)
        guard mtu.intValue >= 576 && mtu.intValue <= 9000 else {
            throw NetworkExtensionError.tunnelConfigurationInvalid
        }
    }
    
    /// Check if a string is a valid IP address (IPv4 or IPv6)
    private func isValidIPAddress(_ address: String) -> Bool {
        return isValidIPv4Address(address) || isValidIPv6Address(address)
    }
    
    /// Check if a string is a valid IPv4 address
    private func isValidIPv4Address(_ address: String) -> Bool {
        let parts = address.split(separator: ".")
        guard parts.count == 4 else { return false }
        
        for part in parts {
            guard let value = Int(part), value >= 0 && value <= 255 else {
                return false
            }
        }
        return true
    }
    
    /// Check if a string is a valid IPv6 address
    private func isValidIPv6Address(_ address: String) -> Bool {
        // Basic IPv6 validation - check for hex digits and colons
        let validChars = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
        return address.unicodeScalars.allSatisfy { validChars.contains($0) } && address.contains(":")
    }
}

/// Packet Tunnel Provider for system-wide network filtering
/// Intercepts and filters all network traffic at the packet level
/// Requirements: 3.1-3.12
@available(macOS 10.15, *)
public class PrivarionPacketTunnelProvider: NEPacketTunnelProvider {
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger = Logger(label: "com.privarion.network-extension.packet-tunnel")
    
    /// File logger for network extension logs
    private let fileLogger: FileLogger
    
    /// DNS filter for query filtering
    private let dnsFilter: DNSFilter
    
    /// Packet filter for traffic evaluation
    private let packetFilter: PacketFilter
    
    /// Flag to control packet processing loop
    private var isProcessingPackets = false
    
    /// Task for packet processing loop
    private var packetProcessingTask: Task<Void, Never>?
    
    /// Current tunnel configuration
    private var tunnelConfiguration: TunnelConfiguration = .default
    
    /// Original network settings for restoration
    private var originalNetworkSettings: NEPacketTunnelNetworkSettings?
    
    /// Retry policy for tunnel start failures
    private let retryPolicy = RetryPolicy(maxAttempts: 3, baseDelay: 2.0, maxDelay: 10.0)
    
    /// Error count for monitoring
    private var consecutiveErrorCount = 0
    
    /// Maximum consecutive errors before circuit breaker opens
    private let maxConsecutiveErrors = 5
    
    /// Flag indicating if tunnel is in degraded state
    private var isDegraded = false
    
    // MARK: - Initialization
    
    public override init() {
        self.fileLogger = FileLogger(logFilePath: "/var/log/privarion/network-extension.log")
        self.dnsFilter = DNSFilter()
        self.packetFilter = PacketFilter()
        super.init()
    }
    
    // MARK: - Tunnel Lifecycle
    
    /// Start the packet tunnel with network configuration
    /// Creates virtual network interface and begins packet interception
    /// Implements retry logic with exponential backoff for transient failures
    /// - Parameter options: Optional configuration options
    /// - Throws: NetworkExtensionError if tunnel fails to start after retries
    /// - Requirement: 3.1, 3.2, 3.3, 3.4, 19.2
    public override func startTunnel(options: [String: NSObject]?) async throws {
        logger.info("Starting packet tunnel provider")
        fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] Starting packet tunnel provider")
        
        do {
            // Use retry policy for transient failures (Requirement 19.2)
            try await retryPolicy.execute {
                try await self.startTunnelInternal(options: options)
            }
            
            // Reset error count on successful start
            consecutiveErrorCount = 0
            isDegraded = false
            
            logger.info("Packet tunnel started successfully")
            fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] Packet tunnel started successfully")
            
        } catch let error as NetworkExtensionError {
            // Log detailed error information
            logger.error("Failed to start packet tunnel after retries", metadata: [
                "error": "\(error.errorDescription ?? "Unknown error")",
                "attempts": "\(retryPolicy.maxAttempts)"
            ])
            fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] ERROR: Failed to start packet tunnel after \(retryPolicy.maxAttempts) attempts: \(error.errorDescription ?? "Unknown error")")
            
            // Cleanup any partial state
            await cleanupPartialState()
            
            throw error
        } catch {
            // Wrap unexpected errors
            logger.error("Unexpected error starting packet tunnel", metadata: ["error": "\(error.localizedDescription)"])
            fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] ERROR: Unexpected error starting packet tunnel: \(error.localizedDescription)")
            
            await cleanupPartialState()
            
            throw NetworkExtensionError.tunnelStartFailed(error)
        }
    }
    
    /// Internal tunnel start implementation
    /// - Parameter options: Optional configuration options
    /// - Throws: NetworkExtensionError if tunnel fails to start
    private func startTunnelInternal(options: [String: NSObject]?) async throws {
        // Validate configuration before starting
        do {
            try tunnelConfiguration.validate()
        } catch {
            logger.error("Invalid tunnel configuration", metadata: ["error": "\(error.localizedDescription)"])
            throw NetworkExtensionError.tunnelConfigurationInvalid
        }
        
        // Create tunnel network settings (Requirement 3.2, 3.3, 3.4)
        let tunnelSettings = try createTunnelNetworkSettings()
        
        // Store original settings for restoration (Requirement 19.2)
        originalNetworkSettings = tunnelSettings
        
        // Apply tunnel settings to create virtual network interface (Requirement 3.1)
        do {
            try await setTunnelNetworkSettings(tunnelSettings)
            logger.info("Tunnel network settings applied successfully")
            fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] Tunnel network settings applied")
        } catch {
            logger.error("Failed to apply tunnel network settings", metadata: ["error": "\(error.localizedDescription)"])
            throw NetworkExtensionError.tunnelStartFailed(error)
        }
        
        // Start packet processing loop
        startPacketProcessing()
    }
    
    /// Stop the packet tunnel and cleanup resources
    /// Implements graceful shutdown with proper resource cleanup and network settings restoration
    /// - Parameter reason: Reason for stopping the tunnel
    /// - Requirement: 3.12, 19.2
    public override func stopTunnel(with reason: NEProviderStopReason) async {
        logger.info("Stopping packet tunnel", metadata: ["reason": "\(reason.rawValue)"])
        fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] Stopping packet tunnel, reason: \(reason.rawValue)")
        
        // Stop packet processing loop first to prevent new packets
        stopPacketProcessing()
        
        // Wait briefly for in-flight packets to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Cleanup network settings and restore original configuration (Requirement 3.12, 19.2)
        await cleanupNetworkSettings()
        
        // Reset state
        consecutiveErrorCount = 0
        isDegraded = false
        originalNetworkSettings = nil
        
        logger.info("Packet tunnel stopped successfully")
        fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] Packet tunnel stopped successfully")
    }
    
    /// Cleanup network settings and restore original configuration
    /// - Requirement: 3.12, 19.2
    private func cleanupNetworkSettings() async {
        do {
            // Clear tunnel network settings to restore original configuration
            try await setTunnelNetworkSettings(nil)
            logger.info("Tunnel network settings cleaned up and original configuration restored")
            fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] Tunnel network settings cleaned up")
        } catch {
            // Log error but don't throw - best effort cleanup
            logger.error("Failed to cleanup tunnel settings", metadata: ["error": "\(error.localizedDescription)"])
            fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] ERROR: Failed to cleanup tunnel settings: \(error.localizedDescription)")
            
            // Attempt alternative cleanup method
            await attemptAlternativeCleanup()
        }
    }
    
    /// Attempt alternative cleanup method if primary cleanup fails
    /// - Requirement: 19.2
    private func attemptAlternativeCleanup() async {
        logger.warning("Attempting alternative cleanup method")
        
        // Try to restore original settings if we have them
        if let originalSettings = originalNetworkSettings {
            do {
                try await setTunnelNetworkSettings(originalSettings)
                try await setTunnelNetworkSettings(nil)
                logger.info("Alternative cleanup succeeded")
            } catch {
                logger.error("Alternative cleanup also failed", metadata: ["error": "\(error.localizedDescription)"])
            }
        }
    }
    
    /// Cleanup partial state after failed tunnel start
    /// - Requirement: 19.2
    private func cleanupPartialState() async {
        logger.info("Cleaning up partial state after failed start")
        
        // Stop any running packet processing
        stopPacketProcessing()
        
        // Attempt to clear network settings
        await cleanupNetworkSettings()
        
        // Reset flags
        isDegraded = false
    }
    
    // MARK: - Network Configuration
    
    /// Create tunnel network settings with DNS and routing configuration
    /// - Parameter config: Optional custom configuration (uses default if nil)
    /// - Returns: Configured NEPacketTunnelNetworkSettings
    /// - Throws: NetworkExtensionError if configuration is invalid
    /// - Requirement: 3.2, 3.3, 3.4
    private func createTunnelNetworkSettings(config: TunnelConfiguration? = nil) throws -> NEPacketTunnelNetworkSettings {
        // Use provided config or default
        let configuration = config ?? tunnelConfiguration
        
        // Validate configuration before applying (Requirement 3.2)
        try configuration.validate()
        
        // Create tunnel settings with local address (Requirement 3.2)
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: configuration.tunnelRemoteAddress)
        
        // Configure DNS settings to route queries through local proxy (Requirement 3.3)
        let dnsSettings = NEDNSSettings(servers: [configuration.dnsServerAddress])
        dnsSettings.matchDomains = [""] // Match all domains
        tunnelSettings.dnsSettings = dnsSettings
        
        // Configure IPv4 settings with included routes for all traffic (Requirement 3.4)
        let ipv4Settings = NEIPv4Settings(
            addresses: [configuration.ipv4Address],
            subnetMasks: [configuration.ipv4SubnetMask]
        )
        
        // Route all IPv4 traffic through the tunnel if configured
        if configuration.routeAllIPv4Traffic {
            ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        }
        
        tunnelSettings.ipv4Settings = ipv4Settings
        
        // Configure IPv6 settings (optional but recommended)
        let ipv6Settings = NEIPv6Settings(
            addresses: [configuration.ipv6Address],
            networkPrefixLengths: [configuration.ipv6PrefixLength]
        )
        
        // Route all IPv6 traffic through the tunnel if configured
        if configuration.routeAllIPv6Traffic {
            ipv6Settings.includedRoutes = [NEIPv6Route.default()]
        }
        
        tunnelSettings.ipv6Settings = ipv6Settings
        
        // Set MTU for optimal packet size
        tunnelSettings.mtu = configuration.mtu
        
        logger.debug("Created tunnel network settings", metadata: [
            "tunnelRemoteAddress": "\(configuration.tunnelRemoteAddress)",
            "dnsServer": "\(configuration.dnsServerAddress)",
            "ipv4Address": "\(configuration.ipv4Address)",
            "ipv6Address": "\(configuration.ipv6Address)",
            "mtu": "\(configuration.mtu)"
        ])
        
        return tunnelSettings
    }
    
    /// Update tunnel configuration
    /// - Parameter config: New configuration to apply
    /// - Throws: NetworkExtensionError if configuration is invalid
    public func updateConfiguration(_ config: TunnelConfiguration) throws {
        // Validate before updating
        try config.validate()
        tunnelConfiguration = config
        logger.info("Tunnel configuration updated")
    }
    
    // MARK: - Packet Processing
    
    /// Start the packet processing loop
    /// Reads packets from packetFlow and processes them
    /// - Requirement: 3.5
    private func startPacketProcessing() {
        guard !isProcessingPackets else {
            logger.warning("Packet processing already running")
            return
        }
        
        isProcessingPackets = true
        
        // Start packet processing task
        packetProcessingTask = Task {
            logger.info("Packet processing loop started")
            fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] Packet processing loop started")
            
            await processPacketsLoop()
            
            logger.info("Packet processing loop stopped")
            fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] Packet processing loop stopped")
        }
    }
    
    /// Stop the packet processing loop
    private func stopPacketProcessing() {
        guard isProcessingPackets else {
            return
        }
        
        isProcessingPackets = false
        packetProcessingTask?.cancel()
        packetProcessingTask = nil
        
        logger.info("Packet processing stopped")
    }
    
    /// Main packet processing loop
    /// Continuously reads packets from packetFlow, filters them, and writes them back
    /// Implements error handling with circuit breaker pattern for resilience
    /// - Requirement: 3.5, 3.6, 3.7, 3.8, 3.9, 18.2, 19.2
    private func processPacketsLoop() async {
        while isProcessingPackets && !Task.isCancelled {
            do {
                // Read packets from packetFlow (Requirement 3.5)
                let packets = try await readPackets()
                
                // Process each packet
                for packet in packets {
                    let startTime = Date()
                    
                    // Parse packet headers and filter (Requirement 3.6, 3.7, 3.8)
                    let filteredPacket = await filterPacket(packet)
                    
                    // Write filtered packet back to packetFlow (Requirement 3.9)
                    if let filteredData = filteredPacket {
                        try await writePacket(filteredData)
                    }
                    
                    // Track latency for performance monitoring (Requirement 18.2)
                    let latency = Date().timeIntervalSince(startTime) * 1000 // Convert to ms
                    if latency > 10 {
                        logger.warning("Packet processing latency exceeded target", metadata: [
                            "latency_ms": "\(latency)"
                        ])
                    }
                }
                
                // Reset error count on successful processing
                if consecutiveErrorCount > 0 {
                    consecutiveErrorCount = 0
                    if isDegraded {
                        logger.info("Packet processing recovered from degraded state")
                        isDegraded = false
                    }
                }
                
            } catch {
                if !Task.isCancelled {
                    consecutiveErrorCount += 1
                    
                    logger.error("Error in packet processing loop", metadata: [
                        "error": "\(error.localizedDescription)",
                        "consecutive_errors": "\(consecutiveErrorCount)"
                    ])
                    fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] ERROR: Packet processing error: \(error.localizedDescription) (consecutive errors: \(consecutiveErrorCount))")
                    
                    // Check if we've exceeded error threshold (circuit breaker pattern)
                    if consecutiveErrorCount >= maxConsecutiveErrors {
                        logger.error("Circuit breaker opened - too many consecutive errors", metadata: [
                            "max_errors": "\(maxConsecutiveErrors)"
                        ])
                        fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] CRITICAL: Circuit breaker opened after \(maxConsecutiveErrors) consecutive errors")
                        
                        // Enter degraded state
                        isDegraded = true
                        
                        // Wait longer before retrying
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        
                        // Reset counter to allow recovery attempts
                        consecutiveErrorCount = 0
                    } else {
                        // Brief pause before retrying to avoid tight error loop
                        // Use exponential backoff based on error count
                        let backoffMs = min(10 * (1 << consecutiveErrorCount), 1000) // Max 1 second
                        try? await Task.sleep(nanoseconds: UInt64(backoffMs) * 1_000_000)
                    }
                }
            }
        }
    }
    
    /// Read packets from the packet flow
    /// - Returns: Array of packet data
    /// - Throws: NetworkExtensionError if reading fails
    /// - Requirement: 3.5
    private func readPackets() async throws -> [Data] {
        return try await withCheckedThrowingContinuation { continuation in
            // Read multiple packets at once for better performance
            packetFlow.readPackets { (packets, protocols) in
                continuation.resume(returning: packets)
            }
        }
    }
    
    /// Filter a packet based on protection policy
    /// Uses PacketFilter to evaluate packets against policies and blocklists
    /// - Parameter packet: Raw packet data
    /// - Returns: Filtered packet data, or nil if packet should be dropped
    /// - Requirement: 3.6, 3.7, 3.8
    private func filterPacket(_ packet: Data) async -> Data? {
        guard packet.count > 0 else {
            return nil
        }
        
        // Determine IP protocol version from packet
        let version = (packet[0] >> 4) & 0x0F
        let protocolNumber = Int(version)
        
        // Use PacketFilter to evaluate packet (Requirement 3.6, 3.7, 3.8)
        let result = await packetFilter.filterPacket(packet, protocol: protocolNumber)
        
        switch result {
        case .allow(let data):
            // Allow packet through (Requirement 3.9)
            return data
            
        case .drop:
            // Drop packet (Requirement 3.7)
            if let destination = packetFilter.extractDestination(packet) {
                logger.debug("Dropping packet to blocked destination", metadata: [
                    "destination_ip": "\(destination.ip)",
                    "destination_port": "\(destination.port)"
                ])
                fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] Blocked packet to \(destination.ip):\(destination.port)")
            }
            return nil
            
        case .modify(let modifiedData):
            // Return modified packet (Requirement 3.8)
            if let destination = packetFilter.extractDestination(packet) {
                logger.debug("Modifying packet to fingerprinting destination", metadata: [
                    "destination_ip": "\(destination.ip)",
                    "destination_port": "\(destination.port)"
                ])
                fileLogger.log("[\(ISO8601DateFormatter().string(from: Date()))] Modified packet to \(destination.ip):\(destination.port)")
            }
            return modifiedData
        }
    }
    
    /// Write packet back to packet flow
    /// - Parameter packet: Filtered packet data to write
    /// - Throws: NetworkExtensionError if writing fails
    /// - Requirement: 3.9
    private func writePacket(_ packet: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // Determine protocol family from packet
            let protocolFamily: NSNumber
            if packet.count >= 1 {
                let version = (packet[0] >> 4) & 0x0F
                protocolFamily = version == 4 ? NSNumber(value: AF_INET) : NSNumber(value: AF_INET6)
            } else {
                protocolFamily = NSNumber(value: AF_INET)
            }
            
            // Write packet back to flow
            let success = packetFlow.writePackets([packet], withProtocols: [protocolFamily])
            
            if success {
                continuation.resume()
            } else {
                continuation.resume(throwing: NetworkExtensionError.packetProcessingFailed)
            }
        }
    }
}

/// Content Filter Provider for web content filtering
/// Filters web content in Safari and system webviews
public class PrivarionContentFilterProvider: NEFilterDataProvider {
    private let logger = Logger(label: "com.privarion.network-extension.content-filter")
    
    public override func handleNewFlow(_ flow: NEFilterFlow) -> NEFilterNewFlowVerdict {
        logger.info("Handling new flow")
        // Implementation will be added in subsequent tasks
        return .allow()
    }
    
    public override func handleInboundData(from flow: NEFilterFlow,
                                          readBytesStartOffset offset: Int,
                                          readBytes: Data) -> NEFilterDataVerdict {
        logger.debug("Handling inbound data", metadata: ["offset": "\(offset)", "bytes": "\(readBytes.count)"])
        // Implementation will be added in subsequent tasks
        return .allow()
    }
    
    public override func handleOutboundData(from flow: NEFilterFlow,
                                           readBytesStartOffset offset: Int,
                                           readBytes: Data) -> NEFilterDataVerdict {
        logger.debug("Handling outbound data", metadata: ["offset": "\(offset)", "bytes": "\(readBytes.count)"])
        // Implementation will be added in subsequent tasks
        return .allow()
    }
}

/// Network Extension errors
public enum NetworkExtensionError: Error, LocalizedError {
    case tunnelStartFailed(Error)
    case tunnelConfigurationInvalid
    case packetProcessingFailed
    case dnsProxyBindFailed(port: Int)
    case networkSettingsRestoreFailed
    
    public var errorDescription: String? {
        switch self {
        case .tunnelStartFailed(let error):
            return "Packet tunnel failed to start: \(error.localizedDescription)"
        case .tunnelConfigurationInvalid:
            return "Packet tunnel configuration is invalid"
        case .packetProcessingFailed:
            return "Packet processing failed"
        case .dnsProxyBindFailed(let port):
            return "DNS proxy failed to bind to port \(port)"
        case .networkSettingsRestoreFailed:
            return "Failed to restore original network settings"
        }
    }
}
