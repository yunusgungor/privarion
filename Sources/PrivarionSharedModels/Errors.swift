// PrivarionSharedModels - Error Definitions
// Comprehensive error handling for all system extension components
// Requirements: 1.5, 2.9, 3.11, 8.9, 15.6, 19.1-19.11

import Foundation
import SystemExtensions

/// Errors related to System Extension installation and lifecycle
public enum SystemExtensionError: Error, LocalizedError {
    case installationFailed(reason: String)
    case activationFailed(OSSystemExtensionError.Code)
    case entitlementMissing(String)
    case notarizationFailed
    case userDeniedApproval
    case incompatibleMacOSVersion
    
    public var errorDescription: String? {
        switch self {
        case .installationFailed(let reason):
            return "System Extension installation failed: \(reason)"
        case .activationFailed(let code):
            return "System Extension activation failed with code: \(code.rawValue)"
        case .entitlementMissing(let entitlement):
            return "Required entitlement missing: \(entitlement)"
        case .notarizationFailed:
            return "System Extension notarization failed"
        case .userDeniedApproval:
            return "User denied System Extension approval"
        case .incompatibleMacOSVersion:
            return "Incompatible macOS version. Requires macOS 13.0 or later"
        }
    }
}

/// Errors related to Endpoint Security Framework operations
public enum EndpointSecurityError: Error, LocalizedError {
    case clientInitializationFailed(Int32)
    case subscriptionFailed(UInt32)
    case fullDiskAccessDenied
    case eventProcessingTimeout
    case clientDisconnected
    
    public var errorDescription: String? {
        switch self {
        case .clientInitializationFailed(let result):
            return "Endpoint Security client initialization failed with result: \(result)"
        case .subscriptionFailed(let eventType):
            return "Failed to subscribe to event type: \(eventType)"
        case .fullDiskAccessDenied:
            return "Full Disk Access permission denied. Please grant permission in System Preferences > Privacy & Security"
        case .eventProcessingTimeout:
            return "Event processing exceeded timeout threshold"
        case .clientDisconnected:
            return "Endpoint Security client disconnected unexpectedly"
        }
    }
}

/// Errors related to Network Extension operations
public enum NetworkExtensionError: Error, LocalizedError {
    case tunnelStartFailed(Error)
    case tunnelConfigurationInvalid
    case packetProcessingFailed
    case dnsProxyBindFailed(port: Int)
    case networkSettingsRestoreFailed
    
    public var errorDescription: String? {
        switch self {
        case .tunnelStartFailed(let error):
            return "Packet tunnel failed to start: \(error.localizedDescription)"
        case .tunnelConfigurationInvalid:
            return "Packet tunnel configuration is invalid"
        case .packetProcessingFailed:
            return "Packet processing failed"
        case .dnsProxyBindFailed(let port):
            return "DNS proxy failed to bind to port \(port)"
        case .networkSettingsRestoreFailed:
            return "Failed to restore original network settings"
        }
    }
}

/// Errors related to Virtual Machine operations
public enum VMError: Error, LocalizedError {
    case configurationInvalid(String)
    case resourceAllocationFailed
    case vmStartFailed(Error)
    case vmCrashed(reason: String)
    case snapshotFailed
    case diskImageCorrupted
    
    public var errorDescription: String? {
        switch self {
        case .configurationInvalid(let details):
            return "VM configuration is invalid: \(details)"
        case .resourceAllocationFailed:
            return "Failed to allocate resources for VM"
        case .vmStartFailed(let error):
            return "VM failed to start: \(error.localizedDescription)"
        case .vmCrashed(let reason):
            return "VM crashed: \(reason)"
        case .snapshotFailed:
            return "VM snapshot operation failed"
        case .diskImageCorrupted:
            return "VM disk image is corrupted"
        }
    }
}

/// Errors related to configuration parsing and validation
public enum ConfigurationError: Error, LocalizedError {
    case fileNotFound(URL)
    case parseError(line: Int, message: String)
    case validationFailed([String])
    case schemaVersionMismatch
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "Configuration file not found at: \(url.path)"
        case .parseError(let line, let message):
            return "Configuration parse error at line \(line): \(message)"
        case .validationFailed(let errors):
            return "Configuration validation failed:\n" + errors.joined(separator: "\n")
        case .schemaVersionMismatch:
            return "Configuration schema version mismatch"
        }
    }
}
