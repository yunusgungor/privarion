import XCTest
@testable import PrivarionCore

final class IdentityBackupManagerTests: XCTestCase {
    var backupManager: IdentityBackupManager!
    var logger: PrivarionLogger!
    
    override func setUp() {
        super.setUp()
        logger = PrivarionLogger.shared
        logger.updateLogLevel(.debug)
        
        do {
            backupManager = try IdentityBackupManager(logger: logger)
        } catch {
            XCTFail("Failed to initialize IdentityBackupManager: \(error)")
        }
    }
    
    override func tearDown() {
        // Clean up any test sessions
        do {
            try backupManager?.cleanupOldBackups(olderThan: 0) // Clean all non-persistent backups
        } catch {
            // Ignore cleanup errors in tests
        }
        backupManager = nil
        logger = nil
        super.tearDown()
    }
    
    func testSessionStartAndComplete() throws {
        // Given
        let sessionName = "test_session_\(UUID().uuidString)"
        
        // When
        let sessionId = try backupManager.startSession(name: sessionName, persistent: false)
        
        // Then
        XCTAssertFalse(sessionId.uuidString.isEmpty)
        
        // Add at least one backup to make session completable
        _ = try backupManager.addBackup(
            type: .hostname,
            originalValue: "test-hostname"
        )
        
        // When completing session
        XCTAssertNoThrow(try backupManager.completeSession())
    }
    
    func testAddBackupToSession() throws {
        // Given
        let sessionName = "backup_test_session"
        _ = try backupManager.startSession(name: sessionName)
        
        // When
        let backupId = try backupManager.addBackup(
            type: .hostname,
            originalValue: "original-hostname",
            newValue: "new-hostname",
            metadata: ["test": "value"]
        )
        
        // Then
        XCTAssertFalse(backupId.uuidString.isEmpty)
        
        // Complete session
        try backupManager.completeSession()
    }
    
    func testCreateSingleBackup() throws {
        // Given
        let originalMAC = "aa:bb:cc:dd:ee:ff"
        
        // When
        let backupId = try backupManager.createBackup(
            type: .macAddress,
            originalValue: originalMAC
        )
        
        // Then
        XCTAssertFalse(backupId.uuidString.isEmpty)
    }
    
    func testRestoreFromBackup() throws {
        // Given - Create a backup first
        let originalHostname = "test-hostname"
        let backupId = try backupManager.createBackup(
            type: .hostname,
            originalValue: originalHostname
        )
        
        // When
        let restoredBackup = try backupManager.restoreFromBackup(backupId: backupId)
        
        // Then
        XCTAssertEqual(restoredBackup.backupId, backupId)
        XCTAssertEqual(restoredBackup.originalValue, originalHostname)
        XCTAssertEqual(restoredBackup.type, .hostname)
    }
    
    func testRestoreFromNonexistentBackup() {
        // Given
        let nonexistentId = UUID()
        
        // When/Then
        XCTAssertThrowsError(try backupManager.restoreFromBackup(backupId: nonexistentId)) { error in
            guard case IdentityBackupManager.BackupError.backupNotFound(let id) = error else {
                XCTFail("Expected backupNotFound error, got \(error)")
                return
            }
            XCTAssertEqual(id, nonexistentId)
        }
    }
    
    func testSessionRestore() throws {
        // Given - Create a session with multiple backups
        let sessionName = "multi_backup_session"
        let sessionId = try backupManager.startSession(name: sessionName)
        
        _ = try backupManager.addBackup(type: .hostname, originalValue: "host1")
        _ = try backupManager.addBackup(type: .macAddress, originalValue: "aa:bb:cc:dd:ee:ff")
        
        try backupManager.completeSession()
        
        // When
        let restoredBackups = try backupManager.restoreSession(sessionId: sessionId)
        
        // Then
        XCTAssertEqual(restoredBackups.count, 2)
        
        let hostnames = restoredBackups.filter { $0.type == .hostname }
        let macAddresses = restoredBackups.filter { $0.type == .macAddress }
        
        XCTAssertEqual(hostnames.count, 1)
        XCTAssertEqual(macAddresses.count, 1)
        XCTAssertEqual(hostnames.first?.originalValue, "host1")
        XCTAssertEqual(macAddresses.first?.originalValue, "aa:bb:cc:dd:ee:ff")
    }
    
    func testListBackups() throws {
        // Given - Start with no backups
        let initialBackups = try backupManager.listBackups()
        let initialCount = initialBackups.count
        
        // Create some backups
        _ = try backupManager.createBackup(type: .hostname, originalValue: "test-host-1")
        _ = try backupManager.createBackup(type: .macAddress, originalValue: "aa:bb:cc:dd:ee:ff")
        
        // When
        let backups = try backupManager.listBackups()
        
        // Then
        XCTAssertEqual(backups.count, initialCount + 2)
        
        // Verify sessions are sorted by timestamp (newest first)
        if backups.count > 1 {
            for i in 0..<(backups.count - 1) {
                XCTAssertGreaterThanOrEqual(backups[i].timestamp, backups[i + 1].timestamp)
            }
        }
    }
    
    func testPersistentSession() throws {
        // Given
        let sessionName = "persistent_test_session"
        
        // When - Create persistent session
        let sessionId = try backupManager.startSession(name: sessionName, persistent: true)
        _ = try backupManager.addBackup(type: .hostname, originalValue: "persistent-host")
        try backupManager.completeSession()
        
        // Create new backup manager instance to test persistence
        let newBackupManager = try IdentityBackupManager(logger: logger)
        let sessions = try newBackupManager.listBackups()
        
        // Then
        let persistentSession = sessions.first { $0.sessionId == sessionId }
        XCTAssertNotNil(persistentSession)
        XCTAssertTrue(persistentSession?.persistent ?? false)
        XCTAssertEqual(persistentSession?.sessionName, sessionName)
    }
    
