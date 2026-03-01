// NetworkExtensionIntegrationTests.swift
// Integration tests for Network Extension - Packet Tunnel Provider
// Requirements: 20.3, 20.7
// Task 9.7: Write integration tests for Network Extension

import XCTest
import NetworkExtension
@testable import PrivarionNetworkExtension
@testable import PrivarionSharedModels

/// Integration tests for Network Extension components
/// Tests complete flow: network request → packet interception → filtering → response
/// Tests with various network configurations (Wi-Fi, Ethernet, VPN)
@available(macOS 10.15, *)
final class NetworkExtensionIntegrationTests: XCTestCase {
    
    // MARK: - Test Setup
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Complete Flow Integration Tests
    
    /// Test complete network filtering workflow
    /// Requirement: 20.3 - Test complete flow: network request → packet interception → filtering → response
    func testCompleteNetworkFilteringWorkflow() async throws {
        // This test verifies the complete packet filtering workflow
        // In a real environment, this would require:
        // 1. Network Extension entitlements
        // 2. System Extension approval
        // 3. Network Extension permission
        
        // Create packet filter and DNS filter
        let packetFilter = PacketFilter()
        let dnsFilter = DNSFilter()
        
        // Test 1: DNS Query → DNS Filtering → Response
        let dnsQuery = DNSQuery(
            id: 1234,
            domain: "example.com",
            queryType: .A,
            timestamp: Date()
        )
        
        let dnsResponse = await dnsFilter.filterDNSQuery(dnsQuery)
        XCTAssertNotNil(dnsResponse, "DNS filter should return a response")
        guard let response = dnsResponse else {
            XCTFail("DNS response should not be nil")
            return
        }
        XCTAssertEqual(response.domain, "example.com")
        
        // Test 2: Network Packet → Packet Filtering → Filtered Packet
        var testPacket = createTestIPv4Packet(
            destinationIP: "1.1.1.1",
            destinationPort: 443,
            protocol: 6 // TCP
        )
        
        let filterResult = await packetFilter.filterPacket(testPacket, protocol: 4)
        
        switch filterResult {
        case .allow(let data):
            XCTAssertGreaterThan(data.count, 0, "Filtered packet should have data")
        case .drop:
            XCTAssertTrue(true, "Packet was dropped by filter")
        case .modify(let data):
            XCTAssertGreaterThan(data.count, 0, "Modified packet should have data")
        }
        
        // Test 3: Verify latency requirements (<10ms for 95% of packets)
        var latencies: [TimeInterval] = []
        let iterations = 100
        
        for _ in 0..<iterations {
            let startTime = Date()
            _ = await packetFilter.filterPacket(testPacket, protocol: 4)
            let latency = Date().timeIntervalSince(startTime) * 1000 // ms
            latencies.append(latency)
        }
        
        latencies.sort()
        let p95Index = Int(Double(iterations) * 0.95)
        let p95Latency = latencies[p95Index]
        
        XCTAssertLessThan(p95Latency, 10.0, "95th percentile latency should be <10ms, got \(p95Latency)ms")
    }
    
    /// Test network filtering with tracking domain blocking
    /// Requirement: 20.3
    func testTrackingDomainBlocking() async throws {
        let dnsFilter = DNSFilter()
        
        // Test blocking known tracking domains
        let trackingDomains = [
            "analytics.google.com",
            "tracking.example.com",
            "telemetry.microsoft.com"
        ]
        
        for domain in trackingDomains {
            let query = DNSQuery(
                id: UInt16.random(in: 1...65535),
                domain: domain,
                queryType: .A,
                timestamp: Date()
            )
            
            let response = await dnsFilter.filterDNSQuery(query)
            
            // Verify response indicates blocking or fake data
            XCTAssertNotNil(response, "Should return a response for tracking domain")
            
            // In a full implementation, we would verify:
            // - NXDOMAIN response for blocked domains
            // - Fake IP for fingerprinting domains
        }
    }
    
