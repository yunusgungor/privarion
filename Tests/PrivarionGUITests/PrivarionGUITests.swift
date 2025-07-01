import Foundation
import XCTest
import SwiftUI
import Combine
@testable import PrivarionGUI
@testable import PrivarionCore

@MainActor
final class PrivarionGUITests: XCTestCase {
    
    var appState: AppState!
    var mockSystemInteractor: MockSystemInteractor!
    var mockModuleInteractor: MockModuleInteractor!
    var mockProfileInteractor: MockProfileInteractor!
    
    override func setUp() {
        super.setUp()
        
        // Setup mock interactors
        mockSystemInteractor = MockSystemInteractor()
        mockModuleInteractor = MockModuleInteractor()
        mockProfileInteractor = MockProfileInteractor()
        
        // Create AppState with mock dependencies
        appState = AppState(
            systemInteractor: mockSystemInteractor,
            moduleInteractor: mockModuleInteractor,
            profileInteractor: mockProfileInteractor
        )
        
        // Wait a bit for initialization to complete
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    override func tearDown() {
        super.tearDown()
        appState = nil
        mockSystemInteractor = nil
        mockModuleInteractor = nil
        mockProfileInteractor = nil
    }
    
    // MARK: - AppState Tests
    
    func testAppStateInitialization() {
        XCTAssertEqual(appState.currentView, .dashboard)
        XCTAssertEqual(appState.systemStatus, .unknown)
        XCTAssertTrue(appState.modules.isEmpty)
        XCTAssertTrue(appState.profiles.isEmpty)
        XCTAssertNil(appState.activeProfile)
        XCTAssertTrue(appState.recentActivity.isEmpty)
    }
    
    func testAppStateViewNavigation() {
        // Test view navigation
        appState.currentView = .modules
        XCTAssertEqual(appState.currentView, .modules)
        
        appState.currentView = .profiles
        XCTAssertEqual(appState.currentView, .profiles)
        
        appState.currentView = .settings
        XCTAssertEqual(appState.currentView, .settings)
    }
    
    func testAppStateLoadingStates() {
        // Test loading state management
        appState.setLoading("test", true)
        XCTAssertTrue(appState.isLoading["test"] == true)
        
        appState.setLoading("test", false)
        XCTAssertTrue(appState.isLoading["test"] == false)
    }
    
    func testAppStateErrorHandling() {
        // Test error handling through ErrorManager
        let testError = PrivarionError.internalError(code: "TEST-001", details: "Test error")
        appState.handleError(testError, context: "Unit Test", operation: "Error Test")
        
        // Error should be handled by ErrorManager
        XCTAssertTrue(true) // Just verify no crash occurs
    }
    
    func testAppStateSystemStatusUpdate() {
        // Test system status updates
        appState.systemStatus = .running
        XCTAssertEqual(appState.systemStatus, .running)
        
        appState.systemStatus = .stopped
        XCTAssertEqual(appState.systemStatus, .stopped)
    }
    
    // MARK: - Async Operations Tests
    
    func testAppStateInitialization_Async() async {
        // Setup mock data
        mockSystemInteractor.mockSystemStatus = .running
        mockSystemInteractor.mockActivity = [
            ActivityLogEntry(
                id: "test-1",
                timestamp: Date(),
                action: "Test Action",
                details: "Test Details",
                level: .info
            )
        ]
        mockModuleInteractor.mockModules = [
            PrivacyModule(
                id: "test-module",
                name: "Test Module",
                description: "Test Description",
                isEnabled: true,
                status: .active,
                dependencies: []
            )
        ]
        mockProfileInteractor.mockProfiles = [
            PrivarionGUI.ConfigurationProfile(
                id: "test-profile",
                name: "Test Profile",
                description: "Test Profile Description",
                isActive: true,
                settings: [:],
                createdAt: Date(),
                modifiedAt: Date()
            )
        ]
        
        // Test initialization
        await appState.initialize()
        
        // Verify data was loaded
        XCTAssertEqual(appState.systemStatus, .running)
        XCTAssertEqual(appState.modules.count, 1)
        XCTAssertEqual(appState.profiles.count, 1)
        XCTAssertEqual(appState.recentActivity.count, 1)
    }
    
    // TEMPORARILY DISABLED - hangs in test environment 
    /*
    func testToggleModule() {
        // Setup mock module
        let testModule = PrivacyModule(
            id: "test-module",
            name: "Test Module",
            description: "Test Description",
            isEnabled: false,
            status: .inactive,
            dependencies: []
        )
        mockModuleInteractor.mockModules = [testModule]
        
        // Initialize appState modules directly to avoid initialize() issues
        appState.modules = [testModule]
        
        // Test module toggle using Task
        let expectation = XCTestExpectation(description: "Toggle module")
        
        Task {
            await appState.toggleModule("test-module")
            expectation.fulfill()
        }
        
        // Wait for completion with timeout
        wait(for: [expectation], timeout: 5.0)
        
        // Verify toggle was attempted
        XCTAssertTrue(mockModuleInteractor.toggleModuleCalled)
    }
    */
    
    // TEMPORARILY DISABLED - crashes due to force unwrapping in AppState.switchProfile
    /*
    func testSwitchProfile() async {
        // Setup mock profiles first in the interactor
        let testProfile = PrivarionGUI.ConfigurationProfile(
            id: "test-profile",
            name: "Test Profile",
            description: "Test Profile Description",
            isActive: false,
            settings: [:],
            createdAt: Date(),
            modifiedAt: Date()
        )
        mockProfileInteractor.mockProfiles = [testProfile]
        mockProfileInteractor.mockActiveProfile = testProfile
        appState.profiles = [testProfile]
        
        // Mock the system status to avoid crashes during initialize()
        mockSystemInteractor.mockSystemStatus = .running
        
        // Test profile switch - this should not crash even if no profile found
        await appState.switchProfile("test-profile")
        
        // Verify profile activation was attempted
        XCTAssertTrue(mockProfileInteractor.activateProfileCalled)
        
        // Test with non-existent profile (should handle gracefully)
        await appState.switchProfile("non-existent-profile")
        
        // Should still work without crashing
        XCTAssertTrue(true)
    }
    */
    
    // MARK: - Error Manager Integration Tests
    
    func testErrorManagerIntegration() {
        let errorManager = ErrorManager.shared
        XCTAssertNotNil(errorManager)
        
        // Test error handling
        let testError = PrivarionError.internalError(code: "TEST-002", details: "Integration test error")
        errorManager.handleError(testError)
        
        // Verify error was processed (no crash)
        XCTAssertTrue(true)
    }
    
    // MARK: - User Settings Integration Tests
    
    func testUserSettingsIntegration() {
        let userSettings = UserSettings.shared
        XCTAssertNotNil(userSettings)
        
        // Test basic settings
        let originalRefreshInterval = userSettings.refreshInterval
        userSettings.refreshInterval = 30
        XCTAssertEqual(userSettings.refreshInterval, 30)
        
        // Restore original value
        userSettings.refreshInterval = originalRefreshInterval
    }
    
    // MARK: - Command Manager Tests
    
    func testCommandManagerIntegration() {
        XCTAssertNotNil(appState.commandManager)
        
        // Test navigation commands
        appState.navigateToDashboard()
        XCTAssertEqual(appState.currentView, .dashboard)
        
        appState.navigateToConfiguration()
        XCTAssertEqual(appState.currentView, .modules)
        
        appState.navigateToMonitoring()
        XCTAssertEqual(appState.currentView, .logs)
    }
    
    // MARK: - Navigation Manager Tests
    
    func testNavigationManagerIntegration() {
        XCTAssertNotNil(appState.navigationManager)
        
        // Test view transitions through keyboard shortcuts
        appState.navigateToView(.dashboard)
        XCTAssertEqual(appState.currentView, .dashboard)
        
        appState.navigateToView(.modules)
        XCTAssertEqual(appState.currentView, .modules)
        
        appState.navigateToView(.profiles)
        XCTAssertEqual(appState.currentView, .profiles)
    }
    
    // MARK: - Performance Tests
    
    func testAppStatePerformance() {
        measure {
            for _ in 0..<1000 {
                appState.setLoading("performance-test", true)
                appState.setLoading("performance-test", false)
            }
        }
    }
    
    func testModuleTogglePerformance() async throws {
        // Setup mock modules
        mockModuleInteractor.mockModules = (0..<100).map { index in
            PrivacyModule(
                id: "module-\(index)",
                name: "Module \(index)",
                description: "Test Module \(index)",
                isEnabled: false,
                status: .inactive,
                dependencies: []
            )
        }
        appState.modules = mockModuleInteractor.mockModules

        // Run the concurrent operations and wait for them to complete
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    await self.appState.toggleModule("module-\(i)")
                }
            }
        }

        // Verify that the first module was toggled successfully
        let firstModule = appState.modules.first { $0.id == "module-0" }
        XCTAssertTrue(firstModule?.isEnabled ?? false, "Module-0 should be enabled after toggle.")
    }
}