    func testCleanupOldBackups() throws {
        // Given - Create non-persistent and persistent sessions
        let nonPersistentId = try backupManager.startSession(name: "temp_session", persistent: false)
        _ = try backupManager.addBackup(type: .hostname, originalValue: "temp-host")
        try backupManager.completeSession()
        
        let persistentId = try backupManager.startSession(name: "permanent_session", persistent: true)
        _ = try backupManager.addBackup(type: .hostname, originalValue: "permanent-host")
        try backupManager.completeSession()
        
        // When - Cleanup with 0 age (should remove all non-persistent)
        try backupManager.cleanupOldBackups(olderThan: 0)
        
        // Then
        let remainingSessions = try backupManager.listBackups()
        let persistentSessions = remainingSessions.filter { $0.persistent }
        let nonPersistentSessions = remainingSessions.filter { !$0.persistent }
        
        // Persistent session should remain
        XCTAssertTrue(persistentSessions.contains { $0.sessionId == persistentId })
        
        // Non-persistent session should be removed
        XCTAssertFalse(nonPersistentSessions.contains { $0.sessionId == nonPersistentId })
    }
    
    func testValidateBackupIntegrity() throws {
        // Given - Create valid backups
        _ = try backupManager.createBackup(type: .hostname, originalValue: "valid-hostname")
        _ = try backupManager.createBackup(type: .macAddress, originalValue: "aa:bb:cc:dd:ee:ff")
        
        // When
        let isValid = try backupManager.validateBackupIntegrity()
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testSessionWithMetadata() throws {
        // Given
        let sessionName = "metadata_test_session"
        _ = try backupManager.startSession(name: sessionName)
        
        let metadata = [
            "environment": "test",
            "version": "1.0.0",
            "user": "test_user"
        ]
        
        // When
        let backupId = try backupManager.addBackup(
            type: .hostname,
            originalValue: "test-host",
            newValue: "modified-host",
            metadata: metadata
        )
        
        try backupManager.completeSession()
        
        // Then
        let restoredBackup = try backupManager.restoreFromBackup(backupId: backupId)
        XCTAssertEqual(restoredBackup.metadata, metadata)
        XCTAssertEqual(restoredBackup.newValue, "modified-host")
    }
    
    func testSequentialSessionManagement() throws {
        // Given
        let sessionNames = ["session_1", "session_2", "session_3"]
        var createdSessionIds: [UUID] = []
        
        // When - Create multiple sessions sequentially
        for (index, sessionName) in sessionNames.enumerated() {
            let sessionId = try backupManager.startSession(name: sessionName)
            createdSessionIds.append(sessionId)
            
            _ = try backupManager.addBackup(type: .hostname, originalValue: "host-\(index)")
            try backupManager.completeSession()
        }
        
        // Then
        let sessions = try backupManager.listBackups()
        let testSessions = sessions.filter { sessionNames.contains($0.sessionName) }
        XCTAssertEqual(testSessions.count, 3)
        
        // Verify each session was created with correct ID
        for sessionId in createdSessionIds {
            let matchingSession = sessions.first { $0.sessionId == sessionId }
            XCTAssertNotNil(matchingSession, "Session with ID \(sessionId) should exist")
        }
    }
    
    func testBackupTypes() throws {
        // Test all supported identity types
        let testCases: [(IdentitySpoofingManager.IdentityType, String)] = [
            (.hostname, "test-hostname"),
            (.macAddress, "aa:bb:cc:dd:ee:ff"),
            (.diskUUID, "12345678-1234-5678-9abc-123456789abc"),
            (.serialNumber, "TEST123456"),
            (.networkInterface, "en0")
        ]
        
        // Given/When - Create backups for each type
        var backupIds: [UUID] = []
        for (type, value) in testCases {
            let backupId = try backupManager.createBackup(type: type, originalValue: value)
            backupIds.append(backupId)
        }
        
        // Then - Verify all backups can be restored
        for (index, backupId) in backupIds.enumerated() {
            let restoredBackup = try backupManager.restoreFromBackup(backupId: backupId)
            let (expectedType, expectedValue) = testCases[index]
            
            XCTAssertEqual(restoredBackup.type, expectedType)
            XCTAssertEqual(restoredBackup.originalValue, expectedValue)
        }
    }
    
    func testThreadSafetyReadOperations() throws {
        // Given - Create some test data first
        _ = try backupManager.createBackup(type: .hostname, originalValue: "thread-test-host")
        _ = try backupManager.createBackup(type: .macAddress, originalValue: "aa:bb:cc:dd:ee:ff")
        
        let expectation = XCTestExpectation(description: "Concurrent read operations complete")
        expectation.expectedFulfillmentCount = 5
        
        let concurrentQueue = DispatchQueue(label: "test.concurrent.read", attributes: .concurrent)
        
        // When - Perform multiple concurrent read operations
        for i in 0..<5 {
            concurrentQueue.async {
                do {
                    // Test concurrent list operations
                    let sessions = try self.backupManager.listBackups()
                    XCTAssertGreaterThanOrEqual(sessions.count, 2)
                    
                    // Test concurrent integrity validation
                    let isValid = try self.backupManager.validateBackupIntegrity()
                    XCTAssertTrue(isValid)
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent read operation \(i) failed: \(error)")
                }
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 5.0)
    }
}
