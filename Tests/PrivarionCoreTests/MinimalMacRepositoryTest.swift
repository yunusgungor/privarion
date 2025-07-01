import XCTest
import Foundation
@testable import PrivarionCore

/// Minimal test to isolate the crash issue
final class MinimalMacRepositoryTest: XCTestCase {
    
    func testBasicRepositoryCreation() throws {
        // Create temp directory
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("privarion_minimal_test_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        // Test repository creation without crashes
        let repository = try MacAddressRepository(
            storageURL: tempDirectory.appendingPathComponent("test.json")
        )
        
        // Very basic test
        XCTAssertNotNil(repository)
        print("Repository created successfully")
    }
    
    func testSyncRepositoryOperations() throws {
        // Create temp directory
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("privarion_sync_test_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        // Test repository creation
        let repository = try MacAddressRepository(
            storageURL: tempDirectory.appendingPathComponent("test.json")
        )
        
        // Test sync operations only (no async)
        try repository.backupOriginalMACSync(interface: "en0", macAddress: "02:11:22:33:44:55")
        let retrieved = repository.getOriginalMAC(for: "en0")
        XCTAssertEqual(retrieved, "02:11:22:33:44:55")
        
        print("Sync operations completed successfully")
    }
    
    func testAsyncRepositoryOperations() throws {
        // Create temp directory
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("privarion_async_test_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        // Test repository creation
        let repository = try MacAddressRepository(
            storageURL: tempDirectory.appendingPathComponent("test.json")
        )
        
        // Test async operations with expectation
        let expectation = XCTestExpectation(description: "Async test")
        
        Task {
            do {
                print("Starting async backup...")
                try await repository.backupOriginalMAC(interface: "en0", macAddress: "02:11:22:33:44:55")
                print("Async backup completed")
                
                print("Starting async retrieval...")
                let retrieved = try await repository.getOriginalMAC(interface: "en0")
                print("Async retrieval completed")
                
                XCTAssertEqual(retrieved, "02:11:22:33:44:55")
                expectation.fulfill()
            } catch {
                print("Async operation failed: \(error)")
                XCTFail("Async operation failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        print("Async operations completed successfully")
    }
}