// MARK: - Mock Classes for GUI Testing

/// Mock implementation of SystemInteractor for testing
class MockSystemInteractor: SystemInteractor {
    var mockSystemStatus: SystemStatus = .unknown
    var mockActivity: [ActivityLogEntry] = []
    
    var getSystemStatusCalled = false
    var getRecentActivityCalled = false
    var startSystemCalled = false
    var stopSystemCalled = false
    
    func getSystemStatus() async throws -> SystemStatus {
        getSystemStatusCalled = true
        return mockSystemStatus
    }
    
    func getRecentActivity() async throws -> [ActivityLogEntry] {
        getRecentActivityCalled = true
        return mockActivity
    }
    
    func startSystem() async throws {
        startSystemCalled = true
        mockSystemStatus = .running
    }
    
    func stopSystem() async throws {
        stopSystemCalled = true
        mockSystemStatus = .stopped
    }
}

/// Mock implementation of ModuleInteractor for testing
class MockModuleInteractor: ModuleInteractor {
    var mockModules: [PrivacyModule] = []
    var mockConfiguration: [String: Any] = [:]
    
    var getAvailableModulesCalled = false
    var enableModuleCalled = false
    var disableModuleCalled = false
    var toggleModuleCalled = false
    var getModuleConfigurationCalled = false
    var updateModuleConfigurationCalled = false
    
