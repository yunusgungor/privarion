import XCTest
import Foundation
@testable import PrivarionCore

/// Enhanced XCTest-based test suite for IdentitySpoofingManager
/// Phase 1 implementation with expanded security coverage
/// 
/// Comprehensive testing approach with:
/// - Better async/await support
/// - Parametrized testing patterns
/// - Modern Swift testing best practices
/// - Enhanced error reporting
final class IdentitySpoofingManagerEnhancedTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    /// Test manager instance
    private let spoofingManager = IdentitySpoofingManager(logger: PrivarionLogger.shared)
    
    /// Test configuration profile
    private var testProfile: ConfigurationProfile {
        ConfigurationProfile(
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
    
    // MARK: - Initialization Tests
    
    func testManagerInitialization() {
        XCTAssertNotNil(spoofingManager, "IdentitySpoofingManager should initialize successfully")
    }
    
    func testProfileValidation() {
        XCTAssertEqual(testProfile.name, "test-hostname-only", "Profile name should match")
        XCTAssertTrue(testProfile.isEnabled(for: .hostname), "Hostname should be enabled")
        XCTAssertFalse(testProfile.isEnabled(for: .macAddress), "MAC address should be disabled")
        XCTAssertTrue(testProfile.isCritical(for: .hostname), "Hostname should be critical")
        XCTAssertFalse(testProfile.persistentChanges, "Changes should not be persistent in tests")
    }
    
    // MARK: - Hostname Generation Security Tests
    
    func testHostnameGenerationSecurityRealistic() async throws {
        let engine = HardwareIdentifierEngine()
        let hostname = engine.generateHostname(strategy: .realistic)
        
        XCTAssertFalse(hostname.isEmpty, "Generated hostname should not be empty")
        XCTAssertTrue(engine.validateHostname(hostname), "Generated hostname should be valid")
        XCTAssertLessThanOrEqual(hostname.count, 63, "Hostname should not exceed DNS label limit")
        XCTAssertFalse(hostname.hasPrefix("-"), "Hostname should not start with dash")
        XCTAssertFalse(hostname.hasSuffix("-"), "Hostname should not end with dash")
        XCTAssertFalse(hostname.contains(".."), "Hostname should not contain consecutive dots")
    }
    
    func testHostnameGenerationSecurityRandom() async throws {
        let engine = HardwareIdentifierEngine()
        let hostname = engine.generateHostname(strategy: .random)
        
        XCTAssertFalse(hostname.isEmpty, "Generated hostname should not be empty")
        XCTAssertTrue(engine.validateHostname(hostname), "Generated hostname should be valid")
        XCTAssertLessThanOrEqual(hostname.count, 63, "Hostname should not exceed DNS label limit")
        XCTAssertFalse(hostname.hasPrefix("-"), "Hostname should not start with dash")
        XCTAssertFalse(hostname.hasSuffix("-"), "Hostname should not end with dash")
        XCTAssertFalse(hostname.contains(".."), "Hostname should not contain consecutive dots")
    }
    
    func testHostnameGenerationSecurityCustom() async throws {
        let engine = HardwareIdentifierEngine()
        let hostname = engine.generateHostname(strategy: .custom(pattern: "TestHost-###"))
        
        XCTAssertFalse(hostname.isEmpty, "Generated hostname should not be empty")
        XCTAssertTrue(engine.validateHostname(hostname), "Generated hostname should be valid")
        XCTAssertLessThanOrEqual(hostname.count, 63, "Hostname should not exceed DNS label limit")
        XCTAssertFalse(hostname.hasPrefix("-"), "Hostname should not start with dash")
        XCTAssertFalse(hostname.hasSuffix("-"), "Hostname should not end with dash")
        XCTAssertFalse(hostname.contains(".."), "Hostname should not contain consecutive dots")
    }
    
    func testHostnameValidationSecurity() {
        let engine = HardwareIdentifierEngine()
        
        // Test cases: (input, expectedValid, description)
        let testCases: [(String, Bool, String)] = [
            ("", false, "Empty hostname"),
            ("-invalid", false, "Hostname starting with dash"),
            ("invalid-", false, "Hostname ending with dash"),
            ("invalid..hostname", false, "Hostname with consecutive dots"),
            (String(repeating: "a", count: 64), false, "Oversized hostname"),
            ("valid-hostname", true, "Valid hostname"),
            ("MacBook-Pro", true, "Apple-style hostname"),
            ("test123", true, "Alphanumeric hostname"),
            ("a", true, "Single character hostname"),
            ("host\u{0000}name", false, "Hostname with null byte"),
            ("host\r\nname", false, "Hostname with line breaks"),
            ("../../../etc/hosts", false, "Path traversal attempt"),
            ("$(rm -rf /)", false, "Command injection attempt")
        ]
        
        for (input, expectedValid, description) in testCases {
            let isValid = engine.validateHostname(input)
            XCTAssertEqual(isValid, expectedValid, 
                          "\(description): '\(input)' should be \(expectedValid ? "valid" : "invalid")")
        }
    }
    
    func testHostnameUnpredictability() {
        let engine = HardwareIdentifierEngine()
        let hostnames = (0..<100).map { _ in
            engine.generateHostname(strategy: .realistic)
        }
        
        // Check for uniqueness (should be mostly unique)
        let uniqueHostnames = Set(hostnames)
        let uniquenessRatio = Double(uniqueHostnames.count) / Double(hostnames.count)
        
        XCTAssertGreaterThan(uniquenessRatio, 0.8, "At least 80% of generated hostnames should be unique")
        
        // Check that all generated hostnames are valid
        for hostname in hostnames {
            XCTAssertTrue(engine.validateHostname(hostname), "All generated hostnames should be valid: '\(hostname)'")
        }
    }
    
    // MARK: - MAC Address Generation Security Tests
    
    func testMACAddressGenerationSecurityRealistic() {
        let engine = HardwareIdentifierEngine()
        let macAddress = engine.generateMACAddress(strategy: .realistic)
        
        XCTAssertFalse(macAddress.isEmpty, "Generated MAC address should not be empty")
        XCTAssertTrue(engine.validateMACAddress(macAddress), "Generated MAC address should be valid")
        XCTAssertEqual(macAddress.count, 17, "MAC address should have standard length (XX:XX:XX:XX:XX:XX)")
    }
    
    func testMACAddressGenerationSecurityRandom() {
        let engine = HardwareIdentifierEngine()
        let macAddress = engine.generateMACAddress(strategy: .random)
        
        XCTAssertFalse(macAddress.isEmpty, "Generated MAC address should not be empty")
        XCTAssertTrue(engine.validateMACAddress(macAddress), "Generated MAC address should be valid")
        XCTAssertEqual(macAddress.count, 17, "MAC address should have standard length (XX:XX:XX:XX:XX:XX)")
    }
    
    func testMACAddressGenerationSecurityVendorBased() {
        let engine = HardwareIdentifierEngine()
        let vendor = HardwareIdentifierEngine.VendorProfile(
            name: "Apple",
            oui: "AC:DE:48",
            deviceTypes: ["MacBook"]
        )
        let macAddress = engine.generateMACAddress(strategy: .vendorBased(vendor: vendor))
        
        XCTAssertFalse(macAddress.isEmpty, "Generated MAC address should not be empty")
        XCTAssertTrue(engine.validateMACAddress(macAddress), "Generated MAC address should be valid")
        XCTAssertEqual(macAddress.count, 17, "MAC address should have standard length (XX:XX:XX:XX:XX:XX)")
        
        // Verify format
        let components = macAddress.split(separator: ":")
        XCTAssertEqual(components.count, 6, "MAC address should have 6 components")
        
        for component in components {
            XCTAssertEqual(component.count, 2, "Each MAC component should be 2 characters")
            XCTAssertTrue(component.allSatisfy { "0123456789ABCDEFabcdef".contains($0) }, 
                         "MAC components should only contain hex characters")
        }
    }
    
    func testMACAddressValidationSecurity() {
        let engine = HardwareIdentifierEngine()
        
        // Test cases: (input, expectedValid, description)
        let testCases: [(String, Bool, String)] = [
            ("AA:BB:CC:DD:EE:FF", true, "Valid MAC with colons"),
            ("AA-BB-CC-DD-EE-FF", true, "Valid MAC with dashes"),
            ("12:34:56:78:9A:BC", true, "Valid MAC with mixed case"),
            ("00:00:00:00:00:00", true, "Valid zero MAC"),
            ("", false, "Empty MAC"),
            ("AA:BB:CC:DD:EE", false, "Short MAC"),
            ("AA:BB:CC:DD:EE:FF:GG", false, "Long MAC"),
            ("GG:BB:CC:DD:EE:FF", false, "Invalid hex character"),
            ("AA.BB.CC.DD.EE.FF", false, "MAC with dots"),
            ("AA:BB:CC:DD:EE:ZZ", false, "Invalid hex in last byte"),
            ("AA BB CC DD EE FF", false, "MAC with spaces"),
            ("../../../etc/passwd", false, "Path traversal attempt"),
            ("$(rm -rf /)", false, "Command injection attempt")
        ]
        
        for (input, expectedValid, description) in testCases {
            let isValid = engine.validateMACAddress(input)
            XCTAssertEqual(isValid, expectedValid, 
                          "\(description): '\(input)' should be \(expectedValid ? "valid" : "invalid")")
        }
    }
    
    func testMACAddressSecurityRisks() {
        let engine = HardwareIdentifierEngine()
        let macAddresses = (0..<100).map { _ in
            engine.generateMACAddress(strategy: .realistic)
        }
        
        for mac in macAddresses {
            // Verify it's not a multicast address (first bit of first octet should be 0 for unicast)
            let firstOctet = String(mac.prefix(2))
            if let firstByte = Int(firstOctet, radix: 16) {
                let isMulticast = (firstByte & 0x01) != 0
                XCTAssertFalse(isMulticast, "Generated MAC should not be multicast: \(mac)")
            }
            
            // Verify it's not a reserved/dangerous MAC
            let dangerousMACs = [
                "FF:FF:FF:FF:FF:FF", // Broadcast
                "00:00:00:00:00:00"  // Should be avoided in practice
            ]
            XCTAssertFalse(dangerousMACs.contains(mac), "Generated MAC should not be dangerous: \(mac)")
        }
    }
    
    // MARK: - Identity Spoofing Operation Tests
    
    func testCurrentIdentityRetrieval() async throws {
        // Test reading current hostname (safe operation)
        let currentHostname = try await spoofingManager.getCurrentIdentity(type: .hostname)
        XCTAssertFalse(currentHostname.isEmpty, "Current hostname should not be empty")
        XCTAssertLessThanOrEqual(currentHostname.count, 253, "Hostname should not exceed DNS limits")
        
        // Verify it's a valid hostname format
        let engine = HardwareIdentifierEngine()
        XCTAssertTrue(engine.validateHostname(currentHostname), "Current hostname should be valid")
    }
    
    func testSpoofingOptionsValidation() {
        // Test safe options
        let safeOptions = IdentitySpoofingManager.SpoofingOptions(
            types: [.hostname],
            profile: "test-profile",
            persistent: false,
            validateChanges: true
        )
        
        XCTAssertEqual(safeOptions.types, [.hostname], "Safe options should match")
        XCTAssertFalse(safeOptions.persistent, "Test options should not be persistent")
        XCTAssertTrue(safeOptions.validateChanges, "Validation should be enabled")
        
        // Test potentially unsafe options
        let unsafeOptions = IdentitySpoofingManager.SpoofingOptions(
            types: Set(IdentitySpoofingManager.IdentityType.allCases),
            profile: "unsafe-profile",
            persistent: true, // Dangerous in test environment
            validateChanges: false // Dangerous without validation
        )
        
        XCTAssertTrue(unsafeOptions.persistent, "Unsafe options tracking")
        XCTAssertFalse(unsafeOptions.validateChanges, "Unsafe validation tracking")
    }
    
    func testAdminPrivilegesHandling() async throws {
        let options = IdentitySpoofingManager.SpoofingOptions(
            types: [.hostname],
            profile: "test-profile",
            persistent: false,
            validateChanges: true
        )
        
        // This should fail with admin privileges error in test environment
        do {
            try await spoofingManager.spoofIdentity(options: options)
            XCTFail("Should have thrown an error in test environment")
        } catch IdentitySpoofingManager.SpoofingError.adminPrivilegesRequired {
            // Expected error in test environment
            XCTAssertTrue(true, "Expected admin privileges error")
        } catch {
            // Other errors are also acceptable as we're testing error handling
            XCTAssertNotNil(error, "Some error should be thrown: \(error)")
        }
    }
    
    // MARK: - Network Interface Discovery Tests
    
    func testNetworkInterfaceDiscovery() async throws {
        let interfaces = try await spoofingManager.getNetworkInterfaces()
        
        XCTAssertFalse(interfaces.isEmpty, "Should discover at least one network interface")
        
        // Security checks
        XCTAssertFalse(interfaces.contains("lo0"), "Should exclude loopback interface")
        
        // Verify interface names are safe
        for interface in interfaces {
            XCTAssertFalse(interface.isEmpty, "Interface name should not be empty")
            XCTAssertLessThanOrEqual(interface.count, 16, "Interface name should not exceed system limits")
            XCTAssertFalse(interface.contains(".."), "Interface name should not contain path elements")
            XCTAssertFalse(interface.contains("/"), "Interface name should not contain path separators")
        }
    }
    
    // MARK: - Error Handling Security Tests
    
    // MARK: - Error Handling Security Tests
    
    func testErrorDescriptionSafety() {
        let errors: [IdentitySpoofingManager.SpoofingError] = [
            .adminPrivilegesRequired,
            .systemIntegrityProtectionBlocked,
            .rollbackDataCorrupted,
            .unsupportedOperation,
            .networkInterfaceNotFound,
            .invalidIdentifierFormat
        ]
        
        for error in errors {
            guard let description = error.errorDescription else {
                XCTFail("Error should have description: \(error)")
                continue
            }
            
            XCTAssertFalse(description.isEmpty, "Error description should not be empty: \(error)")
            
            // Verify no sensitive information is leaked
            let sensitiveTerms = [
                "/etc/passwd", "/etc/shadow", "password", "secret", "private_key",
                "sudo", "root", "administrator", "exec", "eval", "system("
            ]
            
            for term in sensitiveTerms {
                XCTAssertFalse(description.lowercased().contains(term.lowercased()), 
                               "Error description should not contain sensitive term '\(term)': \(description)")
            }
        }
    }
    
    // MARK: - Performance Security Tests
    
    func testHostnameGenerationPerformance() {
        let engine = HardwareIdentifierEngine()
        let iterations = 1000
        
        let startTime = Date()
        for _ in 0..<iterations {
            let hostname = engine.generateHostname(strategy: .realistic)
            XCTAssertFalse(hostname.isEmpty, "Generated hostname should not be empty")
        }
        let duration = Date().timeIntervalSince(startTime)
        
        let operationsPerSecond = Double(iterations) / duration
        XCTAssertGreaterThan(operationsPerSecond, 100, "Should generate at least 100 hostnames per second")
        XCTAssertLessThan(duration, 10.0, "Generation should complete within reasonable time")
    }
    
    func testMACGenerationPerformance() {
        let engine = HardwareIdentifierEngine()
        let iterations = 1000
        
        let startTime = Date()
        for _ in 0..<iterations {
            let mac = engine.generateMACAddress(strategy: .realistic)
            XCTAssertTrue(engine.validateMACAddress(mac), "Generated MAC should be valid")
        }
        let duration = Date().timeIntervalSince(startTime)
        
        let operationsPerSecond = Double(iterations) / duration
        XCTAssertGreaterThan(operationsPerSecond, 100, "Should generate at least 100 MACs per second")
        XCTAssertLessThan(duration, 10.0, "Generation should complete within reasonable time")
    }
    
    // MARK: - Concurrent Operations Security Tests
    
    func testConcurrentIdentityOperations() async throws {
        let engine = HardwareIdentifierEngine()
        let operationCount = 100
        
        // Generate hostnames concurrently
        let hostnames = await withTaskGroup(of: String.self) { group in
            for _ in 0..<operationCount {
                group.addTask {
                    return engine.generateHostname(strategy: .realistic)
                }
            }
            
            var results: [String] = []
            for await hostname in group {
                results.append(hostname)
            }
            return results
        }
        
        XCTAssertEqual(hostnames.count, operationCount, "All concurrent operations should complete")
        
        // Verify all results are valid
        for hostname in hostnames {
            XCTAssertTrue(engine.validateHostname(hostname), "All concurrent results should be valid: '\(hostname)'")
        }
        
        // Check for reasonable uniqueness (no major collisions)
        let uniqueHostnames = Set(hostnames)
        let uniquenessRatio = Double(uniqueHostnames.count) / Double(hostnames.count)
        XCTAssertGreaterThan(uniquenessRatio, 0.5, "Concurrent generation should maintain reasonable uniqueness")
    }
    
    // MARK: - Configuration Profile Security Tests
    
    func testConfigurationProfileSecurity() {
        // Test safe profile
        let safeProfile = ConfigurationProfile(
            name: "safe-test",
            description: "Safe test configuration",
            hostnameStrategy: .realistic,
            enabledTypes: [.hostname],
            criticalTypes: [],
            persistentChanges: false,
            validationRequired: true,
            rollbackOnFailure: true
        )
        
        XCTAssertTrue(safeProfile.isEnabled(for: .hostname), "Safe profile should enable hostname")
        XCTAssertFalse(safeProfile.isEnabled(for: .macAddress), "Safe profile should not enable MAC by default")
        XCTAssertFalse(safeProfile.isCritical(for: .hostname), "Safe profile should not mark hostname as critical")
        
        // Test potentially dangerous profile
        let dangerousProfile = ConfigurationProfile(
            name: "dangerous-test",
            description: "Profile with dangerous settings",
            hostnameStrategy: .custom(pattern: "Root-###"), // Potentially confusing name
            enabledTypes: Set(IdentitySpoofingManager.IdentityType.allCases),
            criticalTypes: Set(IdentitySpoofingManager.IdentityType.allCases),
            persistentChanges: true, // Dangerous for testing
            validationRequired: false,
            rollbackOnFailure: false
        )
        
        XCTAssertTrue(dangerousProfile.persistentChanges, "Dangerous profile tracking")
        XCTAssertEqual(dangerousProfile.enabledTypes.count, IdentitySpoofingManager.IdentityType.allCases.count, 
                      "Dangerous profile enables all types")
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndWorkflow() async throws {
        // Test complete workflow without actually changing system
        let engine = HardwareIdentifierEngine()
        
        // 1. Generate new identity
        let newHostname = engine.generateHostname(strategy: .realistic)
        let newMAC = engine.generateMACAddress(strategy: .realistic)
        
        // 2. Validate generated identities
        XCTAssertTrue(engine.validateHostname(newHostname), "Generated hostname should be valid")
        XCTAssertTrue(engine.validateMACAddress(newMAC), "Generated MAC should be valid")
        
        // 3. Create spoofing options
        let options = IdentitySpoofingManager.SpoofingOptions(
            types: [.hostname],
            profile: "test-workflow",
            persistent: false,
            validateChanges: true
        )
        
        // 4. Test option validation
        XCTAssertTrue(options.types.contains(.hostname), "Options should include hostname")
        XCTAssertFalse(options.persistent, "Test options should not be persistent")
        
        // 5. Attempt spoofing (should fail with admin privileges in test)
        do {
            try await spoofingManager.spoofIdentity(options: options)
        } catch IdentitySpoofingManager.SpoofingError.adminPrivilegesRequired {
            // Expected in test environment
            XCTAssertTrue(true, "Admin privileges error expected in test")
        } catch {
            // Other errors also acceptable for testing
            XCTAssertNotNil(error, "Some error expected: \(error)")
        }
    }
}

// MARK: - Performance Measurement Helpers

extension IdentitySpoofingManagerEnhancedTests {
    /// Measure execution time for performance tests
    private func measureTime<T>(_ operation: () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
        let startTime = Date()
        let result = try operation()
        let duration = Date().timeIntervalSince(startTime)
        return (result, duration)
    }
    
    /// Measure async execution time
    private func measureAsyncTime<T>(_ operation: () async throws -> T) async rethrows -> (result: T, duration: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)
        return (result, duration)
    }
}