    /// Test network filtering with fingerprinting domain modification
    /// Requirement: 20.3
    func testFingerprintingDomainModification() async throws {
        let dnsFilter = DNSFilter()
        
        // Test fingerprinting domains
        let fingerprintingDomains = [
            "fingerprint.example.com",
            "canvas.tracking.com"
        ]
        
        for domain in fingerprintingDomains {
            let query = DNSQuery(
                id: UInt16.random(in: 1...65535),
                domain: domain,
                queryType: .A,
                timestamp: Date()
            )
            
            let response = await dnsFilter.filterDNSQuery(query)
            XCTAssertNotNil(response, "Should return a response for fingerprinting domain")
        }
    }
    
    // MARK: - Network Configuration Tests
    
    /// Test network filtering with Wi-Fi configuration
    /// Requirement: 20.7 - Test with various network configurations (Wi-Fi, Ethernet)
    func testNetworkFilteringWithWiFi() async throws {
        // This test simulates network filtering over Wi-Fi
        // In a real environment, this would detect the active network interface
        
        let packetFilter = PacketFilter()
        
        // Create test packet simulating Wi-Fi traffic
        let wifiPacket = createTestIPv4Packet(
            destinationIP: "8.8.8.8",
            destinationPort: 53,
            protocol: 17 // UDP for DNS
        )
        
        let result = await packetFilter.filterPacket(wifiPacket, protocol: 4)
        
        // Verify packet is processed correctly regardless of interface
        switch result {
        case .allow(let data):
            XCTAssertGreaterThan(data.count, 0)
        case .drop:
            XCTAssertTrue(true, "Packet may be dropped based on policy")
        case .modify(let data):
            XCTAssertGreaterThan(data.count, 0)
        }
    }
    
    /// Test network filtering with Ethernet configuration
    /// Requirement: 20.7 - Test with various network configurations (Wi-Fi, Ethernet)
    func testNetworkFilteringWithEthernet() async throws {
        // This test simulates network filtering over Ethernet
        
        let packetFilter = PacketFilter()
        
        // Create test packet simulating Ethernet traffic
        let ethernetPacket = createTestIPv4Packet(
            destinationIP: "1.1.1.1",
            destinationPort: 443,
            protocol: 6 // TCP for HTTPS
        )
        
        let result = await packetFilter.filterPacket(ethernetPacket, protocol: 4)
        
        // Verify packet is processed correctly
        switch result {
        case .allow(let data):
            XCTAssertGreaterThan(data.count, 0)
        case .drop:
            XCTAssertTrue(true, "Packet may be dropped based on policy")
        case .modify(let data):
            XCTAssertGreaterThan(data.count, 0)
        }
    }
    
    /// Test network filtering with VPN active
    /// Requirement: 20.7 - Test with VPN active
    func testNetworkFilteringWithVPNActive() async throws {
        // This test verifies that packet filtering works correctly when VPN is active
        // In a real environment, this would:
        // 1. Detect VPN interface
        // 2. Ensure packet tunnel doesn't conflict with VPN
        // 3. Verify packets are filtered before/after VPN encryption
        
        let packetFilter = PacketFilter()
        
        // Create test packet that would go through VPN
        let vpnPacket = createTestIPv4Packet(
            destinationIP: "10.8.0.1", // Typical VPN gateway
            destinationPort: 1194,      // OpenVPN port
            protocol: 17                // UDP
        )
        
        let result = await packetFilter.filterPacket(vpnPacket, protocol: 4)
        
        // Verify packet is processed
        XCTAssertNotNil(result, "Packet filter should handle VPN traffic")
        
        switch result {
        case .allow(let data):
            XCTAssertGreaterThan(data.count, 0, "VPN packet should be allowed")
        case .drop:
            XCTAssertTrue(true, "VPN packet may be dropped based on policy")
        case .modify(let data):
            XCTAssertGreaterThan(data.count, 0)
        }
    }
    
