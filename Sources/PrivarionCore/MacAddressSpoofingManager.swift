import Foundation
import Security

// MARK: - Local Error Types for MAC Address Spoofing
// TODO: Refactor to use shared PrivarionError from Core module
public enum MacSpoofingError: LocalizedError {
    case networkInterfaceEnumerationFailed(Error)
    case multipleInterfaceRestoreFailed([Error])
    case interfaceStatusRetrievalFailed(Error)
    case invalidNetworkInterface(String)
    case interfaceAlreadySpoofed(String)
    case connectivityLostAfterSpoofing(String)
    case interfaceNotSpoofed(String)
    case originalMACNotFound(String)
    case macRestoreFailed(String, Error)
    case invalidMACFormat(String)
    case interfaceNotFound(String)
    case macChangeVerificationFailed(interface: String, expected: String, actual: String)
    
    public var errorDescription: String? {
        switch self {
        case .networkInterfaceEnumerationFailed(let error):
            return "Failed to enumerate network interfaces: \(error.localizedDescription)"
        case .multipleInterfaceRestoreFailed(let errors):
            return "Failed to restore multiple interfaces: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        case .interfaceStatusRetrievalFailed(let error):
            return "Failed to retrieve interface status: \(error.localizedDescription)"
        case .invalidNetworkInterface(let interface):
            return "Invalid network interface: \(interface)"
        case .interfaceAlreadySpoofed(let interface):
            return "Interface already spoofed: \(interface)"
        case .connectivityLostAfterSpoofing(let interface):
            return "Connectivity lost after spoofing interface: \(interface)"
        case .interfaceNotSpoofed(let interface):
            return "Interface not currently spoofed: \(interface)"
        case .originalMACNotFound(let interface):
            return "Original MAC address not found for interface: \(interface)"
        case .macRestoreFailed(let interface, let error):
            return "Failed to restore MAC for interface \(interface): \(error.localizedDescription)"
        case .invalidMACFormat(let mac):
            return "Invalid MAC address format: \(mac)"
        case .interfaceNotFound(let interface):
            return "Interface not found: \(interface)"
        case .macChangeVerificationFailed(let interface, let expected, let actual):
            return "MAC change verification failed for \(interface). Expected: \(expected), Actual: \(actual)"
        }
    }
}

/// Manager for handling MAC address spoofing operations with security and rollback capabilities
/// Implements transactional behavior for safe network interface modifications
public class MacAddressSpoofingManager {
    
    // MARK: - Dependencies
    private let networkManager: NetworkInterfaceManager
    private let repository: MacAddressRepository
    private let commandExecutor: SystemCommandExecutor
    private let logger: PrivarionLogger
    
    // MARK: - State Management
    private var activeSpoofingOperations: [String: SpoofingOperation] = [:]
    private let operationQueue = DispatchQueue(label: "com.privarion.mac-spoofing", qos: .userInitiated)
    
    // MARK: - Initialization
    public init(
        networkManager: NetworkInterfaceManager = NetworkInterfaceManager(),
        repository: MacAddressRepository = MacAddressRepository(),
        commandExecutor: SystemCommandExecutor = SystemCommandExecutor(logger: PrivarionLogger.shared),
        logger: PrivarionLogger = PrivarionLogger.shared
    ) {
        self.networkManager = networkManager
        self.repository = repository
        self.commandExecutor = commandExecutor
        self.logger = logger
        
        // Restore any incomplete operations on startup
        restoreIncompleteOperations()
    }
    
    // MARK: - Public Interface
    
    /// Lists all available network interfaces that can be spoofed
    public func listAvailableInterfaces() async throws -> [NetworkInterface] {
        logger.info("Listing available network interfaces for spoofing")
        
        do {
            let interfaces = try await networkManager.enumerateInterfaces()
            let spoofableInterfaces = interfaces.filter { $0.isEligibleForSpoofing }
            
            logger.info("Found \(spoofableInterfaces.count) spoofable interfaces")
            return spoofableInterfaces
        } catch {
            logger.error("Failed to enumerate network interfaces: \(error)")
            throw MacSpoofingError.networkInterfaceEnumerationFailed(error)
        }
    }
    
    /// Spoofs the MAC address for a specific interface
    public func spoofMACAddress(
        interface: String,
        customMAC: String? = nil,
        preserveVendorPrefix: Bool = true
    ) async throws {
        try await performSpoofingOperation(
            interface: interface,
            customMAC: customMAC,
            preserveVendorPrefix: preserveVendorPrefix
        )
    }
    
    /// Restores the original MAC address for a specific interface
    public func restoreOriginalMAC(interface: String) async throws {
        try await performRestoreOperation(interface: interface)
    }
    
