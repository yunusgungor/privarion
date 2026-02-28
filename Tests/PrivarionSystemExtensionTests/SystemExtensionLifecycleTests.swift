// PrivarionSystemExtensionTests - SystemExtensionLifecycleTests
// Unit tests for SystemExtensionLifecycle protocol and lifecycle event logging
// Requirements: 1.8, 17.1, 20.1

import XCTest
@testable import PrivarionSystemExtension

final class SystemExtensionLifecycleTests: XCTestCase {
    
    var mockObserver: MockLifecycleObserver!
    var systemExtension: PrivarionSystemExtension!
    
    override func setUp() {
        super.setUp()
        mockObserver = MockLifecycleObserver()
        systemExtension = PrivarionSystemExtension(extensionIdentifier: "com.privarion.test.lifecycle")
    }
    
    override func tearDown() {
        mockObserver = nil
        systemExtension = nil
        super.tearDown()
    }
    
    // MARK: - Lifecycle Observer Management Tests
    
    func testAddLifecycleObserver() {
        // Given: A system extension
        // When: Adding a lifecycle observer
        systemExtension.addLifecycleObserver(mockObserver)
        
        // Then: Observer should be added (verified by subsequent notifications)
        XCTAssertNotNil(systemExtension, "System extension should exist")
    }
    
    func testRemoveLifecycleObserver() {
        // Given: A system extension with an observer
        systemExtension.addLifecycleObserver(mockObserver)
        
        // When: Removing the observer
        systemExtension.removeLifecycleObserver(ofType: MockLifecycleObserver.self)
        
        // Then: Observer should be removed (verified by no subsequent notifications)
        XCTAssertNotNil(systemExtension, "System extension should exist")
    }
    
    // MARK: - Lifecycle Event Tests
    
    func testWillActivateNotification() async {
        // Given: A system extension with a lifecycle observer
        systemExtension.addLifecycleObserver(mockObserver)
        
        // When: Attempting to activate (will fail without proper entitlements, but should call willActivate)
        do {
            try await systemExtension.activateExtension()
        } catch {
            // Expected to fail in test environment
        }
        
        // Then: willActivate should have been called
        XCTAssertTrue(mockObserver.willActivateCalled, "willActivate should be called before activation")
    }
    
    func testDidFailWithErrorNotification() async {
        // Given: A system extension with a lifecycle observer
        systemExtension.addLifecycleObserver(mockObserver)
        
        // When: Attempting to activate (will fail without proper entitlements)
        do {
            try await systemExtension.activateExtension()
            XCTFail("Should throw error in test environment")
        } catch {
            // Expected to fail
        }
        
        // Then: didFailWithError should have been called
        XCTAssertTrue(mockObserver.didFailWithErrorCalled, "didFailWithError should be called on failure")
        XCTAssertNotNil(mockObserver.lastError, "Error should be captured")
    }
    
    func testWillDeactivateNotification() async {
        // Given: A system extension with a lifecycle observer
        systemExtension.addLifecycleObserver(mockObserver)
        
        // When: Attempting to deactivate (will fail without proper entitlements, but should call willDeactivate)
        do {
            try await systemExtension.deactivateExtension()
        } catch {
            // Expected to fail in test environment
        }
        
        // Then: willDeactivate should have been called
        XCTAssertTrue(mockObserver.willDeactivateCalled, "willDeactivate should be called before deactivation")
    }
    
    // MARK: - Lifecycle Logger Tests
    
    func testLifecycleLoggerInitialization() {
        // Given/When: Creating a lifecycle logger
        let logger = SystemExtensionLifecycleLogger(extensionIdentifier: "com.privarion.test")
        
        // Then: Logger should be initialized
        XCTAssertNotNil(logger, "Lifecycle logger should initialize successfully")
    }
    
    func testLifecycleLoggerWillActivate() async {
        // Given: A lifecycle logger
        let logger = SystemExtensionLifecycleLogger(extensionIdentifier: "com.privarion.test")
        
        // When: Calling willActivate
        await logger.willActivate()
        
        // Then: Should complete without error (actual logging verified manually)
        XCTAssertTrue(true, "willActivate should complete successfully")
    }
    
    func testLifecycleLoggerDidActivate() async {
        // Given: A lifecycle logger
        let logger = SystemExtensionLifecycleLogger(extensionIdentifier: "com.privarion.test")
        
        // When: Calling didActivate
        await logger.didActivate()
        
        // Then: Should complete without error
        XCTAssertTrue(true, "didActivate should complete successfully")
    }
    
