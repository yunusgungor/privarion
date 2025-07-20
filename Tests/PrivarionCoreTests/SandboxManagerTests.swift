import XCTest
import Foundation
@testable import PrivarionCore

final class SandboxManagerTests: XCTestCase {
    
    var sandboxManager: SandboxManager!
    
    override func setUp() {
        super.setUp()
        sandboxManager = SandboxManager()
    }
    
    override func tearDown() {
        sandboxManager = nil
        super.tearDown()
    }
    
    // MARK: - Profile Management Tests
    
    func testCreateProfile_ValidProfile_ShouldSucceed() {
        // Given
        let testBundleID = "com.test.app"
        let testConfig = SandboxConfiguration(
            allowNetworkAccess: false,
            allowFileSystemWrite: false,
            allowedDirectories: ["/tmp"],
            blockedDirectories: ["/System"],
            allowedExecutables: ["curl"],
            maxMemoryMB: 512,
            maxCPUPercent: 50
        )
        
        // When
        let result = sandboxManager.createProfile(bundleID: testBundleID, config: testConfig)
        
        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(sandboxManager.getActiveProfiles().count, 1)
        XCTAssertEqual(sandboxManager.getActiveProfiles().first?.bundleID, testBundleID)
    }
    
    func testCreateProfile_DuplicateBundleID_ShouldFail() {
        // Given
        let testBundleID = "com.test.app"
        let testConfig = SandboxConfiguration(
            allowNetworkAccess: false,
            allowFileSystemWrite: false,
            allowedDirectories: [],
            blockedDirectories: [],
            allowedExecutables: [],
            maxMemoryMB: 512,
            maxCPUPercent: 50
        )
        
        // When
        let firstResult = sandboxManager.createProfile(bundleID: testBundleID, config: testConfig)
        let secondResult = sandboxManager.createProfile(bundleID: testBundleID, config: testConfig)
        
        // Then
        XCTAssertTrue(firstResult.isSuccess)
        XCTAssertFalse(secondResult.isSuccess)
        XCTAssertEqual(sandboxManager.getActiveProfiles().count, 1)
    }
    
    func testUpdateProfile_ExistingProfile_ShouldSucceed() {
        // Given
        let testBundleID = "com.test.app"
        let initialConfig = SandboxConfiguration(
            allowNetworkAccess: false,
            allowFileSystemWrite: false,
            allowedDirectories: [],
            blockedDirectories: [],
            allowedExecutables: [],
            maxMemoryMB: 512,
            maxCPUPercent: 50
        )
        let updatedConfig = SandboxConfiguration(
            allowNetworkAccess: true,
            allowFileSystemWrite: true,
            allowedDirectories: ["/tmp"],
            blockedDirectories: ["/System"],
            allowedExecutables: ["curl"],
            maxMemoryMB: 1024,
            maxCPUPercent: 75
        )
        
        _ = sandboxManager.createProfile(bundleID: testBundleID, config: initialConfig)
        
        // When
        let result = sandboxManager.updateProfile(bundleID: testBundleID, config: updatedConfig)
        
        // Then
        XCTAssertTrue(result.isSuccess)
        let profile = sandboxManager.getActiveProfiles().first
        XCTAssertEqual(profile?.configuration.allowNetworkAccess, true)
        XCTAssertEqual(profile?.configuration.maxMemoryMB, 1024)
    }
    
    func testDeleteProfile_ExistingProfile_ShouldSucceed() {
        // Given
        let testBundleID = "com.test.app"
        let testConfig = SandboxConfiguration(
            allowNetworkAccess: false,
            allowFileSystemWrite: false,
            allowedDirectories: [],
            blockedDirectories: [],
            allowedExecutables: [],
            maxMemoryMB: 512,
            maxCPUPercent: 50
        )
        
        _ = sandboxManager.createProfile(bundleID: testBundleID, config: testConfig)
        XCTAssertEqual(sandboxManager.getActiveProfiles().count, 1)
        
        // When
        let result = sandboxManager.deleteProfile(bundleID: testBundleID)
        
        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(sandboxManager.getActiveProfiles().count, 0)
    }
    