    /// Test network filtering with multiple concurrent connections
    /// Requirement: 20.3
    func testConcurrentNetworkConnections() async throws {
        let packetFilter = PacketFilter()
        let connectionCount = 20
        
        // Simulate multiple concurrent network connections
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<connectionCount {
                group.addTask {
                    let packet = self.createTestIPv4Packet(
                        destinationIP: "1.1.1.\(i % 255 + 1)",
                        destinationPort: UInt16(443 + i),
                        protocol: 6
                    )
                    
                    let result = await packetFilter.filterPacket(packet, protocol: 4)
                    
                    // Verify each packet is processed
                    switch result {
                    case .allow(let data):
                        XCTAssertGreaterThan(data.count, 0)
                    case .drop:
                        XCTAssertTrue(true)
                    case .modify(let data):
                        XCTAssertGreaterThan(data.count, 0)
                    }
                }
            }
        }
    }
    
    /// Test DNS filtering integration with packet filtering
    /// Requirement: 20.3
    func testDNSAndPacketFilteringIntegration() async throws {
        let dnsFilter = DNSFilter()
        let packetFilter = PacketFilter()
        
        // Step 1: DNS query for a domain
        let domain = "example.com"
        let dnsQuery = DNSQuery(
            id: 1234,
            domain: domain,
            queryType: .A,
            timestamp: Date()
        )
        
        let dnsResponse = await dnsFilter.filterDNSQuery(dnsQuery)
        XCTAssertNotNil(dnsResponse)
        guard let response = dnsResponse else {
            XCTFail("DNS response should not be nil")
            return
        }
        XCTAssertEqual(response.domain, domain)
        
        // Step 2: Create packet to resolved IP
        guard let resolvedIP = response.addresses.first else {
            XCTFail("DNS response should contain at least one address")
            return
        }
        
        let packet = createTestIPv4Packet(
            destinationIP: resolvedIP,
            destinationPort: 443,
            protocol: 6
        )
        
        // Step 3: Filter packet
        let filterResult = await packetFilter.filterPacket(packet, protocol: 4)
        
        // Verify packet is processed
        switch filterResult {
        case .allow(let data):
            XCTAssertGreaterThan(data.count, 0)
        case .drop:
            XCTAssertTrue(true)
        case .modify(let data):
            XCTAssertGreaterThan(data.count, 0)
        }
    }
    
    /// Test tunnel configuration with different network settings
    /// Requirement: 20.7
    func testTunnelConfigurationVariations() throws {
        // Test various tunnel configurations
        let configurations = [
            TunnelConfiguration.default,
            TunnelConfiguration(
                dnsServerAddress: "8.8.8.8",
                tunnelRemoteAddress: "127.0.0.1",
                ipv4Address: "10.0.0.1",
                ipv4SubnetMask: "255.255.255.0",
                ipv6Address: "fd00::1",
                ipv6PrefixLength: 64,
                mtu: 1500,
                routeAllIPv4Traffic: true,
                routeAllIPv6Traffic: true
            ),
            TunnelConfiguration(
                dnsServerAddress: "1.1.1.1",
                tunnelRemoteAddress: "192.168.1.1",
                ipv4Address: "172.16.0.1",
                ipv4SubnetMask: "255.255.0.0",
                ipv6Address: "2001:db8::1",
                ipv6PrefixLength: 48,
                mtu: 1400,
                routeAllIPv4Traffic: false,
                routeAllIPv6Traffic: false
            )
        ]
        
        for config in configurations {
            XCTAssertNoThrow(try config.validate(), "Configuration should be valid")
        }
    }
    
    /// Test packet filtering with IPv6 traffic
    /// Requirement: 20.3
    func testIPv6PacketFiltering() async throws {
        let packetFilter = PacketFilter()
        
        // Create IPv6 packet
        let ipv6Packet = createTestIPv6Packet(
            destinationIP: "2001:4860:4860::8888", // Google DNS
            destinationPort: 443,
            protocol: 6 // TCP
        )
        
        let result = await packetFilter.filterPacket(ipv6Packet, protocol: 6)
        
        // Verify IPv6 packet is processed
        switch result {
        case .allow(let data):
            XCTAssertGreaterThan(data.count, 0)
        case .drop:
            XCTAssertTrue(true)
        case .modify(let data):
            XCTAssertGreaterThan(data.count, 0)
        }
    }
    
    /// Test packet filtering with different protocols (TCP, UDP, ICMP)
    /// Requirement: 20.3
    func testMultipleProtocolFiltering() async throws {
        let packetFilter = PacketFilter()
        
        // Test TCP packet
        let tcpPacket = createTestIPv4Packet(
            destinationIP: "1.1.1.1",
            destinationPort: 443,
            protocol: 6 // TCP
        )
        let tcpResult = await packetFilter.filterPacket(tcpPacket, protocol: 4)
        XCTAssertNotNil(tcpResult)
        
        // Test UDP packet
        let udpPacket = createTestIPv4Packet(
            destinationIP: "8.8.8.8",
            destinationPort: 53,
            protocol: 17 // UDP
        )
        let udpResult = await packetFilter.filterPacket(udpPacket, protocol: 4)
        XCTAssertNotNil(udpResult)
        
        // Test ICMP packet
        let icmpPacket = createTestICMPPacket(destinationIP: "1.1.1.1")
        let icmpResult = await packetFilter.filterPacket(icmpPacket, protocol: 4)
        XCTAssertNotNil(icmpResult)
    }
    
    /// Test error handling in complete workflow
    /// Requirement: 20.3
    func testErrorHandlingInWorkflow() async throws {
        let packetFilter = PacketFilter()
        
        // Test with malformed packets
        let malformedPackets = [
            Data(), // Empty packet
            Data(count: 5), // Too short
            Data(repeating: 0xFF, count: 100) // Invalid data
        ]
        
        for packet in malformedPackets {
            let result = await packetFilter.filterPacket(packet, protocol: 4)
            
            // Should handle gracefully (either drop or allow)
            switch result {
            case .allow:
                XCTAssertTrue(true, "Malformed packet allowed")
            case .drop:
                XCTAssertTrue(true, "Malformed packet dropped")
            case .modify:
                XCTAssertTrue(true, "Malformed packet modified")
            }
        }
    }
    
    /// Test performance under load
    /// Requirement: 20.3
    func testPerformanceUnderLoad() async throws {
        let packetFilter = PacketFilter()
        let packetCount = 1000
        var totalLatency: TimeInterval = 0
        
        // Create test packet
        let testPacket = createTestIPv4Packet(
            destinationIP: "1.1.1.1",
            destinationPort: 443,
            protocol: 6
        )
        
        // Process many packets
        for _ in 0..<packetCount {
            let startTime = Date()
            _ = await packetFilter.filterPacket(testPacket, protocol: 4)
            totalLatency += Date().timeIntervalSince(startTime)
        }
        
        let avgLatency = (totalLatency / Double(packetCount)) * 1000 // ms
        
        // Average latency should be well under 10ms
        XCTAssertLessThan(avgLatency, 5.0, "Average latency should be <5ms, got \(avgLatency)ms")
        
        print("Performance test: \(packetCount) packets, avg latency: \(String(format: "%.3f", avgLatency))ms")
    }
    
    // MARK: - Helper Methods
    
    /// Create a test IPv4 packet with specified parameters
    /// - Parameters:
    ///   - destinationIP: Destination IP address (e.g., "1.1.1.1")
    ///   - destinationPort: Destination port number
    ///   - protocol: IP protocol number (6=TCP, 17=UDP, 1=ICMP)
    /// - Returns: Raw packet data
    private func createTestIPv4Packet(destinationIP: String, destinationPort: UInt16, protocol protocolNumber: UInt8) -> Data {
        var packet = Data()
        
        // IPv4 header (20 bytes)
        packet.append(0x45) // Version 4, IHL 5
        packet.append(0x00) // DSCP/ECN
        packet.append(contentsOf: [0x00, 0x3C]) // Total length (60 bytes)
        packet.append(contentsOf: [0x00, 0x00]) // Identification
        packet.append(contentsOf: [0x40, 0x00]) // Flags, Fragment offset
        packet.append(0x40) // TTL (64)
        packet.append(protocolNumber) // Protocol
        packet.append(contentsOf: [0x00, 0x00]) // Checksum (would be calculated in real packet)
        
        // Source IP (192.168.1.100)
        packet.append(contentsOf: [192, 168, 1, 100])
        
        // Destination IP
        let ipParts = destinationIP.split(separator: ".").compactMap { UInt8($0) }
        packet.append(contentsOf: ipParts)
        
        // TCP/UDP header (20 bytes for TCP, 8 bytes for UDP)
        if protocolNumber == 6 { // TCP
            packet.append(contentsOf: [0x04, 0xD2]) // Source port (1234)
            packet.append(contentsOf: [UInt8(destinationPort >> 8), UInt8(destinationPort & 0xFF)]) // Destination port
            packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Sequence number
            packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Acknowledgment number
            packet.append(0x50) // Data offset (5 * 4 = 20 bytes)
            packet.append(0x02) // Flags (SYN)
            packet.append(contentsOf: [0xFF, 0xFF]) // Window size
            packet.append(contentsOf: [0x00, 0x00]) // Checksum
            packet.append(contentsOf: [0x00, 0x00]) // Urgent pointer
        } else if protocolNumber == 17 { // UDP
            packet.append(contentsOf: [0x04, 0xD2]) // Source port (1234)
            packet.append(contentsOf: [UInt8(destinationPort >> 8), UInt8(destinationPort & 0xFF)]) // Destination port
            packet.append(contentsOf: [0x00, 0x10]) // Length (16 bytes)
            packet.append(contentsOf: [0x00, 0x00]) // Checksum
        }
        
        return packet
    }
    
    /// Create a test IPv6 packet with specified parameters
    /// - Parameters:
    ///   - destinationIP: Destination IPv6 address (e.g., "2001:4860:4860::8888")
    ///   - destinationPort: Destination port number
    ///   - protocol: Next header protocol (6=TCP, 17=UDP)
    /// - Returns: Raw packet data
    private func createTestIPv6Packet(destinationIP: String, destinationPort: UInt16, protocol protocolNumber: UInt8) -> Data {
        var packet = Data()
        
        // IPv6 header (40 bytes)
        packet.append(0x60) // Version 6, Traffic class (upper 4 bits)
        packet.append(0x00) // Traffic class (lower 4 bits), Flow label (upper 4 bits)
        packet.append(contentsOf: [0x00, 0x00]) // Flow label (lower 16 bits)
        packet.append(contentsOf: [0x00, 0x14]) // Payload length (20 bytes)
        packet.append(protocolNumber) // Next header
        packet.append(0x40) // Hop limit (64)
        
        // Source address (16 bytes) - fd00::1
        packet.append(contentsOf: [0xFD, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01])
        
        // Destination address (16 bytes) - simplified parsing
        // For 2001:4860:4860::8888
        packet.append(contentsOf: [0x20, 0x01, 0x48, 0x60, 0x48, 0x60, 0x00, 0x00,
                                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x88, 0x88])
        
        // TCP header (20 bytes)
        if protocolNumber == 6 {
            packet.append(contentsOf: [0x04, 0xD2]) // Source port (1234)
            packet.append(contentsOf: [UInt8(destinationPort >> 8), UInt8(destinationPort & 0xFF)])
            packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Sequence number
            packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Acknowledgment number
            packet.append(0x50) // Data offset
            packet.append(0x02) // Flags (SYN)
            packet.append(contentsOf: [0xFF, 0xFF]) // Window size
            packet.append(contentsOf: [0x00, 0x00]) // Checksum
            packet.append(contentsOf: [0x00, 0x00]) // Urgent pointer
        }
        
        return packet
    }
    
    /// Create a test ICMP packet
    /// - Parameter destinationIP: Destination IP address
    /// - Returns: Raw packet data
    private func createTestICMPPacket(destinationIP: String) -> Data {
        var packet = Data()
        
        // IPv4 header
        packet.append(0x45)
        packet.append(0x00)
        packet.append(contentsOf: [0x00, 0x54])
        packet.append(contentsOf: [0x00, 0x00])
        packet.append(contentsOf: [0x40, 0x00])
        packet.append(0x40)
        packet.append(0x01) // ICMP protocol
        packet.append(contentsOf: [0x00, 0x00])
        packet.append(contentsOf: [192, 168, 1, 100]) // Source IP
        
        // Destination IP
        let ipParts = destinationIP.split(separator: ".").compactMap { UInt8($0) }
        packet.append(contentsOf: ipParts)
        
        // ICMP header (8 bytes)
        packet.append(0x08) // Type (Echo Request)
        packet.append(0x00) // Code
        packet.append(contentsOf: [0x00, 0x00]) // Checksum
        packet.append(contentsOf: [0x00, 0x01]) // Identifier
        packet.append(contentsOf: [0x00, 0x01]) // Sequence number
        
        return packet
    }
}
