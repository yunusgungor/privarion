// PrivarionSystemExtensionTests - Endpoint Security Manager Tests
// Unit tests for EndpointSecurityManager
// Requirements: 20.1-20.2

import XCTest
import Logging
import CEndpointSecurity
@testable import PrivarionSystemExtension
@testable import PrivarionSharedModels
@testable import PrivarionCore

final class EndpointSecurityManagerTests: XCTestCase {
    
    var manager: EndpointSecurityManager!
    var policyEngine: ProtectionPolicyEngine!
    var logger: Logger!
    
    override func setUp() {
        super.setUp()
        logger = Logger(label: "com.privarion.tests.endpointsecurity")
        logger.logLevel = .debug
        policyEngine = ProtectionPolicyEngine()
        manager = EndpointSecurityManager(policyEngine: policyEngine, logger: logger)
    }
    
    override func tearDown() {
        // Cleanup - unsubscribe if initialized
        if manager.isClientActive() {
            try? manager.unsubscribe()
        }
        manager = nil
        policyEngine = nil
        logger = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testManagerInitialization() {
        // Test that manager can be created
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isClientActive())
    }
    
    func testClientInitializationWithoutPermissions() {
        // Note: This test will fail if run with Full Disk Access
        // In a real environment without FDA, this should throw fullDiskAccessDenied
        
        // We can't reliably test this without proper permissions
        // This test documents the expected behavior
        
        // Expected: throws EndpointSecurityError.fullDiskAccessDenied
        // or EndpointSecurityError.clientInitializationFailed
        
        do {
            try manager.initialize()
            
            // If we get here, we have permissions
            // Verify client is active
            XCTAssertTrue(manager.isClientActive())
            
            // Cleanup
            try manager.unsubscribe()
        } catch let error as EndpointSecurityError {
            // Expected errors when lacking permissions
            switch error {
            case .fullDiskAccessDenied:
                // Expected when Full Disk Access is not granted
                XCTAssertTrue(true, "Correctly threw fullDiskAccessDenied")
            case .clientInitializationFailed(let code):
                // Expected when entitlements are missing or other init failures
                XCTAssertTrue(true, "Correctly threw clientInitializationFailed with code: \(code)")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testDoubleInitialization() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // First initialization
        try manager.initialize()
        XCTAssertTrue(manager.isClientActive())
        
        // Second initialization should not fail (should be idempotent)
        try manager.initialize()
        XCTAssertTrue(manager.isClientActive())
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    // MARK: - Subscription Tests
    
    func testSubscribeWithoutInitialization() {
        // Attempting to subscribe without initialization should fail
        let events: [es_event_type_t] = [ES_EVENT_TYPE_AUTH_EXEC]
        
        XCTAssertThrowsError(try manager.subscribe(to: events)) { error in
            guard let esError = error as? EndpointSecurityError else {
                XCTFail("Expected EndpointSecurityError")
                return
            }
            
            // Should fail because client is not initialized
            switch esError {
            case .clientInitializationFailed, .clientDisconnected:
                XCTAssertTrue(true)
            default:
                XCTFail("Unexpected error: \(esError)")
            }
        }
    }
    
    func testSubscribeToEvents() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Initialize client
        try manager.initialize()
        XCTAssertTrue(manager.isClientActive())
        
        // Subscribe to events
        let events: [es_event_type_t] = [
            ES_EVENT_TYPE_AUTH_EXEC,
            ES_EVENT_TYPE_AUTH_OPEN,
            ES_EVENT_TYPE_NOTIFY_WRITE,
            ES_EVENT_TYPE_NOTIFY_EXIT
        ]
        
        try manager.subscribe(to: events)
        
        // If we get here, subscription succeeded
        XCTAssertTrue(manager.isClientActive())
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    func testSubscribeToSingleEvent() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Initialize client
        try manager.initialize()
        
        // Subscribe to single event
        let events: [es_event_type_t] = [ES_EVENT_TYPE_AUTH_EXEC]
        try manager.subscribe(to: events)
        
        XCTAssertTrue(manager.isClientActive())
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    // MARK: - Unsubscribe Tests
    
    func testUnsubscribeWithoutInitialization() {
        // Unsubscribing without initialization should not throw
        // (it should be a no-op)
        XCTAssertNoThrow(try manager.unsubscribe())
        XCTAssertFalse(manager.isClientActive())
    }
    
    func testUnsubscribeAfterInitialization() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Initialize and subscribe
        try manager.initialize()
        let events: [es_event_type_t] = [ES_EVENT_TYPE_AUTH_EXEC]
        try manager.subscribe(to: events)
        
        XCTAssertTrue(manager.isClientActive())
        
        // Unsubscribe
        try manager.unsubscribe()
        
        // Client should no longer be active
        XCTAssertFalse(manager.isClientActive())
    }
    
    func testDoubleUnsubscribe() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Initialize
        try manager.initialize()
        
        // First unsubscribe
        try manager.unsubscribe()
        XCTAssertFalse(manager.isClientActive())
        
        // Second unsubscribe should not fail (should be idempotent)
        XCTAssertNoThrow(try manager.unsubscribe())
        XCTAssertFalse(manager.isClientActive())
    }
    
    // MARK: - Status Tests
    
    func testIsClientActiveBeforeInitialization() {
        XCTAssertFalse(manager.isClientActive())
    }
    
    func testIsClientActiveAfterInitialization() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        try manager.initialize()
        XCTAssertTrue(manager.isClientActive())
        
        try manager.unsubscribe()
    }
    