    func testDeleteProfile_NonExistentProfile_ShouldFail() {
        // Given
        let nonExistentBundleID = "com.nonexistent.app"
        
        // When
        let result = sandboxManager.deleteProfile(bundleID: nonExistentBundleID)
        
        // Then
        XCTAssertFalse(result.isSuccess)
    }
    
    // MARK: - Application Management Tests
    
    func testLaunchApplication_ValidProfile_ShouldSucceed() {
        // Given
        let testBundleID = "com.test.app"
        let testConfig = SandboxConfiguration(
            allowNetworkAccess: true,
            allowFileSystemWrite: true,
            allowedDirectories: ["/tmp"],
            blockedDirectories: [],
            allowedExecutables: ["echo"],
            maxMemoryMB: 512,
            maxCPUPercent: 50
        )
        let testLaunchInfo = ApplicationLaunchInfo(
            bundleID: testBundleID,
            executablePath: "/bin/echo",
            arguments: ["Hello", "World"],
            environment: ["TEST": "value"]
        )
        
        _ = sandboxManager.createProfile(bundleID: testBundleID, config: testConfig)
        
        // When
        let result = sandboxManager.launchApplication(launchInfo: testLaunchInfo)
        
        // Then
        XCTAssertTrue(result.isSuccess)
        XCTAssertNotNil(result.processID)
        XCTAssertGreaterThan(result.processID ?? 0, 0)
    }
    
