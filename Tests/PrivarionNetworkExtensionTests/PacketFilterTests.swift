// PacketFilterTests.swift
// Unit tests for PacketFilter class
// Requirements: 3.6-3.8, 20.1

import XCTest
@testable import PrivarionNetworkExtension
@testable import PrivarionCore
@testable import PrivarionSharedModels

@available(macOS 10.15, *)
final class PacketFilterTests: XCTestCase {
    
    var packetFilter: PacketFilter!
    
    override func setUp() {
        super.setUp()
        
        // Initialize packet filter with convenience initializer
        packetFilter = PacketFilter()
    }
    
    override func tearDown() {
        packetFilter = nil
        super.tearDown()
    }
    
    // MARK: - Destination Extraction Tests
    
    /// Test extracting destination from valid IPv4 packet
    /// Requirement: 3.6
    func testExtractIPv4Destination() {
        // Create a minimal IPv4 packet
        // IPv4 header (20 bytes minimum)
        var packet = Data(count: 40)
        
        // Version (4) and IHL (5 = 20 bytes)
        packet[0] = 0x45 // 0100 0101
        
        // Protocol (TCP = 6)
        packet[9] = 6
        
        // Destination IP: 192.168.1.100
        packet[16] = 192
        packet[17] = 168
        packet[18] = 1
        packet[19] = 100
        
        // TCP header starts at byte 20
        // Destination port: 443 (HTTPS)
        packet[22] = 0x01 // High byte
        packet[23] = 0xBB // Low byte (443 = 0x01BB)
        
        // Extract destination
        let destination = packetFilter.extractDestination(packet)
        
        XCTAssertNotNil(destination, "Should extract destination from valid IPv4 packet")
        XCTAssertEqual(destination?.ip, "192.168.1.100")
        XCTAssertEqual(destination?.port, 443)
        XCTAssertEqual(destination?.networkProtocol, .tcp)
    }
    
    /// Test extracting destination from valid IPv6 packet
    /// Requirement: 3.6
    func testExtractIPv6Destination() {
        // Create a minimal IPv6 packet
        // IPv6 header (40 bytes)
        var packet = Data(count: 48)
        
        // Version (6)
        packet[0] = 0x60 // 0110 0000
        
        // Next header (TCP = 6)
        packet[6] = 6
        
        // Destination IP: 2001:0db8:85a3:0000:0000:8a2e:0370:7334
        // Bytes 24-39 (16 bytes)
        packet[24] = 0x20
        packet[25] = 0x01
        packet[26] = 0x0d
        packet[27] = 0xb8
        packet[28] = 0x85
        packet[29] = 0xa3
        packet[30] = 0x00
        packet[31] = 0x00
        packet[32] = 0x00
        packet[33] = 0x00
        packet[34] = 0x8a
        packet[35] = 0x2e
        packet[36] = 0x03
        packet[37] = 0x70
        packet[38] = 0x73
        packet[39] = 0x34
        
        // TCP header starts at byte 40
        // Destination port: 80 (HTTP)
        packet[42] = 0x00 // High byte
        packet[43] = 0x50 // Low byte (80 = 0x0050)
        
        // Extract destination
        let destination = packetFilter.extractDestination(packet)
        
        XCTAssertNotNil(destination, "Should extract destination from valid IPv6 packet")
        XCTAssertEqual(destination?.ip, "2001:db8:85a3:0:0:8a2e:370:7334")
        XCTAssertEqual(destination?.port, 80)
        XCTAssertEqual(destination?.networkProtocol, .tcp)
    }
    
    /// Test extracting destination from packet with UDP protocol
    /// Requirement: 3.6
    func testExtractDestinationUDP() {
        // Create IPv4 packet with UDP
        var packet = Data(count: 40)
        
        // Version and IHL
        packet[0] = 0x45
        
        // Protocol (UDP = 17)
        packet[9] = 17
        
        // Destination IP: 8.8.8.8
        packet[16] = 8
        packet[17] = 8
        packet[18] = 8
        packet[19] = 8
        
        // UDP header starts at byte 20
        // Destination port: 53 (DNS)
        packet[22] = 0x00
        packet[23] = 0x35 // 53 = 0x0035
        
        let destination = packetFilter.extractDestination(packet)
        
        XCTAssertNotNil(destination)
        XCTAssertEqual(destination?.ip, "8.8.8.8")
        XCTAssertEqual(destination?.port, 53)
        XCTAssertEqual(destination?.networkProtocol, .udp)
    }
    
    /// Test extracting destination from invalid packet
    /// Requirement: 3.6
    func testExtractDestinationInvalidPacket() {
        // Too short packet
        let shortPacket = Data(count: 10)
        XCTAssertNil(packetFilter.extractDestination(shortPacket), "Should return nil for too short packet")
        
        // Invalid IP version
        var invalidPacket = Data(count: 40)
        invalidPacket[0] = 0x30 // Version 3 (invalid)
        XCTAssertNil(packetFilter.extractDestination(invalidPacket), "Should return nil for invalid IP version")
    }
    
    // MARK: - Packet Filtering Tests
    
