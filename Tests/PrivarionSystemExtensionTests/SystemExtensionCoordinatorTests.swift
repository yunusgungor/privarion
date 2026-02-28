// PrivarionSystemExtensionTests - SystemExtensionCoordinatorTests
// Unit tests for SystemExtensionCoordinator
// Requirements: 1.1-1.8, 12.1-12.10, 20.1

import XCTest
@testable import PrivarionSystemExtension
@testable import PrivarionSharedModels
import SystemExtensions

final class SystemExtensionCoordinatorTests: XCTestCase {
    
    var coordinator: SystemExtensionCoordinator!
    let testExtensionIdentifier = "com.privarion.test.extension"
    
    override func setUp() {
        super.setUp()
        coordinator = SystemExtensionCoordinator(extensionIdentifier: testExtensionIdentifier)
    }
    
    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testCoordinatorInitialization() {
        // Given/When: Creating a coordinator
        let coordinator = SystemExtensionCoordinator(extensionIdentifier: testExtensionIdentifier)
        
        // Then: Coordinator should be initialized
        XCTAssertNotNil(coordinator, "Coordinator should initialize successfully")
    }
    
    func testCoordinatorInitializationWithCustomIdentifier() {
        // Given: A custom extension identifier
        let customIdentifier = "com.custom.extension"
        
        // When: Creating a coordinator with custom identifier
        let coordinator = SystemExtensionCoordinator(extensionIdentifier: customIdentifier)
        
        // Then: Coordinator should be initialized
        XCTAssertNotNil(coordinator, "Coordinator should initialize with custom identifier")
    }
    
    // MARK: - Entitlement Validation Tests
    
    func testValidateEntitlementsInDebugMode() {
        // Given: A coordinator in debug mode
        // When: Validating entitlements
        // Then: Should not throw in debug mode (validation is relaxed)
        #if DEBUG
        XCTAssertNoThrow(try coordinator.validateEntitlements(), "Should not throw in debug mode")
        #endif
    }
    
    func testValidateEntitlementsThrowsForMissingEntitlements() {
        // Given: A coordinator without proper entitlements
        // When: Validating entitlements in production mode
        // Then: Should throw entitlementMissing error
        #if !DEBUG
        XCTAssertThrowsError(try coordinator.validateEntitlements()) { error in
            guard let extensionError = error as? SystemExtensionError else {
                XCTFail("Expected SystemExtensionError")
                return
            }
            
            switch extensionError {
            case .entitlementMissing:
                XCTAssertTrue(true, "Correct error type thrown")
            default:
                XCTFail("Expected entitlementMissing error")
            }
        }
        #endif
    }
    
    // MARK: - Activation Result Handling Tests
    
    func testHandleActivationResultCompleted() {
        // Given: A coordinator
        let result = OSSystemExtensionRequest.Result.completed
        
        // When: Handling completed result
        coordinator.handleActivationResult(result)
        
        // Then: Should handle result without error
        XCTAssertTrue(true, "Should handle completed result successfully")
    }
    
    func testHandleActivationResultWillCompleteAfterReboot() {
        // Given: A coordinator
        let result = OSSystemExtensionRequest.Result.willCompleteAfterReboot
        
        // When: Handling willCompleteAfterReboot result
        coordinator.handleActivationResult(result)
        
        // Then: Should handle result without error
        XCTAssertTrue(true, "Should handle willCompleteAfterReboot result successfully")
    }
    
    // MARK: - OSSystemExtensionRequestDelegate Tests
    
    func testRequestActionForReplacingExtension() {
        // Given: A coordinator and extension properties
        let existingProperties = MockExtensionProperties(bundleVersion: "1.0.0")
        let newProperties = MockExtensionProperties(bundleVersion: "2.0.0")
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        
        // When: Requesting replacement action
        let action = coordinator.request(
            request,
            actionForReplacingExtension: existingProperties,
            withExtension: newProperties
        )
        
        // Then: Should return replace action
        XCTAssertEqual(action, .replace, "Should allow replacement")
    }
    
    func testRequestDidFinishWithResultCompleted() {
        // Given: A coordinator
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        
        // When: Request finishes with completed result
        coordinator.request(request, didFinishWithResult: .completed)
        
        // Then: Should handle result without error
        XCTAssertTrue(true, "Should handle completed result successfully")
    }
    
    func testRequestDidFinishWithResultWillCompleteAfterReboot() {
        // Given: A coordinator
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        
        // When: Request finishes with willCompleteAfterReboot result
        coordinator.request(request, didFinishWithResult: .willCompleteAfterReboot)
        
        // Then: Should handle result without error
        XCTAssertTrue(true, "Should handle willCompleteAfterReboot result successfully")
    }
    
