import XCTest
@testable import PrivarionCore

/// Unit tests for MacAddressSpoofingManager
/// Tests core functionality including spoofing, restoration, error handling, and async operations
final class MacAddressSpoofingManagerTests: XCTestCase {
    
    var manager: MacAddressSpoofingManager!
    var mockNetworkManager: MockNetworkInterfaceManager!
    var mockRepository: MockMacAddressRepository!
    var mockCommandExecutor: MockSystemCommandExecutor!
    var testLogger: PrivarionLogger!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup test logger
        testLogger = PrivarionLogger.shared
        
        // Setup mock dependencies
        mockNetworkManager = MockNetworkInterfaceManager()
        mockRepository = MockMacAddressRepository()
        mockCommandExecutor = MockSystemCommandExecutor(logger: testLogger)
        
        // Create manager with mocked dependencies
        manager = MacAddressSpoofingManager(
            networkManager: mockNetworkManager,
            repository: mockRepository,
            commandExecutor: mockCommandExecutor,
            logger: testLogger
        )
    }
    
    override func tearDown() async throws {
        manager = nil
        mockNetworkManager = nil
        mockRepository = nil
        mockCommandExecutor = nil
        testLogger = nil
        try await super.tearDown()
    }
    
    // MARK: - Interface Listing Tests
    
    func testListAvailableInterfaces_Success() async throws {
        // Given
        let expectedInterfaces = [
            NetworkInterface(name: "en0", macAddress: "aa:bb:cc:dd:ee:ff", type: .ethernet, isActive: true, isEligibleForSpoofing: true),
            NetworkInterface(name: "en1", macAddress: "11:22:33:44:55:66", type: .wifi, isActive: true, isEligibleForSpoofing: true)
        ]
        mockNetworkManager.interfacesToReturn = expectedInterfaces
        
        // When
        let interfaces = try await manager.listAvailableInterfaces()
        
        // Then
        XCTAssertEqual(interfaces.count, 2)
        XCTAssertEqual(interfaces[0].name, "en0")
        XCTAssertEqual(interfaces[1].name, "en1")
        XCTAssertTrue(mockNetworkManager.enumerateInterfacesCalled)
    }
    
    func testListAvailableInterfaces_NetworkError() async throws {
        // Given
        mockNetworkManager.shouldThrowError = true
        mockNetworkManager.errorToThrow = NetworkError.interfaceEnumerationFailed
        
        // When/Then
        do {
            _ = try await manager.listAvailableInterfaces()
            XCTFail("Expected error to be thrown")
        } catch let error as MacSpoofingError {
            switch error {
            case .networkInterfaceEnumerationFailed(_):
                // Expected error
                break
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - MAC Address Spoofing Tests
    
    func testSpoofMACAddress_Success() async throws {
        // Given
        let testInterface = "en0"
        let originalMAC = "aa:bb:cc:dd:ee:ff"
        let customMAC = "11:22:33:44:55:66"
        
        setupValidInterfaceForSpoofing(name: testInterface, originalMAC: originalMAC)
        
        // When
        try await manager.spoofMACAddress(
            interface: testInterface,
            customMAC: customMAC,
            preserveVendorPrefix: false
        )
        
        // Then
        XCTAssertTrue(mockRepository.backupOriginalMACCalled)
        XCTAssertTrue(mockNetworkManager.changeMACAddressCalled)
        XCTAssertTrue(mockRepository.markAsSpoofedCalled)
        XCTAssertEqual(mockNetworkManager.lastChangedInterface, testInterface)
        XCTAssertEqual(mockNetworkManager.lastChangedMAC, customMAC)
    }
    
    func testSpoofMACAddress_InterfaceAlreadySpoofed() async throws {
        // Given
        let testInterface = "en0"
        let originalMAC = "aa:bb:cc:dd:ee:ff"
        
        setupValidInterfaceForSpoofing(name: testInterface, originalMAC: originalMAC)
        mockRepository.isSpoofedResult = true // Already spoofed
        
        // When/Then
        do {
            try await manager.spoofMACAddress(
                interface: testInterface,
                customMAC: "11:22:33:44:55:66",
                preserveVendorPrefix: false
            )
            XCTFail("Expected error to be thrown")
        } catch let error as MacSpoofingError {
            switch error {
            case .interfaceAlreadySpoofed(let interface):
                XCTAssertEqual(interface, testInterface)
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testSpoofMACAddress_InvalidInterface() async throws {
        // Given
        let testInterface = "invalid"
        mockNetworkManager.getInterfaceResult = nil // Interface not found
        
        // When/Then
        do {
            try await manager.spoofMACAddress(
                interface: testInterface,
                customMAC: "11:22:33:44:55:66",
                preserveVendorPrefix: false
            )
            XCTFail("Expected error to be thrown")
        } catch let error as MacSpoofingError {
            switch error {
            case .invalidNetworkInterface(let interface):
                XCTAssertEqual(interface, testInterface)
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testSpoofMACAddress_ConnectivityLoss() async throws {
        // Given
        let testInterface = "en0"
        let originalMAC = "aa:bb:cc:dd:ee:ff"
        
        setupValidInterfaceForSpoofing(name: testInterface, originalMAC: originalMAC)
        mockNetworkManager.connectivityBeforeChange = true
        mockNetworkManager.connectivityAfterChange = false // Lost connectivity
        
        // When/Then
        do {
            try await manager.spoofMACAddress(
                interface: testInterface,
                customMAC: "11:22:33:44:55:66",
                preserveVendorPrefix: false
            )
            XCTFail("Expected error to be thrown")
        } catch let error as MacSpoofingError {
            switch error {
            case .connectivityLostAfterSpoofing(let interface):
                XCTAssertEqual(interface, testInterface)
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
        
        // Verify rollback was attempted
        XCTAssertTrue(mockNetworkManager.rollbackAttempted)
    }
    
    // MARK: - MAC Address Restoration Tests
    
    func testRestoreOriginalMAC_Success() async throws {
        // Given
        let testInterface = "en0"
        let originalMAC = "aa:bb:cc:dd:ee:ff"
        
        setupValidInterfaceForRestore(name: testInterface, originalMAC: originalMAC)
        
        // When
        try await manager.restoreOriginalMAC(interface: testInterface)
        
        // Then
        XCTAssertTrue(mockNetworkManager.changeMACAddressCalled)
        XCTAssertTrue(mockRepository.removeBackupCalled)
        XCTAssertEqual(mockNetworkManager.lastChangedInterface, testInterface)
        XCTAssertEqual(mockNetworkManager.lastChangedMAC, originalMAC)
    }
    
    func testRestoreOriginalMAC_InterfaceNotSpoofed() async throws {
        // Given
        let testInterface = "en0"
        mockRepository.isSpoofedResult = false // Not spoofed
        
        // When/Then
        do {
            try await manager.restoreOriginalMAC(interface: testInterface)
            XCTFail("Expected error to be thrown")
        } catch let error as MacSpoofingError {
            switch error {
            case .interfaceNotSpoofed(let interface):
                XCTAssertEqual(interface, testInterface)
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testRestoreOriginalMAC_OriginalMACNotFound() async throws {
        // Given
        let testInterface = "en0"
        mockRepository.isSpoofedResult = true
        mockRepository.getOriginalMACResult = nil // No original MAC stored
        
        // When/Then
        do {
            try await manager.restoreOriginalMAC(interface: testInterface)
            XCTFail("Expected error to be thrown")
        } catch let error as MacSpoofingError {
            switch error {
            case .originalMACNotFound(let interface):
                XCTAssertEqual(interface, testInterface)
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Restore All Interfaces Tests
    
    func testRestoreAllInterfaces_Success() async throws {
        // Given
        let spoofedInterfaces = ["en0", "en1"]
        mockRepository.getSpoofedInterfacesResult = spoofedInterfaces
        
        for interface in spoofedInterfaces {
            setupValidInterfaceForRestore(name: interface, originalMAC: "aa:bb:cc:dd:ee:ff")
        }
        
        // When
        try await manager.restoreAllInterfaces()
        
        // Then
        XCTAssertEqual(mockNetworkManager.changeMACAddressCallCount, 2)
        XCTAssertEqual(mockRepository.removeBackupCallCount, 2)
    }
    
    func testRestoreAllInterfaces_PartialFailure() async throws {
        // Given
        let spoofedInterfaces = ["en0", "en1"]
        mockRepository.getSpoofedInterfacesResult = spoofedInterfaces
        
        setupValidInterfaceForRestore(name: "en0", originalMAC: "aa:bb:cc:dd:ee:ff")
        mockRepository.getOriginalMACResults["en1"] = nil // Fail for en1
        
        // When/Then
        do {
            try await manager.restoreAllInterfaces()
            XCTFail("Expected error to be thrown")
        } catch let error as MacSpoofingError {
            switch error {
            case .multipleInterfaceRestoreFailed(let errors):
                XCTAssertEqual(errors.count, 1)
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    // MARK: - Interface Status Tests
    
    func testGetInterfaceStatus_Success() async throws {
        // Given
        let interfaces = [
            NetworkInterface(name: "en0", macAddress: "aa:bb:cc:dd:ee:ff", type: .ethernet, isActive: true, isEligibleForSpoofing: true),
            NetworkInterface(name: "en1", macAddress: "11:22:33:44:55:66", type: .wifi, isActive: false, isEligibleForSpoofing: true)
        ]
        mockNetworkManager.interfacesToReturn = interfaces
        mockRepository.getSpoofedInterfacesResult = ["en0"] // en0 is spoofed
        mockRepository.getOriginalMACResults["en0"] = "ff:ee:dd:cc:bb:aa"
        
        // When
        let statuses = try await manager.getInterfaceStatus()
        
        // Then
        XCTAssertEqual(statuses.count, 2)
        
        let en0Status = statuses.first { $0.name == "en0" }!
        XCTAssertEqual(en0Status.currentMAC, "aa:bb:cc:dd:ee:ff")
        XCTAssertEqual(en0Status.originalMAC, "ff:ee:dd:cc:bb:aa")
        XCTAssertTrue(en0Status.isActive)
        XCTAssertTrue(en0Status.isSpoofed)
        
        let en1Status = statuses.first { $0.name == "en1" }!
        XCTAssertEqual(en1Status.currentMAC, "11:22:33:44:55:66")
        XCTAssertNil(en1Status.originalMAC)
        XCTAssertFalse(en1Status.isActive)
        XCTAssertFalse(en1Status.isSpoofed)
    }
    
    // MARK: - Helper Methods
    
    private func setupValidInterfaceForSpoofing(name: String, originalMAC: String) {
        let interface = NetworkInterface(name: name, macAddress: originalMAC, type: .ethernet, isActive: true, isEligibleForSpoofing: true)
        mockNetworkManager.getInterfaceResult = interface
        mockRepository.isSpoofedResult = false
        mockNetworkManager.connectivityBeforeChange = true
        mockNetworkManager.connectivityAfterChange = true
    }
    
    private func setupValidInterfaceForRestore(name: String, originalMAC: String) {
        mockRepository.isSpoofedResult = true
        mockRepository.getOriginalMACResults[name] = originalMAC
        
        let restoredInterface = NetworkInterface(name: name, macAddress: originalMAC, type: .ethernet, isActive: true, isEligibleForSpoofing: true)
        mockNetworkManager.getInterfaceResult = restoredInterface
    }
}

// MARK: - Mock Classes

class MockNetworkInterfaceManager: NetworkInterfaceManager {
    var interfacesToReturn: [NetworkInterface] = []
    var getInterfaceResult: NetworkInterface?
    var shouldThrowError = false
    var errorToThrow: Error = NetworkError.interfaceEnumerationFailed
    var connectivityBeforeChange = true
    var connectivityAfterChange = true
    var rollbackAttempted = false
    
    var enumerateInterfacesCalled = false
    var changeMACAddressCalled = false
    var changeMACAddressCallCount = 0
    var lastChangedInterface: String?
    var lastChangedMAC: String?
    
    override func enumerateInterfaces() async throws -> [NetworkInterface] {
        enumerateInterfacesCalled = true
        if shouldThrowError {
            throw errorToThrow
        }
        return interfacesToReturn.filter { $0.isEligibleForSpoofing }
    }
    
    override func getInterface(name: String) async throws -> NetworkInterface? {
        if shouldThrowError {
            throw errorToThrow
        }
        return getInterfaceResult
    }
    
    override func changeMACAddress(interface: String, newMAC: String) async throws {
        changeMACAddressCalled = true
        changeMACAddressCallCount += 1
        lastChangedInterface = interface
        lastChangedMAC = newMAC
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Update the interface result to reflect the change
        if var currentInterface = getInterfaceResult {
            currentInterface.macAddress = newMAC
            getInterfaceResult = currentInterface
        }
    }
    
    override func testConnectivity(interface: String) async throws -> Bool {
        if shouldThrowError {
            throw errorToThrow
        }
        
        // Return different connectivity based on call order
        if changeMACAddressCalled {
            rollbackAttempted = !connectivityAfterChange
            return connectivityAfterChange
        } else {
            return connectivityBeforeChange
        }
    }
}

class MockMacAddressRepository: MacAddressRepository {
    var isSpoofedResult = false
    var getSpoofedInterfacesResult: [String] = []
    var getOriginalMACResult: String?
    var getOriginalMACResults: [String: String] = [:]
    
    var backupOriginalMACCalled = false
    var markAsSpoofedCalled = false
    var removeBackupCalled = false
    var removeBackupCallCount = 0
    
    override func isSpoofed(interface: String) -> Bool {
        return isSpoofedResult
    }
    
    override func getSpoofedInterfaces() -> [String] {
        return getSpoofedInterfacesResult
    }
    
    override func getOriginalMAC(for interface: String) -> String? {
        return getOriginalMACResults[interface] ?? getOriginalMACResult
    }
    
    override func backupOriginalMAC(interface: String, macAddress: String) throws {
        backupOriginalMACCalled = true
        getOriginalMACResults[interface] = macAddress
    }
    
    override func markAsSpoofed(interface: String, originalMAC: String) throws {
        markAsSpoofedCalled = true
        getSpoofedInterfacesResult.append(interface)
    }
    
    override func removeBackup(interface: String) throws {
        removeBackupCalled = true
        removeBackupCallCount += 1
        getOriginalMACResults.removeValue(forKey: interface)
        getSpoofedInterfacesResult.removeAll { $0 == interface }
    }
}

class MockSystemCommandExecutor: SystemCommandExecutor {
    var shouldThrowError = false
    var errorToThrow: Error = SystemError.commandFailed
    
    override func executeCommand(_ command: String, arguments: [String] = []) async throws -> CommandResult {
        if shouldThrowError {
            throw errorToThrow
        }
        
        return CommandResult(
            standardOutput: "Command executed successfully",
            standardError: "",
            exitCode: 0,
            executionTime: 0.1
        )
    }
}

// MARK: - Error Types for Mocks

enum NetworkError: Error {
    case interfaceEnumerationFailed
    case interfaceNotFound
    case macChangeFailure
    case connectivityTestFailure
}

enum SystemError: Error {
    case commandFailed
    case permissionDenied
}
