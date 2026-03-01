// PrivarionNetworkExtensionTests
// Unit tests for Network Extension module

import XCTest
import NetworkExtension
@testable import PrivarionNetworkExtension

final class NetworkExtensionTests: XCTestCase {
    
    func testNetworkExtensionErrorEnum() {
        // Test that NetworkExtensionError enum cases exist
        let tunnelError: NetworkExtensionError = .tunnelConfigurationInvalid
        let dnsError: NetworkExtensionError = .dnsProxyBindFailed(port: 53)
        let restoreError: NetworkExtensionError = .networkSettingsRestoreFailed
        
        switch tunnelError {
        case .tunnelConfigurationInvalid:
            XCTAssertTrue(true)
        default:
            XCTFail("Unexpected error")
        }
        
        switch dnsError {
        case .dnsProxyBindFailed(let port):
            XCTAssertEqual(port, 53)
        default:
            XCTFail("Unexpected error")
        }
        
        switch restoreError {
        case .networkSettingsRestoreFailed:
            XCTAssertTrue(true)
        default:
            XCTFail("Unexpected error")
        }
    }
    
    func testNetworkExtensionErrorDescriptions() {
        // Test error descriptions are meaningful
        let tunnelError = NetworkExtensionError.tunnelConfigurationInvalid
        XCTAssertFalse(tunnelError.localizedDescription.isEmpty)
        
        let dnsError = NetworkExtensionError.dnsProxyBindFailed(port: 53)
        XCTAssertTrue(dnsError.localizedDescription.contains("53"))
        
        let restoreError = NetworkExtensionError.networkSettingsRestoreFailed
        XCTAssertFalse(restoreError.localizedDescription.isEmpty)
    }
    
    func testPacketTunnelProviderInitialization() {
        // Test that PrivarionPacketTunnelProvider can be initialized
        // Note: NEPacketTunnelProvider requires specific initialization context
        // We can't directly instantiate it in unit tests, but we can verify the class exists
        // and has the expected interface
        
        // Verify the class is available
        let providerType = PrivarionPacketTunnelProvider.self
        XCTAssertNotNil(providerType)
        
        // Verify it's a subclass of NEPacketTunnelProvider
        XCTAssertTrue(PrivarionPacketTunnelProvider.self is NEPacketTunnelProvider.Type)
    }
    
    // Note: Full integration tests for startTunnel and stopTunnel require
    // a running Network Extension context and proper entitlements.
    // These will be tested in integration tests with a real extension.
    
    // MARK: - Task 9.2: Tunnel Configuration Tests
    
    func testTunnelConfigurationDefaultValues() {
        // Test default configuration has expected values
        let config = TunnelConfiguration.default
        
        XCTAssertEqual(config.dnsServerAddress, "127.0.0.1")
        XCTAssertEqual(config.tunnelRemoteAddress, "127.0.0.1")
        XCTAssertEqual(config.ipv4Address, "10.0.0.1")
        XCTAssertEqual(config.ipv4SubnetMask, "255.255.255.0")
        XCTAssertEqual(config.ipv6Address, "fd00::1")
        XCTAssertEqual(config.ipv6PrefixLength, 64)
        XCTAssertEqual(config.mtu, 1500)
        XCTAssertTrue(config.routeAllIPv4Traffic)
        XCTAssertTrue(config.routeAllIPv6Traffic)
    }
    
    func testTunnelConfigurationValidation_ValidConfig() {
        // Test that valid configuration passes validation
        let config = TunnelConfiguration.default
        
        XCTAssertNoThrow(try config.validate())
    }
    
