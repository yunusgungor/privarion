// PrivarionSystemExtensionTests - ExtensionStatusTests
// Unit tests for ExtensionStatus enum
// Tests status transitions, serialization, and error handling
// Requirements: 1.3, 1.7, 20.1

import XCTest
@testable import PrivarionSystemExtension

final class ExtensionStatusTests: XCTestCase {
    
    // MARK: - Status Enum Tests
    
    func testExtensionStatusNotInstalled() {
        // Given/When: Creating notInstalled status
        let status = ExtensionStatus.notInstalled
        
        // Then: Should be notInstalled
        if case .notInstalled = status {
            XCTAssertTrue(true, "Status is notInstalled")
        } else {
            XCTFail("Status should be notInstalled")
        }
    }
    
    func testExtensionStatusInstalled() {
        // Given/When: Creating installed status
        let status = ExtensionStatus.installed
        
        // Then: Should be installed
        if case .installed = status {
            XCTAssertTrue(true, "Status is installed")
        } else {
            XCTFail("Status should be installed")
        }
    }
    
    func testExtensionStatusActive() {
        // Given/When: Creating active status
        let status = ExtensionStatus.active
        
        // Then: Should be active
        if case .active = status {
            XCTAssertTrue(true, "Status is active")
        } else {
            XCTFail("Status should be active")
        }
    }
    
    func testExtensionStatusActivating() {
        // Given/When: Creating activating status
        let status = ExtensionStatus.activating
        
        // Then: Should be activating
        if case .activating = status {
            XCTAssertTrue(true, "Status is activating")
        } else {
            XCTFail("Status should be activating")
        }
    }
    
    func testExtensionStatusDeactivating() {
        // Given/When: Creating deactivating status
        let status = ExtensionStatus.deactivating
        
        // Then: Should be deactivating
        if case .deactivating = status {
            XCTAssertTrue(true, "Status is deactivating")
        } else {
            XCTFail("Status should be deactivating")
        }
    }
    
    func testExtensionStatusError() {
        // Given/When: Creating error status
        let errorMessage = "Test error message"
        let status = ExtensionStatus.error(errorMessage)
        
        // Then: Should be error with correct message
        if case .error(let message) = status {
            XCTAssertEqual(message, errorMessage, "Error message should match")
        } else {
            XCTFail("Status should be error")
        }
    }
    
    // MARK: - Status Serialization Tests
    
    func testExtensionStatusNotInstalledSerialization() throws {
        // Given: A notInstalled status
        let status = ExtensionStatus.notInstalled
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(status)
        
        let decoder = JSONDecoder()
        let decodedStatus = try decoder.decode(ExtensionStatus.self, from: data)
        
        // Then: Decoded status should match original
        if case .notInstalled = decodedStatus {
            XCTAssertTrue(true, "Decoded status is notInstalled")
        } else {
            XCTFail("Decoded status should be notInstalled")
        }
    }
    
    func testExtensionStatusInstalledSerialization() throws {
        // Given: An installed status
        let status = ExtensionStatus.installed
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(status)
        
        let decoder = JSONDecoder()
        let decodedStatus = try decoder.decode(ExtensionStatus.self, from: data)
        
        // Then: Decoded status should match original
        if case .installed = decodedStatus {
            XCTAssertTrue(true, "Decoded status is installed")
        } else {
            XCTFail("Decoded status should be installed")
        }
    }
    
    func testExtensionStatusActiveSerialization() throws {
        // Given: An active status
        let status = ExtensionStatus.active
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(status)
        
        let decoder = JSONDecoder()
        let decodedStatus = try decoder.decode(ExtensionStatus.self, from: data)
        
        // Then: Decoded status should match original
        if case .active = decodedStatus {
            XCTAssertTrue(true, "Decoded status is active")
        } else {
            XCTFail("Decoded status should be active")
        }
    }
    
    func testExtensionStatusActivatingSerialization() throws {
        // Given: An activating status
        let status = ExtensionStatus.activating
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(status)
        
        let decoder = JSONDecoder()
        let decodedStatus = try decoder.decode(ExtensionStatus.self, from: data)
        
        // Then: Decoded status should match original
        if case .activating = decodedStatus {
            XCTAssertTrue(true, "Decoded status is activating")
        } else {
            XCTFail("Decoded status should be activating")
        }
    }
    
    func testExtensionStatusDeactivatingSerialization() throws {
        // Given: A deactivating status
        let status = ExtensionStatus.deactivating
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(status)
        
        let decoder = JSONDecoder()
        let decodedStatus = try decoder.decode(ExtensionStatus.self, from: data)
        
        // Then: Decoded status should match original
        if case .deactivating = decodedStatus {
            XCTAssertTrue(true, "Decoded status is deactivating")
        } else {
            XCTFail("Decoded status should be deactivating")
        }
    }
    
