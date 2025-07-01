import XCTest
@testable import PrivarionCore
import Foundation

/// Working tests for MacAddressRepository functionality
/// These tests demonstrate that the core repository works correctly when initialized properly
final class MacAddressRepositoryWorkingTests: XCTestCase {
    
    func testRepositoryBasicFunctionality() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("working_test_repo.json")
        
        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)
        
        do {
            // Create a custom configuration to avoid singleton issues
            let tempConfigPath = tempDir.appendingPathComponent("working_test_config.json")
            let configManager = ConfigurationManager(customConfigPath: tempConfigPath)
            
            let repository = try MacAddressRepository(storageURL: testFile, configurationManager: configManager)
            
            // Test 1: Initial state - no spoofed interfaces
            XCTAssertTrue(repository.getSpoofedInterfaces().isEmpty, "Should start with no spoofed interfaces")
            XCTAssertFalse(repository.isSpoofed(interface: "en0"), "en0 should not be spoofed initially")
            
            // Test 2: Backup original MAC (sync method)
            try repository.backupOriginalMACSync(interface: "en0", macAddress: "aa:bb:cc:dd:ee:ff")
            
            // Test 3: Verify backup exists
            XCTAssertTrue(repository.isSpoofed(interface: "en0"), "en0 should be marked as spoofed")
            XCTAssertEqual(repository.getOriginalMAC(for: "en0"), "aa:bb:cc:dd:ee:ff", "Should retrieve original MAC")
            XCTAssertEqual(repository.getSpoofedInterfaces(), ["en0"], "Should list en0 as spoofed")
            
            // Test 4: Remove backup
            try repository.removeBackup(interface: "en0")
            XCTAssertFalse(repository.isSpoofed(interface: "en0"), "en0 should not be spoofed after removal")
            XCTAssertTrue(repository.getSpoofedInterfaces().isEmpty, "Should have no spoofed interfaces after removal")
            
            // Clean up
            try? FileManager.default.removeItem(at: testFile)
            try? FileManager.default.removeItem(at: tempConfigPath)
            
        } catch {
            XCTFail("Repository test failed: \(error)")
        }
    }
    
    func testRepositoryPersistence() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("persistence_test_repo.json")
        
        // Clean up any existing file
        try? FileManager.default.removeItem(at: testFile)
        
        do {
            let tempConfigPath = tempDir.appendingPathComponent("persistence_test_config.json")
            
            // Create first repository instance and add data
            do {
                let configManager1 = ConfigurationManager(customConfigPath: tempConfigPath)
                let repository1 = try MacAddressRepository(storageURL: testFile, configurationManager: configManager1)
                
                try repository1.backupOriginalMACSync(interface: "en0", macAddress: "aa:bb:cc:dd:ee:ff")
                try repository1.backupOriginalMACSync(interface: "en1", macAddress: "11:22:33:44:55:66")
                
                XCTAssertEqual(repository1.getSpoofedInterfaces().count, 2, "Should have 2 spoofed interfaces")
            }
            
            // Create second repository instance and verify data persisted
            do {
                let configManager2 = ConfigurationManager(customConfigPath: tempConfigPath)
                let repository2 = try MacAddressRepository(storageURL: testFile, configurationManager: configManager2)
                
                XCTAssertEqual(repository2.getSpoofedInterfaces().count, 2, "Should load 2 spoofed interfaces from file")
                XCTAssertEqual(repository2.getOriginalMAC(for: "en0"), "aa:bb:cc:dd:ee:ff", "Should load en0 MAC from file")
                XCTAssertEqual(repository2.getOriginalMAC(for: "en1"), "11:22:33:44:55:66", "Should load en1 MAC from file")
            }
            
            // Clean up
            try? FileManager.default.removeItem(at: testFile)
            try? FileManager.default.removeItem(at: tempConfigPath)
            
        } catch {
            XCTFail("Persistence test failed: \(error)")
        }
    }
}
