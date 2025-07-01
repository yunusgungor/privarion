import XCTest
import Foundation
@testable import PrivarionCore

/// Simple test to isolate async crash issue
final class SimpleAsyncTest: XCTestCase {
    
    func testSimpleAsyncBackup() throws {
        // Create temp directory
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("privarion_simple_async_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        // Test repository creation
        let repository = try MacAddressRepository(
            storageURL: tempDirectory.appendingPathComponent("test.json")
        )
        
        // Test only async backup, nothing else
        let expectation = XCTestExpectation(description: "Simple async backup")
        
        Task {
            do {
                print("About to call async backup...")
                try await repository.backupOriginalMAC(interface: "en0", macAddress: "02:11:22:33:44:55")
                print("Async backup succeeded!")
                expectation.fulfill()
            } catch {
                print("Async backup failed: \(error)")
                XCTFail("Async backup failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}