    /// Restores all interfaces to their original MAC addresses
    public func restoreAllInterfaces() async throws {
        logger.info("Restoring all interfaces to original MAC addresses")
        
        let spoofedInterfaces = repository.getSpoofedInterfaces()
        var errors: [Error] = []
        
        for interface in spoofedInterfaces {
            do {
                try await restoreOriginalMAC(interface: interface)
            } catch {
                errors.append(error)
                logger.error("Failed to restore interface \(interface): \(error)")
            }
        }
        
        if !errors.isEmpty {
            throw MacSpoofingError.multipleInterfaceRestoreFailed(errors)
        }
        
        logger.info("Successfully restored all interfaces")
    }
    
    /// Gets the current status of all network interfaces
    public func getInterfaceStatus() async throws -> [InterfaceStatus] {
        logger.debug("Getting status for all network interfaces")
        
        do {
            let interfaces = try await networkManager.enumerateInterfaces()
            let spoofedInterfaces = Set(repository.getSpoofedInterfaces())
            
            return interfaces.map { interface in
                InterfaceStatus(
                    name: interface.name,
                    currentMAC: interface.macAddress,
                    originalMAC: repository.getOriginalMAC(for: interface.name),
                    isActive: interface.isActive,
                    isSpoofed: spoofedInterfaces.contains(interface.name),
                    interfaceType: interface.type
                )
            }
        } catch {
            logger.error("Failed to get interface status: \(error)")
            throw MacSpoofingError.interfaceStatusRetrievalFailed(error)
        }
    }
    
    // MARK: - Private Implementation
    
    private func performSpoofingOperation(
        interface: String,
        customMAC: String?,
        preserveVendorPrefix: Bool
    ) async throws {
        logger.info("Starting MAC spoofing operation for interface: \(interface)")
        
        // Validate interface
        guard let networkInterface = try await networkManager.getInterface(name: interface) else {
            throw MacSpoofingError.invalidNetworkInterface(interface)
        }
        
        // Check if already spoofed
        if repository.isSpoofed(interface: interface) {
            logger.warning("Interface \(interface) is already spoofed")
            throw MacSpoofingError.interfaceAlreadySpoofed(interface)
        }
        
        // Generate or validate new MAC address
        let newMAC: String
        if let customMAC = customMAC {
            try validateMACAddress(customMAC)
            newMAC = customMAC
        } else {
            newMAC = try generateRandomMAC(
                preserveVendorPrefix: preserveVendorPrefix,
                originalMAC: networkInterface.macAddress
            )
        }
        
        // Create spoofing operation
        let operation = SpoofingOperation(
            interface: interface,
            originalMAC: networkInterface.macAddress,
            newMAC: newMAC,
            timestamp: Date()
        )
        
        activeSpoofingOperations[interface] = operation
        
        do {
            // Backup original MAC address
            try await repository.backupOriginalMAC(interface: interface, macAddress: networkInterface.macAddress)
            
            // Test network connectivity before change
            let connectivityBefore = try await networkManager.testConnectivity(interface: interface)
            logger.debug("Connectivity before spoofing: \(connectivityBefore)")
            
            // Perform the MAC address change
            try await networkManager.changeMACAddress(interface: interface, newMAC: newMAC)
            
            // Verify the change was successful
            try await verifyMACChange(interface: interface, expectedMAC: newMAC)
            
            // Test connectivity after change
            let connectivityAfter = try await networkManager.testConnectivity(interface: interface)
            logger.debug("Connectivity after spoofing: \(connectivityAfter)")
            
            if !connectivityAfter && connectivityBefore {
                logger.warning("Connectivity lost after MAC change, attempting rollback")
                try await performEmergencyRollback(operation: operation)
                throw MacSpoofingError.connectivityLostAfterSpoofing(interface)
            }
            
            // Mark operation as successful
            try repository.markAsSpoofed(interface: interface, originalMAC: networkInterface.macAddress)
            activeSpoofingOperations.removeValue(forKey: interface)
            
            logger.info("Successfully spoofed MAC address for interface \(interface): \(networkInterface.macAddress) -> \(newMAC)")
            
        } catch {
            // Rollback on any failure
            activeSpoofingOperations.removeValue(forKey: interface)
            
            do {
                try await performEmergencyRollback(operation: operation)
            } catch let rollbackError {
                logger.error("Failed to rollback after spoofing failure: \(rollbackError)")
                // Don't mask the original error
            }
            
            throw error
        }
    }
    
    private func performRestoreOperation(interface: String) async throws {
        logger.info("Restoring original MAC address for interface: \(interface)")
        
        guard repository.isSpoofed(interface: interface) else {
            logger.warning("Interface \(interface) is not currently spoofed")
            throw MacSpoofingError.interfaceNotSpoofed(interface)
        }
        
        guard let originalMAC = repository.getOriginalMAC(for: interface) else {
            logger.error("Original MAC address not found for interface: \(interface)")
            throw MacSpoofingError.originalMACNotFound(interface)
        }
        
        do {
            // Perform the MAC address restoration
            try await networkManager.changeMACAddress(interface: interface, newMAC: originalMAC)
            
            // Verify the restoration was successful
            try await verifyMACChange(interface: interface, expectedMAC: originalMAC)
            
            // Clean up repository
            try repository.removeBackup(interface: interface)
            
            logger.info("Successfully restored original MAC address for interface \(interface): \(originalMAC)")
            
        } catch {
            logger.error("Failed to restore MAC address for interface \(interface): \(error)")
            throw MacSpoofingError.macRestoreFailed(interface, error)
        }
    }
    
