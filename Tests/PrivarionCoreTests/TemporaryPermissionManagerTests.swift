import XCTest
import Foundation
@testable import PrivarionCore

/// Comprehensive test suite for TemporaryPermissionManager
/// Tests all aspects including CLI integration, performance, and reliability
final class TemporaryPermissionManagerTests: XCTestCase {
    
    var manager: TemporaryPermissionManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        manager = TemporaryPermissionManager()
    }
    
    override func tearDownWithError() throws {
        // Clean up any remaining grants asynchronously
        if let manager = manager {
            Task {
                await manager.clearAllGrants()
            }
        }
        manager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Core Functionality Tests
    
    func testGrantPermissionSuccess() async throws {
        // Clear any existing grants for test isolation
        await manager.clearAllGrants()
        
        let request = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "com.test.app.grant.success.\(UUID().uuidString)",
            serviceName: "kTCCServiceCamera",
            duration: 300, // 5 minutes
            reason: "Test camera access",
            requestedBy: "unit-test"
        )
        
        let result = try await manager.grantPermission(request)
        
        // Verify result is granted and contains valid grant
        guard case .granted(let grantedPermission) = result else {
            XCTFail("Expected .granted result, got \(result)")
            return
        }
        
        // Verify grant details
        XCTAssertEqual(grantedPermission.bundleIdentifier, request.bundleIdentifier)
        XCTAssertEqual(grantedPermission.serviceName, "kTCCServiceCamera")
        XCTAssertEqual(grantedPermission.reason, "Test camera access")
        XCTAssertEqual(grantedPermission.grantedBy, "unit-test")
        
        // Verify grant was created in active grants
        let grants = await manager.getActiveGrants()
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.id, grantedPermission.id)
    }
    
    func testRevokePermissionSuccess() async throws {
        // Clear any existing grants for test isolation
        await manager.clearAllGrants()
        
        // Grant permission first
        let request = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "com.test.app.revoke.\(UUID().uuidString)",
            serviceName: "kTCCServiceCamera",
            duration: 300,
            reason: "Test grant",
            requestedBy: "unit-test"
        )
        
        let result = try await manager.grantPermission(request)
        guard case .granted(let grant) = result else {
            XCTFail("Grant should succeed")
            return
        }
        
        // Revoke the permission
        let revokeSuccess = await manager.revokePermission(grantID: grant.id)
        XCTAssertTrue(revokeSuccess)
        
        // Verify grant no longer exists
        let remainingGrants = await manager.getActiveGrants()
        XCTAssertEqual(remainingGrants.count, 0)
    }
    
    func testGetGrantById() async throws {
        // Clear any existing grants for test isolation
        await manager.clearAllGrants()
        
        // Grant permission
        let bundleId = "com.test.app.getbyid.\(UUID().uuidString)"
        let request = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: bundleId,
            serviceName: "kTCCServiceCamera",
            duration: 300,
            reason: "Test grant",
            requestedBy: "unit-test"
        )
        
        let result = try await manager.grantPermission(request)
        guard case .granted(let originalGrant) = result else {
            XCTFail("Grant should succeed")
            return
        }
        
        // Retrieve grant by ID
        let retrievedGrant = await manager.getGrant(id: originalGrant.id)
        XCTAssertNotNil(retrievedGrant)
        XCTAssertEqual(retrievedGrant?.id, originalGrant.id)
        XCTAssertEqual(retrievedGrant?.bundleIdentifier, bundleId)
    }
    
    // MARK: - CLI Integration Tests
    
    func testListGrantsForCLI() async throws {
        // Clear any existing grants for test isolation
        await manager.clearAllGrants()
        
        // Grant a permission
        let bundleId = "com.test.app.cli.\(UUID().uuidString)"
        let request = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: bundleId,
            serviceName: "kTCCServiceCamera",
            duration: 300,
            reason: "CLI test grant",
            requestedBy: "cli-test"
        )
        
        let result = try await manager.grantPermission(request)
        guard case .granted = result else {
            XCTFail("Grant should succeed")
            return
        }
        
        // Test CLI listing
        let cliOutput = await manager.listGrantsForCLI()
        
        // Bundle ID gets truncated in the output, so check for prefix
        let bundleIdPrefix = String(bundleId.prefix(18))
        XCTAssertTrue(cliOutput.contains(bundleIdPrefix))
        XCTAssertTrue(cliOutput.contains("Camera"))
        XCTAssertTrue(cliOutput.contains("CLI test grant"))
        XCTAssertTrue(cliOutput.contains("cli-test"))
        
        // Also verify with getActiveGrants
        let grants = await manager.getActiveGrants()
        XCTAssertEqual(grants.count, 1)
        XCTAssertEqual(grants.first?.bundleIdentifier, bundleId)
    }
    
    func testExportToJSON() async throws {
        // Clear any existing grants for test isolation
        await manager.clearAllGrants()
        
        // Grant a permission
        let bundleId = "com.test.app.json.\(UUID().uuidString)"
        let request = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: bundleId,
            serviceName: "kTCCServiceMicrophone",
            duration: 300,
            reason: "JSON export test",
            requestedBy: "json-test"
        )
        
        let result = try await manager.grantPermission(request)
        guard case .granted = result else {
            XCTFail("Grant should succeed")
            return
        }
        
        // Test JSON export
        let jsonOutput = try await manager.exportGrantsToJSON()
        
        XCTAssertTrue(jsonOutput.contains(bundleId))
        XCTAssertTrue(jsonOutput.contains("kTCCServiceMicrophone"))
        XCTAssertTrue(jsonOutput.contains("JSON export test"))
        
        // Verify it's valid JSON
        let jsonData = jsonOutput.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(parsed)
    }
    
    func testFormatGrantResultForCLI() async throws {
        // Create a dummy grant for testing CLI formatting
        let request = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "com.test.app",
            serviceName: "kTCCServiceCamera",
            duration: 300,
            reason: "Test grant",
            requestedBy: "test"
        )
        
        let result = try await manager.grantPermission(request)
        
        // Test formatting different result types
        let message = await manager.formatGrantResultForCLI(result)
        XCTAssertFalse(message.isEmpty)
        XCTAssertTrue(message.contains("✅") || message.contains("❌") || message.contains("⚠️"))
    }
    
    // MARK: - Duration Parsing Tests
    
    func testParseDuration() {
        let testCases: [(String, TimeInterval?)] = [
            ("30s", 30),
            ("5m", 300),
            ("2h", 7200),
            ("1h30m", 5400),
            ("90m", 5400),
            ("0.5h", 1800),
            ("invalid", nil),
            ("", nil),
            ("30", nil), // Missing unit
            ("-5m", nil) // Negative duration
        ]
        
        for (input, expected) in testCases {
            let result = TemporaryPermissionManager.parseDuration(input)
            if let expected = expected {
                XCTAssertEqual(result, expected, "Failed to parse '\(input)'")
            } else {
                XCTAssertNil(result, "Should have failed to parse '\(input)'")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testGrantPerformance() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Grant permission
        let request = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "com.performance.test",
            serviceName: "kTCCServiceCamera",
            duration: 300,
            reason: "Performance test",
            requestedBy: "perf-test"
        )
        
        let result = try await manager.grantPermission(request)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        guard case .granted = result else {
            XCTFail("Grant should succeed")
            return
        }
        
        XCTAssertLessThan(duration, 0.05, "Grant operation should complete within 50ms")
    }
    
    func testSystemReliabilityMetrics() async throws {
        // Get initial metrics
        let (initialSuccessRate, initialAvgCleanup, initialTotalGrants) = await manager.getReliabilityMetrics()
        
        // Verify metrics are reasonable
        XCTAssertGreaterThanOrEqual(initialSuccessRate, 0.0)
        XCTAssertLessThanOrEqual(initialSuccessRate, 1.0)
        XCTAssertGreaterThanOrEqual(initialAvgCleanup, 0.0)
        XCTAssertGreaterThanOrEqual(initialTotalGrants, 0)
        
        // Test cleanup operation
        let stats = await manager.cleanupExpiredGrants()
        XCTAssertGreaterThanOrEqual(stats.expiredCleaned, 0)
        XCTAssertGreaterThanOrEqual(stats.successRate, 0.0)
        XCTAssertLessThanOrEqual(stats.successRate, 1.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidDurationRequest() async throws {
        let request = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "com.test.app",
            serviceName: "kTCCServiceCamera",
            duration: -100, // Invalid negative duration
            reason: "Invalid test",
            requestedBy: "test"
        )
        
        let result = try await manager.grantPermission(request)
        guard case .invalidRequest = result else {
            XCTFail("Should return .invalidRequest for negative duration")
            return
        }
    }
    
    func testEmptyBundleIdentifier() async throws {
        let request = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "", // Invalid empty bundle
            serviceName: "kTCCServiceCamera",
            duration: 300,
            reason: "Empty bundle test",
            requestedBy: "test"
        )
        
        let result = try await manager.grantPermission(request)
        guard case .invalidRequest = result else {
            XCTFail("Should return .invalidRequest for empty bundle identifier")
            return
        }
    }
    
    func testRevokeNonExistentGrant() async {
        let success = await manager.revokePermission(grantID: "non-existent-id")
        XCTAssertFalse(success)
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflow() async throws {
        // Clear any existing grants for test isolation
        await manager.clearAllGrants()
        
        // Grant permission
        let bundleId = "com.workflow.test.\(UUID().uuidString)"
        let grantRequest = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: bundleId,
            serviceName: "kTCCServiceCamera",
            duration: 300,
            reason: "Full workflow test",
            requestedBy: "integration-test"
        )
        
        let grantResult = try await manager.grantPermission(grantRequest)
        guard case .granted(let grant) = grantResult else {
            XCTFail("Grant should succeed")
            return
        }
        
        // Verify grant details
        XCTAssertEqual(grant.bundleIdentifier, bundleId)
        XCTAssertEqual(grant.serviceName, "kTCCServiceCamera")
        XCTAssertEqual(grant.reason, "Full workflow test")
        XCTAssertEqual(grant.grantedBy, "integration-test")
        XCTAssertFalse(grant.isExpired)
        
        // Test CLI output
        let cliOutput = await manager.listGrantsForCLI()
        let bundleIdPrefix = String(bundleId.prefix(18))
        XCTAssertTrue(cliOutput.contains(bundleIdPrefix))
        
        // Test JSON export
        let jsonOutput = try await manager.exportGrantsToJSON()
        XCTAssertTrue(jsonOutput.contains(bundleId))
        
        // Revoke permission
        let revokeSuccess = await manager.revokePermission(grantID: grant.id)
        XCTAssertTrue(revokeSuccess)
        
        // Verify removal
        let finalGrants = await manager.getActiveGrants()
        XCTAssertEqual(finalGrants.count, 0)
    }
    
    // MARK: - System Health Tests
    
    func testSystemStatus() async throws {
        // Test reliability metrics
        let (successRate, avgCleanup, totalGrants) = await manager.getReliabilityMetrics()
        
        XCTAssertGreaterThanOrEqual(successRate, 0.0)
        XCTAssertLessThanOrEqual(successRate, 1.0)
        XCTAssertGreaterThanOrEqual(avgCleanup, 0.0)
        XCTAssertGreaterThanOrEqual(totalGrants, 0)
        
        // Test cleanup stats
        let cleanupStats = await manager.getCleanupStats()
        XCTAssertTrue(cleanupStats.count >= 0)
    }
}

// MARK: - Test Helper Extensions

extension TemporaryPermissionManagerTests {
    
    /// Helper to create test grant request
    func createTestRequest(
        bundle: String = "com.test.app",
        service: String = "kTCCServiceCamera",
        duration: TimeInterval = 300
    ) -> TemporaryPermissionManager.GrantRequest {
        return TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: bundle,
            serviceName: service,
            duration: duration,
            reason: "Test grant",
            requestedBy: "unit-test"
        )
    }
}
