import XCTest
import SwiftUI
@testable import PrivarionGUI
@testable import PrivarionCore

/// Unit tests for MacAddressState following Clean Architecture
/// Tests state management, async operations, and error handling
@MainActor
final class MacAddressStateTests: XCTestCase {
    
    var sut: MacAddressState!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = MacAddressState()
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertTrue(sut.interfaces.isEmpty)
        XCTAssertNil(sut.selectedInterface)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.showingError)
    }
    
    // MARK: - Interface Loading Tests
    
    func testLoadInterfacesSuccess() async {
        // Given
        XCTAssertTrue(sut.interfaces.isEmpty)
        
        // When
        await sut.loadInterfaces()
        
        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
        // Note: Actual interface loading will depend on system state
    }
    
    // MARK: - State Management Tests
    
    func testSetSelectedInterface() {
        // Given
        let mockInterface = createMockInterface()
        
        // When
        sut.selectedInterface = mockInterface
        
        // Then
        XCTAssertEqual(sut.selectedInterface?.name, "en0")
        XCTAssertEqual(sut.selectedInterface?.macAddress, "00:11:22:33:44:55")
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorStateHandling() {
        // Given
        let testError = MacSpoofingError.invalidNetworkInterface("Test error")
        
        // When
        sut.error = testError
        
        // Then
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(sut.error?.localizedDescription, testError.localizedDescription)
    }
    
    func testClearError() {
        // Given
        sut.error = MacSpoofingError.invalidNetworkInterface("Test error")
        XCTAssertNotNil(sut.error)
        
        // When
        sut.clearError()
        
        // Then
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.showingError)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStateToggle() {
        // Test initial state
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.loadingOperation)
    }
    
    // MARK: - Integration Tests
    
    func testFullWorkflowSimulation() async {
        // Given - Initial state
        XCTAssertTrue(sut.interfaces.isEmpty)
        
        // When - Load interfaces
        await sut.loadInterfaces()
        
        // Then - Should have completed loading
        XCTAssertFalse(sut.isLoading)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceOfStateUpdates() {
        measure {
            for i in 0..<1000 {
                let mockInterface = createMockInterface(name: "en\(i)")
                sut.selectedInterface = mockInterface
            }
        }
    }
}

// MARK: - Mock Objects for Testing

extension MacAddressStateTests {
    
    /// Create a mock network interface for testing
    private func createMockInterface(
        name: String = "en0",
        macAddress: String = "00:11:22:33:44:55",
        type: NetworkInterfaceType = .wifi,
        isActive: Bool = true,
        isEligibleForSpoofing: Bool = true
    ) -> NetworkInterface {
        return NetworkInterface(
            name: name,
            macAddress: macAddress,
            type: type,
            isActive: isActive,
            isEligibleForSpoofing: isEligibleForSpoofing,
            ipAddresses: ["192.168.1.100"]
        )
    }
}