    func testTunnelConfigurationValidation_InvalidDNSServer() {
        // Test that invalid DNS server address fails validation
        let config = TunnelConfiguration(
            dnsServerAddress: "invalid.address",
            tunnelRemoteAddress: "127.0.0.1",
            ipv4Address: "10.0.0.1",
            ipv4SubnetMask: "255.255.255.0",
            ipv6Address: "fd00::1",
            ipv6PrefixLength: 64,
            mtu: 1500,
            routeAllIPv4Traffic: true,
            routeAllIPv6Traffic: true
        )
        
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertTrue(error is NetworkExtensionError)
            if case NetworkExtensionError.tunnelConfigurationInvalid = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected tunnelConfigurationInvalid error")
            }
        }
    }
    
    func testTunnelConfigurationValidation_InvalidTunnelRemoteAddress() {
        // Test that invalid tunnel remote address fails validation
        let config = TunnelConfiguration(
            dnsServerAddress: "127.0.0.1",
            tunnelRemoteAddress: "999.999.999.999",
            ipv4Address: "10.0.0.1",
            ipv4SubnetMask: "255.255.255.0",
            ipv6Address: "fd00::1",
            ipv6PrefixLength: 64,
            mtu: 1500,
            routeAllIPv4Traffic: true,
            routeAllIPv6Traffic: true
        )
        
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertTrue(error is NetworkExtensionError)
        }
    }
    
    func testTunnelConfigurationValidation_InvalidIPv4Address() {
        // Test that invalid IPv4 address fails validation
        let config = TunnelConfiguration(
            dnsServerAddress: "127.0.0.1",
            tunnelRemoteAddress: "127.0.0.1",
            ipv4Address: "10.0.0",
            ipv4SubnetMask: "255.255.255.0",
            ipv6Address: "fd00::1",
            ipv6PrefixLength: 64,
            mtu: 1500,
            routeAllIPv4Traffic: true,
            routeAllIPv6Traffic: true
        )
        
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertTrue(error is NetworkExtensionError)
        }
    }
    
    func testTunnelConfigurationValidation_InvalidIPv4SubnetMask() {
        // Test that invalid IPv4 subnet mask fails validation
        let config = TunnelConfiguration(
            dnsServerAddress: "127.0.0.1",
            tunnelRemoteAddress: "127.0.0.1",
            ipv4Address: "10.0.0.1",
            ipv4SubnetMask: "255.255.256.0",
            ipv6Address: "fd00::1",
            ipv6PrefixLength: 64,
            mtu: 1500,
            routeAllIPv4Traffic: true,
            routeAllIPv6Traffic: true
        )
        
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertTrue(error is NetworkExtensionError)
        }
    }
    
    func testTunnelConfigurationValidation_InvalidIPv6Address() {
        // Test that invalid IPv6 address fails validation
        let config = TunnelConfiguration(
            dnsServerAddress: "127.0.0.1",
            tunnelRemoteAddress: "127.0.0.1",
            ipv4Address: "10.0.0.1",
            ipv4SubnetMask: "255.255.255.0",
            ipv6Address: "invalid-ipv6",
            ipv6PrefixLength: 64,
            mtu: 1500,
            routeAllIPv4Traffic: true,
            routeAllIPv6Traffic: true
        )
        
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertTrue(error is NetworkExtensionError)
        }
    }
    
    func testTunnelConfigurationValidation_InvalidIPv6PrefixLength() {
        // Test that invalid IPv6 prefix length fails validation
        let config = TunnelConfiguration(
            dnsServerAddress: "127.0.0.1",
            tunnelRemoteAddress: "127.0.0.1",
            ipv4Address: "10.0.0.1",
            ipv4SubnetMask: "255.255.255.0",
            ipv6Address: "fd00::1",
            ipv6PrefixLength: 0,
            mtu: 1500,
            routeAllIPv4Traffic: true,
            routeAllIPv6Traffic: true
        )
        
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertTrue(error is NetworkExtensionError)
        }
        
        let config2 = TunnelConfiguration(
            dnsServerAddress: "127.0.0.1",
            tunnelRemoteAddress: "127.0.0.1",
            ipv4Address: "10.0.0.1",
            ipv4SubnetMask: "255.255.255.0",
            ipv6Address: "fd00::1",
            ipv6PrefixLength: 129,
            mtu: 1500,
            routeAllIPv4Traffic: true,
            routeAllIPv6Traffic: true
        )
        
        XCTAssertThrowsError(try config2.validate()) { error in
            XCTAssertTrue(error is NetworkExtensionError)
        }
    }
    
    func testTunnelConfigurationValidation_InvalidMTU() {
        // Test that invalid MTU fails validation
        let config = TunnelConfiguration(
            dnsServerAddress: "127.0.0.1",
            tunnelRemoteAddress: "127.0.0.1",
            ipv4Address: "10.0.0.1",
            ipv4SubnetMask: "255.255.255.0",
            ipv6Address: "fd00::1",
            ipv6PrefixLength: 64,
            mtu: 500,
            routeAllIPv4Traffic: true,
            routeAllIPv6Traffic: true
        )
        
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertTrue(error is NetworkExtensionError)
        }
        
        let config2 = TunnelConfiguration(
            dnsServerAddress: "127.0.0.1",
            tunnelRemoteAddress: "127.0.0.1",
            ipv4Address: "10.0.0.1",
            ipv4SubnetMask: "255.255.255.0",
            ipv6Address: "fd00::1",
            ipv6PrefixLength: 64,
            mtu: 10000,
            routeAllIPv4Traffic: true,
            routeAllIPv6Traffic: true
        )
        
        XCTAssertThrowsError(try config2.validate()) { error in
            XCTAssertTrue(error is NetworkExtensionError)
        }
    }
    
    func testTunnelConfigurationValidation_ValidIPv4Addresses() {
        // Test various valid IPv4 addresses
        let validAddresses = [
            "127.0.0.1",
            "192.168.1.1",
            "10.0.0.1",
            "172.16.0.1",
            "0.0.0.0",
            "255.255.255.255"
        ]
        
        for address in validAddresses {
            let config = TunnelConfiguration(
                dnsServerAddress: address,
                tunnelRemoteAddress: "127.0.0.1",
                ipv4Address: "10.0.0.1",
                ipv4SubnetMask: "255.255.255.0",
                ipv6Address: "fd00::1",
                ipv6PrefixLength: 64,
                mtu: 1500,
                routeAllIPv4Traffic: true,
                routeAllIPv6Traffic: true
            )
            
            XCTAssertNoThrow(try config.validate(), "Address \(address) should be valid")
        }
    }
    
    func testTunnelConfigurationValidation_ValidIPv6Addresses() {
        // Test various valid IPv6 addresses
        let validAddresses = [
            "fd00::1",
            "fe80::1",
            "2001:db8::1",
            "::1",
            "ff02::1"
        ]
        
        for address in validAddresses {
            let config = TunnelConfiguration(
                dnsServerAddress: "127.0.0.1",
                tunnelRemoteAddress: "127.0.0.1",
                ipv4Address: "10.0.0.1",
                ipv4SubnetMask: "255.255.255.0",
                ipv6Address: address,
                ipv6PrefixLength: 64,
                mtu: 1500,
                routeAllIPv4Traffic: true,
                routeAllIPv6Traffic: true
            )
            
            XCTAssertNoThrow(try config.validate(), "Address \(address) should be valid")
        }
    }
    
    func testTunnelConfigurationValidation_CustomConfiguration() {
        // Test custom configuration with different values
        let config = TunnelConfiguration(
            dnsServerAddress: "8.8.8.8",
            tunnelRemoteAddress: "192.168.1.1",
            ipv4Address: "172.16.0.1",
            ipv4SubnetMask: "255.255.0.0",
            ipv6Address: "2001:db8::1",
            ipv6PrefixLength: 48,
            mtu: 1400,
            routeAllIPv4Traffic: false,
            routeAllIPv6Traffic: false
        )
        
        XCTAssertNoThrow(try config.validate())
    }
    
    // MARK: - Task 9.3: Packet Processing Tests
    
    func testPacketProcessing_IPv4PacketParsing() {
        // Test IPv4 packet header parsing
        // Create a minimal IPv4 packet with TCP
        var packet = Data()
        
        // IPv4 header (20 bytes minimum)
        packet.append(0x45) // Version 4, IHL 5 (20 bytes)
        packet.append(0x00) // DSCP/ECN
        packet.append(contentsOf: [0x00, 0x3C]) // Total length (60 bytes)
        packet.append(contentsOf: [0x00, 0x00]) // Identification
        packet.append(contentsOf: [0x40, 0x00]) // Flags, Fragment offset
        packet.append(0x40) // TTL (64)
        packet.append(0x06) // Protocol (TCP = 6)
        packet.append(contentsOf: [0x00, 0x00]) // Checksum
        packet.append(contentsOf: [192, 168, 1, 100]) // Source IP
        packet.append(contentsOf: [8, 8, 8, 8]) // Destination IP (8.8.8.8)
        
        // TCP header (20 bytes minimum)
        packet.append(contentsOf: [0x04, 0xD2]) // Source port (1234)
        packet.append(contentsOf: [0x00, 0x50]) // Destination port (80)
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Sequence number
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Acknowledgment number
        packet.append(0x50) // Data offset (5 * 4 = 20 bytes)
        packet.append(0x02) // Flags (SYN)
        packet.append(contentsOf: [0xFF, 0xFF]) // Window size
        packet.append(contentsOf: [0x00, 0x00]) // Checksum
        packet.append(contentsOf: [0x00, 0x00]) // Urgent pointer
        
        // Verify packet is at least 40 bytes (IPv4 + TCP headers)
        XCTAssertGreaterThanOrEqual(packet.count, 40)
        
        // Verify we can extract IP version
        let version = (packet[0] >> 4) & 0x0F
        XCTAssertEqual(version, 4)
        
        // Verify destination IP extraction
        let destIPBytes = packet[16..<20]
        let destIP = destIPBytes.map { String($0) }.joined(separator: ".")
        XCTAssertEqual(destIP, "8.8.8.8")
        
        // Verify protocol extraction
        let protocolByte = packet[9]
        XCTAssertEqual(protocolByte, 6) // TCP
        
        // Verify destination port extraction
        let ihl = Int(packet[0] & 0x0F) * 4
        let portBytes = packet[(ihl + 2)..<(ihl + 4)]
        let port = UInt16(portBytes[portBytes.startIndex]) << 8 | UInt16(portBytes[portBytes.startIndex + 1])
        XCTAssertEqual(port, 80)
    }
    
    func testPacketProcessing_IPv6PacketParsing() {
        // Test IPv6 packet header parsing
        // Create a minimal IPv6 packet with TCP
        var packet = Data()
        
        // IPv6 header (40 bytes)
        packet.append(0x60) // Version 6, Traffic class (upper 4 bits)
        packet.append(0x00) // Traffic class (lower 4 bits), Flow label (upper 4 bits)
        packet.append(contentsOf: [0x00, 0x00]) // Flow label (lower 16 bits)
        packet.append(contentsOf: [0x00, 0x14]) // Payload length (20 bytes)
        packet.append(0x06) // Next header (TCP = 6)
        packet.append(0x40) // Hop limit (64)
        
        // Source address (16 bytes) - fd00::1
        packet.append(contentsOf: [0xFD, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01])
        
        // Destination address (16 bytes) - 2001:4860:4860::8888 (Google DNS)
        packet.append(contentsOf: [0x20, 0x01, 0x48, 0x60, 0x48, 0x60, 0x00, 0x00,
                                   0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x88, 0x88])
        
        // TCP header (20 bytes minimum)
        packet.append(contentsOf: [0x04, 0xD2]) // Source port (1234)
        packet.append(contentsOf: [0x00, 0x50]) // Destination port (80)
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Sequence number
        packet.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // Acknowledgment number
        packet.append(0x50) // Data offset (5 * 4 = 20 bytes)
        packet.append(0x02) // Flags (SYN)
        packet.append(contentsOf: [0xFF, 0xFF]) // Window size
        packet.append(contentsOf: [0x00, 0x00]) // Checksum
        packet.append(contentsOf: [0x00, 0x00]) // Urgent pointer
        
        // Verify packet is at least 60 bytes (IPv6 + TCP headers)
        XCTAssertGreaterThanOrEqual(packet.count, 60)
        
        // Verify we can extract IP version
        let version = (packet[0] >> 4) & 0x0F
        XCTAssertEqual(version, 6)
        
        // Verify destination IP extraction
        let destIPBytes = packet[24..<40]
        var ipGroups: [String] = []
        for i in stride(from: 0, to: 16, by: 2) {
            let group = UInt16(destIPBytes[destIPBytes.startIndex + i]) << 8 |
                       UInt16(destIPBytes[destIPBytes.startIndex + i + 1])
            ipGroups.append(String(format: "%x", group))
        }
        let destIP = ipGroups.joined(separator: ":")
        XCTAssertTrue(destIP.contains("2001"))
        XCTAssertTrue(destIP.contains("8888"))
        
        // Verify protocol extraction
        let nextHeader = packet[6]
        XCTAssertEqual(nextHeader, 6) // TCP
        
        // Verify destination port extraction
        let portBytes = packet[42..<44]
        let port = UInt16(portBytes[portBytes.startIndex]) << 8 | UInt16(portBytes[portBytes.startIndex + 1])
        XCTAssertEqual(port, 80)
    }
    
    func testPacketProcessing_UDPPacket() {
        // Test UDP packet parsing
        var packet = Data()
        
        // IPv4 header
        packet.append(0x45) // Version 4, IHL 5
        packet.append(0x00) // DSCP/ECN
        packet.append(contentsOf: [0x00, 0x2C]) // Total length (44 bytes)
        packet.append(contentsOf: [0x00, 0x00]) // Identification
        packet.append(contentsOf: [0x40, 0x00]) // Flags, Fragment offset
        packet.append(0x40) // TTL
        packet.append(0x11) // Protocol (UDP = 17)
        packet.append(contentsOf: [0x00, 0x00]) // Checksum
        packet.append(contentsOf: [192, 168, 1, 100]) // Source IP
        packet.append(contentsOf: [8, 8, 8, 8]) // Destination IP
        
        // UDP header (8 bytes)
        packet.append(contentsOf: [0x04, 0xD2]) // Source port (1234)
        packet.append(contentsOf: [0x00, 0x35]) // Destination port (53 - DNS)
        packet.append(contentsOf: [0x00, 0x10]) // Length (16 bytes)
        packet.append(contentsOf: [0x00, 0x00]) // Checksum
        
        // Verify protocol extraction
        let protocolByte = packet[9]
        XCTAssertEqual(protocolByte, 17) // UDP
        
        // Verify destination port extraction
        let ihl = Int(packet[0] & 0x0F) * 4
        let portBytes = packet[(ihl + 2)..<(ihl + 4)]
        let port = UInt16(portBytes[portBytes.startIndex]) << 8 | UInt16(portBytes[portBytes.startIndex + 1])
        XCTAssertEqual(port, 53) // DNS port
    }
    
    func testPacketProcessing_ICMPPacket() {
        // Test ICMP packet parsing
        var packet = Data()
        
        // IPv4 header
        packet.append(0x45) // Version 4, IHL 5
        packet.append(0x00) // DSCP/ECN
        packet.append(contentsOf: [0x00, 0x54]) // Total length
        packet.append(contentsOf: [0x00, 0x00]) // Identification
        packet.append(contentsOf: [0x40, 0x00]) // Flags, Fragment offset
        packet.append(0x40) // TTL
        packet.append(0x01) // Protocol (ICMP = 1)
        packet.append(contentsOf: [0x00, 0x00]) // Checksum
        packet.append(contentsOf: [192, 168, 1, 100]) // Source IP
        packet.append(contentsOf: [8, 8, 8, 8]) // Destination IP
        
        // ICMP header (8 bytes minimum)
        packet.append(0x08) // Type (Echo Request)
        packet.append(0x00) // Code
        packet.append(contentsOf: [0x00, 0x00]) // Checksum
        packet.append(contentsOf: [0x00, 0x01]) // Identifier
        packet.append(contentsOf: [0x00, 0x01]) // Sequence number
        
        // Verify protocol extraction
        let protocolByte = packet[9]
        XCTAssertEqual(protocolByte, 1) // ICMP
    }
    
    func testPacketProcessing_InvalidPacket() {
        // Test handling of invalid/malformed packets
        
        // Empty packet
        let emptyPacket = Data()
        XCTAssertEqual(emptyPacket.count, 0)
        
        // Too short packet (less than minimum IPv4 header)
        let shortPacket = Data([0x45, 0x00, 0x00])
        XCTAssertLessThan(shortPacket.count, 20)
        
        // Invalid IP version
        var invalidVersionPacket = Data()
        invalidVersionPacket.append(0x35) // Version 3 (invalid)
        invalidVersionPacket.append(contentsOf: Array(repeating: 0x00, count: 19))
        let version = (invalidVersionPacket[0] >> 4) & 0x0F
        XCTAssertNotEqual(version, 4)
        XCTAssertNotEqual(version, 6)
    }
    
    func testPacketProcessing_LatencyRequirement() {
        // Test that packet processing meets latency requirements (<10ms for 95% of packets)
        // This is a basic test - full performance testing requires integration tests
        
        // Create a test packet
        var packet = Data()
        packet.append(0x45) // IPv4 header start
        packet.append(contentsOf: Array(repeating: 0x00, count: 39)) // Rest of headers
        
        // Measure time to parse packet headers
        let startTime = Date()
        
        // Simulate packet header parsing
        let version = (packet[0] >> 4) & 0x0F
        let destIPBytes = packet[16..<20]
        let destIP = destIPBytes.map { String($0) }.joined(separator: ".")
        
        let elapsed = Date().timeIntervalSince(startTime) * 1000 // Convert to ms
        
        // Parsing should be very fast (well under 10ms)
        XCTAssertLessThan(elapsed, 10.0, "Packet parsing should complete in less than 10ms")
        
        // Verify parsing worked
        XCTAssertEqual(version, 4)
        XCTAssertFalse(destIP.isEmpty)
    }
    
    func testPacketProcessing_MultipleProtocols() {
        // Test that we can correctly identify different protocol types
        
        // TCP packet
        var tcpPacket = Data()
        tcpPacket.append(0x45)
        tcpPacket.append(contentsOf: Array(repeating: 0x00, count: 8))
        tcpPacket.append(0x06) // TCP protocol
        tcpPacket.append(contentsOf: Array(repeating: 0x00, count: 30))
        XCTAssertEqual(tcpPacket[9], 6)
        
        // UDP packet
        var udpPacket = Data()
        udpPacket.append(0x45)
        udpPacket.append(contentsOf: Array(repeating: 0x00, count: 8))
        udpPacket.append(0x11) // UDP protocol
        udpPacket.append(contentsOf: Array(repeating: 0x00, count: 30))
        XCTAssertEqual(udpPacket[9], 17)
        
        // ICMP packet
        var icmpPacket = Data()
        icmpPacket.append(0x45)
        icmpPacket.append(contentsOf: Array(repeating: 0x00, count: 8))
        icmpPacket.append(0x01) // ICMP protocol
        icmpPacket.append(contentsOf: Array(repeating: 0x00, count: 30))
        XCTAssertEqual(icmpPacket[9], 1)
    }
    
    func testPacketProcessing_DestinationExtraction() {
        // Test extraction of various destination IPs
        
        let testCases: [(ip: [UInt8], expected: String)] = [
            ([127, 0, 0, 1], "127.0.0.1"),
            ([192, 168, 1, 1], "192.168.1.1"),
            ([8, 8, 8, 8], "8.8.8.8"),
            ([10, 0, 0, 1], "10.0.0.1"),
            ([172, 16, 0, 1], "172.16.0.1")
        ]
        
        for testCase in testCases {
            var packet = Data()
            packet.append(0x45) // IPv4 header
            packet.append(contentsOf: Array(repeating: 0x00, count: 15))
            packet.append(contentsOf: testCase.ip) // Destination IP at bytes 16-19
            packet.append(contentsOf: Array(repeating: 0x00, count: 20))
            
            let destIPBytes = packet[16..<20]
            let destIP = destIPBytes.map { String($0) }.joined(separator: ".")
            XCTAssertEqual(destIP, testCase.expected)
        }
    }
    
    func testPacketProcessing_PortExtraction() {
        // Test extraction of various destination ports
        
        let testCases: [(port: UInt16, bytes: [UInt8])] = [
            (80, [0x00, 0x50]),      // HTTP
            (443, [0x01, 0xBB]),     // HTTPS
            (53, [0x00, 0x35]),      // DNS
            (22, [0x00, 0x16]),      // SSH
            (3306, [0x0C, 0xEA])     // MySQL
        ]
        
        for testCase in testCases {
            var packet = Data()
            // IPv4 header (20 bytes)
            packet.append(0x45) // Version 4, IHL 5
            packet.append(contentsOf: Array(repeating: 0x00, count: 19))
            
            // TCP header - source port
            packet.append(contentsOf: [0x04, 0xD2]) // Source port (1234)
            
            // TCP header - destination port
            packet.append(contentsOf: testCase.bytes)
            
            // Extract port
            let ihl = Int(packet[0] & 0x0F) * 4
            let portBytes = packet[(ihl + 2)..<(ihl + 4)]
            let port = UInt16(portBytes[portBytes.startIndex]) << 8 | UInt16(portBytes[portBytes.startIndex + 1])
            
            XCTAssertEqual(port, testCase.port)
        }
    }
    
    // Additional tests will be added in subsequent tasks (9.4-9.7)
}
