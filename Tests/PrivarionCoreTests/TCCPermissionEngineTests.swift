import XCTest
import SQLite3
@testable import PrivarionCore

@available(macOS 12.0, *)
final class TCCPermissionEngineTests: XCTestCase {
    
    var tccEngine: TCCPermissionEngine!
    var mockDatabasePath: String!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock database path for testing
        mockDatabasePath = createMockTCCDatabase()
        tccEngine = TCCPermissionEngine(databasePath: mockDatabasePath)
    }
    
    override func tearDown() async throws {
        // Clean up mock database
        if let mockPath = mockDatabasePath {
            try? FileManager.default.removeItem(atPath: mockPath)
        }
        
        try await super.tearDown()
    }
    
    // MARK: - Connection Tests
    
    func testDatabaseConnection() async throws {
        // Test successful connection to mock database
        try await tccEngine.connect()
        
        let metrics = await tccEngine.getPerformanceMetrics()
        XCTAssertTrue(metrics.isConnected, "Should be connected to database")
        
        await tccEngine.disconnect()
        
        let metricsAfterDisconnect = await tccEngine.getPerformanceMetrics()
        XCTAssertFalse(metricsAfterDisconnect.isConnected, "Should be disconnected from database")
    }
    
    func testConnectionToNonExistentDatabase() async throws {
        let nonExistentEngine = TCCPermissionEngine(databasePath: "/non/existent/path/TCC.db")
        
        do {
            try await nonExistentEngine.connect()
            XCTFail("Should throw databaseNotFound error")
        } catch TCCPermissionEngine.TCCError.databaseNotFound {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Permission Enumeration Tests
    
    func testPermissionEnumerationPerformance() async throws {
        // Test enumeration performance target: <50ms
        try await tccEngine.connect()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let permissions = try await tccEngine.enumeratePermissions()
        let enumerationTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(enumerationTime, 0.050, "Enumeration should complete in under 50ms")
        XCTAssertGreaterThan(permissions.count, 0, "Should return mock permissions")
        
        // Verify performance metrics are updated
        let metrics = await tccEngine.getPerformanceMetrics()
        XCTAssertGreaterThan(metrics.enumerationCount, 0, "Enumeration count should be tracked")
        XCTAssertGreaterThan(metrics.lastEnumerationTime, 0, "Last enumeration time should be recorded")
    }
    
    func testPermissionEnumerationContent() async throws {
        try await tccEngine.connect()
        let permissions = try await tccEngine.enumeratePermissions()
        
        // Verify mock data contains expected permissions
        let cameraPermissions = permissions.filter { $0.service == .camera }
        XCTAssertGreaterThan(cameraPermissions.count, 0, "Should contain camera permissions")
        
        let microphonePermissions = permissions.filter { $0.service == .microphone }
        XCTAssertGreaterThan(microphonePermissions.count, 0, "Should contain microphone permissions")
        
        // Verify permission structure
        for permission in permissions {
            XCTAssertFalse(permission.bundleId.isEmpty, "Bundle ID should not be empty")
            XCTAssert(permission.lastModified <= Date(), "Last modified should not be in future")
            XCTAssertGreaterThanOrEqual(permission.promptCount, 0, "Prompt count should not be negative")
        }
    }
    
    // MARK: - Specific Permission Query Tests
    
    func testGetPermissionStatusForSpecificApp() async throws {
        try await tccEngine.connect()
        
        // Test querying permission for specific app
        let status = try await tccEngine.getPermissionStatus(for: "com.test.mockapp", service: .camera)
        XCTAssertNotNil(status, "Should return status for mock app")
        XCTAssertEqual(status, .allowed, "Mock app should have camera permission allowed")
        
        // Test querying non-existent permission
        let nonExistentStatus = try await tccEngine.getPermissionStatus(for: "com.nonexistent.app", service: .camera)
        XCTAssertNil(nonExistentStatus, "Should return nil for non-existent permission")
    }
    
    func testGetPermissionsForApplication() async throws {
        try await tccEngine.connect()
        
        let permissions = try await tccEngine.getPermissions(for: "com.test.mockapp")
        XCTAssertGreaterThan(permissions.count, 0, "Mock app should have permissions")
        
        // Verify all returned permissions belong to the requested app
        for permission in permissions {
            XCTAssertEqual(permission.bundleId, "com.test.mockapp", "All permissions should belong to requested app")
        }
    }
    
    func testGetPermissionsForService() async throws {
        try await tccEngine.connect()
        
        let cameraPermissions = try await tccEngine.getPermissions(for: .camera)
        XCTAssertGreaterThan(cameraPermissions.count, 0, "Should have camera permissions")
        
        // Verify all returned permissions are for camera service
        for permission in cameraPermissions {
            XCTAssertEqual(permission.service, .camera, "All permissions should be for camera service")
        }
    }
    
    // MARK: - Risk Analysis Tests
    
    func testPermissionRiskAnalysis() async throws {
        try await tccEngine.connect()
        
        let riskProfile = try await tccEngine.analyzePermissionRisk(for: "com.test.mockapp")
        
        XCTAssertEqual(riskProfile.bundleId, "com.test.mockapp", "Risk profile should be for requested app")
        XCTAssertGreaterThan(riskProfile.totalRiskScore, 0, "Risk score should be calculated")
        XCTAssertNotNil(riskProfile.riskLevel, "Risk level should be determined")
        
        // Test high-risk app analysis
        let highRiskProfile = try await tccEngine.analyzePermissionRisk(for: "com.test.highriskapp")
        XCTAssertEqual(highRiskProfile.riskLevel, .critical, "High risk app should have critical risk level")
        XCTAssertGreaterThan(highRiskProfile.criticalPermissions.count, 0, "Should identify critical permissions")
    }
    
    // MARK: - Service Type Tests
    
    func testTCCServiceProperties() {
        // Test service display names
        XCTAssertEqual(TCCPermissionEngine.TCCService.camera.displayName, "Camera")
        XCTAssertEqual(TCCPermissionEngine.TCCService.microphone.displayName, "Microphone")
        XCTAssertEqual(TCCPermissionEngine.TCCService.fullDiskAccess.displayName, "Full Disk Access")
        
        // Test sensitivity levels
        XCTAssertEqual(TCCPermissionEngine.TCCService.camera.sensitivityLevel, .critical)
        XCTAssertEqual(TCCPermissionEngine.TCCService.microphone.sensitivityLevel, .critical)
        XCTAssertEqual(TCCPermissionEngine.TCCService.fullDiskAccess.sensitivityLevel, .high)
        XCTAssertEqual(TCCPermissionEngine.TCCService.contacts.sensitivityLevel, .medium)
        XCTAssertEqual(TCCPermissionEngine.TCCService.bluetoothAlways.sensitivityLevel, .low)
        
        // Test service enumeration
        let allServices = TCCPermissionEngine.TCCService.allCases
        XCTAssertGreaterThan(allServices.count, 10, "Should have comprehensive service coverage")
    }
    
    func testPermissionStatusProperties() {
        // Test permission status display names
        XCTAssertEqual(TCCPermissionEngine.TCCPermissionStatus.allowed.displayName, "Allowed")
        XCTAssertEqual(TCCPermissionEngine.TCCPermissionStatus.denied.displayName, "Denied")
        XCTAssertEqual(TCCPermissionEngine.TCCPermissionStatus.unknown.displayName, "Unknown")
        XCTAssertEqual(TCCPermissionEngine.TCCPermissionStatus.limited.displayName, "Limited")
        
        // Test granted status logic
        XCTAssertTrue(TCCPermissionEngine.TCCPermissionStatus.allowed.isGranted)
        XCTAssertTrue(TCCPermissionEngine.TCCPermissionStatus.limited.isGranted)
        XCTAssertFalse(TCCPermissionEngine.TCCPermissionStatus.denied.isGranted)
        XCTAssertFalse(TCCPermissionEngine.TCCPermissionStatus.unknown.isGranted)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorDescriptions() {
        let errors: [TCCPermissionEngine.TCCError] = [
            .databaseNotFound,
            .accessDenied,
            .invalidQuery,
            .corruptedData,
            .unknownService("test")
        ]
        
        for error in errors {
            XCTAssertFalse(error.description.isEmpty, "Error should have descriptive message")
            XCTAssertTrue(error.description.count > 10, "Error description should be meaningful")
        }
    }
    
    // MARK: - Mock Database Creation
    
    private func createMockTCCDatabase() -> String {
        let tempDir = NSTemporaryDirectory()
        let mockDBPath = tempDir + "mock_tcc_\(UUID().uuidString).db"
        
        var db: OpaquePointer?
        guard sqlite3_open(mockDBPath, &db) == SQLITE_OK else {
            XCTFail("Failed to create mock database")
            return mockDBPath
        }
        
        // Create TCC access table structure
        let createTableSQL = """
            CREATE TABLE access (
                service TEXT,
                client TEXT,
                client_type INTEGER,
                auth_value INTEGER,
                auth_reason INTEGER,
                auth_version INTEGER,
                csreq BLOB,
                policy_id INTEGER,
                indirect_object_identifier_type INTEGER,
                indirect_object_identifier TEXT,
                indirect_object_code_identity BLOB,
                flags INTEGER,
                last_modified INTEGER,
                pid INTEGER,
                pid_version INTEGER,
                boot_uuid TEXT,
                prompt_count INTEGER,
                PRIMARY KEY (service, client, client_type, indirect_object_identifier)
            )
        """
        
        sqlite3_exec(db, createTableSQL, nil as sqlite3_callback?, nil, nil)
        
        // Insert mock permission data
        let mockPermissions = [
            // Camera permissions
            ("kTCCServiceCamera", "com.test.mockapp", 2, Date().timeIntervalSince1970, 1),
            ("kTCCServiceCamera", "com.test.highriskapp", 2, Date().timeIntervalSince1970, 5),
            ("kTCCServiceCamera", "com.malware.suspicious", 0, Date().timeIntervalSince1970, 10),
            
            // Microphone permissions
            ("kTCCServiceMicrophone", "com.test.mockapp", 2, Date().timeIntervalSince1970, 0),
            ("kTCCServiceMicrophone", "com.test.highriskapp", 2, Date().timeIntervalSince1970, 2),
            
            // Full Disk Access
            ("kTCCServiceSystemPolicyAllFiles", "com.test.highriskapp", 2, Date().timeIntervalSince1970, 1),
            
            // Screen Recording
            ("kTCCServiceScreenCapture", "com.test.highriskapp", 2, Date().timeIntervalSince1970, 0),
            
            // Contact access
            ("kTCCServiceAddressBook", "com.test.mockapp", 2, Date().timeIntervalSince1970, 1),
        ]
        
        for (service, bundleId, authValue, timestamp, promptCount) in mockPermissions {
            let insertSQL = """
                INSERT INTO access (service, client, client_type, auth_value, auth_reason, 
                                  auth_version, last_modified, prompt_count)
                VALUES (?, ?, 0, ?, 1, 1, ?, ?)
            """
            
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, service, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_text(statement, 2, bundleId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                sqlite3_bind_int(statement, 3, Int32(authValue))
                sqlite3_bind_int64(statement, 4, Int64(timestamp))
                sqlite3_bind_int(statement, 5, Int32(promptCount))
                
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
        
        sqlite3_close(db)
        return mockDBPath
    }
}
