import XCTest
import Foundation
@testable import PrivarionCore

/// Async/await interface'ini XCTestExpectation ile test etme denemesi
/// Signal 4 sorununu çözmek için async işlemleri expectation ile wrap ediyor
final class AsyncCompatibilityMacRepositoryTests: XCTestCase {
    
    private var tempDirectory: URL!
    private var repository: MacAddressRepository!
    
    override func setUp() {
        super.setUp()
        
        // Temporary test directory
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("privarion_async_test_\(UUID().uuidString)")
        
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create repository with custom storage - use safer error handling
        do {
            repository = try MacAddressRepository(
                storageURL: tempDirectory.appendingPathComponent("mac_addresses.json")
            )
        } catch {
            XCTFail("Failed to initialize MacAddressRepository: \(error)")
            return
        }
    }
    
    override func tearDown() {
        super.tearDown()
        
        // Clean up
        if let tempDirectory = tempDirectory,
           FileManager.default.fileExists(atPath: tempDirectory.path) {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    /// Test async backup and retrieve operation
    func testAsyncBackup() async throws {
        let testAddress = "02:34:56:78:9A:BC"
        let interfaceName = "en0"
        
        try await repository.backupOriginalMAC(interface: interfaceName, macAddress: testAddress)
        let retrieved = try await repository.getOriginalMAC(interface: interfaceName)
        XCTAssertEqual(retrieved, testAddress, "Retrieved MAC address should match")
    }
    
    /// Test async backup/export/import cycle
    func testAsyncBackupExportImportCycle() async throws {
        let testData = [
            "en0": "02:11:22:33:44:55",
            "en1": "02:66:77:88:99:AA"
        ]
        
        // Backup test data
        for (interface, address) in testData {
            try await repository.backupOriginalMAC(interface: interface, macAddress: address)
        }
        
        // Export backup
        let exportedData = try repository.exportBackup()
        
        // Clear current data
        for interface in testData.keys {
            try await repository.clearBackup(interface: interface)
        }
        
        // Verify data is cleared
        let hasBackupEn0 = try await repository.hasBackup(interface: "en0")
        let hasBackupEn1 = try await repository.hasBackup(interface: "en1")
        XCTAssertFalse(hasBackupEn0, "Backup for en0 should be cleared")
        XCTAssertFalse(hasBackupEn1, "Backup for en1 should be cleared")
        
        // Import from backup
        try repository.importBackup(data: exportedData)
        
        // Verify restoration
        let allBackups = try await repository.getAllBackups()
        XCTAssertEqual(allBackups.count, testData.count, "All backups should be restored")
        
        for (interface, expectedAddress) in testData {
            let retrievedAddress = try await repository.getOriginalMAC(interface: interface)
            XCTAssertEqual(retrievedAddress, expectedAddress, "Restored MAC for \(interface) should match")
        }
    }
}