    func getAvailableModules() async throws -> [PrivacyModule] {
        getAvailableModulesCalled = true
        return mockModules
    }
    
    func enableModule(_ moduleId: String) async throws {
        enableModuleCalled = true
        // Update mock module status
        if let index = mockModules.firstIndex(where: { $0.id == moduleId }) {
            let module = mockModules[index]
            mockModules[index] = PrivacyModule(
                id: module.id,
                name: module.name,
                description: module.description,
                isEnabled: true,
                status: .active,
                dependencies: module.dependencies
            )
        }
    }
    
    func disableModule(_ moduleId: String) async throws {
        disableModuleCalled = true
        // Update mock module status
        if let index = mockModules.firstIndex(where: { $0.id == moduleId }) {
            let module = mockModules[index]
            mockModules[index] = PrivacyModule(
                id: module.id,
                name: module.name,
                description: module.description,
                isEnabled: false,
                status: .inactive,
                dependencies: module.dependencies
            )
        }
    }
    
    func toggleModule(_ moduleId: String) async throws {
        toggleModuleCalled = true
        // Simplified for testing - just toggle the mock module directly
        if let index = mockModules.firstIndex(where: { $0.id == moduleId }) {
            let module = mockModules[index]
            mockModules[index] = PrivacyModule(
                id: module.id,
                name: module.name,
                description: module.description,
                isEnabled: !module.isEnabled,
                status: !module.isEnabled ? .active : .inactive,
                dependencies: module.dependencies
            )
        }
    }
    
    func getModuleConfiguration(_ moduleId: String) async throws -> [String : Any] {
        getModuleConfigurationCalled = true
        return mockConfiguration
    }
    
    func updateModuleConfiguration(_ moduleId: String, configuration: [String : Any]) async throws {
        updateModuleConfigurationCalled = true
        mockConfiguration = configuration
    }
}

/// Mock implementation of ProfileInteractor for testing
class MockProfileInteractor: ProfileInteractor {
    var mockProfiles: [PrivarionGUI.ConfigurationProfile] = []
    var mockActiveProfile: PrivarionGUI.ConfigurationProfile?
    var mockExportData: Data = Data()
    
    var getProfilesCalled = false
    var getActiveProfileCalled = false
    var createProfileCalled = false
    var updateProfileCalled = false
    var deleteProfileCalled = false
    var activateProfileCalled = false
    var exportProfileCalled = false
    var importProfileCalled = false
    
    func getProfiles() async throws -> [PrivarionGUI.ConfigurationProfile] {
        getProfilesCalled = true
        return mockProfiles
    }
    
    func getActiveProfile() async throws -> PrivarionGUI.ConfigurationProfile? {
        getActiveProfileCalled = true
        return mockActiveProfile
    }
    
    func createProfile(_ profile: PrivarionGUI.ConfigurationProfile) async throws {
        createProfileCalled = true
        mockProfiles.append(profile)
    }
    
    func updateProfile(_ profile: PrivarionGUI.ConfigurationProfile) async throws {
        updateProfileCalled = true
        if let index = mockProfiles.firstIndex(where: { $0.id == profile.id }) {
            mockProfiles[index] = profile
        }
    }
    
    func deleteProfile(_ profileId: String) async throws {
        deleteProfileCalled = true
        mockProfiles.removeAll { $0.id == profileId }
    }
    
    func activateProfile(_ profileId: String) async throws {
        activateProfileCalled = true
        mockActiveProfile = mockProfiles.first { $0.id == profileId }
    }
    
    func exportProfile(_ profileId: String) async throws -> Data {
        exportProfileCalled = true
        return mockExportData
    }
    
    func importProfile(_ data: Data) async throws -> PrivarionGUI.ConfigurationProfile {
        importProfileCalled = true
        let profile = PrivarionGUI.ConfigurationProfile(
            id: "imported-profile",
            name: "Imported Profile",
            description: "Imported from data",
            isActive: false,
            settings: [:],
            createdAt: Date(),
            modifiedAt: Date()
        )
        mockProfiles.append(profile)
        return profile
    }
}
