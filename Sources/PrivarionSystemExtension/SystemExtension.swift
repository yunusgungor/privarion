// PrivarionSystemExtension
// System Extension for system-level privacy protection
// Requirements: 1.1-1.8, 12.1-12.10

import Foundation
import SystemExtensions
import Logging
import PrivarionSharedModels

/// Main System Extension entry point
/// Manages System Extension lifecycle, installation, activation, and status monitoring
/// Conforms to OSSystemExtensionRequestDelegate for handling system callbacks
public class PrivarionSystemExtension: NSObject, OSSystemExtensionRequestDelegate {
    private let logger = Logger(label: "com.privarion.system-extension")
    private let coordinator: SystemExtensionCoordinator
    private let extensionIdentifier: String
    
    // Status observers for notification
    private var statusObservers: [SystemExtensionStatusObserver] = []
    
    // Current extension status
    private var currentStatus: ExtensionStatus = .notInstalled
    
    // Persistence manager
    private let persistenceManager: ExtensionStatusPersistence
    
    /// Initialize with extension identifier
    /// - Parameter extensionIdentifier: Bundle identifier of the system extension (defaults to com.privarion.system-extension)
    public init(extensionIdentifier: String = "com.privarion.system-extension") {
        self.extensionIdentifier = extensionIdentifier
        self.coordinator = SystemExtensionCoordinator(extensionIdentifier: extensionIdentifier)
        self.persistenceManager = ExtensionStatusPersistence()
        super.init()
        
        // Load persisted status on initialization
        loadPersistedStatus()
    }
    
    /// Install the system extension
    /// Creates and submits an installation request to the system
    /// - Throws: SystemExtensionError if installation fails
    public func installExtension() async throws {
        logger.info("System Extension installation requested", metadata: [
            "identifier": .string(extensionIdentifier)
        ])
        
        // Check macOS version compatibility
        guard #available(macOS 13.0, *) else {
            logger.error("Incompatible macOS version")
            throw SystemExtensionError.incompatibleMacOSVersion
        }
        
        // Update status to activating
        updateStatus(.activating)
        
        do {
            // Create activation request
            let request = OSSystemExtensionRequest.activationRequest(
                forExtensionWithIdentifier: extensionIdentifier,
                queue: .main
            )
            
            // Submit request through coordinator
            try await coordinator.submitRequest(request)
            
            logger.info("System Extension installation completed successfully")
            
            // Update status to active
            updateStatus(.active)
            
        } catch {
            logger.error("System Extension installation failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            
            // Update status to error with error message
            updateStatus(.error(error.localizedDescription))
            
            throw error
        }
    }
    
    /// Activate the system extension
    /// Activates an already installed extension
    /// - Throws: SystemExtensionError if activation fails
    public func activateExtension() async throws {
        logger.info("System Extension activation requested", metadata: [
            "identifier": .string(extensionIdentifier)
        ])
        
        // Check macOS version compatibility
        guard #available(macOS 13.0, *) else {
            logger.error("Incompatible macOS version")
            throw SystemExtensionError.incompatibleMacOSVersion
        }
        
        // Update status to activating
        updateStatus(.activating)
        
        do {
            // Create activation request
            let request = OSSystemExtensionRequest.activationRequest(
                forExtensionWithIdentifier: extensionIdentifier,
                queue: .main
            )
            
            // Submit request through coordinator
            try await coordinator.submitRequest(request)
            
            logger.info("System Extension activation completed successfully")
            
            // Update status to active
            updateStatus(.active)
            
        } catch {
            logger.error("System Extension activation failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            
            // Update status to error with error message
            updateStatus(.error(error.localizedDescription))
            
            throw error
        }
    }
    
    /// Deactivate the system extension
    /// Deactivates a running extension
    /// - Throws: SystemExtensionError if deactivation fails
    public func deactivateExtension() async throws {
        logger.info("System Extension deactivation requested", metadata: [
            "identifier": .string(extensionIdentifier)
        ])
        
        // Check macOS version compatibility
        guard #available(macOS 13.0, *) else {
            logger.error("Incompatible macOS version")
            throw SystemExtensionError.incompatibleMacOSVersion
        }
        
        // Update status to deactivating
        updateStatus(.deactivating)
        
        do {
            // Create deactivation request
            let request = OSSystemExtensionRequest.deactivationRequest(
                forExtensionWithIdentifier: extensionIdentifier,
                queue: .main
            )
            
            // Submit request through coordinator
            try await coordinator.submitRequest(request)
            
            logger.info("System Extension deactivation completed successfully")
            
            // Update status to installed (but not active)
            updateStatus(.installed)
            
        } catch {
            logger.error("System Extension deactivation failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            
            // Update status to error with error message
            updateStatus(.error(error.localizedDescription))
            
            throw error
        }
    }
    
    /// Check current extension status
    /// Queries the system for the current state of the extension
    /// - Returns: Current ExtensionStatus
    public func checkStatus() async -> ExtensionStatus {
        logger.info("Checking System Extension status", metadata: [
            "identifier": .string(extensionIdentifier)
        ])
        
        // Check macOS version compatibility
        guard #available(macOS 13.0, *) else {
            logger.warning("Incompatible macOS version")
            return .error(SystemExtensionError.incompatibleMacOSVersion.localizedDescription)
        }
        
