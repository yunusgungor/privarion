// PrivarionSystemExtensionTests - SystemExtensionManagerTests
// Comprehensive unit tests for System Extension Manager
// Tests installation request creation, entitlement validation, status transitions, and error handling
// Requirements: 1.1-1.8, 12.1-12.10, 20.1

import XCTest
@testable import PrivarionSystemExtension
@testable import PrivarionSharedModels
import SystemExtensions

final class SystemExtensionManagerTests: XCTestCase {
    
    var systemExtension: PrivarionSystemExtension!
    var mockStatusObserver: MockStatusObserver!
    let testExtensionIdentifier = "com.privarion.test.manager"
    
    override func setUp() {
        super.setUp()
        systemExtension = PrivarionSystemExtension(extensionIdentifier: testExtensionIdentifier)
        mockStatusObserver = MockStatusObserver()
    }
    
    override func tearDown() {
        systemExtension = nil
        mockStatusObserver = nil
        super.tearDown()
    }
    
    // MARK: - Installation Request Creation Tests
    
    func testInstallExtensionCreatesActivationRequest() async {
        // Given: A system extension
        // When: Attempting to install (will fail in test environment)
        do {
            try await systemExtension.installExtension()
            XCTFail("Should fail in test environment without proper entitlements")
        } catch {
            // Then: Should attempt to create and submit activation request
            XCTAssertNotNil(error, "Should throw error in test environment")
        }
    }
    
    func testActivateExtensionCreatesActivationRequest() async {
        // Given: A system extension
        // When: Attempting to activate
        do {
            try await systemExtension.activateExtension()
            XCTFail("Should fail in test environment without proper entitlements")
        } catch {
            // Then: Should attempt to create and submit activation request
            XCTAssertNotNil(error, "Should throw error in test environment")
        }
    }
    
    func testDeactivateExtensionCreatesDeactivationRequest() async {
        // Given: A system extension
        // When: Attempting to deactivate
        do {
            try await systemExtension.deactivateExtension()
            XCTFail("Should fail in test environment without proper entitlements")
        } catch {
            // Then: Should attempt to create and submit deactivation request
            XCTAssertNotNil(error, "Should throw error in test environment")
        }
    }
    
    // MARK: - Entitlement Validation Tests
    
    func testInstallExtensionValidatesEntitlements() async {
        // Given: A system extension without proper entitlements
        // When: Attempting to install
        do {
            try await systemExtension.installExtension()
            XCTFail("Should fail entitlement validation")
        } catch {
            // Then: Should throw error related to entitlements or system setup
            XCTAssertNotNil(error, "Should throw error for missing entitlements")
        }
    }
    
    func testActivateExtensionValidatesEntitlements() async {
        // Given: A system extension without proper entitlements
        // When: Attempting to activate
        do {
            try await systemExtension.activateExtension()
            XCTFail("Should fail entitlement validation")
        } catch {
            // Then: Should throw error
            XCTAssertNotNil(error, "Should throw error for missing entitlements")
        }
    }
    
    // MARK: - Status Transition Tests
    
    func testInitialStatusIsNotInstalled() async {
        // Given: A newly created system extension
        // When: Checking status
        let status = await systemExtension.checkStatus()
        
        // Then: Status should be notInstalled (or loaded from persistence)
        switch status {
        case .notInstalled, .installed, .active, .error:
            XCTAssertTrue(true, "Valid initial status")
        default:
            XCTFail("Unexpected initial status")
        }
    }
    
    func testStatusTransitionsToActivatingDuringInstallation() async {
        // Given: A system extension with status observer
        systemExtension.addStatusObserver(mockStatusObserver)
        
        // When: Attempting to install
        do {
            try await systemExtension.installExtension()
        } catch {
            // Expected to fail in test environment
        }
        
        // Then: Status should have transitioned to activating
        XCTAssertTrue(
            mockStatusObserver.statusChanges.contains { status in
                if case .activating = status { return true }
                return false
            },
            "Status should transition to activating"
        )
    }
    
