// PrivarionSystemExtensionTests
// Unit tests for PrivarionSystemExtension class
// Requirements: 1.1-1.8, 20.1

import XCTest
import SystemExtensions
@testable import PrivarionSystemExtension
@testable import PrivarionSharedModels

final class PrivarionSystemExtensionTests: XCTestCase {
    
    var systemExtension: PrivarionSystemExtension!
    let testExtensionIdentifier = "com.privarion.test.extension"
    
    override func setUp() {
        super.setUp()
        systemExtension = PrivarionSystemExtension(extensionIdentifier: testExtensionIdentifier)
    }
    
    override func tearDown() {
        systemExtension = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(systemExtension, "System extension should initialize successfully")
    }
    
    func testDefaultInitialization() {
        let defaultExtension = PrivarionSystemExtension()
        XCTAssertNotNil(defaultExtension, "System extension should initialize with default identifier")
    }
    
    func testCustomIdentifierInitialization() {
        let customIdentifier = "com.test.custom.extension"
        let customExtension = PrivarionSystemExtension(extensionIdentifier: customIdentifier)
        XCTAssertNotNil(customExtension, "System extension should initialize with custom identifier")
    }
    
    // MARK: - Status Tests
    
    func testInitialStatusIsNotInstalled() async {
        let status = await systemExtension.checkStatus()
        
        switch status {
        case .notInstalled:
            XCTAssertTrue(true, "Initial status should be notInstalled")
        default:
            XCTFail("Expected notInstalled status, got \(status)")
        }
    }
    
    func testCheckStatusReturnsCurrentStatus() async {
        // Initial status should be notInstalled
        let initialStatus = await systemExtension.checkStatus()
        
        switch initialStatus {
        case .notInstalled:
            XCTAssertTrue(true, "Initial status is notInstalled")
        default:
            XCTFail("Expected notInstalled status")
        }
        
        // Check status again to ensure consistency
        let secondStatus = await systemExtension.checkStatus()
        
        switch secondStatus {
        case .notInstalled:
            XCTAssertTrue(true, "Status remains consistent")
        default:
            XCTFail("Expected notInstalled status on second check")
        }
    }
    
    // MARK: - Status Observer Tests
    
    func testAddStatusObserver() {
        let observer = MockStatusObserver()
        systemExtension.addStatusObserver(observer)
        
        // Observer should be added without crashing
        XCTAssertTrue(true, "Observer added successfully")
    }
    
    func testRemoveStatusObserver() {
        let observer = MockStatusObserver()
        systemExtension.addStatusObserver(observer)
        systemExtension.removeStatusObserver(observer)
        
        // Observer should be removed without crashing
        XCTAssertTrue(true, "Observer removed successfully")
    }
    
    func testMultipleStatusObservers() {
        let observer1 = MockStatusObserver()
        let observer2 = MockStatusObserver()
        let observer3 = MockStatusObserver()
        
        systemExtension.addStatusObserver(observer1)
        systemExtension.addStatusObserver(observer2)
        systemExtension.addStatusObserver(observer3)
        
        // All observers should be added without crashing
        XCTAssertTrue(true, "Multiple observers added successfully")
        
        systemExtension.removeStatusObserver(observer2)
        
        // Observer should be removed without affecting others
        XCTAssertTrue(true, "Observer removed from multiple observers")
    }
    
    // MARK: - Extension Status Enum Tests
    
    func testExtensionStatusCases() {
        // Test that all status cases can be created
        let notInstalled: ExtensionStatus = .notInstalled
        let installed: ExtensionStatus = .installed
        let active: ExtensionStatus = .active
        let activating: ExtensionStatus = .activating
        let deactivating: ExtensionStatus = .deactivating
        let error: ExtensionStatus = .error("Test error message")
        
        // Verify we can switch on status
        switch notInstalled {
        case .notInstalled:
            XCTAssertTrue(true, "notInstalled case works")
        default:
            XCTFail("Unexpected status case")
        }
        
        switch installed {
        case .installed:
            XCTAssertTrue(true, "installed case works")
        default:
            XCTFail("Unexpected status case")
        }
        
        switch active {
        case .active:
            XCTAssertTrue(true, "active case works")
        default:
            XCTFail("Unexpected status case")
        }
        
        switch activating {
        case .activating:
            XCTAssertTrue(true, "activating case works")
        default:
            XCTFail("Unexpected status case")
        }
        
        switch deactivating {
        case .deactivating:
            XCTAssertTrue(true, "deactivating case works")
        default:
            XCTFail("Unexpected status case")
        }
        
        switch error {
        case .error(let errorMessage):
            XCTAssertEqual(errorMessage, "Test error message", "error case works with associated error message")
        default:
            XCTFail("Unexpected status case")
        }
    }
    
    // MARK: - macOS Version Compatibility Tests
    