        // Query system for extension properties
        // Note: OSSystemExtensionManager doesn't provide a direct status query API
        // We maintain status based on request results and delegate callbacks
        
        // Return current cached status
        logger.info("Current extension status", metadata: [
            "status": .string(String(describing: currentStatus))
        ])
        
        return currentStatus
    }
    
    /// Add a status observer
    /// - Parameter observer: Observer to receive status change notifications
    public func addStatusObserver(_ observer: SystemExtensionStatusObserver) {
        statusObservers.append(observer)
        logger.debug("Status observer added", metadata: [
            "observer_count": .stringConvertible(statusObservers.count)
        ])
    }
    
    /// Remove a status observer
    /// - Parameter observer: Observer to remove
    public func removeStatusObserver(_ observer: SystemExtensionStatusObserver) {
        statusObservers.removeAll { $0 === observer }
        logger.debug("Status observer removed", metadata: [
            "observer_count": .stringConvertible(statusObservers.count)
        ])
    }
    
    // MARK: - Private Methods
    
    /// Load persisted status from disk
    private func loadPersistedStatus() {
        do {
            if let status = try persistenceManager.loadStatus() {
                currentStatus = status
                logger.info("Loaded persisted extension status", metadata: [
                    "status": .string(String(describing: status))
                ])
            } else {
                logger.debug("No persisted status found, using default")
            }
        } catch {
            logger.warning("Failed to load persisted status", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }
    
    /// Update status and notify observers
    private func updateStatus(_ newStatus: ExtensionStatus) {
        currentStatus = newStatus
        
        // Persist status to disk
        do {
            try persistenceManager.saveStatus(newStatus)
            logger.debug("Status persisted to disk")
        } catch {
            logger.warning("Failed to persist status", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
        
        // Notify all observers
        for observer in statusObservers {
            observer.extensionStatusDidChange(newStatus)
        }
        
        logger.debug("Status updated and observers notified", metadata: [
            "status": .string(String(describing: newStatus)),
            "observer_count": .stringConvertible(statusObservers.count)
        ])
    }
    
    // MARK: - OSSystemExtensionRequestDelegate
    
    /// Called when the request requires user approval for replacing an existing extension
    public func request(_ request: OSSystemExtensionRequest,
                       actionForReplacingExtension existing: OSSystemExtensionProperties,
                       withExtension ext: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        logger.info("System extension replacement requested", metadata: [
            "existing_version": .string(existing.bundleVersion),
            "new_version": .string(ext.bundleVersion)
        ])
        
        // Allow replacement (upgrade)
        return .replace
    }
    
    /// Called when the request completes successfully
    public func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        logger.info("System extension request finished", metadata: [
            "result": .string(String(describing: result))
        ])
        
        // Handle result based on type
        switch result {
        case .completed:
            logger.info("System extension request completed successfully")
            updateStatus(.active)
            
        case .willCompleteAfterReboot:
            logger.info("System extension will complete after reboot")
            // Extension is installed but requires reboot
            updateStatus(.installed)
            
        @unknown default:
            logger.warning("Unknown system extension request result")
            updateStatus(.error("Unknown result"))
        }
    }
    
    /// Called when the request fails
    public func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        logger.error("System extension request failed", metadata: [
            "error": .string(error.localizedDescription)
        ])
        
        // Map error to SystemExtensionError
        let mappedError: SystemExtensionError
        
        if let osError = error as? OSSystemExtensionError {
            switch osError.code {
            case .authorizationRequired:
                mappedError = .userDeniedApproval
            case .extensionNotFound:
                mappedError = .installationFailed(reason: "Extension not found")
            case .extensionMissingIdentifier:
                mappedError = .installationFailed(reason: "Extension missing identifier")
            case .duplicateExtensionIdentifer:
                mappedError = .installationFailed(reason: "Duplicate extension identifier")
            case .forbiddenBySystemPolicy:
                mappedError = .installationFailed(reason: "Forbidden by system policy")
            case .requestCanceled:
                mappedError = .installationFailed(reason: "Request canceled by user")
            case .requestSuperseded:
                mappedError = .installationFailed(reason: "Request superseded by another request")
            case .validationFailed:
                mappedError = .notarizationFailed
            case .unsupportedParentBundleLocation:
                mappedError = .installationFailed(reason: "Unsupported parent bundle location")
            case .unknown:
                mappedError = .installationFailed(reason: "Unknown error")
            case .missingEntitlement:
                mappedError = .entitlementMissing("Required entitlement missing")
            case .unknownExtensionCategory:
                mappedError = .installationFailed(reason: "Unknown extension category")
            case .codeSignatureInvalid:
                mappedError = .notarizationFailed
            @unknown default:
                mappedError = .activationFailed(osError.code)
            }
        } else {
            mappedError = .installationFailed(reason: error.localizedDescription)
        }
        
        // Update status to error with error message
        updateStatus(.error(mappedError.localizedDescription))
    }
    
    /// Called when user approval is required
    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.info("System extension requires user approval - system dialog will be shown")
        // System will show approval dialog automatically
        // No action needed here, but we can notify observers
        updateStatus(.activating)
    }
}