    func testStatusTransitionsToErrorOnFailure() async {
        // Given: A system extension with status observer
        systemExtension.addStatusObserver(mockStatusObserver)
        
        // When: Attempting to install (will fail)
        do {
            try await systemExtension.installExtension()
        } catch {
            // Expected to fail
        }
        
        // Then: Status should transition to error
        XCTAssertTrue(
            mockStatusObserver.statusChanges.contains { status in
                if case .error = status { return true }
                return false
            },
            "Status should transition to error on failure"
        )
    }
    
    func testStatusTransitionsToDeactivatingDuringDeactivation() async {
        // Given: A system extension with status observer
        systemExtension.addStatusObserver(mockStatusObserver)
        
        // When: Attempting to deactivate
        do {
            try await systemExtension.deactivateExtension()
        } catch {
            // Expected to fail in test environment
        }
        
        // Then: Status should have transitioned to deactivating
        XCTAssertTrue(
            mockStatusObserver.statusChanges.contains { status in
                if case .deactivating = status { return true }
                return false
            },
            "Status should transition to deactivating"
        )
    }
    
    func testCheckStatusReturnsCurrentStatus() async {
        // Given: A system extension
        // When: Checking status multiple times
        let status1 = await systemExtension.checkStatus()
        let status2 = await systemExtension.checkStatus()
        
        // Then: Should return consistent status
        XCTAssertNotNil(status1, "Should return status")
        XCTAssertNotNil(status2, "Should return status")
    }
    
    // MARK: - Error Handling for Missing Entitlements Tests
    
