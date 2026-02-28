// PrivarionSharedModelsTests - Hardware Profile Validation Tests
// Unit tests for hardware profile validation logic
// Requirements: 20.1

import XCTest
@testable import PrivarionSharedModels

final class HardwareProfileValidationTests: XCTestCase {
    
    // MARK: - Valid Profile Tests
    
    func testValidHardwareProfile() throws {
        let profile = HardwareProfile(
            name: "MacBook Pro 2021",
            hardwareModel: Data([0x01, 0x02, 0x03]),
            machineIdentifier: Data([0x04, 0x05, 0x06]),
            macAddress: "00:11:22:33:44:55",
            serialNumber: "C02ABC123DEF"
        )
        
        XCTAssertNoThrow(try profile.validate())
    }
    
    func testValidMACAddressFormats() throws {
        let validMACAddresses = [
            "00:11:22:33:44:55",
            "AA:BB:CC:DD:EE:FF",
            "a1:b2:c3:d4:e5:f6",
            "00:00:00:00:00:00",
            "FF:FF:FF:FF:FF:FF"
        ]
        
        for macAddress in validMACAddresses {
            let profile = HardwareProfile(
                name: "Test",
                hardwareModel: Data([0x01]),
                machineIdentifier: Data([0x02]),
                macAddress: macAddress,
                serialNumber: "TEST123"
            )
            
            XCTAssertNoThrow(try profile.validate(), "MAC address \(macAddress) should be valid")
        }
    }
    
    // MARK: - Invalid MAC Address Tests
    
    func testInvalidMACAddressFormat() {
        let invalidMACAddresses = [
            "00:11:22:33:44",        // Too short
            "00:11:22:33:44:55:66",  // Too long
            "00-11-22-33-44-55",     // Wrong separator
            "00:11:22:33:44:GG",     // Invalid hex
            "0011223344",            // No separators
            "",                      // Empty
            "invalid"                // Completely invalid
        ]
        
        for macAddress in invalidMACAddresses {
            let profile = HardwareProfile(
                name: "Test",
                hardwareModel: Data([0x01]),
                machineIdentifier: Data([0x02]),
                macAddress: macAddress,
                serialNumber: "TEST123"
            )
            
            XCTAssertThrowsError(try profile.validate(), "MAC address \(macAddress) should be invalid") { error in
                guard case ConfigurationError.validationFailed(let errors) = error else {
                    XCTFail("Expected ConfigurationError.validationFailed")
                    return
                }
                XCTAssertTrue(errors.first?.contains("Invalid MAC address") ?? false)
            }
        }
    }
    
    // MARK: - Empty Field Tests
    
    func testEmptySerialNumber() {
        let profile = HardwareProfile(
            name: "Test",
            hardwareModel: Data([0x01]),
            machineIdentifier: Data([0x02]),
            macAddress: "00:11:22:33:44:55",
            serialNumber: ""
        )
        
        XCTAssertThrowsError(try profile.validate()) { error in
            guard case ConfigurationError.validationFailed(let errors) = error else {
                XCTFail("Expected ConfigurationError.validationFailed")
                return
            }
            XCTAssertTrue(errors.first?.contains("Serial number cannot be empty") ?? false)
        }
    }
    
    func testEmptyHardwareModel() {
        let profile = HardwareProfile(
            name: "Test",
            hardwareModel: Data(),
            machineIdentifier: Data([0x02]),
            macAddress: "00:11:22:33:44:55",
            serialNumber: "TEST123"
        )
        
        XCTAssertThrowsError(try profile.validate()) { error in
            guard case ConfigurationError.validationFailed(let errors) = error else {
                XCTFail("Expected ConfigurationError.validationFailed")
                return
            }
            XCTAssertTrue(errors.first?.contains("Hardware model data cannot be empty") ?? false)
        }
    }
    
    func testEmptyMachineIdentifier() {
        let profile = HardwareProfile(
            name: "Test",
            hardwareModel: Data([0x01]),
            machineIdentifier: Data(),
            macAddress: "00:11:22:33:44:55",
            serialNumber: "TEST123"
        )
        
        XCTAssertThrowsError(try profile.validate()) { error in
            guard case ConfigurationError.validationFailed(let errors) = error else {
                XCTFail("Expected ConfigurationError.validationFailed")
                return
            }
            XCTAssertTrue(errors.first?.contains("Machine identifier data cannot be empty") ?? false)
        }
    }
    
    // MARK: - HardwareProfileProtocol Conformance Tests
    
    func testHardwareProfileProtocolConformance() {
        let profile = HardwareProfile(
            name: "Test Profile",
            hardwareModel: Data([0x01, 0x02]),
            machineIdentifier: Data([0x03, 0x04]),
            macAddress: "AA:BB:CC:DD:EE:FF",
            serialNumber: "SERIAL123"
        )
        
        // Test protocol conformance
        let protocolProfile: HardwareProfileProtocol = profile
        
        XCTAssertEqual(protocolProfile.hardwareModel, Data([0x01, 0x02]))
        XCTAssertEqual(protocolProfile.machineIdentifier, Data([0x03, 0x04]))
        XCTAssertEqual(protocolProfile.macAddress, "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(protocolProfile.serialNumber, "SERIAL123")
        XCTAssertNoThrow(try protocolProfile.validate())
    }
    
    // MARK: - Identifiable Conformance Tests
    
    func testHardwareProfileIdentifiable() {
        let profile1 = HardwareProfile(
            name: "Profile 1",
            hardwareModel: Data([0x01]),
            machineIdentifier: Data([0x02]),
            macAddress: "00:11:22:33:44:55",
            serialNumber: "TEST1"
        )
        
        let profile2 = HardwareProfile(
            name: "Profile 2",
            hardwareModel: Data([0x01]),
            machineIdentifier: Data([0x02]),
            macAddress: "00:11:22:33:44:55",
            serialNumber: "TEST2"
        )
        
        // IDs should be unique
        XCTAssertNotEqual(profile1.id, profile2.id)
    }
}