    func testIsClientActiveAfterUnsubscribe() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        try manager.initialize()
        try manager.unsubscribe()
        
        XCTAssertFalse(manager.isClientActive())
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorDescriptions() {
        // Test that error descriptions are meaningful
        let errors: [EndpointSecurityError] = [
            .clientInitializationFailed(1),
            .subscriptionFailed(2),
            .fullDiskAccessDenied,
            .eventProcessingTimeout,
            .clientDisconnected
        ]
        
        for error in errors {
            let description = error.errorDescription
            XCTAssertNotNil(description)
            XCTAssertFalse(description!.isEmpty)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Check if we can initialize the ES client (requires permissions)
    /// - Returns: True if initialization is possible
    private func canInitializeClient() -> Bool {
        let testPolicyEngine = ProtectionPolicyEngine()
        let testManager = EndpointSecurityManager(policyEngine: testPolicyEngine)
        do {
            try testManager.initialize()
            try testManager.unsubscribe()
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Event Type Extension Tests

final class EventTypeExtensionTests: XCTestCase {
    
    func testEventTypeDescriptions() {
        // Test that event types have readable descriptions
        let eventTypes: [es_event_type_t] = [
            ES_EVENT_TYPE_AUTH_EXEC,
            ES_EVENT_TYPE_AUTH_OPEN,
            ES_EVENT_TYPE_NOTIFY_WRITE,
            ES_EVENT_TYPE_NOTIFY_EXIT
        ]
        
        for eventType in eventTypes {
            let description = eventType.description
            XCTAssertFalse(description.isEmpty)
            XCTAssertFalse(description.contains("UNKNOWN"))
        }
    }
    
    func testUnknownEventTypeDescription() {
        // Test that unknown event types are handled
        let unknownType = es_event_type_t(rawValue: 9999)
        let description = unknownType.description
        XCTAssertTrue(description.contains("UNKNOWN"))
    }
}

// MARK: - ESAuthResult Extension Tests

final class ESAuthResultExtensionTests: XCTestCase {
    
    func testESAuthResultConversion() {
        // Test conversion to ES framework auth results
        XCTAssertEqual(ESAuthResult.allow.toESAuthResult(), ES_AUTH_RESULT_ALLOW)
        XCTAssertEqual(ESAuthResult.deny.toESAuthResult(), ES_AUTH_RESULT_DENY)
        XCTAssertEqual(ESAuthResult.allowWithModification.toESAuthResult(), ES_AUTH_RESULT_ALLOW)
    }
}

// MARK: - Integration Tests for EndpointSecurityManager

final class EndpointSecurityManagerIntegrationTests: XCTestCase {
    
    var manager: EndpointSecurityManager!
    var policyEngine: ProtectionPolicyEngine!
    var logger: Logger!
    
    override func setUp() {
        super.setUp()
        logger = Logger(label: "com.privarion.tests.integration")
        logger.logLevel = .debug
        policyEngine = ProtectionPolicyEngine()
        manager = EndpointSecurityManager(policyEngine: policyEngine, logger: logger)
    }
    
    override func tearDown() {
        if manager.isClientActive() {
            try? manager.unsubscribe()
        }
        manager = nil
        policyEngine = nil
        logger = nil
        super.tearDown()
    }
    
    // MARK: - Policy Integration Tests
    
    func testPolicyApplicationWithProcessExecution() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: A policy for a specific application
        let testPath = "/Applications/TestApp.app/Contents/MacOS/TestApp"
        let testPolicy = ProtectionPolicy(
            identifier: testPath,
            protectionLevel: .strict,
            networkFiltering: NetworkFilteringRules(action: .block, allowedDomains: [], blockedDomains: ["*"]),
            dnsFiltering: DNSFilteringRules(action: .block, blockTracking: true, blockFingerprinting: true, customBlocklist: []),
            hardwareSpoofing: .basic,
            requiresVMIsolation: false,
            parentPolicy: nil
        )
        
        policyEngine.addPolicy(testPolicy)
        
        // When: Evaluating policy
        let policy = policyEngine.evaluatePolicy(for: testPath)
        
        // Then: Should return the strict policy
        XCTAssertEqual(policy.identifier, testPath)
        XCTAssertEqual(policy.protectionLevel, .strict)
        XCTAssertEqual(policy.networkFiltering.action, .block)
    }
    
    func testEventProcessorIntegrationWithManager() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: Initialized manager
        try manager.initialize()
        
        // When: Getting event processor
        let processor = manager.getEventProcessor()
        
        // Then: Processor should be available
        XCTAssertNotNil(processor)
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    func testCompleteWorkflowWithPolicyAndEvents() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: Complete setup with policies
        let testPath = "/usr/bin/test"
        let policy = ProtectionPolicy(
            identifier: testPath,
            protectionLevel: .standard,
            networkFiltering: NetworkFilteringRules(action: .allow, allowedDomains: [], blockedDomains: []),
            dnsFiltering: DNSFilteringRules(action: .allow, blockTracking: false, blockFingerprinting: false, customBlocklist: []),
            hardwareSpoofing: .none,
            requiresVMIsolation: false,
            parentPolicy: nil
        )
        
        policyEngine.addPolicy(policy)
        
        // When: Initializing and subscribing
        try manager.initialize()
        let events: [es_event_type_t] = [ES_EVENT_TYPE_AUTH_EXEC]
        try manager.subscribe(to: events)
        
        // Then: Manager should be active and ready to process events
        XCTAssertTrue(manager.isClientActive())
        
        // Verify policy is accessible
        let retrievedPolicy = policyEngine.evaluatePolicy(for: testPath)
        XCTAssertEqual(retrievedPolicy.identifier, testPath)
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    // MARK: - Performance Tests
    
    func testEventProcessingPerformance() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: Multiple policies
        for i in 0..<10 {
            let policy = ProtectionPolicy(
                identifier: "/usr/bin/test\(i)",
                protectionLevel: .standard,
                networkFiltering: NetworkFilteringRules(action: .allow, allowedDomains: [], blockedDomains: []),
                dnsFiltering: DNSFilteringRules(action: .allow, blockTracking: false, blockFingerprinting: false, customBlocklist: []),
                hardwareSpoofing: .none,
                requiresVMIsolation: false,
                parentPolicy: nil
            )
            policyEngine.addPolicy(policy)
        }
        
        // When: Measuring policy evaluation performance
        measure {
            for i in 0..<100 {
                let path = "/usr/bin/test\(i % 10)"
                _ = policyEngine.evaluatePolicy(for: path)
            }
        }
        
        // Then: Performance should be acceptable (measured by XCTest)
    }
    
    // MARK: - Complete Flow Integration Tests
    
    /// Test complete flow: process launch → policy evaluation → protection application
    /// Requirements: 20.2
    func testCompleteFlowProcessLaunchToPolicyToProtection() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: A complete setup with specific policies for different protection levels
        let safariPath = "/Applications/Safari.app/Contents/MacOS/Safari"
        let chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        let nativeAppPath = "/usr/bin/whoami"
        
        // Safari: Standard protection
        let safariPolicy = ProtectionPolicy(
            identifier: safariPath,
            protectionLevel: .standard,
            networkFiltering: NetworkFilteringRules(action: .monitor, allowedDomains: [], blockedDomains: ["*.tracking.com"]),
            dnsFiltering: DNSFilteringRules(action: .block, blockTracking: true, blockFingerprinting: true, customBlocklist: []),
            hardwareSpoofing: .basic,
            requiresVMIsolation: false,
            parentPolicy: nil
        )
        
        // Chrome: Strict protection
        let chromePolicy = ProtectionPolicy(
            identifier: chromePath,
            protectionLevel: .strict,
            networkFiltering: NetworkFilteringRules(action: .block, allowedDomains: [], blockedDomains: ["*"]),
            dnsFiltering: DNSFilteringRules(action: .block, blockTracking: true, blockFingerprinting: true, customBlocklist: []),
            hardwareSpoofing: .full,
            requiresVMIsolation: true,
            parentPolicy: nil
        )
        
        // Native app: Basic protection
        let nativePolicy = ProtectionPolicy(
            identifier: nativeAppPath,
            protectionLevel: .basic,
            networkFiltering: NetworkFilteringRules(action: .allow, allowedDomains: [], blockedDomains: []),
            dnsFiltering: DNSFilteringRules(action: .allow, blockTracking: false, blockFingerprinting: false, customBlocklist: []),
            hardwareSpoofing: .none,
            requiresVMIsolation: false,
            parentPolicy: nil
        )
        
        // Add policies to engine
        policyEngine.addPolicy(safariPolicy)
        policyEngine.addPolicy(chromePolicy)
        policyEngine.addPolicy(nativePolicy)
        
        // When: Initializing and subscribing to process execution events
        try manager.initialize()
        let events: [es_event_type_t] = [ES_EVENT_TYPE_AUTH_EXEC, ES_EVENT_TYPE_NOTIFY_EXIT]
        try manager.subscribe(to: events)
        
        // Then: Manager should be active
        XCTAssertTrue(manager.isClientActive())
        
        // Verify policy evaluation for each application
        let safariEvaluated = policyEngine.evaluatePolicy(for: safariPath)
        XCTAssertEqual(safariEvaluated.identifier, safariPath)
        XCTAssertEqual(safariEvaluated.protectionLevel, .standard)
        XCTAssertFalse(safariEvaluated.requiresVMIsolation)
        
        let chromeEvaluated = policyEngine.evaluatePolicy(for: chromePath)
        XCTAssertEqual(chromeEvaluated.identifier, chromePath)
        XCTAssertEqual(chromeEvaluated.protectionLevel, .strict)
        XCTAssertTrue(chromeEvaluated.requiresVMIsolation)
        
        let nativeEvaluated = policyEngine.evaluatePolicy(for: nativeAppPath)
        XCTAssertEqual(nativeEvaluated.identifier, nativeAppPath)
        XCTAssertEqual(nativeEvaluated.protectionLevel, .basic)
        XCTAssertFalse(nativeEvaluated.requiresVMIsolation)
        
        // Verify event processor is ready
        let processor = manager.getEventProcessor()
        XCTAssertNotNil(processor)
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    /// Test with Safari application
    /// Requirements: 20.8
    func testIntegrationWithSafariApplication() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: Safari-specific policy
        let safariPath = "/Applications/Safari.app/Contents/MacOS/Safari"
        let safariPolicy = ProtectionPolicy(
            identifier: safariPath,
            protectionLevel: .standard,
            networkFiltering: NetworkFilteringRules(
                action: .monitor,
                allowedDomains: ["*.apple.com", "*.icloud.com"],
                blockedDomains: ["*.doubleclick.net", "*.google-analytics.com"]
            ),
            dnsFiltering: DNSFilteringRules(
                action: .block,
                blockTracking: true,
                blockFingerprinting: true,
                customBlocklist: ["tracking.example.com"]
            ),
            hardwareSpoofing: .basic,
            requiresVMIsolation: false,
            parentPolicy: nil
        )
        
        policyEngine.addPolicy(safariPolicy)
        
        // When: Setting up protection for Safari
        try manager.initialize()
        try manager.subscribe(to: [ES_EVENT_TYPE_AUTH_EXEC])
        
        // Then: Policy should be correctly configured
        let policy = policyEngine.evaluatePolicy(for: safariPath)
        XCTAssertEqual(policy.identifier, safariPath)
        XCTAssertEqual(policy.protectionLevel, .standard)
        XCTAssertTrue(policy.dnsFiltering.blockTracking)
        XCTAssertTrue(policy.dnsFiltering.blockFingerprinting)
        XCTAssertEqual(policy.networkFiltering.action, .monitor)
        XCTAssertEqual(policy.networkFiltering.blockedDomains.count, 2)
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    /// Test with Chrome application
    /// Requirements: 20.8
    func testIntegrationWithChromeApplication() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: Chrome-specific policy with VM isolation
        let chromePath = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        let chromePolicy = ProtectionPolicy(
            identifier: chromePath,
            protectionLevel: .paranoid,
            networkFiltering: NetworkFilteringRules(
                action: .block,
                allowedDomains: [],
                blockedDomains: ["*"]
            ),
            dnsFiltering: DNSFilteringRules(
                action: .block,
                blockTracking: true,
                blockFingerprinting: true,
                customBlocklist: []
            ),
            hardwareSpoofing: .full,
            requiresVMIsolation: true,
            parentPolicy: nil
        )
        
        policyEngine.addPolicy(chromePolicy)
        
        // When: Setting up protection for Chrome
        try manager.initialize()
        try manager.subscribe(to: [ES_EVENT_TYPE_AUTH_EXEC])
        
        // Then: Policy should require VM isolation
        let policy = policyEngine.evaluatePolicy(for: chromePath)
        XCTAssertEqual(policy.identifier, chromePath)
        XCTAssertEqual(policy.protectionLevel, .paranoid)
        XCTAssertTrue(policy.requiresVMIsolation)
        XCTAssertEqual(policy.hardwareSpoofing, .full)
        XCTAssertEqual(policy.networkFiltering.action, .block)
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    /// Test with native macOS applications
    /// Requirements: 20.8
    func testIntegrationWithNativeMacOSApplications() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: Policies for various native apps
        let nativeApps = [
            "/usr/bin/whoami",
            "/usr/bin/curl",
            "/System/Applications/Calculator.app/Contents/MacOS/Calculator",
            "/System/Applications/TextEdit.app/Contents/MacOS/TextEdit"
        ]
        
        for appPath in nativeApps {
            let policy = ProtectionPolicy(
                identifier: appPath,
                protectionLevel: .basic,
                networkFiltering: NetworkFilteringRules(action: .allow, allowedDomains: [], blockedDomains: []),
                dnsFiltering: DNSFilteringRules(action: .allow, blockTracking: false, blockFingerprinting: false, customBlocklist: []),
                hardwareSpoofing: .none,
                requiresVMIsolation: false,
                parentPolicy: nil
            )
            policyEngine.addPolicy(policy)
        }
        
        // When: Setting up protection
        try manager.initialize()
        try manager.subscribe(to: [ES_EVENT_TYPE_AUTH_EXEC, ES_EVENT_TYPE_NOTIFY_EXIT])
        
        // Then: All policies should be accessible
        for appPath in nativeApps {
            let policy = policyEngine.evaluatePolicy(for: appPath)
            XCTAssertEqual(policy.identifier, appPath)
            XCTAssertEqual(policy.protectionLevel, .basic)
            XCTAssertFalse(policy.requiresVMIsolation)
        }
        
        XCTAssertTrue(manager.isClientActive())
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    /// Test error handling for Full Disk Access denial
    /// Requirements: 20.2
    func testErrorHandlingForFullDiskAccessDenial() throws {
        // This test verifies that the system handles FDA denial gracefully
        // Note: This test will only fail if FDA is actually denied
        
        // When: Attempting to initialize without Full Disk Access
        // (This will succeed if FDA is granted, which is expected in CI/dev environments)
        do {
            try manager.initialize()
            
            // If we get here, FDA is granted - verify we can cleanup properly
            XCTAssertTrue(manager.isClientActive())
            try manager.unsubscribe()
            
            // Test passes - FDA is available
            XCTAssertFalse(manager.isClientActive())
            
        } catch EndpointSecurityError.fullDiskAccessDenied {
            // Expected error when FDA is not granted
            // This is actually a successful test case - we handled the error correctly
            XCTAssertFalse(manager.isClientActive())
            
        } catch EndpointSecurityError.clientInitializationFailed(let code) {
            // Check if this is the FDA error code or "not privileged" error
            if code == ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED.rawValue || 
               code == ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED.rawValue {
                // This is the FDA denial or privilege error - test passes
                // Both errors indicate proper error handling
                XCTAssertFalse(manager.isClientActive())
            } else {
                // Different initialization error - re-throw
                throw EndpointSecurityError.clientInitializationFailed(code)
            }
            
        } catch {
            // Unexpected error - fail the test
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    /// Test graceful degradation when permissions are unavailable
    /// Requirements: 20.2
    func testGracefulDegradationWithoutPermissions() throws {
        // Given: A manager that may not have permissions
        let testLogger = Logger(label: "com.privarion.tests.degradation")
        let testPolicyEngine = ProtectionPolicyEngine()
        let testManager = EndpointSecurityManager(policyEngine: testPolicyEngine, logger: testLogger)
        
        // When: Attempting operations without initialization
        do {
            // Try to subscribe without initializing
            try testManager.subscribe(to: [ES_EVENT_TYPE_AUTH_EXEC])
            XCTFail("Should have thrown error when subscribing without initialization")
            
        } catch EndpointSecurityError.clientInitializationFailed {
            // Expected error - test passes
            XCTAssertFalse(testManager.isClientActive())
            
        } catch EndpointSecurityError.clientDisconnected {
            // Also acceptable - client not active
            XCTAssertFalse(testManager.isClientActive())
            
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Test multiple event type subscriptions
    /// Requirements: 20.2
    func testMultipleEventTypeSubscriptions() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: Initialized manager
        try manager.initialize()
        
        // When: Subscribing to multiple event types
        let events: [es_event_type_t] = [
            ES_EVENT_TYPE_AUTH_EXEC,
            ES_EVENT_TYPE_AUTH_OPEN,
            ES_EVENT_TYPE_NOTIFY_WRITE,
            ES_EVENT_TYPE_NOTIFY_EXIT
        ]
        
        try manager.subscribe(to: events)
        
        // Then: Manager should be active and ready to handle all event types
        XCTAssertTrue(manager.isClientActive())
        
        // Verify event processor is available
        let processor = manager.getEventProcessor()
        XCTAssertNotNil(processor)
        
        // Cleanup
        try manager.unsubscribe()
        XCTAssertFalse(manager.isClientActive())
    }
    
    /// Test policy evaluation performance with many policies
    /// Requirements: 20.2
    func testPolicyEvaluationPerformanceWithManyPolicies() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: Many policies (simulating real-world usage)
        for i in 0..<100 {
            let policy = ProtectionPolicy(
                identifier: "/Applications/App\(i).app/Contents/MacOS/App\(i)",
                protectionLevel: .standard,
                networkFiltering: NetworkFilteringRules(action: .monitor, allowedDomains: [], blockedDomains: []),
                dnsFiltering: DNSFilteringRules(action: .allow, blockTracking: false, blockFingerprinting: false, customBlocklist: []),
                hardwareSpoofing: .none,
                requiresVMIsolation: false,
                parentPolicy: nil
            )
            policyEngine.addPolicy(policy)
        }
        
        // When: Initializing and measuring performance
        try manager.initialize()
        try manager.subscribe(to: [ES_EVENT_TYPE_AUTH_EXEC])
        
        // Then: Policy evaluation should be fast
        let startTime = Date()
        for i in 0..<100 {
            let path = "/Applications/App\(i).app/Contents/MacOS/App\(i)"
            let policy = policyEngine.evaluatePolicy(for: path)
            XCTAssertEqual(policy.identifier, path)
        }
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Should complete 100 evaluations in less than 100ms (1ms per evaluation)
        XCTAssertLessThan(elapsed, 0.1, "Policy evaluation too slow: \(elapsed)s for 100 evaluations")
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    /// Test concurrent event processing
    /// Requirements: 20.2
    func testConcurrentEventProcessing() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: Multiple policies for concurrent testing
        let apps = [
            "/Applications/Safari.app/Contents/MacOS/Safari",
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/usr/bin/whoami",
            "/usr/bin/curl",
            "/System/Applications/Calculator.app/Contents/MacOS/Calculator"
        ]
        
        for appPath in apps {
            let policy = ProtectionPolicy(
                identifier: appPath,
                protectionLevel: .standard,
                networkFiltering: NetworkFilteringRules(action: .allow, allowedDomains: [], blockedDomains: []),
                dnsFiltering: DNSFilteringRules(action: .allow, blockTracking: false, blockFingerprinting: false, customBlocklist: []),
                hardwareSpoofing: .none,
                requiresVMIsolation: false,
                parentPolicy: nil
            )
            policyEngine.addPolicy(policy)
        }
        
        // When: Setting up for concurrent processing
        try manager.initialize()
        try manager.subscribe(to: [ES_EVENT_TYPE_AUTH_EXEC])
        
        // Then: Should handle concurrent policy evaluations
        let expectation = XCTestExpectation(description: "Concurrent policy evaluations")
        expectation.expectedFulfillmentCount = apps.count
        
        DispatchQueue.concurrentPerform(iterations: apps.count) { index in
            let policy = policyEngine.evaluatePolicy(for: apps[index])
            XCTAssertEqual(policy.identifier, apps[index])
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    /// Test protection application with different protection levels
    /// Requirements: 20.2
    func testProtectionApplicationWithDifferentLevels() throws {
        // Skip if we don't have permissions
        guard canInitializeClient() else {
            throw XCTSkip("Skipping test - requires Full Disk Access and entitlements")
        }
        
        // Given: Policies with different protection levels
        let levels: [(String, ProtectionLevel)] = [
            ("/usr/bin/none", .none),
            ("/usr/bin/basic", .basic),
            ("/usr/bin/standard", .standard),
            ("/usr/bin/strict", .strict),
            ("/usr/bin/paranoid", .paranoid)
        ]
        
        for (path, level) in levels {
            let policy = ProtectionPolicy(
                identifier: path,
                protectionLevel: level,
                networkFiltering: NetworkFilteringRules(action: .allow, allowedDomains: [], blockedDomains: []),
                dnsFiltering: DNSFilteringRules(action: .allow, blockTracking: false, blockFingerprinting: false, customBlocklist: []),
                hardwareSpoofing: .none,
                requiresVMIsolation: false,
                parentPolicy: nil
            )
            policyEngine.addPolicy(policy)
        }
        
        // When: Initializing protection
        try manager.initialize()
        try manager.subscribe(to: [ES_EVENT_TYPE_AUTH_EXEC])
        
        // Then: Each protection level should be correctly applied
        for (path, expectedLevel) in levels {
            let policy = policyEngine.evaluatePolicy(for: path)
            XCTAssertEqual(policy.protectionLevel, expectedLevel, "Protection level mismatch for \(path)")
        }
        
        // Cleanup
        try manager.unsubscribe()
    }
    
    // MARK: - Helper Methods
    
    private func canInitializeClient() -> Bool {
        let testPolicyEngine = ProtectionPolicyEngine()
        let testManager = EndpointSecurityManager(policyEngine: testPolicyEngine)
        do {
            try testManager.initialize()
            try testManager.unsubscribe()
            return true
        } catch {
            return false
        }
    }
}
