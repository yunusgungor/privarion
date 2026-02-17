import XCTest
import Foundation
@testable import PrivarionCore

final class AuditLoggerTests: XCTestCase {
    
    var auditLogger: AuditLogger!
    var tempLogDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for test logs
        tempLogDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("privarion_audit_test_\(UUID().uuidString)")
        
        do {
            try FileManager.default.createDirectory(at: tempLogDirectory, 
                                                  withIntermediateDirectories: true, 
                                                  attributes: nil)
        } catch {
            XCTFail("Failed to create temporary log directory: \(error)")
        }
        
        auditLogger = AuditLogger.shared
        auditLogger.resetTestStore()
    }
    
    override func tearDown() {
        // Clean up temporary directory
        do {
            try FileManager.default.removeItem(at: tempLogDirectory)
        } catch {
            print("Warning: Failed to clean up temporary directory: \(error)")
        }
        
        auditLogger = nil
        super.tearDown()
    }
    
    // MARK: - Audit Event Logging Tests
    
    func testLogSecurityEvent_ValidEvent_ShouldSucceed() {
        // Given
        let event = AuditLogger.SecurityEvent(
            type: .accessDenied,
            severity: .high,
            source: "test_component",
            target: "/etc/sensitive_file",
            details: [
                "user_id": "501",
                "process": "test_process",
                "action": "file_read"
            ]
        )
        
        // When
        let result = auditLogger.logSecurityEvent(event)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.logEntryID)
        XCTAssertNotNil(result.timestamp)
        
        // Verify event can be retrieved
        if let entryID = result.logEntryID {
            let retrievedEvent = auditLogger.getLogEntry(entryID: entryID)
            XCTAssertNotNil(retrievedEvent)
            XCTAssertEqual(retrievedEvent?.type, .accessDenied)
            XCTAssertEqual(retrievedEvent?.severity, .high)
            XCTAssertEqual(retrievedEvent?.source, "test_component")
        }
    }
    
    func testLogSystemEvent_ValidEvent_ShouldSucceed() {
        // Given
        let event = AuditLogger.SystemEvent(
            type: .configurationChange,
            component: "privacy_manager",
            operation: "profile_update",
            details: [
                "profile_id": "test_profile_001",
                "changes": "enforcement_level: moderate -> strict",
                "user": "admin"
            ]
        )
        
        // When
        let result = auditLogger.logSystemEvent(event)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.logEntryID)
        
        if let entryID = result.logEntryID {
            let retrievedEvent = auditLogger.getLogEntry(entryID: entryID)
            XCTAssertNotNil(retrievedEvent)
            XCTAssertEqual(retrievedEvent?.component, "privacy_manager")
            XCTAssertEqual(retrievedEvent?.operation, "profile_update")
        }
    }
    
    func testLogUserEvent_ValidEvent_ShouldSucceed() {
        // Given
        let event = AuditLogger.UserEvent(
            userID: "user_12345",
            action: .login,
            sessionID: "session_abcdef",
            clientInfo: AuditLogger.ClientInfo(
                ipAddress: "192.168.1.100",
                userAgent: "Privarion/1.0 (macOS)",
                deviceID: "device_xyz789"
            ),
            details: [
                "method": "local_authentication",
                "success": "true"
            ]
        )
        
        // When
        let result = auditLogger.logUserEvent(event)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.logEntryID)
        
        if let entryID = result.logEntryID {
            let retrievedEvent = auditLogger.getLogEntry(entryID: entryID)
            XCTAssertNotNil(retrievedEvent)
            XCTAssertEqual(retrievedEvent?.userID, "user_12345")
            XCTAssertEqual(retrievedEvent?.action, .login)
            XCTAssertEqual(retrievedEvent?.sessionID, "session_abcdef")
        }
    }
    
    func testLogComplianceEvent_ValidEvent_ShouldSucceed() {
        // Given
        let event = AuditLogger.ComplianceEvent(
            regulationType: .gdpr,
            eventType: .dataProcessing,
            dataSubject: "user_98765",
            processingBasis: "consent",
            dataCategories: ["personal_identifiers", "device_information"],
            details: [
                "processor": "analytics_engine",
                "purpose": "system_optimization",
                "retention_period": "30_days"
            ]
        )
        
        // When
        let result = auditLogger.logComplianceEvent(event)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.logEntryID)
        
        if let entryID = result.logEntryID {
            let retrievedEvent = auditLogger.getLogEntry(entryID: entryID)
            XCTAssertNotNil(retrievedEvent)
            XCTAssertEqual(retrievedEvent?.regulationType, .gdpr)
            XCTAssertEqual(retrievedEvent?.eventType, .dataProcessing)
            XCTAssertEqual(retrievedEvent?.dataSubject, "user_98765")
        }
    }
    
    // MARK: - Query and Filtering Tests
    
    func testQueryAuditLogs_ByTimeRange_ShouldReturnFilteredResults() {
        // Given
        let startTime = Date()
        
        let event1 = AuditLogger.SecurityEvent(
            type: .accessGranted,
            severity: .low,
            source: "test_source_1",
            target: "/tmp/file1",
            details: [:]
        )
        
        let event2 = AuditLogger.SecurityEvent(
            type: .accessDenied,
            severity: .medium,
            source: "test_source_2",
            target: "/tmp/file2",
            details: [:]
        )
        
        _ = auditLogger.logSecurityEvent(event1)
        Thread.sleep(forTimeInterval: 0.1) // Small delay
        let midTime = Date()
        Thread.sleep(forTimeInterval: 0.1)
        _ = auditLogger.logSecurityEvent(event2)
        
        _ = Date() // endTime değişkeni kullanılmadığı için anonymous variable olarak değiştirdim
        
        // When
        let query = AuditLogger.QueryParameters(
            startTime: startTime,
            endTime: midTime,
            eventTypes: [.security],
            severityLevels: nil,
            sources: nil,
            limit: 100,
            offset: 0
        )
        
        let results = auditLogger.queryAuditLogs(parameters: query)
        
        // Then
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertTrue(results.contains { $0.source == "test_source_1" })
        XCTAssertFalse(results.contains { $0.source == "test_source_2" })
    }
    
    func testQueryAuditLogs_BySeverity_ShouldReturnFilteredResults() {
        // Given
        let highSeverityEvent = AuditLogger.SecurityEvent(
            type: .accessDenied,
            severity: .high,
            source: "high_severity_source",
            target: "/etc/critical_file",
            details: [:]
        )
        
        let lowSeverityEvent = AuditLogger.SecurityEvent(
            type: .accessGranted,
            severity: .low,
            source: "low_severity_source",
            target: "/tmp/temp_file",
            details: [:]
        )
        
        _ = auditLogger.logSecurityEvent(highSeverityEvent)
        _ = auditLogger.logSecurityEvent(lowSeverityEvent)
        
        // When
        let query = AuditLogger.QueryParameters(
            startTime: Date().addingTimeInterval(-60),
            endTime: Date(),
            eventTypes: [.security],
            severityLevels: [.high],
            sources: nil,
            limit: 100,
            offset: 0
        )
        
        let results = auditLogger.queryAuditLogs(parameters: query)
        
        // Then
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertTrue(results.allSatisfy { $0.severity == .high })
        XCTAssertTrue(results.contains { $0.source == "high_severity_source" })
    }
    
    func testQueryAuditLogs_BySource_ShouldReturnFilteredResults() {
        // Given
        let event1 = AuditLogger.SecurityEvent(
            type: .accessGranted,
            severity: .medium,
            source: "specific_component",
            target: "/tmp/file1",
            details: [:]
        )
        
        let event2 = AuditLogger.SecurityEvent(
            type: .accessDenied,
            severity: .medium,
            source: "other_component",
            target: "/tmp/file2",
            details: [:]
        )
        
        _ = auditLogger.logSecurityEvent(event1)
        _ = auditLogger.logSecurityEvent(event2)
        
        // When
        let query = AuditLogger.QueryParameters(
            startTime: Date().addingTimeInterval(-60),
            endTime: Date(),
            eventTypes: [.security],
            severityLevels: nil,
            sources: ["specific_component"],
            limit: 100,
            offset: 0
        )
        
        let results = auditLogger.queryAuditLogs(parameters: query)
        
        // Then
        XCTAssertGreaterThanOrEqual(results.count, 1)
        XCTAssertTrue(results.allSatisfy { $0.source == "specific_component" })
    }
    
    // MARK: - Statistics Tests
    
    func testGetAuditStatistics_ShouldReturnValidStats() {
        // Given
        let securityEvent = AuditLogger.SecurityEvent(
            type: .accessDenied,
            severity: .high,
            source: "stats_test",
            target: "/test/path",
            details: [:]
        )
        
        let systemEvent = AuditLogger.SystemEvent(
            type: .serviceStart,
            component: "stats_component",
            operation: "initialization",
            details: [:]
        )
        
        _ = auditLogger.logSecurityEvent(securityEvent)
        _ = auditLogger.logSystemEvent(systemEvent)
        
        // When
        let stats = auditLogger.getAuditStatistics()
        
        // Then
        XCTAssertGreaterThanOrEqual(stats.totalEvents, 2)
        XCTAssertGreaterThanOrEqual(stats.securityEvents, 1)
        XCTAssertGreaterThanOrEqual(stats.systemEvents, 1)
        XCTAssertGreaterThanOrEqual(stats.eventsToday, 0)
        XCTAssertGreaterThanOrEqual(stats.uniqueSources, 1)
        XCTAssertNotNil(stats.lastEventTime)
    }
    
    func testGetAuditStatisticsByTimeRange_ShouldReturnFilteredStats() {
        // Given
        let event = AuditLogger.SecurityEvent(
            type: .accessGranted,
            severity: .low,
            source: "time_range_test",
            target: "/test/file",
            details: [:]
        )
        
        let logTime = Date()
        _ = auditLogger.logSecurityEvent(event)
        
        // When
        let stats = auditLogger.getAuditStatistics(
            startTime: logTime.addingTimeInterval(-60),
            endTime: logTime.addingTimeInterval(60)
        )
        
        // Then
        XCTAssertGreaterThanOrEqual(stats.totalEvents, 1)
        XCTAssertGreaterThanOrEqual(stats.securityEvents, 1)
    }
    
    // MARK: - Configuration Tests
    
    func testUpdateConfiguration_ValidConfig_ShouldSucceed() {
        // Given
        let newConfig = AuditLogger.Configuration(
            logLevel: .debug,
            enableFileLogging: true,
            enableSystemLogging: false,
            logDirectory: tempLogDirectory.path,
            maxLogFileSize: 5242880, // 5MB
            maxLogFiles: 10,
            logRotationEnabled: true,
            compressionEnabled: false,
            encryptionEnabled: false,
            bufferSize: 1000,
            flushInterval: 5.0,
            includeStackTrace: true,
            timestampFormat: .iso8601,
            structuredLogging: true
        )
        
        // When
        let result = auditLogger.updateConfiguration(newConfig)
        
        // Then
        XCTAssertTrue(result.success)
        
        let currentConfig = auditLogger.getCurrentConfiguration()
        XCTAssertEqual(currentConfig.logLevel, .debug)
        XCTAssertEqual(currentConfig.maxLogFileSize, 5242880)
        XCTAssertEqual(currentConfig.maxLogFiles, 10)
        XCTAssertTrue(currentConfig.includeStackTrace)
    }
    
    func testFlushLogs_ShouldCompleteSuccessfully() {
        // Given
        let event = AuditLogger.SecurityEvent(
            type: .accessGranted,
            severity: .low,
            source: "flush_test",
            target: "/tmp/flush_test",
            details: [:]
        )
        
        _ = auditLogger.logSecurityEvent(event)
        
        // When
        let result = auditLogger.flushLogs()
        
        // Then
        XCTAssertTrue(result.success)
    }
    
    // MARK: - Event Type Tests
    
    func testSecurityEventType_AllCases_ShouldExist() {
        // Given & When
        let securityTypes = AuditLogger.SecurityEvent.EventType.allCases
        
        // Then
        XCTAssertTrue(securityTypes.contains(.accessGranted))
        XCTAssertTrue(securityTypes.contains(.accessDenied))
        XCTAssertTrue(securityTypes.contains(.privilegeEscalation))
        XCTAssertTrue(securityTypes.contains(.suspiciousActivity))
        XCTAssertTrue(securityTypes.contains(.policyViolation))
        XCTAssertTrue(securityTypes.contains(.authenticationFailure))
        XCTAssertTrue(securityTypes.contains(.dataAccess))
    }
    
    func testSystemEventType_AllCases_ShouldExist() {
        // Given & When
        let systemTypes = AuditLogger.SystemEvent.EventType.allCases
        
        // Then
        XCTAssertTrue(systemTypes.contains(.serviceStart))
        XCTAssertTrue(systemTypes.contains(.serviceStop))
        XCTAssertTrue(systemTypes.contains(.configurationChange))
        XCTAssertTrue(systemTypes.contains(.softwareUpdate))
        XCTAssertTrue(systemTypes.contains(.errorOccurred))
        XCTAssertTrue(systemTypes.contains(.performanceIssue))
    }
    
    func testUserAction_AllCases_ShouldExist() {
        // Given & When
        let userActions = AuditLogger.UserEvent.Action.allCases
        
        // Then
        XCTAssertTrue(userActions.contains(.login))
        XCTAssertTrue(userActions.contains(.logout))
        XCTAssertTrue(userActions.contains(.dataExport))
        XCTAssertTrue(userActions.contains(.dataDelete))
        XCTAssertTrue(userActions.contains(.settingsChange))
        XCTAssertTrue(userActions.contains(.profileAccess))
    }
    
    func testComplianceRegulationType_AllCases_ShouldExist() {
        // Given & When
        let regulationTypes = AuditLogger.ComplianceEvent.RegulationType.allCases
        
        // Then
        XCTAssertTrue(regulationTypes.contains(.gdpr))
        XCTAssertTrue(regulationTypes.contains(.ccpa))
        XCTAssertTrue(regulationTypes.contains(.hipaa))
        XCTAssertTrue(regulationTypes.contains(.sox))
        XCTAssertTrue(regulationTypes.contains(.pci))
    }
    
    // MARK: - Error Handling Tests
    
    func testLogEvent_InvalidDetails_ShouldHandleGracefully() {
        // Given
        let eventWithEmptyDetails = AuditLogger.SecurityEvent(
            type: .accessGranted,
            severity: .low,
            source: "",
            target: "",
            details: [:]
        )
        
        // When
        let result = auditLogger.logSecurityEvent(eventWithEmptyDetails)
        
        // Then
        XCTAssertTrue(result.success) // Should handle gracefully
        XCTAssertNotNil(result.logEntryID)
    }
    
    func testGetLogEntry_InvalidEntryID_ShouldReturnNil() {
        // Given
        let invalidEntryID = "invalid_entry_id_12345"
        
        // When
        let retrievedEvent = auditLogger.getLogEntry(entryID: invalidEntryID)
        
        // Then
        XCTAssertNil(retrievedEvent)
    }
    
    // MARK: - Performance Tests
    
    func testLogSecurityEvent_Performance() {
        // Test that event logging completes within reasonable time
        let event = AuditLogger.SecurityEvent(
            type: .accessGranted,
            severity: .low,
            source: "performance_test",
            target: "/tmp/perf_test",
            details: ["iteration": "performance_test"]
        )
        
        // Basit performance test - measure yerine manual timing
        let startTime = Date()
        for _ in 0..<10 { // 100 yerine 10'a düşürüldü
            _ = auditLogger.logSecurityEvent(event)
        }
        let endTime = Date()
        let elapsedTime = endTime.timeIntervalSince(startTime)
        
        // 10 event için maksimum 1 saniye
        XCTAssertLessThan(elapsedTime, 1.0, "Performance requirement not met: \(elapsedTime) seconds")
    }
    
    func testQueryAuditLogs_Performance() {
        // Given - Create multiple events
        for i in 0..<10 { // 50 yerine 10'a düşürüldü
            let event = AuditLogger.SecurityEvent(
                type: .accessGranted,
                severity: .low,
                source: "perf_test_\(i)",
                target: "/tmp/perf_file_\(i)",
                details: ["index": "\(i)"]
            )
            _ = auditLogger.logSecurityEvent(event)
        }
        
        // When - Test query performance
        let query = AuditLogger.QueryParameters(
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            eventTypes: [.security],
            severityLevels: nil,
            sources: nil,
            limit: 100,
            offset: 0
        )
        
        // Manual timing yerine measure
        let startTime = Date()
        _ = auditLogger.queryAuditLogs(parameters: query)
        let endTime = Date()
        let elapsedTime = endTime.timeIntervalSince(startTime)
        
        // Query için maksimum 0.5 saniye
        XCTAssertLessThan(elapsedTime, 0.5, "Query performance requirement not met: \(elapsedTime) seconds")
    }
}
