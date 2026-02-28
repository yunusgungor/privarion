// PrivarionSystemExtension - SystemExtensionCoordinator
// Coordinates System Extension request submission, entitlement validation, and activation handling
// Requirements: 1.1-1.8, 12.1-12.10

import Foundation
import SystemExtensions
import Logging
import PrivarionSharedModels

/// Coordinates System Extension lifecycle operations
/// Handles request submission, entitlement validation, and activation result processing
public class SystemExtensionCoordinator: NSObject {
    private let logger = Logger(label: "com.privarion.system-extension.coordinator")
    private let extensionIdentifier: String
    
    // Required entitlements for System Extension
    private let requiredEntitlements = [
        "com.apple.developer.system-extension.install",
        "com.apple.developer.endpoint-security.client"
    ]
    
    // Continuation for async/await support
    private var activationContinuation: CheckedContinuation<Void, Error>?
    
    /// Initialize coordinator with extension identifier
    /// - Parameter extensionIdentifier: Bundle identifier of the system extension
    public init(extensionIdentifier: String) {
        self.extensionIdentifier = extensionIdentifier
        super.init()
    }
    
    /// Submit a system extension request
    /// - Parameter request: The OSSystemExtensionRequest to submit
    /// - Throws: SystemExtensionError if submission fails
    public func submitRequest(_ request: OSSystemExtensionRequest) async throws {
        logger.info("Submitting system extension request", metadata: [
            "identifier": .string(extensionIdentifier)
        ])
        
        // Validate entitlements before submission
        try validateEntitlements()
        
        // Submit request using async/await pattern
        return try await withCheckedThrowingContinuation { continuation in
            self.activationContinuation = continuation
            
            // Set delegate to receive callbacks
            request.delegate = self
            
            // Submit request to system
            OSSystemExtensionManager.shared.submitRequest(request)
        }
    }
    
    /// Validate that required entitlements are present
    /// - Throws: SystemExtensionError.entitlementMissing if any required entitlement is missing
    public func validateEntitlements() throws {
        logger.info("Validating system extension entitlements")
        
        // Get the main bundle's entitlements
        guard let entitlements = Bundle.main.object(forInfoDictionaryKey: "Entitlements") as? [String: Any] else {
            // If we can't read entitlements from Info.plist, check the embedded provisioning profile
            // In production, entitlements are embedded in the code signature
            logger.warning("Could not read entitlements from Info.plist, checking code signature")
            
            // For now, we'll validate by attempting to access the entitlements
            // In a real implementation, this would use Security framework to read code signature
            return try validateEntitlementsFromCodeSignature()
        }
        
        // Check each required entitlement
        for entitlement in requiredEntitlements {
            guard entitlements[entitlement] != nil else {
                logger.error("Missing required entitlement", metadata: [
                    "entitlement": .string(entitlement)
                ])
                throw SystemExtensionError.entitlementMissing(entitlement)
            }
        }
        
        logger.info("All required entitlements present")
    }
    
    /// Validate entitlements from code signature
    /// This is a placeholder for production implementation that would use Security framework
    private func validateEntitlementsFromCodeSignature() throws {
        // In production, this would use SecCodeCopySigningInformation to read entitlements
        // For now, we'll assume entitlements are present if the app is properly signed
        
        // Check if running in development or production
        #if DEBUG
        logger.warning("Running in DEBUG mode, skipping strict entitlement validation")
        #else
        // In production, validate code signature
        guard let executableURL = Bundle.main.executableURL else {
            throw SystemExtensionError.installationFailed(reason: "Could not locate executable")
        }
        
        // Verify code signature exists
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        task.arguments = ["--verify", "--verbose", executableURL.path]
        
        let pipe = Pipe()
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SystemExtensionError.installationFailed(reason: "Code signature verification failed: \(output)")
            }
        } catch {
            throw SystemExtensionError.installationFailed(reason: "Failed to verify code signature: \(error.localizedDescription)")
        }
        #endif
    }
    
    /// Handle activation result from system extension request
    /// - Parameter result: The OSSystemExtensionRequest.Result indicating success or failure
    public func handleActivationResult(_ result: OSSystemExtensionRequest.Result) {
        logger.info("Handling activation result", metadata: [
            "result": .string(String(describing: result))
        ])
        
        switch result {
        case .completed:
            logger.info("System extension activation completed successfully")
            activationContinuation?.resume()
            activationContinuation = nil
            
        case .willCompleteAfterReboot:
            logger.info("System extension will complete after reboot")
            // For now, treat this as success
            // In production, might want to notify user about reboot requirement
            activationContinuation?.resume()
            activationContinuation = nil
            
        @unknown default:
            logger.error("Unknown activation result")
            let error = SystemExtensionError.installationFailed(reason: "Unknown activation result")
            activationContinuation?.resume(throwing: error)
            activationContinuation = nil
        }
    }
}

// MARK: - OSSystemExtensionRequestDelegate

extension SystemExtensionCoordinator: OSSystemExtensionRequestDelegate {
    
    /// Called when the request requires user approval
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
        handleActivationResult(result)
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
                mappedError = .installationFailed(reason: "Request canceled")
            case .requestSuperseded:
                mappedError = .installationFailed(reason: "Request superseded")
            case .validationFailed:
                mappedError = .notarizationFailed
            case .unsupportedParentBundleLocation:
                mappedError = .installationFailed(reason: "Unsupported parent bundle location")
            case .unknown:
                mappedError = .installationFailed(reason: "Unknown error")
            case .missingEntitlement:
                mappedError = .entitlementMissing("Unknown entitlement")
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
        
        activationContinuation?.resume(throwing: mappedError)
        activationContinuation = nil
    }
    
    /// Called when user approval is required
    public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.info("System extension requires user approval - system dialog will be shown")
        // System will show approval dialog automatically
        // No action needed here
    }
}
