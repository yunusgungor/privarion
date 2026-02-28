// PrivarionSharedModelsTests - Data Model Serialization Tests
// Unit tests for data model serialization/deserialization
// Requirements: 20.1

import XCTest
@testable import PrivarionSharedModels

final class DataModelSerializationTests: XCTestCase {
    
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    
    override func setUp() {
        super.setUp()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - SecurityEvent Serialization Tests
    
    func testSecurityEventSerialization() throws {
        let event = SecurityEvent(
            id: UUID(),
            timestamp: Date(),
            type: .processExecution,
            processID: 1234,
            executablePath: "/usr/bin/test",
            action: .allow,
            result: .allow
        )
        
        let data = try encoder.encode(event)
        let decoded = try decoder.decode(SecurityEvent.self, from: data)
        
        XCTAssertEqual(event.id, decoded.id)
        XCTAssertEqual(event.type, decoded.type)
        XCTAssertEqual(event.processID, decoded.processID)
        XCTAssertEqual(event.executablePath, decoded.executablePath)
        XCTAssertEqual(event.action, decoded.action)
        XCTAssertEqual(event.result, decoded.result)
    }
    
    func testProcessExecutionEventSerialization() throws {
        let event = ProcessExecutionEvent(
            processID: 5678,
            executablePath: "/Applications/Safari.app/Contents/MacOS/Safari",
            arguments: ["--no-sandbox", "--test"],
            environment: ["PATH": "/usr/bin", "HOME": "/Users/test"],
            parentProcessID: 1
        )
        
        let data = try encoder.encode(event)
        let decoded = try decoder.decode(ProcessExecutionEvent.self, from: data)
        
        XCTAssertEqual(event.processID, decoded.processID)
        XCTAssertEqual(event.executablePath, decoded.executablePath)
        XCTAssertEqual(event.arguments, decoded.arguments)
        XCTAssertEqual(event.environment, decoded.environment)
        XCTAssertEqual(event.parentProcessID, decoded.parentProcessID)
    }
    
    func testFileAccessEventSerialization() throws {
        let event = FileAccessEvent(
            processID: 9999,
            filePath: "/etc/hosts",
            accessType: .read
        )
        
        let data = try encoder.encode(event)
        let decoded = try decoder.decode(FileAccessEvent.self, from: data)
        
        XCTAssertEqual(event.processID, decoded.processID)
        XCTAssertEqual(event.filePath, decoded.filePath)
        XCTAssertEqual(event.accessType, decoded.accessType)
    }
    
    func testNetworkEventSerialization() throws {
        let event = NetworkEvent(
            processID: 1111,
            sourceIP: "192.168.1.100",
            sourcePort: 54321,
            destinationIP: "8.8.8.8",
            destinationPort: 53,
            protocol: .udp
        )
        
        let data = try encoder.encode(event)
        let decoded = try decoder.decode(NetworkEvent.self, from: data)
        
        XCTAssertEqual(event.processID, decoded.processID)
        XCTAssertEqual(event.sourceIP, decoded.sourceIP)
        XCTAssertEqual(event.sourcePort, decoded.sourcePort)
        XCTAssertEqual(event.destinationIP, decoded.destinationIP)
        XCTAssertEqual(event.destinationPort, decoded.destinationPort)
        XCTAssertEqual(event.protocol, decoded.protocol)
    }
    
    // MARK: - Network Model Serialization Tests
    
    func testNetworkRequestSerialization() throws {
        let request = NetworkRequest(
            processID: 2222,
            sourceIP: "10.0.0.1",
            sourcePort: 12345,
            destinationIP: "93.184.216.34",
            destinationPort: 443,
            protocol: .tcp,
            domain: "example.com"
        )
        
        let data = try encoder.encode(request)
        let decoded = try decoder.decode(NetworkRequest.self, from: data)
        
        XCTAssertEqual(request.id, decoded.id)
        XCTAssertEqual(request.processID, decoded.processID)
        XCTAssertEqual(request.sourceIP, decoded.sourceIP)
        XCTAssertEqual(request.sourcePort, decoded.sourcePort)
        XCTAssertEqual(request.destinationIP, decoded.destinationIP)
        XCTAssertEqual(request.destinationPort, decoded.destinationPort)
        XCTAssertEqual(request.protocol, decoded.protocol)
        XCTAssertEqual(request.domain, decoded.domain)
    }
    
    func testDNSQuerySerialization() throws {
        let query = DNSQuery(
            id: 12345,
            domain: "example.com",
            queryType: .A
        )
        
        let data = try encoder.encode(query)
        let decoded = try decoder.decode(DNSQuery.self, from: data)
        
        XCTAssertEqual(query.id, decoded.id)
        XCTAssertEqual(query.domain, decoded.domain)
        XCTAssertEqual(query.queryType, decoded.queryType)
    }
    
    func testDNSResponseSerialization() throws {
        let response = DNSResponse(
            id: 12345,
            domain: "example.com",
            addresses: ["93.184.216.34"],
            ttl: 300,
            cached: true
        )
        
        let data = try encoder.encode(response)
        let decoded = try decoder.decode(DNSResponse.self, from: data)
        
        XCTAssertEqual(response.id, decoded.id)
        XCTAssertEqual(response.domain, decoded.domain)
        XCTAssertEqual(response.addresses, decoded.addresses)
        XCTAssertEqual(response.ttl, decoded.ttl)
        XCTAssertEqual(response.cached, decoded.cached)
    }
    
    func testDNSResponseValidation() {
        let validResponse = DNSResponse(
            id: 1,
            domain: "test.com",
            addresses: ["1.2.3.4"],
            ttl: 300,
            cached: false,
            timestamp: Date()
        )
        XCTAssertTrue(validResponse.isValid)
        
        let expiredResponse = DNSResponse(
            id: 2,
            domain: "test.com",
            addresses: ["1.2.3.4"],
            ttl: 1,
            cached: false,
            timestamp: Date().addingTimeInterval(-10)
        )
        XCTAssertFalse(expiredResponse.isValid)
    }
    
    // MARK: - VM Model Serialization Tests
    
    func testHardwareProfileSerialization() throws {
        let profile = HardwareProfile(
            id: UUID(),
            name: "MacBook Pro 2021",
            hardwareModel: Data([0x01, 0x02, 0x03]),
            machineIdentifier: Data([0x04, 0x05, 0x06]),
            macAddress: "00:11:22:33:44:55",
            serialNumber: "C02ABC123DEF"
        )
        
        let data = try encoder.encode(profile)
        let decoded = try decoder.decode(HardwareProfile.self, from: data)
        
        XCTAssertEqual(profile.id, decoded.id)
        XCTAssertEqual(profile.name, decoded.name)
        XCTAssertEqual(profile.hardwareModel, decoded.hardwareModel)
        XCTAssertEqual(profile.machineIdentifier, decoded.machineIdentifier)
        XCTAssertEqual(profile.macAddress, decoded.macAddress)
        XCTAssertEqual(profile.serialNumber, decoded.serialNumber)
    }
    
    func testVMSnapshotSerialization() throws {
        let snapshot = VMSnapshot(
            id: UUID(),
            vmID: UUID(),
            name: "Test Snapshot",
            diskImagePath: URL(fileURLWithPath: "/tmp/disk.img"),
            memoryStatePath: URL(fileURLWithPath: "/tmp/memory.state")
        )
        
        let data = try encoder.encode(snapshot)
        let decoded = try decoder.decode(VMSnapshot.self, from: data)
        
        XCTAssertEqual(snapshot.id, decoded.id)
        XCTAssertEqual(snapshot.vmID, decoded.vmID)
        XCTAssertEqual(snapshot.name, decoded.name)
        XCTAssertEqual(snapshot.diskImagePath, decoded.diskImagePath)
        XCTAssertEqual(snapshot.memoryStatePath, decoded.memoryStatePath)
    }
    
    func testVMResourceUsageSerialization() throws {
        let usage = VMResourceUsage(
            cpuUsage: 0.45,
            memoryUsage: 4_294_967_296, // 4GB
            diskUsage: 53_687_091_200, // 50GB
            networkBytesIn: 1_048_576, // 1MB
            networkBytesOut: 2_097_152 // 2MB
        )
        
        let data = try encoder.encode(usage)
        let decoded = try decoder.decode(VMResourceUsage.self, from: data)
        
        XCTAssertEqual(usage.cpuUsage, decoded.cpuUsage)
        XCTAssertEqual(usage.memoryUsage, decoded.memoryUsage)
        XCTAssertEqual(usage.diskUsage, decoded.diskUsage)
        XCTAssertEqual(usage.networkBytesIn, decoded.networkBytesIn)
        XCTAssertEqual(usage.networkBytesOut, decoded.networkBytesOut)
    }
    
    func testVMResourceUsageFormatting() {
        let usage = VMResourceUsage(
            cpuUsage: 0.45,
            memoryUsage: 4_294_967_296, // 4GB
            diskUsage: 53_687_091_200, // 50GB
            networkBytesIn: 0,
            networkBytesOut: 0
        )
        
        XCTAssertEqual(usage.cpuPercentage, 45.0)
        XCTAssertFalse(usage.formattedMemoryUsage.isEmpty)
        XCTAssertFalse(usage.formattedDiskUsage.isEmpty)
    }
}
