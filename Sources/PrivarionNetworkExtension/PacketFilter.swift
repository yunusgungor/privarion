// PacketFilter.swift
// Packet filtering engine for network traffic evaluation
// Requirements: 3.6-3.8

import Foundation
import Logging
import PrivarionSharedModels
import PrivarionCore

/// Result of packet filtering evaluation
/// Requirements: 3.6-3.8
public enum FilterResult {
    /// Allow packet to pass through unchanged
    case allow(Data)
    
    /// Drop packet (block traffic)
    case drop
    
    /// Modify packet data before forwarding
    case modify(Data)
}

/// Packet filter for evaluating network traffic against protection policies
/// Integrates with ProtectionPolicyEngine and BlocklistManager to make filtering decisions
/// Requirements: 3.6-3.8
@available(macOS 10.15, *)
public class PacketFilter {
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger = Logger(label: "com.privarion.network-extension.packet-filter")
    
    /// Protection policy engine for policy evaluation
    private let policyEngine: ProtectionPolicyEngine
    
    /// Blocklist manager for domain/IP blocking
    private let blocklistManager: BlocklistManager
    
    /// DNS filter for domain resolution
    private let dnsFilter: DNSFilter
    
    /// Cache for recently evaluated destinations (performance optimization)
    private var destinationCache: [String: FilterResult] = [:]
    private let cacheQueue = DispatchQueue(label: "com.privarion.packet-filter.cache", attributes: .concurrent)
    
    /// Maximum cache size
    private let maxCacheSize = 1000
    
    // MARK: - Initialization
    
    /// Initialize packet filter with dependencies
    /// - Parameters:
    ///   - policyEngine: Protection policy engine for policy evaluation
    ///   - blocklistManager: Blocklist manager for domain/IP blocking
    ///   - dnsFilter: DNS filter for domain resolution
    internal init(
        policyEngine: ProtectionPolicyEngine,
        blocklistManager: BlocklistManager,
        dnsFilter: DNSFilter
    ) {
        self.policyEngine = policyEngine
        self.blocklistManager = blocklistManager
        self.dnsFilter = dnsFilter
        
        logger.info("PacketFilter initialized")
    }
    
    /// Convenience initializer with default dependencies
    public convenience init() {
        let policyEngine = ProtectionPolicyEngine()
        let blocklistManager = BlocklistManager()
        let dnsFilter = DNSFilter()
        
        self.init(
            policyEngine: policyEngine,
            blocklistManager: blocklistManager,
            dnsFilter: dnsFilter
        )
    }
    
    // MARK: - Public Interface
    
    /// Filter a packet based on protection policies and blocklists
    /// - Parameters:
    ///   - packet: Raw packet data
    ///   - protocol: IP protocol number (4 for IPv4, 6 for IPv6)
    /// - Returns: FilterResult indicating whether to allow, drop, or modify the packet
    /// - Requirement: 3.6, 3.7, 3.8
    public func filterPacket(_ packet: Data, protocol: Int) async -> FilterResult {
        // Extract destination from packet
        guard let destination = extractDestination(packet) else {
            // If we can't parse the packet, allow it to avoid breaking connectivity
            logger.debug("Could not extract destination from packet, allowing through")
            return .allow(packet)
        }
        
        // Check cache first for performance
        let cacheKey = "\(destination.ip):\(destination.port)"
        if let cachedResult = getCachedResult(for: cacheKey) {
            logger.debug("Cache hit for destination", metadata: ["destination": "\(cacheKey)"])
            return cachedResult
        }
        
        // Evaluate packet against filtering rules
        let result = await evaluatePacket(packet, destination: destination)
        
        // Cache the result
        cacheResult(result, for: cacheKey)
        
        return result
    }
    
