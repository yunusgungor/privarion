import XCTest
import Foundation
@testable import PrivarionCore

/// Debug test to isolate exactly where the signal 4 happens
final class DebugMacRepositoryTest: XCTestCase {
    
    func testRepositoryDebugSteps() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let storageURL = tempDir.appendingPathComponent("debug_test_\(UUID().uuidString).json")
        
        print("🔍 Step 1: Creating storage directory...")
        let parentDirectory = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        print("✅ Step 1 complete")
        
        print("🔍 Step 2: Creating PrivarionLogger.shared...")
        _ = PrivarionLogger.shared
        print("✅ Step 2 complete")
        
        print("🔍 Step 3: Creating ConfigurationManager.shared...")
        _ = ConfigurationManager.shared
        print("✅ Step 3 complete")
        
        print("🔍 Step 4: Creating RepositoryData...")
        let repositoryData = MacAddressRepository.BackupEntry(interface: "test", originalMAC: "aa:bb:cc:dd:ee:ff")
        print("✅ Step 4 complete - Entry created: \(repositoryData.interface)")
        
        print("🔍 Step 5: Creating repository manually...")
        let repository = try MacAddressRepository(storageURL: storageURL)
        print("✅ Step 5 complete - Repository created successfully")
        
        XCTAssertNotNil(repository)
    }
}