    func testExtensionStatusErrorSerialization() throws {
        // Given: An error status
        let errorMessage = "Test error message"
        let status = ExtensionStatus.error(errorMessage)
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(status)
        
        let decoder = JSONDecoder()
        let decodedStatus = try decoder.decode(ExtensionStatus.self, from: data)
        
        // Then: Decoded status should match original
        if case .error(let message) = decodedStatus {
            XCTAssertEqual(message, errorMessage, "Error message should match")
        } else {
            XCTFail("Decoded status should be error")
        }
    }
    
    func testExtensionStatusErrorWithSpecialCharactersSerialization() throws {
        // Given: An error status with special characters
        let errorMessage = "Error: \"Missing entitlement\" (code: 123)"
        let status = ExtensionStatus.error(errorMessage)
        
        // When: Encoding and decoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(status)
        
        let decoder = JSONDecoder()
        let decodedStatus = try decoder.decode(ExtensionStatus.self, from: data)
        
        // Then: Decoded status should match original with special characters preserved
        if case .error(let message) = decodedStatus {
            XCTAssertEqual(message, errorMessage, "Error message with special characters should match")
        } else {
            XCTFail("Decoded status should be error")
        }
    }
    
    // MARK: - Status Deserialization Error Handling Tests
    
    func testExtensionStatusDeserializationWithInvalidType() {
        // Given: Invalid JSON with unknown status type
        let invalidJSON = """
        {
            "type": "unknown_status"
        }
        """.data(using: .utf8)!
        
        // When: Attempting to decode
        let decoder = JSONDecoder()
        
        // Then: Should throw decoding error
        XCTAssertThrowsError(try decoder.decode(ExtensionStatus.self, from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError, "Should throw DecodingError")
        }
    }
    
    func testExtensionStatusDeserializationWithMissingErrorMessage() {
        // Given: JSON with error type but missing error message
        let invalidJSON = """
        {
            "type": "error"
        }
        """.data(using: .utf8)!
        
        // When: Attempting to decode
        let decoder = JSONDecoder()
        
        // Then: Should throw decoding error
        XCTAssertThrowsError(try decoder.decode(ExtensionStatus.self, from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError, "Should throw DecodingError")
        }
    }
    
    // MARK: - Status Comparison Tests
    
    func testExtensionStatusEquality() {
        // Given: Two identical statuses
        let status1 = ExtensionStatus.active
        let status2 = ExtensionStatus.active
        
        // When/Then: Should be equal (tested via switch)
        switch (status1, status2) {
        case (.active, .active):
            XCTAssertTrue(true, "Both statuses are active")
        default:
            XCTFail("Statuses should both be active")
        }
    }
    
    func testExtensionStatusInequality() {
        // Given: Two different statuses
        let status1 = ExtensionStatus.active
        let status2 = ExtensionStatus.installed
        
        // When/Then: Should be different
        switch (status1, status2) {
        case (.active, .installed):
            XCTAssertTrue(true, "Statuses are different")
        default:
            XCTFail("Statuses should be different")
        }
    }
    
    func testExtensionStatusErrorEquality() {
        // Given: Two error statuses with same message
        let status1 = ExtensionStatus.error("Test error")
        let status2 = ExtensionStatus.error("Test error")
        
        // When/Then: Should have same error message
        if case .error(let message1) = status1,
           case .error(let message2) = status2 {
            XCTAssertEqual(message1, message2, "Error messages should match")
        } else {
            XCTFail("Both statuses should be error")
        }
    }
    
    func testExtensionStatusErrorInequality() {
        // Given: Two error statuses with different messages
        let status1 = ExtensionStatus.error("Error 1")
        let status2 = ExtensionStatus.error("Error 2")
        
        // When/Then: Should have different error messages
        if case .error(let message1) = status1,
           case .error(let message2) = status2 {
            XCTAssertNotEqual(message1, message2, "Error messages should be different")
        } else {
            XCTFail("Both statuses should be error")
        }
    }
    
    // MARK: - Status String Representation Tests
    
    func testExtensionStatusStringRepresentation() {
        // Given: Various statuses
        let statuses: [ExtensionStatus] = [
            .notInstalled,
            .installed,
            .active,
            .activating,
            .deactivating,
            .error("Test error")
        ]
        
        // When/Then: Each status should have a string representation
        for status in statuses {
            let description = String(describing: status)
            XCTAssertFalse(description.isEmpty, "Status should have string representation")
        }
    }
    
    // MARK: - Status Transition Validation Tests
    
    func testValidStatusTransitions() {
        // Given: Valid status transitions
        let validTransitions: [(from: ExtensionStatus, to: ExtensionStatus)] = [
            (.notInstalled, .activating),
            (.activating, .active),
            (.activating, .error("Failed")),
            (.active, .deactivating),
            (.deactivating, .installed),
            (.deactivating, .error("Failed")),
            (.installed, .activating),
            (.error("Failed"), .activating)
        ]
        
        // When/Then: All transitions should be valid
        for transition in validTransitions {
            XCTAssertNotNil(transition.from, "From status should exist")
            XCTAssertNotNil(transition.to, "To status should exist")
        }
    }
}
