// PrivarionVMTests
// Unit tests for VM Manager module

import XCTest
@testable import PrivarionVM

final class VMManagerTests: XCTestCase {
    
    func testVMManagerInitialization() {
        // Test that VMManager can be initialized
        let vmManager = VMManager()
        XCTAssertNotNil(vmManager)
    }
    
    func testHardwareProfileInitialization() {
        // Test that HardwareProfile can be created
        let profile = HardwareProfile(
            name: "Test Profile",
            hardwareModel: Data(),
            machineIdentifier: Data(),
            macAddress: "02:00:00:00:00:01",
            serialNumber: "TEST123"
        )
        
        XCTAssertEqual(profile.name, "Test Profile")
        XCTAssertEqual(profile.macAddress, "02:00:00:00:00:01")
        XCTAssertEqual(profile.serialNumber, "TEST123")
    }
    
    func testVMSnapshotInitialization() {
        // Test that VMSnapshot can be created
        let vmID = UUID()
        let snapshot = VMSnapshot(
            vmID: vmID,
            name: "Test Snapshot",
            diskImagePath: URL(fileURLWithPath: "/tmp/disk.img"),
            memoryStatePath: URL(fileURLWithPath: "/tmp/memory.state")
        )
        
        XCTAssertEqual(snapshot.vmID, vmID)
        XCTAssertEqual(snapshot.name, "Test Snapshot")
    }
    
    func testVMResourceUsageInitialization() {
        // Test that VMResourceUsage can be created
        let usage = VMResourceUsage(
            cpuUsage: 0.5,
            memoryUsage: 1024 * 1024 * 1024,
            diskUsage: 10 * 1024 * 1024 * 1024,
            networkBytesIn: 1000,
            networkBytesOut: 2000
        )
        
        XCTAssertEqual(usage.cpuUsage, 0.5)
        XCTAssertEqual(usage.memoryUsage, 1024 * 1024 * 1024)
    }
    
    // Additional tests will be added in subsequent tasks
}
