import XCTest
import Foundation
@testable import PrivarionCore

/// Simple test to verify MacAddressRepository functionality
final class SimpleMacRepositoryTest: XCTestCase {
    
    func testBasicBackupAndRestore() async throws {
        // Create temporary directory for test storage
        let tempDir = FileManager.default.temporaryDirectory
        let tempStorageURL = tempDir.appendingPathComponent("simple_test_\(UUID().uuidString).json")
        
        // Initialize repository with temporary storage
        let repository = try MacAddressRepository(storageURL: tempStorageURL)
        
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Test backup creation
        try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
        
        // Verify backup exists
        let hasBackup = try await repository.hasBackup(interface: interface)
        XCTAssertTrue(hasBackup, "Backup should exist after creation")
        
        // Verify MAC can be retrieved
        let retrievedMAC = try await repository.getOriginalMAC(interface: interface)
        XCTAssertEqual(retrievedMAC, macAddress, "Retrieved MAC should match original")
        
        // Test restore
        let restoredMAC = try await repository.restoreOriginalMAC(interface: interface)
        XCTAssertEqual(restoredMAC, macAddress, "Restored MAC should match original")
        
        // Verify backup is removed after restoration
        let hasBackupAfter = try await repository.hasBackup(interface: interface)
        XCTAssertFalse(hasBackupAfter, "Backup should be removed after restoration")
        
        // Clean up
        try? FileManager.default.removeItem(at: tempStorageURL)
        
        print("✅ MacAddressRepository basic functionality test PASSED!")
    }
}
