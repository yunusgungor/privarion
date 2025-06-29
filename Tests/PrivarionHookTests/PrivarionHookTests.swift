import XCTest
@testable import PrivarionHook
@testable import PrivarionCore

final class PrivarionHookTests: XCTestCase {
    
    var hookManager: SyscallHookManager!
    
    override func setUp() {
        super.setUp()
        hookManager = SyscallHookManager.shared
        
        // Enable debug logging for tests
        hookManager.setDebugLogging(enabled: true)
    }
    
    override func tearDown() {
        hookManager.cleanup()
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testSystemInitialization() throws {
        // Test basic initialization
        try hookManager.initialize()
        
        // Verify platform support
        XCTAssertTrue(hookManager.isPlatformSupported, "Platform should be supported on macOS")
        
        // Verify version information
        let version = hookManager.version
        XCTAssertFalse(version.isEmpty, "Version should not be empty")
        XCTAssertTrue(version.contains("."), "Version should contain dots")
        
        print("Hook system version: \(version)")
    }
    
    func testMultipleInitialization() throws {
        // Test that multiple initializations don't cause issues
        try hookManager.initialize()
        try hookManager.initialize()
        try hookManager.initialize()
        
        // Should not throw or cause issues
        XCTAssertEqual(hookManager.activeHookCount, 0, "Should start with no active hooks")
    }
    
    // MARK: - Hook Installation Tests
    
    func testBasicHookInstallation() throws {
        try hookManager.initialize()
        
        // Create a test configuration with enabled hooks
        var config = SyscallHookConfiguration()
        config.hooks.getuid = true
        config.fakeData.userId = 12345
        
        try hookManager.updateConfiguration(config)
        
        // Install hooks based on configuration
        let installedHooks = try hookManager.installConfiguredHooks()
        
        XCTAssertEqual(installedHooks.count, 1, "Should have installed one hook")
        XCTAssertNotNil(installedHooks["getuid"], "Should have getuid hook")
        
        let handle = installedHooks["getuid"]!
        XCTAssertTrue(handle.isValid, "Hook handle should be valid")
        XCTAssertEqual(handle.functionName, "getuid", "Function name should match")
        XCTAssertGreaterThan(handle.id, 0, "Hook ID should be positive")
        
        // Verify hook is active
        XCTAssertTrue(hookManager.isHooked(.getuid), "getuid should be hooked")
        XCTAssertEqual(hookManager.activeHookCount, 1, "Should have one active hook")
        
        let activeHooks = hookManager.activeHooks
        XCTAssertEqual(activeHooks.count, 1, "Should report one active hook")
        XCTAssertTrue(activeHooks.contains("getuid"), "Active hooks should contain getuid")
    }
    
    func testMultipleHookInstallation() throws {
        try hookManager.initialize()
        
        // Create configuration with multiple hooks enabled
        var config = SyscallHookConfiguration()
        config.hooks.getuid = true
        config.hooks.getgid = true
        config.fakeData.userId = 1001
        config.fakeData.groupId = 1001
        
        try hookManager.updateConfiguration(config)
        
        // Install hooks based on configuration
        let installedHooks = try hookManager.installConfiguredHooks()
        
        XCTAssertEqual(installedHooks.count, 2, "Should have installed two hooks")
        XCTAssertNotNil(installedHooks["getuid"], "Should have getuid hook")
        XCTAssertNotNil(installedHooks["getgid"], "Should have getgid hook")
        
        // Verify both hooks are active
        XCTAssertEqual(hookManager.activeHookCount, 2, "Should have two active hooks")
        XCTAssertTrue(hookManager.isHooked(.getuid), "getuid should be hooked")
        XCTAssertTrue(hookManager.isHooked(.getgid), "getgid should be hooked")
        
        let activeHooks = hookManager.activeHooks
        XCTAssertEqual(activeHooks.count, 2, "Should report two active hooks")
        XCTAssertTrue(activeHooks.contains("getuid"), "Should contain getuid")
        XCTAssertTrue(activeHooks.contains("getgid"), "Should contain getgid")
    }
    
    func testDirectHookInstallation() throws {
        try hookManager.initialize()
        
        // Test direct hook installation using configuration
        var config = SyscallHookConfiguration()
        config.hooks.getuid = true
        config.fakeData.userId = 1001
        
        try hookManager.updateConfiguration(config)
        let installedHooks = try hookManager.installConfiguredHooks()
        let handle = installedHooks["getuid"]!
        
        XCTAssertTrue(handle.isValid, "Hook handle should be valid")
        XCTAssertEqual(handle.functionName, "getuid", "Function name should match")
        XCTAssertEqual(hookManager.activeHookCount, 1, "Should have one active hook")
    }
    
    func testDuplicateHookInstallation() throws {
        try hookManager.initialize()
        
        // Install first hook with configuration
        var config = SyscallHookConfiguration()
        config.hooks.getuid = true
        config.fakeData.userId = 1001
        try hookManager.updateConfiguration(config)
        
        let _ = try hookManager.installConfiguredHooks()
        
        // Try to install duplicate hook directly - should fail
        var duplicateConfig = SyscallHookConfiguration()
        duplicateConfig.hooks.getuid = true
        duplicateConfig.fakeData.userId = 1002
        try hookManager.updateConfiguration(duplicateConfig)
        
        XCTAssertThrowsError(
            try hookManager.installConfiguredHooks()
        ) { error in
            if case SyscallHookManager.HookError.alreadyHooked = error {
                // Expected error
            } else {
                XCTFail("Expected alreadyHooked error, got \(error)")
            }
        }
    }
    
    // MARK: - Hook Removal Tests
    
    func testHookRemoval() throws {
        try hookManager.initialize()
        
        // Install hook through configuration
        var config = SyscallHookConfiguration()
        config.hooks.getuid = true
        config.fakeData.userId = 1001
        try hookManager.updateConfiguration(config)
        
        let installedHooks = try hookManager.installConfiguredHooks()
        let handle = installedHooks["getuid"]!
        
        XCTAssertEqual(hookManager.activeHookCount, 1, "Should have one active hook")
        
        // Remove hook
        try hookManager.removeHook(handle)
        
        // Verify removal
        XCTAssertEqual(hookManager.activeHookCount, 0, "Should have no active hooks")
        XCTAssertFalse(hookManager.isHooked(.getuid), "getuid should not be hooked")
        
        let activeHooks = hookManager.activeHooks
        XCTAssertEqual(activeHooks.count, 0, "Should report no active hooks")
    }
    
    func testInvalidHookRemoval() throws {
        try hookManager.initialize()
        
        // Create a mock handle for a non-existent hook
        var mockRawHandle = PHookHandle()
        mockRawHandle.id = 99999
        mockRawHandle.is_valid = true
        strncpy(&mockRawHandle.function_name.0, "nonexistent", 255)
        
        let invalidHandle = SyscallHookManager.HookHandle(rawHandle: mockRawHandle)
        
        // Try to remove non-existent hook
        XCTAssertThrowsError(
            try hookManager.removeHook(invalidHandle)
        ) { error in
            if case SyscallHookManager.HookError.notHooked = error {
                // Expected error
            } else {
                XCTFail("Expected notHooked error, got \(error)")
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testUninitializedSystemError() {
        // Don't initialize the system
        
        var config = SyscallHookConfiguration()
        config.hooks.getuid = true
        config.fakeData.userId = 1001
        
        XCTAssertThrowsError(
            try hookManager.updateConfiguration(config)
        ) { error in
            if case SyscallHookManager.HookError.systemNotInitialized = error {
                // Expected error
            } else {
                XCTFail("Expected systemNotInitialized error, got \(error)")
            }
        }
    }
    
    func testPlatformSupport() throws {
        try hookManager.initialize()
        
        // On macOS, platform should be supported
        XCTAssertTrue(hookManager.isPlatformSupported, "macOS should be supported")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() throws {
        try hookManager.initialize()
        
        // Install hooks using configuration
        var config = SyscallHookConfiguration()
        config.hooks.getuid = true
        config.hooks.getgid = true
        config.fakeData.userId = 1001
        config.fakeData.groupId = 1001
        
        try hookManager.updateConfiguration(config)
        let installedHooks = try hookManager.installConfiguredHooks()
        
        let getuidHandle = installedHooks["getuid"]!
        let getgidHandle = installedHooks["getgid"]!
        
        // Verify installation
        XCTAssertEqual(hookManager.activeHookCount, 2)
        XCTAssertTrue(hookManager.isHooked(.getuid))
        XCTAssertTrue(hookManager.isHooked(.getgid))
        
        // Test original function access (if available)
        // Note: Original function access might not be available in all implementations
        
        // Remove one hook
        try hookManager.removeHook(getuidHandle)
        XCTAssertEqual(hookManager.activeHookCount, 1)
        XCTAssertFalse(hookManager.isHooked(.getuid))
        XCTAssertTrue(hookManager.isHooked(.getgid))
        
        // Remove remaining hook
        try hookManager.removeHook(getgidHandle)
        XCTAssertEqual(hookManager.activeHookCount, 0)
        XCTAssertFalse(hookManager.isHooked(.getgid))
        
        // Cleanup
        hookManager.cleanup()
    }
    
    func testCleanupBehavior() throws {
        try hookManager.initialize()
        
        // Install hooks using configuration
        var config = SyscallHookConfiguration()
        config.hooks.getuid = true
        config.hooks.getgid = true
        config.fakeData.userId = 1001
        config.fakeData.groupId = 1001
        
        try hookManager.updateConfiguration(config)
        let _ = try hookManager.installConfiguredHooks()
        
        XCTAssertEqual(hookManager.activeHookCount, 2)
        
        // Cleanup should remove all hooks
        hookManager.cleanup()
        
        // After cleanup, system should be uninitialized
        var testConfig = SyscallHookConfiguration()
        testConfig.hooks.getuid = true
        testConfig.fakeData.userId = 1001
        
        XCTAssertThrowsError(
            try hookManager.updateConfiguration(testConfig)
        ) { error in
            if case SyscallHookManager.HookError.systemNotInitialized = error {
                // Expected error
            } else {
                XCTFail("Expected systemNotInitialized error after cleanup, got \(error)")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testHookInstallationPerformance() throws {
        try hookManager.initialize()
        
        measure {
            do {
                var config = SyscallHookConfiguration()
                config.hooks.getuid = true
                config.fakeData.userId = 1001
                
                try hookManager.updateConfiguration(config)
                let installedHooks = try hookManager.installConfiguredHooks()
                let handle = installedHooks["getuid"]!
                try hookManager.removeHook(handle)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
    
    func testActiveHookEnumeration() throws {
        try hookManager.initialize()
        
        // Install multiple hooks using configuration
        var config = SyscallHookConfiguration()
        config.hooks.getuid = true
        config.hooks.getgid = true
        config.fakeData.userId = 1001
        config.fakeData.groupId = 1001
        
        try hookManager.updateConfiguration(config)
        let _ = try hookManager.installConfiguredHooks()
        
        measure {
            let _ = hookManager.activeHooks
            let _ = hookManager.activeHookCount
        }
    }
}