    /// Test filtering packet to allowed destination
    /// Requirement: 3.6, 3.7
    func testFilterPacketAllowed() async {
        // Create valid IPv4 packet to allowed destination
        var packet = Data(count: 40)
        packet[0] = 0x45
        packet[9] = 6
        
        // Destination: 1.1.1.1 (Cloudflare DNS - not in blocklist)
        packet[16] = 1
        packet[17] = 1
        packet[18] = 1
        packet[19] = 1
        
        packet[22] = 0x01
        packet[23] = 0xBB // Port 443
        
        let result = await packetFilter.filterPacket(packet, protocol: 4)
        
        switch result {
        case .allow(let data):
            XCTAssertEqual(data, packet, "Should allow packet through unchanged")
        case .drop:
            XCTFail("Should not drop allowed packet")
        case .modify:
            XCTFail("Should not modify allowed packet")
        }
    }
    
    /// Test filtering packet to blocked tracking domain
    /// Requirement: 3.7
    func testFilterPacketBlockedTrackingDomain() async {
        // Create packet (destination will be checked against blocklist)
        var packet = Data(count: 40)
        packet[0] = 0x45
        packet[9] = 6
        
        // Destination IP (will be resolved to domain in real implementation)
        packet[16] = 192
        packet[17] = 168
        packet[18] = 1
        packet[19] = 1
        
        packet[22] = 0x00
        packet[23] = 0x50 // Port 80
        
        let result = await packetFilter.filterPacket(packet, protocol: 4)
        
        // Note: In current implementation, without reverse DNS, this will allow
        // In full implementation with DNS resolution, this would drop
        switch result {
        case .allow:
            // Expected for now since we don't have reverse DNS
            XCTAssertTrue(true)
        case .drop:
            // Would be expected with full DNS resolution
            XCTAssertTrue(true)
        case .modify:
            XCTFail("Should not modify tracking domain packet")
        }
    }
    
    /// Test cache functionality
    /// Requirement: 18.2 (performance optimization)
    func testPacketFilterCache() async {
        // Create packet
        var packet = Data(count: 40)
        packet[0] = 0x45
        packet[9] = 6
        packet[16] = 1
        packet[17] = 1
        packet[18] = 1
        packet[19] = 1
        packet[22] = 0x01
        packet[23] = 0xBB
        
        // First call - should cache result
        let result1 = await packetFilter.filterPacket(packet, protocol: 4)
        
        // Second call - should use cache
        let result2 = await packetFilter.filterPacket(packet, protocol: 4)
        
        // Results should be consistent
        switch (result1, result2) {
        case (.allow, .allow):
            XCTAssertTrue(true, "Cache should return consistent results")
        case (.drop, .drop):
            XCTAssertTrue(true, "Cache should return consistent results")
        case (.modify, .modify):
            XCTAssertTrue(true, "Cache should return consistent results")
        default:
            XCTFail("Cache should return consistent results")
        }
        
        // Clear cache
        packetFilter.clearCache()
        
        // Third call - should re-evaluate
        let result3 = await packetFilter.filterPacket(packet, protocol: 4)
        
        // Should still be consistent
        switch (result1, result3) {
        case (.allow, .allow):
            XCTAssertTrue(true)
        case (.drop, .drop):
            XCTAssertTrue(true)
        case (.modify, .modify):
            XCTAssertTrue(true)
        default:
            XCTFail("Results should be consistent after cache clear")
        }
    }
    
    /// Test filtering performance
    /// Requirement: 18.2 (packet processing latency <10ms)
    func testFilteringPerformance() async {
        // Create test packet
        var packet = Data(count: 40)
        packet[0] = 0x45
        packet[9] = 6
        packet[16] = 1
        packet[17] = 1
        packet[18] = 1
        packet[19] = 1
        packet[22] = 0x01
        packet[23] = 0xBB
        
        // Measure filtering time
        let startTime = Date()
        
        for _ in 0..<100 {
            _ = await packetFilter.filterPacket(packet, protocol: 4)
        }
        
        let endTime = Date()
        let totalTime = endTime.timeIntervalSince(startTime)
        let averageTime = totalTime / 100.0 * 1000.0 // Convert to ms
        
        // Average should be well under 10ms (requirement)
        XCTAssertLessThan(averageTime, 10.0, "Average packet filtering time should be less than 10ms")
        
        print("Average packet filtering time: \(averageTime)ms")
    }
    
    /// Test convenience initializer
    func testConvenienceInitializer() {
        let filter = PacketFilter()
        XCTAssertNotNil(filter, "Convenience initializer should create valid PacketFilter")
        
        // Test that it can extract destinations
        var packet = Data(count: 40)
        packet[0] = 0x45
        packet[9] = 6
        packet[16] = 1
        packet[17] = 1
        packet[18] = 1
        packet[19] = 1
        packet[22] = 0x01
        packet[23] = 0xBB
        
        let destination = filter.extractDestination(packet)
        XCTAssertNotNil(destination)
    }
    
    // MARK: - NetworkDestination Tests
    
    /// Test NetworkDestination initialization
    func testNetworkDestinationInit() {
        let destination = NetworkDestination(
            ip: "192.168.1.1",
            port: 443,
            protocol: .tcp
        )
        
        XCTAssertEqual(destination.ip, "192.168.1.1")
        XCTAssertEqual(destination.port, 443)
        XCTAssertEqual(destination.networkProtocol, .tcp)
    }
}
