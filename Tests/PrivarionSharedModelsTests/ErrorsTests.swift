// PrivarionSharedModelsTests - Error Enum Tests
// Unit tests for error enums and their descriptions
// Requirements: 20.1

import XCTest
@testable import PrivarionSharedModels
import SystemExtensions

final class ErrorsTests: XCTestCase {
    
    // MARK: - SystemExtensionError Tests
    
    func testSystemExtensionErrorDescriptions() {
        let installationError = SystemExtensionError.installationFailed(reason: "Missing entitlements")
        XCTAssertEqual(
            installationError.errorDescription,
            "System Extension installation failed: Missing entitlements"
        )
        
        // Use a valid OSSystemExtensionError.Code value
        let activationError = SystemExtensionError.activationFailed(.unknown)
        XCTAssertNotNil(activationError.errorDescription)
        XCTAssertTrue(activationError.errorDescription!.contains("activation failed"))
        
        let entitlementError = SystemExtensionError.entitlementMissing("com.apple.developer.system-extension.install")
        XCTAssertEqual(
            entitlementError.errorDescription,
            "Required entitlement missing: com.apple.developer.system-extension.install"
        )
        
        let notarizationError = SystemExtensionError.notarizationFailed
        XCTAssertEqual(
            notarizationError.errorDescription,
            "System Extension notarization failed"
        )
        
        let userDeniedError = SystemExtensionError.userDeniedApproval
        XCTAssertEqual(
            userDeniedError.errorDescription,
            "User denied System Extension approval"
        )
        
        let versionError = SystemExtensionError.incompatibleMacOSVersion
        XCTAssertEqual(
            versionError.errorDescription,
            "Incompatible macOS version. Requires macOS 13.0 or later"
        )
    }
    
    // MARK: - EndpointSecurityError Tests
    
    func testEndpointSecurityErrorDescriptions() {
        let clientError = EndpointSecurityError.clientInitializationFailed(1)
        XCTAssertEqual(
            clientError.errorDescription,
            "Endpoint Security client initialization failed with result: 1"
        )
        
        let subscriptionError = EndpointSecurityError.subscriptionFailed(42)
        XCTAssertEqual(
            subscriptionError.errorDescription,
            "Failed to subscribe to event type: 42"
        )
        
        let fdaError = EndpointSecurityError.fullDiskAccessDenied
        XCTAssertNotNil(fdaError.errorDescription)
        XCTAssertTrue(fdaError.errorDescription!.contains("Full Disk Access"))
        
        let timeoutError = EndpointSecurityError.eventProcessingTimeout
        XCTAssertEqual(
            timeoutError.errorDescription,
            "Event processing exceeded timeout threshold"
        )
        
        let disconnectError = EndpointSecurityError.clientDisconnected
        XCTAssertEqual(
            disconnectError.errorDescription,
            "Endpoint Security client disconnected unexpectedly"
        )
    }
    
    // MARK: - NetworkExtensionError Tests
    
    func testNetworkExtensionErrorDescriptions() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let tunnelError = NetworkExtensionError.tunnelStartFailed(underlyingError)
        XCTAssertNotNil(tunnelError.errorDescription)
        XCTAssertTrue(tunnelError.errorDescription!.contains("Packet tunnel failed to start"))
        
        let configError = NetworkExtensionError.tunnelConfigurationInvalid
        XCTAssertEqual(
            configError.errorDescription,
            "Packet tunnel configuration is invalid"
        )
        
        let packetError = NetworkExtensionError.packetProcessingFailed
        XCTAssertEqual(
            packetError.errorDescription,
            "Packet processing failed"
        )
        
        let dnsError = NetworkExtensionError.dnsProxyBindFailed(port: 53)
        XCTAssertEqual(
            dnsError.errorDescription,
            "DNS proxy failed to bind to port 53"
        )
        
        let restoreError = NetworkExtensionError.networkSettingsRestoreFailed
        XCTAssertEqual(
            restoreError.errorDescription,
            "Failed to restore original network settings"
        )
    }
    
    // MARK: - VMError Tests
    
    func testVMErrorDescriptions() {
        let configError = VMError.configurationInvalid("Invalid CPU count")
        XCTAssertEqual(
            configError.errorDescription,
            "VM configuration is invalid: Invalid CPU count"
        )
        
        let resourceError = VMError.resourceAllocationFailed
        XCTAssertEqual(
            resourceError.errorDescription,
            "Failed to allocate resources for VM"
        )
        
        let underlyingError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Start failed"])
        let startError = VMError.vmStartFailed(underlyingError)
        XCTAssertNotNil(startError.errorDescription)
        XCTAssertTrue(startError.errorDescription!.contains("VM failed to start"))
        
        let crashError = VMError.vmCrashed(reason: "Out of memory")
        XCTAssertEqual(
            crashError.errorDescription,
            "VM crashed: Out of memory"
        )
        
        let snapshotError = VMError.snapshotFailed
        XCTAssertEqual(
            snapshotError.errorDescription,
            "VM snapshot operation failed"
        )
        
        let diskError = VMError.diskImageCorrupted
        XCTAssertEqual(
            diskError.errorDescription,
            "VM disk image is corrupted"
        )
    }
    
    // MARK: - ConfigurationError Tests
    
    func testConfigurationErrorDescriptions() {
        let url = URL(fileURLWithPath: "/tmp/config.json")
        let fileError = ConfigurationError.fileNotFound(url)
        XCTAssertEqual(
            fileError.errorDescription,
            "Configuration file not found at: /tmp/config.json"
        )
        
        let parseError = ConfigurationError.parseError(line: 42, message: "Unexpected token")
        XCTAssertEqual(
            parseError.errorDescription,
            "Configuration parse error at line 42: Unexpected token"
        )
        
        let validationError = ConfigurationError.validationFailed(["Error 1", "Error 2"])
        XCTAssertNotNil(validationError.errorDescription)
        XCTAssertTrue(validationError.errorDescription!.contains("Error 1"))
        XCTAssertTrue(validationError.errorDescription!.contains("Error 2"))
        
        let schemaError = ConfigurationError.schemaVersionMismatch
        XCTAssertEqual(
            schemaError.errorDescription,
            "Configuration schema version mismatch"
        )
    }
}
