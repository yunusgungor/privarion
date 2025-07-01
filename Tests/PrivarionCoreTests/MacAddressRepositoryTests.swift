import XCTest
import Foundation
@testable import PrivarionCore

/// Comprehensive test suite for MacAddressRepository
/// Tests Phase 2b data persistence functionality
final class MacAddressRepositoryTests: XCTestCase {
    
    var repository: MacAddressRepository!
    var tempStorageURL: URL!
    
    override func setUpWithError() throws {
        super.setUp()
        
        // Create test directory in the project folder instead of temp directory
        let workspaceURL = URL(fileURLWithPath: "/Users/yunusgungor/arge/privarion")
        let testDir = workspaceURL.appendingPathComponent(".test_data")
        
        // Create test directory if it doesn't exist
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true, attributes: nil)
        
        tempStorageURL = testDir.appendingPathComponent("test_mac_repository_\(UUID().uuidString).json")
        
        // Use the default configuration manager to avoid file creation issues
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
    
    // MARK: - Basic Functionality Tests
    
    func testBackupOriginalMAC() async throws {
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
    }
    
    func testBackupAlreadyExists() async throws {
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Create initial backup
        try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
        
        // Attempt to create duplicate backup should fail
        do {
            try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
            XCTFail("Should not allow duplicate backup")
        } catch {
            if let repoError = error as? RepositoryError,
               case .interfaceAlreadyBackedUp(let failedInterface) = repoError {
                XCTAssertEqual(failedInterface, interface, "Error should reference correct interface")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
    }
    
    func testGetNonExistentBackup() async throws {
        let interface = "en1"
        
        // Try to get MAC for non-existent backup
        let retrievedMAC = try await repository.getOriginalMAC(interface: interface)
        XCTAssertNil(retrievedMAC, "Should return nil for non-existent backup")
        
        // Verify backup doesn't exist
        let hasBackup = try await repository.hasBackup(interface: interface)
        XCTAssertFalse(hasBackup, "Backup should not exist")
    }
    
    func testRestoreOriginalMAC() async throws {
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Create backup
        try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
        
        // Restore original MAC
        let restoredMAC = try await repository.restoreOriginalMAC(interface: interface)
        XCTAssertEqual(restoredMAC, macAddress, "Restored MAC should match original")
        
        // Verify backup is removed after restoration
        let hasBackup = try await repository.hasBackup(interface: interface)
        XCTAssertFalse(hasBackup, "Backup should be removed after restoration")
        
        // Verify MAC can no longer be retrieved
        let retrievedMAC = try await repository.getOriginalMAC(interface: interface)
        XCTAssertNil(retrievedMAC, "Should return nil after backup removal")
    }
    
    func testRestoreNonExistentBackup() async throws {
        let interface = "en1"
        
        // Try to restore non-existent backup
        do {
            _ = try await repository.restoreOriginalMAC(interface: interface)
            XCTFail("Should not allow restoring non-existent backup")
        } catch {
            if let repoError = error as? RepositoryError,
               case .interfaceNotBackedUp(let failedInterface) = repoError {
                XCTAssertEqual(failedInterface, interface, "Error should reference correct interface")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testClearBackup() async throws {
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Create backup
        try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
        
        // Clear backup
        try await repository.clearBackup(interface: interface)
        
        // Verify backup is removed
        let hasBackup = try await repository.hasBackup(interface: interface)
        XCTAssertFalse(hasBackup, "Backup should be removed after clearing")
    }
    
    func testClearNonExistentBackup() async throws {
        let interface = "en1"
        
        // Try to clear non-existent backup
        do {
            try await repository.clearBackup(interface: interface)
            XCTFail("Should not allow clearing non-existent backup")
        } catch {
            if let repoError = error as? RepositoryError,
               case .interfaceNotBackedUp(let failedInterface) = repoError {
                XCTAssertEqual(failedInterface, interface, "Error should reference correct interface")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testGetAllBackups() async throws {
        let interface1 = "en0"
        let macAddress1 = "aa:bb:cc:dd:ee:ff"
        let interface2 = "en1" 
        let macAddress2 = "11:22:33:44:55:66"
        
        // Create multiple backups
        try await repository.backupOriginalMAC(interface: interface1, macAddress: macAddress1)
        try await repository.backupOriginalMAC(interface: interface2, macAddress: macAddress2)
        
        // Get all backups
        let allBackups = try await repository.getAllBackups()
        
        XCTAssertEqual(allBackups.count, 2, "Should have 2 backups")
        XCTAssertEqual(allBackups[interface1]?.originalMAC, macAddress1, "First backup should match")
        XCTAssertEqual(allBackups[interface2]?.originalMAC, macAddress2, "Second backup should match")
    }
    
    func testUpdateCurrentMAC() async throws {
        let interface = "en0"
        let originalMAC = "aa:bb:cc:dd:ee:ff"
        let currentMAC = "11:22:33:44:55:66"
        
        // Create backup
        try await repository.backupOriginalMAC(interface: interface, macAddress: originalMAC)
        
        // Update current MAC
        try await repository.updateCurrentMAC(interface: interface, macAddress: currentMAC)
        
        // Verify backup was updated
        let allBackups = try await repository.getAllBackups()
        let backup = allBackups[interface]
        
        XCTAssertNotNil(backup, "Backup should exist")
        XCTAssertEqual(backup?.originalMAC, originalMAC, "Original MAC should remain unchanged")
        XCTAssertEqual(backup?.currentMAC, currentMAC, "Current MAC should be updated")
    }
    
    // MARK: - Validation Tests
    
    func testInvalidMACAddressFormat() async throws {
        let interface = "en0"
        let invalidMAC = "invalid-mac-format"
        
        // Try to backup invalid MAC
        do {
            try await repository.backupOriginalMAC(interface: interface, macAddress: invalidMAC)
            XCTFail("Should reject invalid MAC format")
        } catch {
            if let repoError = error as? RepositoryError,
               case .invalidMACFormat(let mac) = repoError {
                XCTAssertTrue(mac.contains("invalid-mac-format"), "Error should mention invalid MAC")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testInvalidInterfaceName() async throws {
        let invalidInterface = ""
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Try to backup with invalid interface
        do {
            try await repository.backupOriginalMAC(interface: invalidInterface, macAddress: macAddress)
            XCTFail("Should reject empty interface name")
        } catch {
            if let repoError = error as? RepositoryError,
               case .invalidMACFormat = repoError {
                // Expected error for empty interface
                XCTAssertTrue(true, "Error handled correctly")
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testValidMACAddressFormats() async throws {
        let validMACs = [
            "aa:bb:cc:dd:ee:ff",
            "AA:BB:CC:DD:EE:FF",
            "12:34:56:78:9a:bc",
            "00:11:22:33:44:55"
        ]
        
        for (index, mac) in validMACs.enumerated() {
            let testInterface = "en\(index)"
            
            // Should not throw for valid MAC formats
            try await repository.backupOriginalMAC(interface: testInterface, macAddress: mac)
            
            let retrievedMAC = try await repository.getOriginalMAC(interface: testInterface)
            XCTAssertEqual(retrievedMAC, mac, "Retrieved MAC should match for valid format: \(mac)")
        }
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentBackupOperations() async throws {
        let operationCount = 10
        
        // Create concurrent backup operations
        let tasks = (0..<operationCount).map { index in
            Task {
                let interface = "en\(index)"
                let macAddress = String(format: "%02x:%02x:%02x:%02x:%02x:%02x", 
                                      index, index, index, index, index, index)
                try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
            }
        }
        
        // Wait for all operations to complete
        for task in tasks {
            try await task.value
        }
        
        // Verify all backups were created
        let allBackups = try await repository.getAllBackups()
        XCTAssertEqual(allBackups.count, operationCount, "All concurrent backups should be created")
    }
    
    func testConcurrentReadOperations() async throws {
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Create backup
        try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
        
        let readCount = 50
        
        // Create concurrent read operations
        let tasks = (0..<readCount).map { _ in
            Task {
                return try await repository.getOriginalMAC(interface: interface)
            }
        }
        
        // Wait for all operations and verify results
        for task in tasks {
            let result = try await task.value
            XCTAssertEqual(result, macAddress, "All concurrent reads should return correct MAC")
        }
    }
    
    // MARK: - Persistence Tests
    
    func testDataPersistence() async throws {
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Create backup
        try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
        
        // Create new repository instance with same storage
        let newRepository = try MacAddressRepository(storageURL: tempStorageURL)
        
        // Verify data persisted
        let retrievedMAC = try await newRepository.getOriginalMAC(interface: interface)
        XCTAssertEqual(retrievedMAC, macAddress, "Data should persist across repository instances")
    }
    
    func testAtomicFileOperations() async throws {
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        // Create backup
        try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
        
        // Verify temporary file doesn't exist after successful write
        let tempFileURL = tempStorageURL.appendingPathExtension("tmp")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tempFileURL.path), 
                      "Temporary file should not exist after successful write")
        
        // Verify main file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempStorageURL.path),
                     "Main storage file should exist")
    }
    
    // MARK: - Error Handling Tests
    
    func testFileSystemErrorHandling() async throws {
        // Create repository with invalid path to trigger file system errors
        let invalidURL = URL(fileURLWithPath: "/invalid/path/that/does/not/exist")
        
        do {
            _ = try MacAddressRepository(storageURL: invalidURL)
            XCTFail("Should fail with invalid storage path")
        } catch {
            // Expected to fail - verify appropriate error handling
            XCTAssertTrue(error is MacRepositoryError || error is CocoaError,
                         "Should throw appropriate file system error")
        }
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflow() async throws {
        let interface = "en0"
        let originalMAC = "aa:bb:cc:dd:ee:ff"
        let spoofedMAC = "11:22:33:44:55:66"
        
        // 1. Backup original MAC
        try await repository.backupOriginalMAC(interface: interface, macAddress: originalMAC)
        
        // 2. Update current MAC (simulate spoofing)
        try await repository.updateCurrentMAC(interface: interface, macAddress: spoofedMAC)
        
        // 3. Verify backup state
        let allBackups = try await repository.getAllBackups()
        let backup = allBackups[interface]
        XCTAssertEqual(backup?.originalMAC, originalMAC, "Original MAC should be preserved")
        XCTAssertEqual(backup?.currentMAC, spoofedMAC, "Current MAC should be updated")
        
        // 4. Restore original MAC
        let restoredMAC = try await repository.restoreOriginalMAC(interface: interface)
        XCTAssertEqual(restoredMAC, originalMAC, "Restored MAC should match original")
        
        // 5. Verify cleanup
        let hasBackup = try await repository.hasBackup(interface: interface)
        XCTAssertFalse(hasBackup, "Backup should be removed after restoration")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceBackupOperations() throws {
        let interface = "en0"
        let macAddress = "aa:bb:cc:dd:ee:ff"
        
        measure {
            Task {
                try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
                try await repository.clearBackup(interface: interface)
            }
        }
    }
    
    func testPerformanceMassOperations() async throws {
        let operationCount = 100
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create many backups
        for i in 0..<operationCount {
            let interface = "en\(i)"
            let macAddress = String(format: "%02x:%02x:%02x:%02x:%02x:%02x", 
                                  i % 256, i % 256, i % 256, i % 256, i % 256, i % 256)
            try await repository.backupOriginalMAC(interface: interface, macAddress: macAddress)
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Should complete within reasonable time (adjust as needed)
        XCTAssertLessThan(executionTime, 5.0, "Mass operations should complete within 5 seconds")
        
        // Verify all backups exist
        let allBackups = try await repository.getAllBackups()
        XCTAssertEqual(allBackups.count, operationCount, "All backups should be created")
    }
    
    // MARK: - Helper Methods
    
    /// Test helper to verify repository state consistency
    func verifyRepositoryConsistency() async throws {
        let allBackups = try await repository.getAllBackups()
        
        for (interface, backup) in allBackups {
            // Verify interface consistency
            XCTAssertEqual(backup.interface, interface, "Interface should match key")
            
            // Verify MAC format
            XCTAssertTrue(isValidMACFormat(backup.originalMAC), "Original MAC should be valid")
            
            if let currentMAC = backup.currentMAC {
                XCTAssertTrue(isValidMACFormat(currentMAC), "Current MAC should be valid if present")
            }
            
            // Verify timestamp is reasonable (should not be in future)
            let currentTimestamp = Int64(Date().timeIntervalSince1970 * 1000)
            XCTAssertTrue(backup.timestamp <= currentTimestamp, "Timestamp should not be in future")
        }
    }
    
    /// Helper to validate MAC address format
    func isValidMACFormat(_ mac: String) -> Bool {
        let macPattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        let regex = try? NSRegularExpression(pattern: macPattern)
        let range = NSRange(location: 0, length: mac.utf16.count)
        return regex?.firstMatch(in: mac, range: range) != nil
    }
}
}