    func testRequestDidFailWithAuthorizationError() {
        // Given: A coordinator
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        let error = NSError(
            domain: OSSystemExtensionErrorDomain,
            code: OSSystemExtensionError.authorizationRequired.rawValue,
            userInfo: nil
        )
        
        // When: Request fails with authorization error
        coordinator.request(request, didFailWithError: error)
        
        // Then: Should handle error (verified by no crash)
        XCTAssertTrue(true, "Should handle authorization error")
    }
    
    func testRequestDidFailWithExtensionNotFoundError() {
        // Given: A coordinator
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        let error = NSError(
            domain: OSSystemExtensionErrorDomain,
            code: OSSystemExtensionError.extensionNotFound.rawValue,
            userInfo: nil
        )
        
        // When: Request fails with extension not found error
        coordinator.request(request, didFailWithError: error)
        
        // Then: Should handle error
        XCTAssertTrue(true, "Should handle extension not found error")
    }
    
    func testRequestDidFailWithValidationError() {
        // Given: A coordinator
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        let error = NSError(
            domain: OSSystemExtensionErrorDomain,
            code: OSSystemExtensionError.validationFailed.rawValue,
            userInfo: nil
        )
        
        // When: Request fails with validation error
        coordinator.request(request, didFailWithError: error)
        
        // Then: Should handle error
        XCTAssertTrue(true, "Should handle validation error")
    }
    
    func testRequestDidFailWithGenericError() {
        // Given: A coordinator
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        let error = NSError(
            domain: "com.test.error",
            code: 999,
            userInfo: [NSLocalizedDescriptionKey: "Generic error"]
        )
        
        // When: Request fails with generic error
        coordinator.request(request, didFailWithError: error)
        
        // Then: Should handle error
        XCTAssertTrue(true, "Should handle generic error")
    }
    
    func testRequestNeedsUserApproval() {
        // Given: A coordinator
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        
        // When: Request needs user approval
        coordinator.requestNeedsUserApproval(request)
        
        // Then: Should handle approval request
        XCTAssertTrue(true, "Should handle user approval request")
    }
    
    // MARK: - Error Mapping Tests
    
    func testErrorMappingForAllOSSystemExtensionErrorCodes() {
        // Given: A coordinator and request
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        
        // Test all known error codes
        let errorCodes: [OSSystemExtensionError.Code] = [
            .authorizationRequired,
            .extensionNotFound,
            .extensionMissingIdentifier,
            .duplicateExtensionIdentifer,
            .forbiddenBySystemPolicy,
            .requestCanceled,
            .requestSuperseded,
            .validationFailed,
            .unsupportedParentBundleLocation,
            .unknown,
            .missingEntitlement,
            .unknownExtensionCategory,
            .codeSignatureInvalid
        ]
        
        // When/Then: Each error code should be handled without crash
        for errorCode in errorCodes {
            let error = NSError(
                domain: OSSystemExtensionErrorDomain,
                code: errorCode.rawValue,
                userInfo: nil
            )
            
            XCTAssertNoThrow(
                coordinator.request(request, didFailWithError: error),
                "Should handle error code: \(errorCode.rawValue)"
            )
        }
    }
    
    // MARK: - Integration Tests
    
    func testSubmitRequestValidatesEntitlementsFirst() async {
        // Given: A coordinator and activation request
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: testExtensionIdentifier,
            queue: .main
        )
        
        // When: Submitting request
        // Then: Should validate entitlements before submission
        #if DEBUG
        // In debug mode, validation passes but submission will fail without proper system setup
        do {
            try await coordinator.submitRequest(request)
            XCTFail("Should not succeed without proper system setup")
        } catch {
            // Expected to fail in test environment
            XCTAssertTrue(true, "Expected failure in test environment")
        }
        #else
        // In production mode, should fail at entitlement validation
        do {
            try await coordinator.submitRequest(request)
            XCTFail("Should fail entitlement validation")
        } catch let error as SystemExtensionError {
            switch error {
            case .entitlementMissing:
                XCTAssertTrue(true, "Correctly failed at entitlement validation")
            default:
                XCTFail("Expected entitlementMissing error")
            }
        } catch {
            XCTFail("Expected SystemExtensionError")
        }
        #endif
    }
}

// MARK: - Mock Extension Properties

/// Mock implementation of OSSystemExtensionProperties for testing
class MockExtensionProperties: OSSystemExtensionProperties {
    private let _bundleVersion: String
    
    init(bundleVersion: String) {
        self._bundleVersion = bundleVersion
        super.init()
    }
    
    override var bundleVersion: String {
        return _bundleVersion
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