/// Extension status enumeration
public enum ExtensionStatus: Codable {
    case notInstalled
    case installed
    case active
    case activating
    case deactivating
    case error(String) // Changed from Error to String for Codable conformance
    
    // Custom coding keys for enum with associated values
    private enum CodingKeys: String, CodingKey {
        case type
        case errorMessage
    }
    
    // Custom encoding
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .notInstalled:
            try container.encode("notInstalled", forKey: .type)
        case .installed:
            try container.encode("installed", forKey: .type)
        case .active:
            try container.encode("active", forKey: .type)
        case .activating:
            try container.encode("activating", forKey: .type)
        case .deactivating:
            try container.encode("deactivating", forKey: .type)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .errorMessage)
        }
    }
    
    // Custom decoding
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "notInstalled":
            self = .notInstalled
        case "installed":
            self = .installed
        case "active":
            self = .active
        case "activating":
            self = .activating
        case "deactivating":
            self = .deactivating
        case "error":
            let message = try container.decode(String.self, forKey: .errorMessage)
            self = .error(message)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown extension status type: \(type)"
            )
        }
    }
}

/// Protocol for observing extension status changes
public protocol SystemExtensionStatusObserver: AnyObject {
    func extensionStatusDidChange(_ status: ExtensionStatus)
}

/// Manages persistence of extension status across app restarts
/// Stores status in /Library/Application Support/Privarion/extension-status.json
internal class ExtensionStatusPersistence {
    private let logger = Logger(label: "com.privarion.system-extension.persistence")
    private let fileManager = FileManager.default
    
    // Persistence directory and file path
    private let persistenceDirectory: URL
    private let statusFilePath: URL
    
    /// Initialize with optional custom directory (for testing)
    /// - Parameter customDirectory: Optional custom directory path for testing
    init(customDirectory: URL? = nil) {
        if let customDir = customDirectory {
            // Use custom directory for testing
            self.persistenceDirectory = customDir
        } else {
            // Use /Library/Application Support/Privarion/ for system-wide persistence
            // Fall back to user's home directory if system directory is not writable
            let libraryDirectory = URL(fileURLWithPath: "/Library/Application Support")
            let systemDirectory = libraryDirectory.appendingPathComponent("Privarion", isDirectory: true)
            
            // Check if we can write to system directory
            if fileManager.isWritableFile(atPath: libraryDirectory.path) {
                self.persistenceDirectory = systemDirectory
            } else {
                // Fall back to user's Application Support directory
                let userLibrary = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                self.persistenceDirectory = userLibrary.appendingPathComponent("Privarion", isDirectory: true)
            }
        }
        
        self.statusFilePath = persistenceDirectory.appendingPathComponent("extension-status.json")
        
        // Ensure directory exists
        createDirectoryIfNeeded()
    }
    
    /// Create persistence directory if it doesn't exist
    private func createDirectoryIfNeeded() {
        guard !fileManager.fileExists(atPath: persistenceDirectory.path) else {
            return
        }
        
        do {
            try fileManager.createDirectory(
                at: persistenceDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.info("Created persistence directory", metadata: [
                "path": .string(persistenceDirectory.path)
            ])
        } catch {
            logger.error("Failed to create persistence directory", metadata: [
                "path": .string(persistenceDirectory.path),
                "error": .string(error.localizedDescription)
            ])
        }
    }
    
    /// Save extension status to disk
    /// - Parameter status: The status to persist
    /// - Throws: Error if saving fails
    func saveStatus(_ status: ExtensionStatus) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(status)
        
        // Write atomically to prevent corruption
        try data.write(to: statusFilePath, options: .atomic)
        
        logger.debug("Extension status saved", metadata: [
            "path": .string(statusFilePath.path),
            "status": .string(String(describing: status))
        ])
    }
    
    /// Load extension status from disk
    /// - Returns: The persisted status, or nil if no status file exists
    /// - Throws: Error if loading fails
    func loadStatus() throws -> ExtensionStatus? {
        // Check if file exists
        guard fileManager.fileExists(atPath: statusFilePath.path) else {
            logger.debug("No persisted status file found")
            return nil
        }
        
        let data = try Data(contentsOf: statusFilePath)
        let decoder = JSONDecoder()
        let status = try decoder.decode(ExtensionStatus.self, from: data)
        
        logger.debug("Extension status loaded", metadata: [
            "path": .string(statusFilePath.path),
            "status": .string(String(describing: status))
        ])
        
        return status
    }
    
    /// Clear persisted status
    func clearStatus() throws {
        guard fileManager.fileExists(atPath: statusFilePath.path) else {
            return
        }
        
        try fileManager.removeItem(at: statusFilePath)
        logger.info("Persisted status cleared", metadata: [
            "path": .string(statusFilePath.path)
        ])
    }
}
