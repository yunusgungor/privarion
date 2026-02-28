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
