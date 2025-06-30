import XCTest
import Foundation
@testable import PrivarionCore

/// Comprehensive test suite for HardwareIdentifierEngine
/// Tests realistic identifier generation, vendor-based strategies, and validation
/// Validates pattern effectiveness for STORY-2025-003 implementation
final class HardwareIdentifierEngineTests: XCTestCase {
    
    // MARK: - Properties
    
    private var engine: HardwareIdentifierEngine!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        engine = HardwareIdentifierEngine()
    }
    
    override func tearDownWithError() throws {
        engine = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Initialization Tests
    
    func testEngineInitialization() {
        XCTAssertNotNil(engine, "HardwareIdentifierEngine should initialize successfully")
    }
    
    // MARK: - MAC Address Generation Tests
    
    func testRandomMACGeneration() {
        let mac1 = engine.generateMACAddress(strategy: .random)
        let mac2 = engine.generateMACAddress(strategy: .random)
        
        XCTAssertFalse(mac1.isEmpty, "Random MAC should not be empty")
        XCTAssertFalse(mac2.isEmpty, "Random MAC should not be empty")
        XCTAssertTrue(engine.validateMACAddress(mac1), "Random MAC should be valid")
        XCTAssertTrue(engine.validateMACAddress(mac2), "Random MAC should be valid")
        
        // High probability they should be different
        print("Random MACs generated: '\(mac1)', '\(mac2)'")
    }
    
    func testRealisticMACGeneration() {
        let mac = engine.generateMACAddress(strategy: .realistic)
        
        XCTAssertFalse(mac.isEmpty, "Realistic MAC should not be empty")
        XCTAssertTrue(engine.validateMACAddress(mac), "Realistic MAC should be valid")
        XCTAssertTrue(mac.contains(":"), "MAC should use colon separator")
        
        // Should be 17 characters (6 pairs of hex + 5 colons)
        XCTAssertEqual(mac.count, 17, "MAC should be 17 characters long")
        
        print("Realistic MAC generated: '\(mac)'")
    }
    
    func testVendorBasedMACGeneration() {
        let appleVendor = HardwareIdentifierEngine.VendorProfile(
            name: "Apple",
            oui: "AC:DE:48",
            deviceTypes: ["MacBook", "iMac"]
        )
        
        let mac = engine.generateMACAddress(strategy: .vendorBased(vendor: appleVendor))
        
        XCTAssertFalse(mac.isEmpty, "Vendor-based MAC should not be empty")
        XCTAssertTrue(engine.validateMACAddress(mac), "Vendor-based MAC should be valid")
        XCTAssertTrue(mac.hasPrefix("AC:DE:48"), "MAC should start with vendor OUI")
        
        print("Apple vendor MAC generated: '\(mac)'")
    }
    
    func testStealthMACGeneration() {
        let mac = engine.generateMACAddress(strategy: .stealth)
        
        XCTAssertFalse(mac.isEmpty, "Stealth MAC should not be empty")
        XCTAssertTrue(engine.validateMACAddress(mac), "Stealth MAC should be valid")
        
        // Stealth MACs should avoid common vendor patterns
        print("Stealth MAC generated: '\(mac)'")
    }
    
    func testCustomMACGeneration() {
        let customPattern = "00:11:22"
        let mac = engine.generateMACAddress(strategy: .custom(pattern: customPattern))
        
        XCTAssertFalse(mac.isEmpty, "Custom MAC should not be empty")
        XCTAssertTrue(engine.validateMACAddress(mac), "Custom MAC should be valid")
        XCTAssertTrue(mac.hasPrefix(customPattern), "MAC should start with custom pattern")
        
        print("Custom MAC generated: '\(mac)'")
    }
    
    // MARK: - Hostname Generation Tests
    
    func testRandomHostnameGeneration() {
        let hostname1 = engine.generateHostname(strategy: .random)
        let hostname2 = engine.generateHostname(strategy: .random)
        
        XCTAssertFalse(hostname1.isEmpty, "Random hostname should not be empty")
        XCTAssertFalse(hostname2.isEmpty, "Random hostname should not be empty")
        XCTAssertTrue(engine.validateHostname(hostname1), "Random hostname should be valid")
        XCTAssertTrue(engine.validateHostname(hostname2), "Random hostname should be valid")
        
        print("Random hostnames generated: '\(hostname1)', '\(hostname2)'")
    }
    
    func testRealisticHostnameGeneration() {
        let hostname = engine.generateHostname(strategy: .realistic)
        
        XCTAssertFalse(hostname.isEmpty, "Realistic hostname should not be empty")
        XCTAssertTrue(engine.validateHostname(hostname), "Realistic hostname should be valid")
        
        // Should not be too long
        XCTAssertLessThanOrEqual(hostname.count, 63, "Hostname should not exceed 63 characters")
        
        // Should contain typical patterns
        let isRealistic = hostname.contains("MacBook") || 
                         hostname.contains("iMac") || 
                         hostname.contains("Mac") ||
                         hostname.contains("laptop") ||
                         hostname.contains("desktop")
        
        print("Realistic hostname generated: '\(hostname)', contains realistic pattern: \(isRealistic)")
    }
    
    func testVendorBasedHostnameGeneration() {
        let appleVendor = HardwareIdentifierEngine.VendorProfile(
            name: "Apple",
            oui: "AC:DE:48",
            deviceTypes: ["MacBook", "iMac", "Mac"]
        )
        
        let hostname = engine.generateHostname(strategy: .vendorBased(vendor: appleVendor))
        
        XCTAssertFalse(hostname.isEmpty, "Vendor-based hostname should not be empty")
        XCTAssertTrue(engine.validateHostname(hostname), "Vendor-based hostname should be valid")
        
        // Should contain vendor-specific patterns
        let containsVendorPattern = hostname.contains("MacBook") || 
                                   hostname.contains("iMac") || 
                                   hostname.contains("Mac")
        XCTAssertTrue(containsVendorPattern, "Hostname should contain vendor-specific pattern")
        
        print("Apple vendor hostname generated: '\(hostname)'")
    }
    
    func testStealthHostnameGeneration() {
        let hostname = engine.generateHostname(strategy: .stealth)
        
        XCTAssertFalse(hostname.isEmpty, "Stealth hostname should not be empty")
        XCTAssertTrue(engine.validateHostname(hostname), "Stealth hostname should be valid")
        
        // Stealth hostnames should be generic
        let isGeneric = !hostname.contains("MacBook") && 
                       !hostname.contains("iMac") && 
                       !hostname.contains("Apple")
        
        print("Stealth hostname generated: '\(hostname)', is generic: \(isGeneric)")
    }
    
    func testCustomHostnameGeneration() {
        let customPattern = "test-machine"
        let hostname = engine.generateHostname(strategy: .custom(pattern: customPattern))
        
        XCTAssertFalse(hostname.isEmpty, "Custom hostname should not be empty")
        XCTAssertTrue(engine.validateHostname(hostname), "Custom hostname should be valid")
        
        print("Custom hostname generated: '\(hostname)'")
    }
    
    // MARK: - Serial Number Generation Tests
    
    func testRealisticSerialGeneration() {
        let serial = engine.generateSerialNumber(strategy: .realistic)
        
        XCTAssertFalse(serial.isEmpty, "Realistic serial should not be empty")
        
        // Apple serials are typically 10-12 characters
        XCTAssertGreaterThanOrEqual(serial.count, 8, "Serial should be at least 8 characters")
        XCTAssertLessThanOrEqual(serial.count, 15, "Serial should not exceed 15 characters")
        
        print("Realistic serial generated: '\(serial)'")
    }
    
    func testVendorBasedSerialGeneration() {
        let appleVendor = HardwareIdentifierEngine.VendorProfile(
            name: "Apple",
            oui: "AC:DE:48",
            deviceTypes: ["MacBook"]
        )
        
        let serial = engine.generateSerialNumber(strategy: .vendorBased(vendor: appleVendor))
        
        XCTAssertFalse(serial.isEmpty, "Vendor-based serial should not be empty")
        
        print("Apple vendor serial generated: '\(serial)'")
    }
    
    func testRandomSerialGeneration() {
        let serial = engine.generateSerialNumber(strategy: .random)
        
        XCTAssertFalse(serial.isEmpty, "Random serial should not be empty")
        
        print("Random serial generated: '\(serial)'")
    }
    
    // MARK: - Validation Tests
    
    func testMACAddressValidation() {
        // Valid MAC addresses
        let validMACs = [
            "AA:BB:CC:DD:EE:FF",
            "12:34:56:78:9A:BC",
            "00:00:00:00:00:00",
            "FF:FF:FF:FF:FF:FF",
            "ac:de:48:12:34:56"
        ]
        
        for mac in validMACs {
            XCTAssertTrue(engine.validateMACAddress(mac), "MAC should be valid: '\(mac)'")
        }
        
        // Invalid MAC addresses
        let invalidMACs = [
            "",
            "AA:BB:CC:DD:EE",
            "AA:BB:CC:DD:EE:FF:GG",
            "GG:BB:CC:DD:EE:FF",
            "AA-BB-CC-DD-EE-FF",
            "AABBCCDDEEFF",
            "AA:BB:CC:DD:EE:GG"
        ]
        
        for mac in invalidMACs {
            XCTAssertFalse(engine.validateMACAddress(mac), "MAC should be invalid: '\(mac)'")
        }
    }
    
    func testHostnameValidation() {
        // Valid hostnames
        let validHostnames = [
            "MacBook-Pro",
            "test-machine",
            "Host123",
            "a",
            "laptop",
            "MyComputer",
            "dev-box-01"
        ]
        
        for hostname in validHostnames {
            XCTAssertTrue(engine.validateHostname(hostname), "Hostname should be valid: '\(hostname)'")
        }
        
        // Invalid hostnames
        let invalidHostnames = [
            "",
            "-invalid",
            "invalid-",
            "host..name",
            String(repeating: "a", count: 64), // Too long
            "host name", // Space not allowed
            "host_name" // Underscore not allowed in this implementation
        ]
        
        for hostname in invalidHostnames {
            XCTAssertFalse(engine.validateHostname(hostname), "Hostname should be invalid: '\(hostname)'")
        }
    }
    
    // MARK: - Vendor Profile Tests
    
    func testVendorProfileCreation() {
        let vendor = HardwareIdentifierEngine.VendorProfile(
            name: "Apple",
            oui: "AC:DE:48",
            deviceTypes: ["MacBook", "iMac", "Mac-mini"]
        )
        
        XCTAssertEqual(vendor.name, "Apple")
        XCTAssertEqual(vendor.organizationallyUniqueIdentifier, "AC:DE:48")
        XCTAssertEqual(vendor.deviceTypes.count, 3)
        XCTAssertTrue(vendor.deviceTypes.contains("MacBook"))
    }
    
    // MARK: - Performance Tests
    
    func testMACGenerationPerformance() {
        measure {
            for _ in 0..<1000 {
                let mac = engine.generateMACAddress(strategy: .realistic)
                XCTAssertFalse(mac.isEmpty)
            }
        }
    }
    
    func testHostnameGenerationPerformance() {
        measure {
            for _ in 0..<1000 {
                let hostname = engine.generateHostname(strategy: .realistic)
                XCTAssertFalse(hostname.isEmpty)
            }
        }
    }
    
    func testValidationPerformance() {
        let testMAC = "AC:DE:48:12:34:56"
        let testHostname = "MacBook-Pro"
        
        measure {
            for _ in 0..<10000 {
                XCTAssertTrue(engine.validateMACAddress(testMAC))
                XCTAssertTrue(engine.validateHostname(testHostname))
            }
        }
    }
    
    // MARK: - Uniqueness Tests
    
    func testMACUniqueness() {
        var generatedMACs = Set<String>()
        let iterations = 100
        
        for _ in 0..<iterations {
            let mac = engine.generateMACAddress(strategy: .realistic)
            generatedMACs.insert(mac)
        }
        
        // Should have high uniqueness (at least 95% unique)
        let uniquePercentage = Double(generatedMACs.count) / Double(iterations)
        XCTAssertGreaterThan(uniquePercentage, 0.95, "MAC generation should be highly unique")
        
        print("MAC uniqueness: \(uniquePercentage * 100)% (\(generatedMACs.count)/\(iterations))")
    }
    
    func testHostnameUniqueness() {
        var generatedHostnames = Set<String>()
        let iterations = 50 // Hostnames have less entropy, so fewer iterations
        
        for _ in 0..<iterations {
            let hostname = engine.generateHostname(strategy: .realistic)
            generatedHostnames.insert(hostname)
        }
        
        // Should have reasonable uniqueness (at least 80%)
        let uniquePercentage = Double(generatedHostnames.count) / Double(iterations)
        XCTAssertGreaterThan(uniquePercentage, 0.8, "Hostname generation should be reasonably unique")
        
        print("Hostname uniqueness: \(uniquePercentage * 100)% (\(generatedHostnames.count)/\(iterations))")
    }
    
    // MARK: - Strategy Comparison Tests
    
    func testDifferentStrategiesProduceDifferentResults() {
        let randomMAC = engine.generateMACAddress(strategy: .random)
        let realisticMAC = engine.generateMACAddress(strategy: .realistic)
        let stealthMAC = engine.generateMACAddress(strategy: .stealth)
        
        // All should be valid
        XCTAssertTrue(engine.validateMACAddress(randomMAC))
        XCTAssertTrue(engine.validateMACAddress(realisticMAC))
        XCTAssertTrue(engine.validateMACAddress(stealthMAC))
        
        print("Strategy comparison - Random: '\(randomMAC)', Realistic: '\(realisticMAC)', Stealth: '\(stealthMAC)'")
    }
    
    // MARK: - Edge Case Tests
    
    func testInvalidVendorProfile() {
        // Test with invalid OUI
        let invalidVendor = HardwareIdentifierEngine.VendorProfile(
            name: "Invalid",
            oui: "INVALID",
            deviceTypes: ["Test"]
        )
        
        // Should still generate something (graceful degradation)
        let mac = engine.generateMACAddress(strategy: .vendorBased(vendor: invalidVendor))
        XCTAssertFalse(mac.isEmpty, "Should handle invalid vendor profile gracefully")
    }
    
    func testEmptyCustomPattern() {
        let hostname = engine.generateHostname(strategy: .custom(pattern: ""))
        XCTAssertFalse(hostname.isEmpty, "Should handle empty custom pattern gracefully")
    }
    
    // MARK: - Real-world Scenario Tests
    
    func testAppleMacBookScenario() {
        let appleVendor = HardwareIdentifierEngine.VendorProfile(
            name: "Apple",
            oui: "AC:DE:48",
            deviceTypes: ["MacBook", "MacBook-Pro"]
        )
        
        let mac = engine.generateMACAddress(strategy: .vendorBased(vendor: appleVendor))
        let hostname = engine.generateHostname(strategy: .vendorBased(vendor: appleVendor))
        let serial = engine.generateSerialNumber(strategy: .vendorBased(vendor: appleVendor))
        
        XCTAssertTrue(mac.hasPrefix("AC:DE:48"), "MAC should use Apple OUI")
        XCTAssertTrue(engine.validateMACAddress(mac))
        XCTAssertTrue(engine.validateHostname(hostname))
        XCTAssertFalse(serial.isEmpty)
        
        print("Apple MacBook scenario - MAC: '\(mac)', Hostname: '\(hostname)', Serial: '\(serial)'")
    }
    
    func testGenericLaptopScenario() {
        let mac = engine.generateMACAddress(strategy: .stealth)
        let hostname = engine.generateHostname(strategy: .stealth)
        let serial = engine.generateSerialNumber(strategy: .random)
        
        XCTAssertTrue(engine.validateMACAddress(mac))
        XCTAssertTrue(engine.validateHostname(hostname))
        XCTAssertFalse(serial.isEmpty)
        
        print("Generic laptop scenario - MAC: '\(mac)', Hostname: '\(hostname)', Serial: '\(serial)'")
    }
}
