import XCTest
import SwiftUI
import OrderedCollections
@testable import PrivarionGUI
@testable import PrivarionCore

/// Comprehensive tests for STORY-2025-020: GUI Advanced Features Completion
/// Tests batch operations, settings integration, and advanced monitoring
final class TemporaryPermissionAdvancedFeaturesTests: XCTestCase {
    
    var appState: AppState!
    var mockPermissionManager: MockTemporaryPermissionManager!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Reset UserDefaults for testing
        let defaults = UserDefaults.standard
        let settingsKeys = [
            "temp_permission_default_duration",
            "temp_permission_auto_refresh",
            "temp_permission_refresh_interval",
            "temp_permission_show_expiry_notifications",
            "temp_permission_notification_advance_time",
            "temp_permission_auto_revoke_expired",
            "temp_permission_export_format",
            "temp_permission_sort_order",
            "temp_permission_group_by_app",
            "temp_permission_show_advanced_details"
        ]
        
        for key in settingsKeys {
            defaults.removeObject(forKey: key)
        }
        
        mockPermissionManager = MockTemporaryPermissionManager()
        // Initialize appState on main actor in an async context when needed
    }
    
    @MainActor
    private func createAppStateForTesting() -> AppState {
        return AppState()
    }
    
    @MainActor
    private func clearAllPermissions(_ appState: AppState) async {
        // Use the internal test helper method to completely clear all grants
        await appState.temporaryPermissionState.clearAllGrantsForTesting()
        
        // Wait for async operations to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let finalGrants = appState.temporaryPermissionState.activeGrants
        if !finalGrants.isEmpty {
            print("Warning: \(finalGrants.count) grants still remain after clearAllGrantsForTesting")
        }
    }
    
    override func tearDownWithError() throws {
        appState = nil
        mockPermissionManager = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Batch Operations Tests
    
    func testBatchSelectionWithOrderedSet() throws {
        // Given
        var selectedPermissions: OrderedSet<PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant> = []
        let grant1 = createMockGrant(id: "grant1", bundleIdentifier: "com.test.app1")
        let grant2 = createMockGrant(id: "grant2", bundleIdentifier: "com.test.app2")
        let grant3 = createMockGrant(id: "grant3", bundleIdentifier: "com.test.app3")
        
        // When
        selectedPermissions.append(grant1)
        selectedPermissions.append(grant2)
        selectedPermissions.append(grant3)
        
        // Then
        XCTAssertEqual(selectedPermissions.count, 3)
        XCTAssertEqual(selectedPermissions[0].id, "grant1")
        XCTAssertEqual(selectedPermissions[1].id, "grant2")
        XCTAssertEqual(selectedPermissions[2].id, "grant3")
        
        // Test order preservation
        XCTAssertTrue(selectedPermissions.contains(grant2))
        XCTAssertEqual(selectedPermissions.firstIndex(of: grant2), 1)
    }
    
    func testBatchRevokation() async throws {
        // Given
        appState = await createAppStateForTesting()
        await clearAllPermissions(appState)
        
        // Create actual grant requests instead of using mock grants
        let request1 = PrivarionCore.TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "com.test.app1",
            serviceName: "kTCCServiceCamera",
            duration: 3600,
            reason: "Test permission 1"
        )
        
        let request2 = PrivarionCore.TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "com.test.app2", 
            serviceName: "kTCCServiceCamera",
            duration: 3600,
            reason: "Test permission 2"
        )
        
        // Grant the permissions through the actual system
        let success1 = await appState.temporaryPermissionState.grantPermission(request1)
        let success2 = await appState.temporaryPermissionState.grantPermission(request2)
        
        // Ensure grants were created
        XCTAssertTrue(success1)
        XCTAssertTrue(success2)
        
        await MainActor.run {
            XCTAssertEqual(appState.temporaryPermissionState.activeGrants.count, 2)
        }
        
        // When - revoke the permissions
        let grantIds = await MainActor.run {
            appState.temporaryPermissionState.activeGrants.map { $0.id }
        }
        let revokeSuccess1 = await appState.temporaryPermissionState.revokePermission(grantID: grantIds[0])
        let revokeSuccess2 = await appState.temporaryPermissionState.revokePermission(grantID: grantIds[1])
        
        // Then
        XCTAssertTrue(revokeSuccess1)
        XCTAssertTrue(revokeSuccess2)
        
        await MainActor.run {
            XCTAssertEqual(appState.temporaryPermissionState.activeGrants.count, 0)
        }
    }
    
    func testBatchExportSelectedPermissions() async throws {
        // Given
        let grant1 = createMockGrant(id: "grant1", bundleIdentifier: "com.test.app1")
        let grant2 = createMockGrant(id: "grant2", bundleIdentifier: "com.test.app2")
        let permissions = [grant1, grant2]
        
        // When
        let exportManager = PermissionExportManager()
        let jsonData = try await exportManager.exportToJSON(permissions: permissions)
        
        // Then
        XCTAssertFalse(jsonData.isEmpty)
        
        // Verify JSON structure
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
        XCTAssertTrue(jsonObject is [String: Any])
        
        if let dict = jsonObject as? [String: Any],
           let exportedPermissions = dict["permissions"] as? [[String: Any]] {
            XCTAssertEqual(exportedPermissions.count, 2)
        } else {
            XCTFail("Invalid JSON structure")
        }
    }
    
    // MARK: - Settings Integration Tests
    
    func testDefaultSettingsValues() {
        // Given - fresh UserDefaults (setup in setUpWithError)
        let settings = TemporaryPermissionSettingsView.getCurrentSettings()
        
        // Then - verify default values
        XCTAssertEqual(settings["defaultDuration"] as? Int, 0) // UserDefaults returns 0 for unset integers
        XCTAssertEqual(settings["autoRefreshEnabled"] as? Bool, false) // UserDefaults returns false for unset bools
        XCTAssertEqual(settings["refreshInterval"] as? Int, 0)
        XCTAssertEqual(settings["preferredExportFormat"] as? String, "json")
        XCTAssertEqual(settings["sortOrder"] as? String, "remaining_time")
    }
    
    func testSettingsPersistence() {
        // Given
        let defaults = UserDefaults.standard
        
        // When
        defaults.set(60, forKey: "temp_permission_default_duration")
        defaults.set(true, forKey: "temp_permission_auto_refresh")
        defaults.set(120, forKey: "temp_permission_refresh_interval")
        defaults.set("csv", forKey: "temp_permission_export_format")
        defaults.set("app_name", forKey: "temp_permission_sort_order")
        
        // Then
        let settings = TemporaryPermissionSettingsView.getCurrentSettings()
        XCTAssertEqual(settings["defaultDuration"] as? Int, 60)
        XCTAssertEqual(settings["autoRefreshEnabled"] as? Bool, true)
        XCTAssertEqual(settings["refreshInterval"] as? Int, 120)
        XCTAssertEqual(settings["preferredExportFormat"] as? String, "csv")
        XCTAssertEqual(settings["sortOrder"] as? String, "app_name")
    }
    
    func testSettingsExportStructure() throws {
        // Given
        let settings = TemporaryPermissionSettings(
            defaultDuration: 30,
            autoRefreshEnabled: true,
            refreshInterval: 60,
            showExpiryNotifications: true,
            notificationAdvanceTime: 5,
            autoRevokeExpired: false,
            preferredExportFormat: "json",
            sortOrder: "remaining_time",
            groupByApp: false,
            showAdvancedDetails: false
        )
        
        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        // Then
        XCTAssertFalse(data.isEmpty)
        
        // Verify roundtrip
        let decoder = JSONDecoder()
        let decodedSettings = try decoder.decode(TemporaryPermissionSettings.self, from: data)
        
        XCTAssertEqual(decodedSettings.defaultDuration, 30)
        XCTAssertEqual(decodedSettings.autoRefreshEnabled, true)
        XCTAssertEqual(decodedSettings.refreshInterval, 60)
        XCTAssertEqual(decodedSettings.preferredExportFormat, "json")
    }
    
    // MARK: - Advanced Monitoring Tests
    
    func testPermissionExpiryDetection() {
        // Given
        let nearExpiryGrant = createMockGrant(
            id: "near_expiry",
            bundleIdentifier: "com.test.app",
            expiryDate: Date().addingTimeInterval(4 * 60) // 4 minutes from now
        )
        
        let farExpiryGrant = createMockGrant(
            id: "far_expiry", 
            bundleIdentifier: "com.test.app2",
            expiryDate: Date().addingTimeInterval(30 * 60) // 30 minutes from now
        )
        
        // When & Then
        XCTAssertTrue(nearExpiryGrant.isExpiringSoon)
        XCTAssertFalse(farExpiryGrant.isExpiringSoon)
    }
    
    func testPermissionStatsCalculation() {
        // Given - use more precise timing
        let now = Date()
        let grants = [
            createMockGrant(id: "1", bundleIdentifier: "com.test.app1", expiryDate: now.addingTimeInterval(10 * 60)),
            createMockGrant(id: "2", bundleIdentifier: "com.test.app2", expiryDate: now.addingTimeInterval(4 * 60)),
            createMockGrant(id: "3", bundleIdentifier: "com.test.app3", expiryDate: now.addingTimeInterval(30 * 60))
        ]
        
        // When
        let expiringSoonCount = grants.filter { $0.isExpiringSoon }.count
        let totalRemainingMinutes = grants.reduce(0) { result, grant in 
            result + Int(grant.remainingTime / 60)
        }
        
        // Then - Allow for some timing flexibility (within 1 minute variance)
        XCTAssertEqual(expiringSoonCount, 1) // Only the 4-minute one
        XCTAssertTrue(totalRemainingMinutes >= 40 && totalRemainingMinutes <= 46, "Expected total minutes to be around 44, got \(totalRemainingMinutes)")
    }
    
    // MARK: - Search and Filter Integration Tests
    
    func testPermissionSearchIntegration() async throws {
        // Given
        appState = await createAppStateForTesting()
        await clearAllPermissions(appState)
        
        // Create actual grant requests
        let safariRequest = PrivarionCore.TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "com.test.safari",
            serviceName: "kTCCServiceCamera",
            duration: 3600,
            reason: "Camera access test"
        )
        
        let chromeRequest = PrivarionCore.TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "com.test.chrome",
            serviceName: "kTCCServiceMicrophone", 
            duration: 3600,
            reason: "Microphone access test"
        )
        
        let firefoxRequest = PrivarionCore.TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: "com.test.firefox",
            serviceName: "kTCCServiceCamera",
            duration: 3600,
            reason: "Camera access test"
        )
        
        // Grant the permissions
        _ = await appState.temporaryPermissionState.grantPermission(safariRequest)
        _ = await appState.temporaryPermissionState.grantPermission(chromeRequest)
        _ = await appState.temporaryPermissionState.grantPermission(firefoxRequest)
        
        // When - search for camera permissions using search manager
        await MainActor.run {
            let searchManager = appState.permissionSearchManager
            searchManager.updatePermissions(appState.temporaryPermissionState.activeGrants)
            searchManager.searchText = "Camera"
            
            // Then - should find 2 camera-related permissions
            let cameraResults = searchManager.filteredPermissions
            XCTAssertEqual(cameraResults.count, 2)
            XCTAssertTrue(cameraResults.contains { $0.bundleIdentifier == "com.test.safari" })
            XCTAssertTrue(cameraResults.contains { $0.bundleIdentifier == "com.test.firefox" })
        }
    }
    
    // MARK: - Performance Tests
    
    func testBatchOperationPerformance() {
        measure {
            // Given
            var selectedPermissions: OrderedSet<PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant> = []
            
            // When - simulate selecting 1000 permissions
            for i in 0..<1000 {
                let grant = createMockGrant(id: "grant\(i)", bundleIdentifier: "com.test.app\(i)")
                selectedPermissions.append(grant)
            }
            
            // Verify performance characteristics
            XCTAssertEqual(selectedPermissions.count, 1000)
        }
    }
    
    func testOrderedSetRemovalPerformance() {
        // Given
        var selectedPermissions: OrderedSet<PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant> = []
        let grants = (0..<100).map { createMockGrant(id: "grant\($0)", bundleIdentifier: "com.test.app\($0)") }
        
        for grant in grants {
            selectedPermissions.append(grant)
        }
        
        measure {
            // When - remove all permissions
            selectedPermissions.removeAll()
        }
        
        // Then
        XCTAssertTrue(selectedPermissions.isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func createMockGrant(
        id: String,
        bundleIdentifier: String,
        serviceName: String = "kTCCServiceCamera",
        expiryDate: Date = Date().addingTimeInterval(3600)
    ) -> PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant {
        let duration = expiryDate.timeIntervalSince(Date())
        return PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant(
            id: id,
            bundleIdentifier: bundleIdentifier,
            serviceName: serviceName,
            duration: duration,
            grantedBy: "test-user",
            reason: "Test permission"
        )
    }
}

// MARK: - Mock Objects

/// Mock implementation of TemporaryPermissionManager for testing
class MockTemporaryPermissionManager {
    var mockGrants: [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant] = []
    var revokedGrants: Set<String> = []
    var shouldFailOperations = false
    
    func getActiveGrants() async -> [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant] {
        return mockGrants.filter { !revokedGrants.contains($0.id) }
    }
    
    func revokePermission(grantID: String) async -> Bool {
        if shouldFailOperations {
            return false
        }
        
        revokedGrants.insert(grantID)
        return true
    }
    
    func hasActiveGrant(bundleIdentifier: String, serviceName: String) async -> PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant? {
        return mockGrants.first { 
            $0.bundleIdentifier == bundleIdentifier && 
            $0.serviceName == serviceName && 
            !revokedGrants.contains($0.id)
        }
    }
}

// MARK: - Private Settings Model for Testing

private struct TemporaryPermissionSettings: Codable {
    let defaultDuration: Int
    let autoRefreshEnabled: Bool
    let refreshInterval: Int
    let showExpiryNotifications: Bool
    let notificationAdvanceTime: Int
    let autoRevokeExpired: Bool
    let preferredExportFormat: String
    let sortOrder: String
    let groupByApp: Bool
    let showAdvancedDetails: Bool
}