    private func generateRandomMAC(preserveVendorPrefix: Bool, originalMAC: String) throws -> String {
        if preserveVendorPrefix {
            // Keep the first 3 octets (vendor prefix)
            let components = originalMAC.split(separator: ":").map(String.init)
            guard components.count == 6 else {
                throw MacSpoofingError.invalidMACFormat(originalMAC)
            }
            
            let vendorPrefix = components[0...2].joined(separator: ":")
            let randomSuffix = generateRandomMACOctets(count: 3)
            return "\(vendorPrefix):\(randomSuffix)"
        } else {
            // Generate completely random MAC with local admin bit set
            return generateCompletelyRandomMAC()
        }
    }
    
    private func generateRandomMACOctets(count: Int) -> String {
        var octets: [String] = []
        for _ in 0..<count {
            let randomByte = UInt8.random(in: 0...255)
            octets.append(String(format: "%02x", randomByte))
        }
        return octets.joined(separator: ":")
    }
    
    private func generateCompletelyRandomMAC() -> String {
        // Generate random MAC with locally administered bit set (bit 1 of first octet)
        var octets: [String] = []
        
        // First octet: set locally administered bit (0x02) and clear multicast bit (0x01)
        let firstOctet = UInt8.random(in: 0...255) | 0x02 & 0xFE
        octets.append(String(format: "%02x", firstOctet))
        
        // Remaining octets
        for _ in 1..<6 {
            let randomByte = UInt8.random(in: 0...255)
            octets.append(String(format: "%02x", randomByte))
        }
        
        return octets.joined(separator: ":")
    }
    
    private func validateMACAddress(_ mac: String) throws {
        let macPattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        let regex = try NSRegularExpression(pattern: macPattern)
        let range = NSRange(location: 0, length: mac.utf16.count)
        
        guard regex.firstMatch(in: mac, options: [], range: range) != nil else {
            throw MacSpoofingError.invalidMACFormat(mac)
        }
    }
    
    private func verifyMACChange(interface: String, expectedMAC: String) async throws {
        // Wait a moment for the change to take effect
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        guard let updatedInterface = try await networkManager.getInterface(name: interface) else {
            throw MacSpoofingError.interfaceNotFound(interface)
        }
        
        guard updatedInterface.macAddress.lowercased() == expectedMAC.lowercased() else {
            throw MacSpoofingError.macChangeVerificationFailed(
                interface: interface,
                expected: expectedMAC,
                actual: updatedInterface.macAddress
            )
        }
    }
    
    private func performEmergencyRollback(operation: SpoofingOperation) async throws {
        logger.warning("Performing emergency rollback for interface: \(operation.interface)")
        
        try await networkManager.changeMACAddress(
            interface: operation.interface,
            newMAC: operation.originalMAC
        )
        
        // Clean up any partial state
        do {
            try repository.removeBackup(interface: operation.interface)
        } catch {
            logger.warning("Failed to remove backup during emergency rollback: \(error.localizedDescription)")
        }
    }
    
    private func restoreIncompleteOperations() {
        logger.info("Checking for incomplete spoofing operations on startup")
        
        let spoofedInterfaces = repository.getSpoofedInterfaces()
        if !spoofedInterfaces.isEmpty {
            logger.info("Found \(spoofedInterfaces.count) interfaces with incomplete operations, attempting recovery")
            
            // Schedule async recovery in background
            Task {
                for interface in spoofedInterfaces {
                    do {
                        // Verify if the interface is actually spoofed
                        if let currentInterface = try? await networkManager.getInterface(name: interface),
                           let originalMAC = repository.getOriginalMAC(for: interface),
                           currentInterface.macAddress.lowercased() != originalMAC.lowercased() {
                            logger.info("Interface \(interface) is confirmed spoofed, marking as active")
                        } else {
                            // Interface is not actually spoofed, clean up repository
                            try repository.removeBackup(interface: interface)
                            logger.info("Cleaned up stale spoofing record for interface \(interface)")
                        }
                    } catch {
                        logger.error("Failed to verify spoofing state for interface \(interface): \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

/// Represents an active spoofing operation
private struct SpoofingOperation {
    let interface: String
    let originalMAC: String
    let newMAC: String
    let timestamp: Date
}

/// Status information for a network interface
public struct InterfaceStatus: Codable {
    public let name: String
    public let currentMAC: String
    public let originalMAC: String?
    public let isActive: Bool
    public let isSpoofed: Bool
    public let interfaceType: NetworkInterfaceType
}