    /// Extract destination IP and port from packet
    /// Parses IPv4/IPv6 headers and TCP/UDP headers
    /// - Parameter packet: Raw packet data
    /// - Returns: NetworkDestination with IP and port, or nil if parsing fails
    /// - Requirement: 3.6
    public func extractDestination(_ packet: Data) -> NetworkDestination? {
        guard packet.count >= 20 else {
            return nil // Minimum IPv4 header size
        }
        
        // Get IP version from first byte (upper 4 bits)
        let versionByte = packet[0]
        let version = (versionByte >> 4) & 0x0F
        
        if version == 4 {
            return extractIPv4Destination(from: packet)
        } else if version == 6 {
            return extractIPv6Destination(from: packet)
        }
        
        return nil
    }
    
    /// Clear the destination cache
    public func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.destinationCache.removeAll()
        }
        logger.debug("Packet filter cache cleared")
    }
    
    // MARK: - Private Methods
    
    /// Evaluate packet against protection policies and blocklists
    /// - Parameters:
    ///   - packet: Raw packet data
    ///   - destination: Extracted network destination
    /// - Returns: FilterResult indicating filtering decision
    /// - Requirement: 3.6, 3.7, 3.8
    private func evaluatePacket(_ packet: Data, destination: NetworkDestination) async -> FilterResult {
        // Try to resolve domain from IP (reverse DNS lookup or DNS cache)
        if let domain = await resolveDomain(for: destination.ip) {
            // Check if domain is a tracking domain
            if blocklistManager.shouldBlockDomain(domain) {
                logger.info("Dropping packet to tracking domain", metadata: [
                    "domain": "\(domain)",
                    "ip": "\(destination.ip)",
                    "port": "\(destination.port)"
                ])
                return .drop // Requirement 3.7
            }
            
            // Check if domain is a fingerprinting domain
            if dnsFilter.isFingerprintingDomain(domain) {
                logger.info("Modifying packet to fingerprinting domain", metadata: [
                    "domain": "\(domain)",
                    "ip": "\(destination.ip)",
                    "port": "\(destination.port)"
                ])
                
                // Modify packet by injecting fake data or redirecting
                let modifiedPacket = modifyPacketForFingerprinting(packet, destination: destination)
                return .modify(modifiedPacket) // Requirement 3.8
            }
        }
        
        // Check protection policy for the destination
        // Note: In a full implementation, we would need to know which process is sending the packet
        // For now, we apply general filtering rules
        
        // Allow packet through
        logger.debug("Allowing packet", metadata: [
            "ip": "\(destination.ip)",
            "port": "\(destination.port)",
            "protocol": "\(destination.networkProtocol)"
        ])
        return .allow(packet)
    }
    
    /// Extract destination from IPv4 packet
    /// - Parameter packet: Raw packet data
    /// - Returns: NetworkDestination or nil if parsing fails
    private func extractIPv4Destination(from packet: Data) -> NetworkDestination? {
        guard packet.count >= 20 else { return nil }
        
        // IPv4 header: bytes 0-19 (minimum)
        // Destination IP: bytes 16-19
        let destIPBytes = packet[16..<20]
        let destIP = destIPBytes.map { String($0) }.joined(separator: ".")
        
        // Get protocol from byte 9
        let protocolByte = packet[9]
        
        // Get header length (lower 4 bits of byte 0, in 32-bit words)
        let ihl = Int(packet[0] & 0x0F) * 4
        
        // Extract port from TCP/UDP header if present
        var port: UInt16 = 0
        if packet.count >= ihl + 4 {
            // Destination port is at bytes 2-3 of TCP/UDP header
            let portBytes = packet[(ihl + 2)..<(ihl + 4)]
            port = UInt16(portBytes[portBytes.startIndex]) << 8 | UInt16(portBytes[portBytes.startIndex + 1])
        }
        
        let protocolType: PrivarionSharedModels.NetworkProtocol
        switch protocolByte {
        case 6: protocolType = .tcp
        case 17: protocolType = .udp
        case 1: protocolType = .icmp
        default: protocolType = .tcp // Default to TCP for unknown protocols
        }
        
        return NetworkDestination(ip: destIP, port: Int(port), protocol: protocolType)
    }
    
    /// Extract destination from IPv6 packet
    /// - Parameter packet: Raw packet data
    /// - Returns: NetworkDestination or nil if parsing fails
    private func extractIPv6Destination(from packet: Data) -> NetworkDestination? {
        guard packet.count >= 40 else { return nil }
        
        // IPv6 header: bytes 0-39
        // Destination IP: bytes 24-39 (16 bytes)
        let destIPBytes = packet[24..<40]
        
        // Format IPv6 address as hex groups
        var ipGroups: [String] = []
        for i in stride(from: 0, to: 16, by: 2) {
            let group = UInt16(destIPBytes[destIPBytes.startIndex + i]) << 8 | 
                       UInt16(destIPBytes[destIPBytes.startIndex + i + 1])
            ipGroups.append(String(format: "%x", group))
        }
        let destIP = ipGroups.joined(separator: ":")
        
        // Get next header (protocol) from byte 6
        let nextHeader = packet[6]
        
        // Extract port from TCP/UDP header if present
        var port: UInt16 = 0
        if packet.count >= 44 {
            // Destination port is at bytes 2-3 of TCP/UDP header (after IPv6 header)
            let portBytes = packet[42..<44]
            port = UInt16(portBytes[portBytes.startIndex]) << 8 | UInt16(portBytes[portBytes.startIndex + 1])
        }
        
        let protocolType: PrivarionSharedModels.NetworkProtocol
        switch nextHeader {
        case 6: protocolType = .tcp
        case 17: protocolType = .udp
        case 58: protocolType = .icmp // ICMPv6
        default: protocolType = .tcp
        }
        
        return NetworkDestination(ip: destIP, port: Int(port), protocol: protocolType)
    }
    
    /// Resolve domain name from IP address
    /// Uses DNS cache or performs reverse DNS lookup
    /// - Parameter ip: IP address to resolve
    /// - Returns: Domain name if found, nil otherwise
    private func resolveDomain(for ip: String) async -> String? {
        // In a full implementation, this would:
        // 1. Check DNS cache for recent queries to this IP
        // 2. Perform reverse DNS lookup if needed
        // 3. Cache the result
        
        // For now, we return nil and rely on IP-based blocking
        // This will be enhanced in future tasks
        return nil
    }
    
    /// Modify packet for fingerprinting domain
    /// - Parameters:
    ///   - packet: Original packet data
    ///   - destination: Network destination
    /// - Returns: Modified packet data
    /// - Requirement: 3.8
    private func modifyPacketForFingerprinting(_ packet: Data, destination: NetworkDestination) -> Data {
        // In a full implementation, this would:
        // 1. Parse the packet payload
        // 2. Inject fake fingerprinting data
        // 3. Recalculate checksums
        // 4. Return modified packet
        
        // For now, we return the original packet
        // This will be enhanced in future tasks when we implement
        // deep packet inspection and payload modification
        return packet
    }
    
    /// Get cached filter result for destination
    /// - Parameter key: Cache key (ip:port)
    /// - Returns: Cached FilterResult or nil
    private func getCachedResult(for key: String) -> FilterResult? {
        return cacheQueue.sync {
            destinationCache[key]
        }
    }
    
    /// Cache filter result for destination
    /// - Parameters:
    ///   - result: FilterResult to cache
    ///   - key: Cache key (ip:port)
    private func cacheResult(_ result: FilterResult, for key: String) {
        cacheQueue.async(flags: .barrier) {
            // Evict oldest entries if cache is full
            if self.destinationCache.count >= self.maxCacheSize {
                // Simple eviction: remove first entry
                // In production, use LRU cache
                if let firstKey = self.destinationCache.keys.first {
                    self.destinationCache.removeValue(forKey: firstKey)
                }
            }
            
            self.destinationCache[key] = result
        }
    }
}

/// Network destination information extracted from packet
public struct NetworkDestination {
    public let ip: String
    public let port: Int
    public let networkProtocol: PrivarionSharedModels.NetworkProtocol
    
    public init(ip: String, port: Int, protocol: PrivarionSharedModels.NetworkProtocol) {
        self.ip = ip
        self.port = port
        self.networkProtocol = `protocol`
    }
}
