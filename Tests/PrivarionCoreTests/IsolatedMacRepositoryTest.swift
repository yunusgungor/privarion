import XCTest
import Foundation
@testable import PrivarionCore

/// Minimal isolated test for MacAddressRepository without external dependencies
final class IsolatedMacRepositoryTest: XCTestCase {
    
    var tempStorageURL: URL!
    
    override func setUpWithError() throws {
        super.setUp()
        
        // Create temporary directory for test storage
        let tempDir = FileManager.default.temporaryDirectory
        tempStorageURL = tempDir.appendingPathComponent("isolated_test_\(UUID().uuidString).json")
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary files
        try? FileManager.default.removeItem(at: tempStorageURL)
        tempStorageURL = nil
        super.tearDown()
    }
    
    func testBackupEntryValidation() {
        // Test the BackupEntry struct independently - this should work without any dependencies
        let entry = MacAddressRepository.BackupEntry(
            interface: "en0",
            originalMAC: "aa:bb:cc:dd:ee:ff"
        )
        
        XCTAssertEqual(entry.interface, "en0")
        XCTAssertEqual(entry.originalMAC, "aa:bb:cc:dd:ee:ff")
        XCTAssertTrue(entry.isValid, "Entry should be valid")
    }
    
    func testBasicRepositoryCreationWithDefaults() throws {
        // Try to create repository without custom dependencies first
        // If this crashes, the problem is in the default singleton dependencies
        
        do {
            let repository = try MacAddressRepository(storageURL: tempStorageURL)
            XCTAssertNotNil(repository, "Repository should be created successfully")
        } catch {
            XCTFail("Repository creation failed: \(error)")
        }
    }
}
