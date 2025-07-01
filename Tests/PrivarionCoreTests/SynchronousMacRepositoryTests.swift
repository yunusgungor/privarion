import XCTest
import Foundation
@testable import PrivarionCore

/// Working MAC Repository tests using synchronous methods only
final class SynchronousMacRepositoryTests: XCTestCase {
    
    var repository: MacAddressRepository!
    var tempStorageURL: URL!
    
    override func setUpWithError() throws {
        super.setUp()
        
        // Create test directory in the project folder 
        let workspaceURL = URL(fileURLWithPath: "/Users/yunusgungor/arge/privarion")
        let testDir = workspaceURL.appendingPathComponent(".test_data")
        
        // Create test directory if it doesn't exist
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true, attributes: nil)
        
        tempStorageURL = testDir.appendingPathComponent("sync_test_\(UUID().uuidString).json")
        
        // Use the default configuration manager
        repository = try MacAddressRepository(storageURL: tempStorageURL)
    }
    
    override func tearDownWithError() throws {
        // Clean up test files
        try? FileManager.default.removeItem(at: tempStorageURL)
        try? FileManager.default.removeItem(at: tempStorageURL.appendingPathExtension("backup"))
        try? FileManager.default.removeItem(at: tempStorageURL.appendingPathExtension("tmp"))
        
        repository = nil
        tempStorageURL = nil
        
        super.tearDown()
    }
    
    // MARK: - Synchronous Tests
    
    func testSyncBackupOriginalMAC() throws {
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Test synchronous backup creation
        try repository.backupOriginalMACSync(interface: interface, macAddress: macAddress)
        
        // Verify backup exists using sync method
        let retrievedMAC = repository.getOriginalMAC(for: interface)
        XCTAssertEqual(retrievedMAC, macAddress, "Retrieved MAC should match original")
        
        // Verify interface is marked as spoofed
        XCTAssertTrue(repository.isSpoofed(interface: interface), "Interface should be marked as spoofed after backup")
    }
    
    func testSyncBackupAlreadyExists() throws {
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Create initial backup
        try repository.backupOriginalMACSync(interface: interface, macAddress: macAddress)
        
        // Attempt to create duplicate backup should fail
        do {
            try repository.backupOriginalMACSync(interface: interface, macAddress: macAddress)
            XCTFail("Should not allow duplicate backup")
        } catch {
            if let repoError = error as? RepositoryError,
               case .interfaceAlreadyBackedUp(let failedInterface) = repoError {
                XCTAssertEqual(failedInterface, interface, "Error should reference correct interface")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testSyncGetNonExistentBackup() {
        let interface = "en1"
        
        // Try to get MAC for non-existent backup
        let retrievedMAC = repository.getOriginalMAC(for: interface)
        XCTAssertNil(retrievedMAC, "Should return nil for non-existent backup")
        
        // Verify backup doesn't exist by checking if interface is spoofed
        XCTAssertFalse(repository.isSpoofed(interface: interface), "Interface should not be spoofed if no backup exists")
    }
    
    func testSyncRemoveBackup() throws {
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Create backup
        try repository.backupOriginalMACSync(interface: interface, macAddress: macAddress)
        
        // Remove backup
        try repository.removeBackup(interface: interface)
        
        // Verify backup is removed
        let retrievedMAC = repository.getOriginalMAC(for: interface)
        XCTAssertNil(retrievedMAC, "MAC should be nil after backup removal")
        
        // Verify interface is no longer marked as spoofed
        XCTAssertFalse(repository.isSpoofed(interface: interface), "Interface should not be spoofed after backup removal")
    }
}