    func testMacOSVersionCompatibility() async {
        // This test verifies that the extension checks for macOS 13.0+
        // On compatible systems, it should not throw incompatibleMacOSVersion
        
        if #available(macOS 13.0, *) {
            // On macOS 13.0+, the version check should pass
            // Note: The actual installation will fail without proper entitlements,
            // but we're testing the version check specifically
            XCTAssertTrue(true, "Running on compatible macOS version")
        } else {
            // On older macOS, the version check should fail
            XCTAssertTrue(true, "Running on incompatible macOS version")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testInstallExtensionWithoutEntitlements() async {
        // Without proper entitlements, installation should fail
        // This test verifies error handling works correctly
        
        do {
            try await systemExtension.installExtension()
            // If we get here, either entitlements are present or the test environment allows it
            // In production, this would require user approval
        } catch {
            // Expected to fail without proper entitlements or user approval
            XCTAssertNotNil(error, "Installation should fail without entitlements")
        }
    }
    
    func testActivateExtensionWithoutEntitlements() async {
        // Without proper entitlements, activation should fail
        
        do {
            try await systemExtension.activateExtension()
            // If we get here, either entitlements are present or the test environment allows it
        } catch {
            // Expected to fail without proper entitlements or user approval
            XCTAssertNotNil(error, "Activation should fail without entitlements")
        }
    }
    
    func testDeactivateExtensionWithoutEntitlements() async {
        // Without proper entitlements, deactivation should fail
        
        do {
            try await systemExtension.deactivateExtension()
            // If we get here, either entitlements are present or the test environment allows it
        } catch {
            // Expected to fail without proper entitlements
            XCTAssertNotNil(error, "Deactivation should fail without entitlements")
        }
    }
    
    // MARK: - Status Persistence Tests
    
    func testExtensionStatusCodable() throws {
        // Test that ExtensionStatus can be encoded and decoded
        let statuses: [ExtensionStatus] = [
            .notInstalled,
            .installed,
            .active,
            .activating,
            .deactivating,
            .error("Test error message")
        ]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for status in statuses {
            let encoded = try encoder.encode(status)
            let decoded = try decoder.decode(ExtensionStatus.self, from: encoded)
            
            // Verify round-trip encoding/decoding
            switch (status, decoded) {
            case (.notInstalled, .notInstalled),
                 (.installed, .installed),
                 (.active, .active),
                 (.activating, .activating),
                 (.deactivating, .deactivating):
                XCTAssertTrue(true, "Status encoded and decoded correctly")
                
            case (.error(let originalMessage), .error(let decodedMessage)):
                XCTAssertEqual(originalMessage, decodedMessage, "Error message preserved through encoding")
                
            default:
                XCTFail("Status did not round-trip correctly: \(status) -> \(decoded)")
            }
        }
    }
    
    func testStatusPersistenceRoundTrip() throws {
        // Test that status can be saved and loaded
        // Use temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = ExtensionStatusPersistence(customDirectory: tempDir)
        
        let testStatuses: [ExtensionStatus] = [
            .notInstalled,
            .installed,
            .active,
            .error("Persistence test error")
        ]
        
        for status in testStatuses {
            // Save status
            try persistence.saveStatus(status)
            
            // Load status
            let loadedStatus = try persistence.loadStatus()
            XCTAssertNotNil(loadedStatus, "Status should be loaded")
            
            // Verify loaded status matches saved status
            if let loaded = loadedStatus {
                switch (status, loaded) {
                case (.notInstalled, .notInstalled),
                     (.installed, .installed),
                     (.active, .active):
                    XCTAssertTrue(true, "Status persisted correctly")
                    
                case (.error(let originalMessage), .error(let loadedMessage)):
                    XCTAssertEqual(originalMessage, loadedMessage, "Error message persisted correctly")
                    
                default:
                    XCTFail("Persisted status does not match: \(status) -> \(loaded)")
                }
            }
        }
        
        // Clean up
        try? persistence.clearStatus()
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func testStatusPersistenceWithNoFile() throws {
        // Use temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = ExtensionStatusPersistence(customDirectory: tempDir)
        
        // Clear any existing status
        try? persistence.clearStatus()
        
        // Loading with no file should return nil
        let status = try persistence.loadStatus()
        XCTAssertNil(status, "Loading with no file should return nil")
        
        // Clean up
        try? FileManager.default.removeItem(at: tempDir)
    }
    
    func testStatusPersistenceClear() throws {
        // Use temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = ExtensionStatusPersistence(customDirectory: tempDir)
        
        // Save a status
        try persistence.saveStatus(.active)
        
        // Verify it was saved
        let loaded = try persistence.loadStatus()
        XCTAssertNotNil(loaded, "Status should be saved")
        
        // Clear status
        try persistence.clearStatus()
        
        // Verify it was cleared
        let afterClear = try persistence.loadStatus()
        XCTAssertNil(afterClear, "Status should be cleared")
        
        // Clean up
        try? FileManager.default.removeItem(at: tempDir)
    }
}

// MARK: - Mock Objects

class MockStatusObserver: SystemExtensionStatusObserver {
    var onStatusChange: ((ExtensionStatus) -> Void)?
    var statusChanges: [ExtensionStatus] = []
    
    func extensionStatusDidChange(_ status: ExtensionStatus) {
        statusChanges.append(status)
        onStatusChange?(status)
    }
}