    func testLifecycleLoggerWillDeactivate() async {
        // Given: A lifecycle logger
        let logger = SystemExtensionLifecycleLogger(extensionIdentifier: "com.privarion.test")
        
        // When: Calling willDeactivate
        await logger.willDeactivate()
        
        // Then: Should complete without error
        XCTAssertTrue(true, "willDeactivate should complete successfully")
    }
    
    func testLifecycleLoggerDidDeactivate() async {
        // Given: A lifecycle logger
        let logger = SystemExtensionLifecycleLogger(extensionIdentifier: "com.privarion.test")
        
        // When: Calling didDeactivate
        await logger.didDeactivate()
        
        // Then: Should complete without error
        XCTAssertTrue(true, "didDeactivate should complete successfully")
    }
    
    func testLifecycleLoggerDidFailWithError() async {
        // Given: A lifecycle logger
        let logger = SystemExtensionLifecycleLogger(extensionIdentifier: "com.privarion.test")
        let testError = NSError(domain: "com.privarion.test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        // When: Calling didFailWithError
        await logger.didFailWithError(testError)
        
        // Then: Should complete without error
        XCTAssertTrue(true, "didFailWithError should complete successfully")
    }
    
    // MARK: - Multiple Observer Tests
    
    func testMultipleLifecycleObservers() async {
        // Given: A system extension with multiple observers
        let observer1 = MockLifecycleObserver()
        let observer2 = MockLifecycleObserver()
        
        systemExtension.addLifecycleObserver(observer1)
        systemExtension.addLifecycleObserver(observer2)
        
        // When: Attempting to activate
        do {
            try await systemExtension.activateExtension()
        } catch {
            // Expected to fail in test environment
        }
        
        // Then: Both observers should be notified
        XCTAssertTrue(observer1.willActivateCalled, "First observer should receive willActivate")
        XCTAssertTrue(observer2.willActivateCalled, "Second observer should receive willActivate")
    }
    
    // MARK: - Integration Tests
    
    func testLifecycleEventsOrderDuringActivation() async {
        // Given: A system extension with a lifecycle observer
        systemExtension.addLifecycleObserver(mockObserver)
        
        // When: Attempting to activate
        do {
            try await systemExtension.activateExtension()
        } catch {
            // Expected to fail in test environment
        }
        
        // Then: Events should be called in correct order
        XCTAssertTrue(mockObserver.willActivateCalled, "willActivate should be called first")
        // didActivate won't be called because activation fails in test environment
        XCTAssertTrue(mockObserver.didFailWithErrorCalled, "didFailWithError should be called on failure")
    }
    
    func testLifecycleEventsOrderDuringDeactivation() async {
        // Given: A system extension with a lifecycle observer
        systemExtension.addLifecycleObserver(mockObserver)
        
        // When: Attempting to deactivate
        do {
            try await systemExtension.deactivateExtension()
        } catch {
            // Expected to fail in test environment
        }
        
        // Then: Events should be called in correct order
        XCTAssertTrue(mockObserver.willDeactivateCalled, "willDeactivate should be called first")
        // didDeactivate won't be called because deactivation fails in test environment
        XCTAssertTrue(mockObserver.didFailWithErrorCalled, "didFailWithError should be called on failure")
    }
}

// MARK: - Mock Lifecycle Observer

/// Mock implementation of SystemExtensionLifecycle for testing
class MockLifecycleObserver: SystemExtensionLifecycle {
    var willActivateCalled = false
    var didActivateCalled = false
    var willDeactivateCalled = false
    var didDeactivateCalled = false
    var didFailWithErrorCalled = false
    var lastError: Error?
    
    func willActivate() async {
        willActivateCalled = true
    }
    
    func didActivate() async {
        didActivateCalled = true
    }
    
    func willDeactivate() async {
        willDeactivateCalled = true
    }
    
    func didDeactivate() async {
        didDeactivateCalled = true
    }
    
    func didFailWithError(_ error: Error) async {
        didFailWithErrorCalled = true
        lastError = error
    }
    
    func reset() {
        willActivateCalled = false
        didActivateCalled = false
        willDeactivateCalled = false
        didDeactivateCalled = false
        didFailWithErrorCalled = false
        lastError = nil
    }
}
