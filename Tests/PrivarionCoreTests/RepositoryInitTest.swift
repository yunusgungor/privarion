import XCTest
@testable import PrivarionCore
import Foundation

final class RepositoryInitTest: XCTestCase {
    
    func testRepositoryWithCustomURL() throws {
        // Use a temporary directory to avoid any configuration issues
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_repo.json")
        
        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)
        
        // Try to create repository with custom storage URL
        do {
            let repository = try MacAddressRepository(storageURL: testFile)
            
            // Simple test - check if repository exists
            XCTAssertNotNil(repository)
            
            // Clean up
            try? FileManager.default.removeItem(at: testFile)
            
        } catch {
            XCTFail("Repository initialization failed: \(error)")
        }
    }
    
    func testRepositoryBasicOperations() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_repo_ops.json")
        
        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)
        
        do {
            let repository = try MacAddressRepository(storageURL: testFile)
            
            // Test basic isSpoofed check
            let isSpoofedbefore = repository.isSpoofed(interface: "en0")
            XCTAssertFalse(isSpoofedbefore)
            
            // Test basic getSpoofedInterfaces
            let spoofedList = repository.getSpoofedInterfaces()
            XCTAssertTrue(spoofedList.isEmpty)
            
            // Clean up
            try? FileManager.default.removeItem(at: testFile)
            
        } catch {
            XCTFail("Repository basic operations failed: \(error)")
        }
    }
}