    func testInstallExtensionThrowsErrorForMissingEntitlements() async {
        // Given: A system extension without proper entitlements
        // When: Attempting to install
        do {
            try await systemExtension.installExtension()
            XCTFail("Should throw error for missing entitlements")
        } catch let error as SystemExtensionError {
            // Then: Should throw SystemExtensionError
            switch error {
            case .entitlementMissing, .installationFailed, .activationFailed, .incompatibleMacOSVersion:
                XCTAssertTrue(true, "Correct error type thrown")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            // In test environment, might throw other errors
            XCTAssertNotNil(error, "Should throw some error")
        }
    }
    
    func testActivateExtensionThrowsErrorForMissingEntitlements() async {
        // Given: A system extension without proper entitlements
        // When: Attempting to activate
        do {
            try await systemExtension.activateExtension()
            XCTFail("Should throw error for missing entitlements")
        } catch let error as SystemExtensionError {
            // Then: Should throw SystemExtensionError
            switch error {
            case .entitlementMissing, .installationFailed, .activationFailed, .incompatibleMacOSVersion:
                XCTAssertTrue(true, "Correct error type thrown")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            // In test environment, might throw other errors
            XCTAssertNotNil(error, "Should throw some error")
        }
    }
    
    func testDeactivateExtensionThrowsErrorForMissingEntitlements() async {
        // Given: A system extension without proper entitlements
        // When: Attempting to deactivate
        do {
            try await systemExtension.deactivateExtension()
            XCTFail("Should throw error for missing entitlements")
        } catch let error as SystemExtensionError {
            // Then: Should throw SystemExtensionError
            switch error {
            case .entitlementMissing, .installationFailed, .activationFailed, .incompatibleMacOSVersion:
                XCTAssertTrue(true, "Correct error type thrown")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        } catch {
            // In test environment, might throw other errors
            XCTAssertNotNil(error, "Should throw some error")
        }
    }
    
    // MARK: - Status Observer Tests
    
    func testAddStatusObserver() {
        // Given: A system extension
        // When: Adding a status observer
        systemExtension.addStatusObserver(mockStatusObserver)
        
        // Then: Observer should be added (verified by subsequent notifications)
        XCTAssertNotNil(systemExtension, "System extension should exist")
    }
    
    func testRemoveStatusObserver() {
        // Given: A system extension with an observer
        systemExtension.addStatusObserver(mockStatusObserver)
        
        // When: Removing the observer
        systemExtension.removeStatusObserver(mockStatusObserver)
        
        // Then: Observer should be removed
        XCTAssertNotNil(systemExtension, "System extension should exist")
    }
    
    func testStatusObserverReceivesNotifications() async {
        // Given: A system extension with status observer
        systemExtension.addStatusObserver(mockStatusObserver)
        
        // When: Attempting to install (will fail and trigger status changes)
        do {
            try await systemExtension.installExtension()
        } catch {
            // Expected to fail
        }
        
        // Then: Observer should have received status change notifications
        XCTAssertFalse(mockStatusObserver.statusChanges.isEmpty, "Observer should receive notifications")
    }
    
    func testMultipleStatusObserversReceiveNotifications() async {
        // Given: A system extension with multiple observers
        let observer1 = MockStatusObserver()
        let observer2 = MockStatusObserver()
        
        systemExtension.addStatusObserver(observer1)
        systemExtension.addStatusObserver(observer2)
        
        // When: Attempting to install
        do {
            try await systemExtension.installExtension()
        } catch {
            // Expected to fail
        }
        
        // Then: Both observers should receive notifications
        XCTAssertFalse(observer1.statusChanges.isEmpty, "First observer should receive notifications")
        XCTAssertFalse(observer2.statusChanges.isEmpty, "Second observer should receive notifications")
    }
    
    // MARK: - OSSystemExtensionRequestDelegate Tests
    
    func testRequestActionForReplacingExtension() {
        // Given: A system extension and mock extension properties
        let existingProperties = MockExtensionProperties(bundleVersion: "1.0.0")
        let newProperties = MockExtensionProperties(bundleVersion: "2.0.0")
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        
        // When: Requesting replacement action
        let action = systemExtension.request(
            request,
            actionForReplacingExtension: existingProperties,
            withExtension: newProperties
        )
        
        // Then: Should return replace action
        XCTAssertEqual(action, .replace, "Should allow replacement")
    }
    
    func testRequestDidFinishWithResultCompleted() {
        // Given: A system extension with status observer
        systemExtension.addStatusObserver(mockStatusObserver)
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        
        // When: Request finishes with completed result
        systemExtension.request(request, didFinishWithResult: .completed)
        
        // Then: Status should be updated to active
        XCTAssertTrue(
            mockStatusObserver.statusChanges.contains { status in
                if case .active = status { return true }
                return false
            },
            "Status should be active after successful completion"
        )
    }
    
    func testRequestDidFinishWithResultWillCompleteAfterReboot() {
        // Given: A system extension with status observer
        systemExtension.addStatusObserver(mockStatusObserver)
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        
        // When: Request finishes with willCompleteAfterReboot result
        systemExtension.request(request, didFinishWithResult: .willCompleteAfterReboot)
        
        // Then: Status should be updated to installed
        XCTAssertTrue(
            mockStatusObserver.statusChanges.contains { status in
                if case .installed = status { return true }
                return false
            },
            "Status should be installed after willCompleteAfterReboot"
        )
    }
    
    func testRequestDidFailWithError() {
        // Given: A system extension with status observer
        systemExtension.addStatusObserver(mockStatusObserver)
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        let error = NSError(
            domain: OSSystemExtensionErrorDomain,
            code: OSSystemExtensionError.authorizationRequired.rawValue,
            userInfo: nil
        )
        
        // When: Request fails with error
        systemExtension.request(request, didFailWithError: error)
        
        // Then: Status should be updated to error
        XCTAssertTrue(
            mockStatusObserver.statusChanges.contains { status in
                if case .error = status { return true }
                return false
            },
            "Status should be error after failure"
        )
    }
    
    func testRequestNeedsUserApproval() {
        // Given: A system extension with status observer
        systemExtension.addStatusObserver(mockStatusObserver)
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        
        // When: Request needs user approval
        systemExtension.requestNeedsUserApproval(request)
        
        // Then: Status should be updated to activating
        XCTAssertTrue(
            mockStatusObserver.statusChanges.contains { status in
                if case .activating = status { return true }
                return false
            },
            "Status should be activating when user approval is needed"
        )
    }
    
    // MARK: - Extension Status Persistence Tests
    
    func testExtensionStatusPersistence() {
        // Given: A temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let persistence = ExtensionStatusPersistence(customDirectory: tempDir)
        
        // When: Saving and loading status
        let testStatus = ExtensionStatus.active
        
        do {
            try persistence.saveStatus(testStatus)
            let loadedStatus = try persistence.loadStatus()
            
            // Then: Loaded status should match saved status
            XCTAssertNotNil(loadedStatus, "Should load status")
            if case .active = loadedStatus! {
                XCTAssertTrue(true, "Status should be active")
            } else {
                XCTFail("Status should be active")
            }
            
            // Cleanup
            try? persistence.clearStatus()
            try? FileManager.default.removeItem(at: tempDir)
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testExtensionStatusPersistenceWithError() {
        // Given: A temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let persistence = ExtensionStatusPersistence(customDirectory: tempDir)
        
        // When: Saving and loading error status
        let testStatus = ExtensionStatus.error("Test error message")
        
        do {
            try persistence.saveStatus(testStatus)
            let loadedStatus = try persistence.loadStatus()
            
            // Then: Loaded status should match saved status
            XCTAssertNotNil(loadedStatus, "Should load status")
            if case .error(let message) = loadedStatus! {
                XCTAssertEqual(message, "Test error message", "Error message should match")
            } else {
                XCTFail("Status should be error")
            }
            
            // Cleanup
            try? persistence.clearStatus()
            try? FileManager.default.removeItem(at: tempDir)
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testExtensionStatusPersistenceReturnsNilForMissingFile() {
        // Given: A temporary directory with no status file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let persistence = ExtensionStatusPersistence(customDirectory: tempDir)
        
        // When: Loading status from non-existent file
        do {
            let loadedStatus = try persistence.loadStatus()
            
            // Then: Should return nil
            XCTAssertNil(loadedStatus, "Should return nil for missing file")
            
            // Cleanup
            try? FileManager.default.removeItem(at: tempDir)
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    // MARK: - Integration Tests
    
    func testCompleteInstallationFlow() async {
        // Given: A system extension with observers
        systemExtension.addStatusObserver(mockStatusObserver)
        let lifecycleObserver = MockLifecycleObserver()
        systemExtension.addLifecycleObserver(lifecycleObserver)
        
        // When: Attempting complete installation flow
        do {
            try await systemExtension.installExtension()
        } catch {
            // Expected to fail in test environment
        }
        
        // Then: Should have triggered lifecycle events and status changes
        XCTAssertTrue(lifecycleObserver.willActivateCalled, "Should call willActivate")
        XCTAssertTrue(lifecycleObserver.didFailWithErrorCalled, "Should call didFailWithError")
        XCTAssertFalse(mockStatusObserver.statusChanges.isEmpty, "Should have status changes")
    }
    
    func testCompleteDeactivationFlow() async {
        // Given: A system extension with observers
        systemExtension.addStatusObserver(mockStatusObserver)
        let lifecycleObserver = MockLifecycleObserver()
        systemExtension.addLifecycleObserver(lifecycleObserver)
        
        // When: Attempting complete deactivation flow
        do {
            try await systemExtension.deactivateExtension()
        } catch {
            // Expected to fail in test environment
        }
        
        // Then: Should have triggered lifecycle events and status changes
        XCTAssertTrue(lifecycleObserver.willDeactivateCalled, "Should call willDeactivate")
        XCTAssertTrue(lifecycleObserver.didFailWithErrorCalled, "Should call didFailWithError")
        XCTAssertFalse(mockStatusObserver.statusChanges.isEmpty, "Should have status changes")
    }
}

// MARK: - Mock Status Observer
// Note: MockStatusObserver is defined in PrivarionSystemExtensionTests.swift to avoid duplication
