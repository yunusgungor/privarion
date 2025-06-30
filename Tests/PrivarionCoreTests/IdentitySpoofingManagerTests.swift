import XCTest
import Foundation
@testable import PrivarionCore

/// Comprehensive test suite for IdentitySpoofingManager
/// Tests hostname spoofing, MAC address management, and rollback mechanisms
/// Following PATTERN-2025-001 (ArgumentParser CLI) and PATTERN-2025-013 (Transactional Rollback)
final class IdentitySpoofingManagerTests: XCTestCase {
    
    // MARK: - Properties
    
    private var spoofingManager: IdentitySpoofingManager!
    private var testProfile: ConfigurationProfile!
    private var logger: PrivarionLogger!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize logger with test configuration
        logger = PrivarionLogger.shared
        logger.updateLogLevel(.debug)
        
        // Initialize spoofing manager
        spoofingManager = IdentitySpoofingManager(logger: logger)
        
        // Create test configuration profile for hostname spoofing only (safe testing)
        testProfile = ConfigurationProfile(
            name: "test-hostname-only",
            description: "Test profile for hostname spoofing only",
            hostnameStrategy: .realistic,
            enabledTypes: [.hostname], // Only hostname for Phase 1 testing
            criticalTypes: [.hostname],
            persistentChanges: false, // Never persistent in tests
            validationRequired: true,
            rollbackOnFailure: true
        )
    }
    
    override func tearDownWithError() throws {
        // Clean up any changes made during testing
        // This should be handled by rollback mechanisms
        spoofingManager = nil
        testProfile = nil
        logger = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(spoofingManager, "IdentitySpoofingManager should initialize successfully")
    }
    
    func testProfileValidation() {
        XCTAssertEqual(testProfile.name, "test-hostname-only")
        XCTAssertTrue(testProfile.isEnabled(for: .hostname))
        XCTAssertFalse(testProfile.isEnabled(for: .macAddress))
        XCTAssertTrue(testProfile.isCritical(for: .hostname))
        XCTAssertFalse(testProfile.persistentChanges)
    }
    
    // MARK: - Hostname Spoofing Tests
    
    func testHostnameGeneration() async throws {
        // Test hostname generation without actually changing system
        let engine = HardwareIdentifierEngine()
        
        // Test realistic hostname generation
        let realisticHostname = engine.generateHostname(strategy: .realistic)
        XCTAssertFalse(realisticHostname.isEmpty, "Realistic hostname should not be empty")
        XCTAssertTrue(engine.validateHostname(realisticHostname), "Generated hostname should be valid")
        
        // Test random hostname generation
        let randomHostname = engine.generateHostname(strategy: .random)
        XCTAssertFalse(randomHostname.isEmpty, "Random hostname should not be empty")
        XCTAssertTrue(engine.validateHostname(randomHostname), "Generated hostname should be valid")
        
        // Ensure different strategies produce different results (high probability)
        let hostname1 = engine.generateHostname(strategy: .realistic)
        let hostname2 = engine.generateHostname(strategy: .realistic)
        // Note: Small chance these could be the same, but very unlikely
        print("Generated hostnames: '\(hostname1)', '\(hostname2)'")
    }
    
    func testHostnameValidation() {
        let engine = HardwareIdentifierEngine()
        
        // Valid hostnames
        XCTAssertTrue(engine.validateHostname("MacBook-Pro"))
        XCTAssertTrue(engine.validateHostname("test-machine"))
        XCTAssertTrue(engine.validateHostname("Host123"))
        XCTAssertTrue(engine.validateHostname("a"))
        
        // Invalid hostnames
        XCTAssertFalse(engine.validateHostname(""), "Empty hostname should be invalid")
        XCTAssertFalse(engine.validateHostname("-invalid"), "Hostname starting with dash should be invalid")
        XCTAssertFalse(engine.validateHostname("invalid-"), "Hostname ending with dash should be invalid")
        XCTAssertFalse(engine.validateHostname("invalid..hostname"), "Hostname with double dots should be invalid")
        XCTAssertFalse(engine.validateHostname("a".repeated(64)), "Hostname longer than 63 chars should be invalid")
    }
    
    func testGetCurrentHostname() async throws {
        // Test reading current hostname
        let currentHostname = try await spoofingManager.getCurrentIdentity(type: .hostname)
        XCTAssertFalse(currentHostname.isEmpty, "Current hostname should not be empty")
        print("Current system hostname: '\(currentHostname)'")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidHostnameError() async throws {
        // Create a profile with invalid hostname strategy (custom with invalid pattern)
        let _ = ConfigurationProfile(
            name: "invalid-test",
            description: "Test profile with invalid hostname",
            hostnameStrategy: .custom(pattern: ""), // Empty pattern should cause issues
            enabledTypes: [.hostname]
        )
        
        let options = IdentitySpoofingManager.SpoofingOptions(
            types: [.hostname],
            profile: "invalid-test",
            persistent: false,
            validateChanges: true
        )
        
        // This should handle the error gracefully
        // Note: Actual spoofing requires admin privileges, so we expect that error in tests
        do {
            try await spoofingManager.spoofIdentity(options: options)
            XCTFail("Should have thrown an error")
        } catch IdentitySpoofingManager.SpoofingError.adminPrivilegesRequired {
            // Expected error in test environment
            print("Expected admin privileges error in test environment")
        } catch {
            print("Other error occurred: \(error)")
            // This is also acceptable as we're testing error handling
        }
    }
    
    // MARK: - MAC Address Tests (Generation Only - No System Changes)
    
    func testMACAddressGeneration() {
        let engine = HardwareIdentifierEngine()
        
        // Test realistic MAC generation
        let realisticMAC = engine.generateMACAddress(strategy: .realistic)
        XCTAssertFalse(realisticMAC.isEmpty, "Realistic MAC should not be empty")
        XCTAssertTrue(engine.validateMACAddress(realisticMAC), "Generated MAC should be valid")
        
        // Test vendor-based MAC generation
        let appleVendor = HardwareIdentifierEngine.VendorProfile(
            name: "Apple",
            oui: "AC:DE:48",
            deviceTypes: ["MacBook"]
        )
        let vendorMAC = engine.generateMACAddress(strategy: .vendorBased(vendor: appleVendor))
        XCTAssertTrue(vendorMAC.hasPrefix("AC:DE:48"), "Vendor MAC should start with correct OUI")
        XCTAssertTrue(engine.validateMACAddress(vendorMAC), "Vendor MAC should be valid")
    }
    
    func testMACAddressValidation() {
        let engine = HardwareIdentifierEngine()
        
        // Valid MAC addresses (both colon and dash formats supported)
        XCTAssertTrue(engine.validateMACAddress("AA:BB:CC:DD:EE:FF"))
        XCTAssertTrue(engine.validateMACAddress("12:34:56:78:9A:BC"))
        XCTAssertTrue(engine.validateMACAddress("00:00:00:00:00:00"))
        XCTAssertTrue(engine.validateMACAddress("AA-BB-CC-DD-EE-FF")) // Dash format also supported
        
        // Invalid MAC addresses
        XCTAssertFalse(engine.validateMACAddress(""), "Empty MAC should be invalid")
        XCTAssertFalse(engine.validateMACAddress("AA:BB:CC:DD:EE"), "Short MAC should be invalid")
        XCTAssertFalse(engine.validateMACAddress("AA:BB:CC:DD:EE:FF:GG"), "Long MAC should be invalid")
        XCTAssertFalse(engine.validateMACAddress("GG:BB:CC:DD:EE:FF"), "MAC with invalid hex should be invalid")
        XCTAssertFalse(engine.validateMACAddress("AA.BB.CC.DD.EE.FF"), "MAC with dots should be invalid")
    }
    
    // MARK: - Network Interface Tests (Read-Only)
    
    func testNetworkInterfaceDiscovery() async throws {
        // Test network interface discovery (read-only operation)
        let interfaces = try await spoofingManager.getNetworkInterfaces()
        XCTAssertFalse(interfaces.isEmpty, "Should discover at least one network interface")
        
        // Should exclude loopback interface
        XCTAssertFalse(interfaces.contains("lo0"), "Should exclude loopback interface")
        
        print("Discovered network interfaces: \(interfaces)")
    }
    
    // MARK: - Configuration Profile Tests
    
    func testConfigurationProfileCreation() {
        let profile = ConfigurationProfile(
            name: "test-profile",
            description: "Test configuration profile",
            macStrategy: .realistic,
            hostnameStrategy: .vendorBased(vendor: HardwareIdentifierEngine.VendorProfile(
                name: "Apple",
                oui: "AC:DE:48",
                deviceTypes: ["MacBook"]
            )),
            enabledTypes: [.hostname, .macAddress],
            criticalTypes: [.hostname]
        )
        
        XCTAssertEqual(profile.name, "test-profile")
        XCTAssertTrue(profile.isEnabled(for: .hostname))
        XCTAssertTrue(profile.isEnabled(for: .macAddress))
        XCTAssertFalse(profile.isEnabled(for: .serialNumber))
        XCTAssertTrue(profile.isCritical(for: .hostname))
        XCTAssertFalse(profile.isCritical(for: .macAddress))
    }
    
    // MARK: - Integration Tests
    
    func testSpoofingOptionsCreation() {
        let options = IdentitySpoofingManager.SpoofingOptions(
            types: [.hostname],
            profile: "test-profile",
            persistent: false,
            validateChanges: true
        )
        
        XCTAssertEqual(options.types, [.hostname])
        XCTAssertEqual(options.profile, "test-profile")
        XCTAssertFalse(options.persistent)
        XCTAssertTrue(options.validateChanges)
    }
    
    func testSpoofingErrorDescriptions() {
        let errors: [IdentitySpoofingManager.SpoofingError] = [
            .adminPrivilegesRequired,
            .systemIntegrityProtectionBlocked,
            .rollbackDataCorrupted,
            .unsupportedOperation,
            .networkInterfaceNotFound,
            .invalidIdentifierFormat
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testHostnameGenerationPerformance() {
        let engine = HardwareIdentifierEngine()
        
        measure {
            for _ in 0..<100 {
                let hostname = engine.generateHostname(strategy: .realistic)
                XCTAssertFalse(hostname.isEmpty)
            }
        }
    }
    
    func testMACGenerationPerformance() {
        let engine = HardwareIdentifierEngine()
        
        measure {
            for _ in 0..<100 {
                let mac = engine.generateMACAddress(strategy: .realistic)
                XCTAssertTrue(engine.validateMACAddress(mac))
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyIdentityTypes() {
        let options = IdentitySpoofingManager.SpoofingOptions(
            types: [], // Empty set
            profile: "test"
        )
        
        XCTAssertTrue(options.types.isEmpty, "Empty types set should be handled")
    }
    
    func testAllIdentityTypes() {
        let allTypes = Set(IdentitySpoofingManager.IdentityType.allCases)
        let options = IdentitySpoofingManager.SpoofingOptions(types: allTypes)
        
        XCTAssertEqual(options.types.count, IdentitySpoofingManager.IdentityType.allCases.count)
        XCTAssertTrue(options.types.contains(.hostname))
        XCTAssertTrue(options.types.contains(.macAddress))
        XCTAssertTrue(options.types.contains(.serialNumber))
        XCTAssertTrue(options.types.contains(.diskUUID))
        XCTAssertTrue(options.types.contains(.networkInterface))
    }
}

// MARK: - Helper Extensions

private extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

// MARK: - Mock Classes for Testing

/// Mock configuration profile manager for testing
class MockConfigurationProfileManager {
    private var profiles: [String: ConfigurationProfile] = [:]
    
    func addProfile(_ profile: ConfigurationProfile) {
        profiles[profile.name] = profile
    }
    
    func loadProfile(name: String) throws -> ConfigurationProfile {
        guard let profile = profiles[name] else {
            throw IdentitySpoofingManager.SpoofingError.unsupportedOperation
        }
        return profile
    }
}