    func testLaunchApplication_NoProfile_ShouldFail() {
        // Given
        let testLaunchInfo = ApplicationLaunchInfo(
            bundleID: "com.nonexistent.app",
            executablePath: "/bin/echo",
            arguments: ["Hello", "World"],
            environment: [:]
        )
        
        // When
        let result = sandboxManager.launchApplication(launchInfo: testLaunchInfo)
        
        // Then
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.processID)
    }
    
    func testTerminateApplication_RunningProcess_ShouldSucceed() {
        // Given
        let testBundleID = "com.test.app"
        let testConfig = SandboxConfiguration(
            allowNetworkAccess: true,
            allowFileSystemWrite: true,
            allowedDirectories: ["/tmp"],
            blockedDirectories: [],
            allowedExecutables: ["sleep"],
            maxMemoryMB: 512,
            maxCPUPercent: 50
        )
        let testLaunchInfo = ApplicationLaunchInfo(
            bundleID: testBundleID,
            executablePath: "/bin/sleep",
            arguments: ["5"],
            environment: [:]
        )
        
        _ = sandboxManager.createProfile(bundleID: testBundleID, config: testConfig)
        let launchResult = sandboxManager.launchApplication(launchInfo: testLaunchInfo)
        XCTAssertTrue(launchResult.isSuccess)
        
        guard let processID = launchResult.processID else {
            XCTFail("Process ID should not be nil")
            return
        }
        
        // When
        let result = sandboxManager.terminateApplication(processID: processID)
        
        // Then
        XCTAssertTrue(result.isSuccess)
    }
    
    // MARK: - Monitoring Tests
    
    func testGetRunningApplications_WithRunningApps_ShouldReturnList() {
        // Given
        let testBundleID = "com.test.app"
        let testConfig = SandboxConfiguration(
            allowNetworkAccess: true,
            allowFileSystemWrite: true,
            allowedDirectories: ["/tmp"],
            blockedDirectories: [],
            allowedExecutables: ["sleep"],
            maxMemoryMB: 512,
            maxCPUPercent: 50
        )
        let testLaunchInfo = ApplicationLaunchInfo(
            bundleID: testBundleID,
            executablePath: "/bin/sleep",
            arguments: ["2"],
            environment: [:]
        )
        
        _ = sandboxManager.createProfile(bundleID: testBundleID, config: testConfig)
        let launchResult = sandboxManager.launchApplication(launchInfo: testLaunchInfo)
        XCTAssertTrue(launchResult.isSuccess)
        
        // When
        let runningApps = sandboxManager.getRunningApplications()
        
        // Then
        XCTAssertGreaterThanOrEqual(runningApps.count, 1)
        XCTAssertTrue(runningApps.contains { $0.bundleID == testBundleID })
        
        // Cleanup
        if let processID = launchResult.processID {
            _ = sandboxManager.terminateApplication(processID: processID)
        }
    }
    
    func testIsApplicationRunning_WithRunningApp_ShouldReturnTrue() {
        // Given
        let testBundleID = "com.test.app"
        let testConfig = SandboxConfiguration(
            allowNetworkAccess: true,
            allowFileSystemWrite: true,
            allowedDirectories: ["/tmp"],
            blockedDirectories: [],
            allowedExecutables: ["sleep"],
            maxMemoryMB: 512,
            maxCPUPercent: 50
        )
        let testLaunchInfo = ApplicationLaunchInfo(
            bundleID: testBundleID,
            executablePath: "/bin/sleep",
            arguments: ["2"],
            environment: [:]
        )
        
        _ = sandboxManager.createProfile(bundleID: testBundleID, config: testConfig)
        let launchResult = sandboxManager.launchApplication(launchInfo: testLaunchInfo)
        XCTAssertTrue(launchResult.isSuccess)
        
        // When
        let isRunning = sandboxManager.isApplicationRunning(bundleID: testBundleID)
        
        // Then
        XCTAssertTrue(isRunning)
        
        // Cleanup
        if let processID = launchResult.processID {
            _ = sandboxManager.terminateApplication(processID: processID)
        }
    }
    
    func testIsApplicationRunning_WithoutRunningApp_ShouldReturnFalse() {
        // Given
        let testBundleID = "com.nonexistent.app"
        
        // When
        let isRunning = sandboxManager.isApplicationRunning(bundleID: testBundleID)
        
        // Then
        XCTAssertFalse(isRunning)
    }
    
    // MARK: - Configuration Validation Tests
    
    func testSandboxConfiguration_ValidConfiguration_ShouldCreate() {
        // Given & When
        let config = SandboxConfiguration(
            allowNetworkAccess: true,
            allowFileSystemWrite: false,
            allowedDirectories: ["/tmp", "/var/tmp"],
            blockedDirectories: ["/System", "/Library"],
            allowedExecutables: ["curl", "wget"],
            maxMemoryMB: 1024,
            maxCPUPercent: 80
        )
        
        // Then
        XCTAssertEqual(config.allowNetworkAccess, true)
        XCTAssertEqual(config.allowFileSystemWrite, false)
        XCTAssertEqual(config.allowedDirectories.count, 2)
        XCTAssertEqual(config.blockedDirectories.count, 2)
        XCTAssertEqual(config.allowedExecutables.count, 2)
        XCTAssertEqual(config.maxMemoryMB, 1024)
        XCTAssertEqual(config.maxCPUPercent, 80)
    }
    
    // MARK: - Performance Tests
    
    func testCreateProfile_Performance() {
        // Test that profile creation completes within reasonable time
        measure {
            let testConfig = SandboxConfiguration(
                allowNetworkAccess: true,
                allowFileSystemWrite: true,
                allowedDirectories: ["/tmp"],
                blockedDirectories: ["/System"],
                allowedExecutables: ["echo"],
                maxMemoryMB: 512,
                maxCPUPercent: 50
            )
            
            for i in 0..<100 {
                let bundleID = "com.test.app.\(i)"
                _ = sandboxManager.createProfile(bundleID: bundleID, config: testConfig)
            }
        }
    }
}
