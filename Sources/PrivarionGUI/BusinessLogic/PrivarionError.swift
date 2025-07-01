import Foundation
import Logging

/// Domain-specific error types for Privarion application
/// Following Clean Architecture error handling patterns
/// Provides structured error information with context and recovery suggestions
enum PrivarionError: LocalizedError {
    
    // MARK: - System Errors
    case systemInitializationFailed(reason: String)
    case systemStatusUnavailable
    case cliBackendNotResponding(timeout: TimeInterval)
    case permissionDenied(operation: String)
    
    // MARK: - Module Management Errors
    case moduleNotFound(moduleId: String)
    case moduleToggleFailed(moduleId: String, reason: String)
    case moduleConfigurationInvalid(moduleId: String, details: String)
    case moduleConflict(conflictingModules: [String])
    
    // MARK: - Profile Management Errors
    case profileNotFound(profileId: String)
    case profileCreationFailed(reason: String)
    case profileValidationFailed(errors: [String])
    case profileSwitchFailed(fromProfile: String, toProfile: String, reason: String)
    case profileDeleteFailed(profileId: String, reason: String)
    
    // MARK: - Configuration Errors
    case invalidConfiguration(key: String, value: String)
    case configurationSaveFailed(reason: String)
    case configurationLoadFailed(source: String)
    case configurationCorrupted(details: String)
    
    // MARK: - User Settings Errors
    case settingsExportFailed(reason: String)
    case settingsImportFailed(reason: String)
    case settingsValidationFailed(invalidKeys: [String])
    case settingsResetFailed(reason: String)
    
    // MARK: - Network/Communication Errors
    case networkError(underlying: Error)
    case apiError(statusCode: Int, message: String)
    case timeoutError(operation: String, timeout: TimeInterval)
    case connectionLost
    
    // MARK: - Data/Persistence Errors
    case dataCorruption(component: String)
    case storageError(operation: String, reason: String)
    case migrationFailed(fromVersion: String, toVersion: String)
    case backupFailed(reason: String)
    
    // MARK: - Validation Errors
    case invalidInput(field: String, value: String, requirement: String)
    case missingRequiredField(field: String)
    case valueTooLarge(field: String, value: String, maximum: String)
    case valueTooSmall(field: String, value: String, minimum: String)
    case inputTooLong(String)
    case invalidRange(String)
    case invalidDateRange(String)
    
    // MARK: - Business Logic Errors
    case invalidState(String)
    case operationNotAllowed(String)
    case businessRuleViolation(String)
    
    // MARK: - Security Errors
    case authenticationFailed
    case authorizationDenied(resource: String)
    case securityViolation(details: String)
    case cryptographicError(operation: String)
    
    // MARK: - System Operation Errors
    case systemOperation(SystemOperationError)
    
    // MARK: - Validation Errors (Extended)
    case validation(ValidationError)
    
    // MARK: - Unknown/Unexpected Errors
    case unknown(underlying: Error)
    case internalError(code: String, details: String)
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        // System Errors
        case .systemInitializationFailed(let reason):
            return "System initialization failed: \(reason)"
        case .systemStatusUnavailable:
            return "System status is currently unavailable"
        case .cliBackendNotResponding(let timeout):
            return "CLI backend not responding (timeout: \(timeout)s)"
        case .permissionDenied(let operation):
            return "Permission denied for operation: \(operation)"
            
        // Module Management Errors
        case .moduleNotFound(let moduleId):
            return "Module not found: \(moduleId)"
        case .moduleToggleFailed(let moduleId, let reason):
            return "Failed to toggle module \(moduleId): \(reason)"
        case .moduleConfigurationInvalid(let moduleId, let details):
            return "Invalid configuration for module \(moduleId): \(details)"
        case .moduleConflict(let conflictingModules):
            return "Module conflict detected: \(conflictingModules.joined(separator: ", "))"
            
        // Profile Management Errors
        case .profileNotFound(let profileId):
            return "Profile not found: \(profileId)"
        case .profileCreationFailed(let reason):
            return "Failed to create profile: \(reason)"
        case .profileValidationFailed(let errors):
            return "Profile validation failed: \(errors.joined(separator: ", "))"
        case .profileSwitchFailed(let fromProfile, let toProfile, let reason):
            return "Failed to switch from \(fromProfile) to \(toProfile): \(reason)"
        case .profileDeleteFailed(let profileId, let reason):
            return "Failed to delete profile \(profileId): \(reason)"
            
        // Configuration Errors
        case .invalidConfiguration(let key, let value):
            return "Invalid configuration - \(key): \(value)"
        case .configurationSaveFailed(let reason):
            return "Failed to save configuration: \(reason)"
        case .configurationLoadFailed(let source):
            return "Failed to load configuration from \(source)"
        case .configurationCorrupted(let details):
            return "Configuration corrupted: \(details)"
            
        // User Settings Errors
        case .settingsExportFailed(let reason):
            return "Failed to export settings: \(reason)"
        case .settingsImportFailed(let reason):
            return "Failed to import settings: \(reason)"
        case .settingsValidationFailed(let invalidKeys):
            return "Settings validation failed for keys: \(invalidKeys.joined(separator: ", "))"
        case .settingsResetFailed(let reason):
            return "Failed to reset settings: \(reason)"
            
        // Network/Communication Errors
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        case .timeoutError(let operation, let timeout):
            return "Operation \(operation) timed out after \(timeout)s"
        case .connectionLost:
            return "Connection lost to backend service"
            
        // Data/Persistence Errors
        case .dataCorruption(let component):
            return "Data corruption detected in \(component)"
        case .storageError(let operation, let reason):
            return "Storage error during \(operation): \(reason)"
        case .migrationFailed(let fromVersion, let toVersion):
            return "Migration failed from \(fromVersion) to \(toVersion)"
        case .backupFailed(let reason):
            return "Backup operation failed: \(reason)"
            
        // Validation Errors
        case .invalidInput(let field, let value, let requirement):
            return "Invalid input for \(field): '\(value)' (required: \(requirement))"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .valueTooLarge(let field, let value, let maximum):
            return "Value too large for \(field): '\(value)' (maximum: \(maximum))"
        case .valueTooSmall(let field, let value, let minimum):
            return "Value too small for \(field): '\(value)' (minimum: \(minimum))"
        case .inputTooLong(let message):
            return "Input too long: \(message)"
        case .invalidRange(let message):
            return "Invalid range: \(message)"
        case .invalidDateRange(let message):
            return "Invalid date range: \(message)"
            
        // Business Logic Errors
        case .invalidState(let message):
            return "Invalid state: \(message)"
        case .operationNotAllowed(let message):
            return "Operation not allowed: \(message)"
        case .businessRuleViolation(let message):
            return "Business rule violation: \(message)"
            
        // Security Errors
        case .authenticationFailed:
            return "Authentication failed"
        case .authorizationDenied(let resource):
            return "Authorization denied for resource: \(resource)"
        case .securityViolation(let details):
            return "Security violation: \(details)"
        case .cryptographicError(let operation):
            return "Cryptographic error during \(operation)"
            
        // System Operation Errors
        case .systemOperation(let error):
            return error.errorDescription
            
        // Validation Errors (Extended)
        case .validation(let error):
            return error.errorDescription
            
        // Unknown/Unexpected Errors
        case .unknown(let underlying):
            return "Unknown error: \(underlying.localizedDescription)"
        case .internalError(let code, let details):
            return "Internal error (\(code)): \(details)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .systemInitializationFailed, .cliBackendNotResponding, .connectionLost:
            return "Backend service communication failure"
        case .moduleConfigurationInvalid, .profileValidationFailed, .configurationCorrupted:
            return "Invalid or corrupted configuration data"
        case .permissionDenied, .authenticationFailed, .authorizationDenied:
            return "Insufficient permissions or authentication failure"
        case .networkError, .apiError, .timeoutError:
            return "Network or communication issue"
        case .dataCorruption, .storageError, .migrationFailed:
            return "Data storage or integrity issue"
        case .inputTooLong, .invalidRange, .invalidDateRange:
            return "Input validation failure"
        case .invalidState, .operationNotAllowed, .businessRuleViolation:
            return "Business logic violation"
        default:
            return "Operation failed due to internal error"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .systemInitializationFailed, .cliBackendNotResponding:
            return "Check if Privarion CLI backend is running and accessible. Try restarting the application."
        case .permissionDenied:
            return "Ensure the application has necessary permissions. Try running with elevated privileges."
        case .moduleNotFound, .profileNotFound:
            return "Refresh the data or check if the item was deleted. Try reloading the application."
        case .moduleToggleFailed, .profileSwitchFailed:
            return "Check for conflicts with other modules/profiles. Try disabling conflicting items first."
        case .configurationCorrupted, .dataCorruption:
            return "Reset to default configuration or restore from backup if available."
        case .networkError, .connectionLost:
            return "Check network connectivity and try again. Verify backend service is running."
        case .settingsExportFailed, .settingsImportFailed:
            return "Check file permissions and available disk space. Ensure the file format is correct."
        case .invalidInput, .missingRequiredField:
            return "Correct the input according to the validation requirements and try again."
        case .authenticationFailed, .authorizationDenied:
            return "Check credentials and permissions. Contact administrator if needed."
        default:
            return "Try the operation again. If the problem persists, contact support."
        }
    }
    
    // MARK: - Error Classification
    
    /// Severity level of the error for logging and user notification purposes
    var severity: ErrorSeverity {
        switch self {
        case .systemInitializationFailed, .dataCorruption, .securityViolation, .authenticationFailed:
            return .critical
        case .cliBackendNotResponding, .connectionLost, .moduleConflict, .configurationCorrupted:
            return .high
        case .moduleToggleFailed, .profileSwitchFailed, .networkError, .storageError:
            return .medium
        case .invalidInput, .missingRequiredField, .settingsValidationFailed:
            return .low
        default:
            return .medium
        }
    }
    
    /// Category of the error for routing to appropriate handlers
    var category: ErrorCategory {
        switch self {
        case .systemInitializationFailed, .systemStatusUnavailable, .cliBackendNotResponding, .permissionDenied:
            return .system
        case .moduleNotFound, .moduleToggleFailed, .moduleConfigurationInvalid, .moduleConflict:
            return .module
        case .profileNotFound, .profileCreationFailed, .profileValidationFailed, .profileSwitchFailed, .profileDeleteFailed:
            return .profile
        case .invalidConfiguration, .configurationSaveFailed, .configurationLoadFailed, .configurationCorrupted:
            return .configuration
        case .settingsExportFailed, .settingsImportFailed, .settingsValidationFailed, .settingsResetFailed:
            return .userSettings
        case .networkError, .apiError, .timeoutError, .connectionLost:
            return .network
        case .dataCorruption, .storageError, .migrationFailed, .backupFailed:
            return .data
        case .invalidInput, .missingRequiredField, .valueTooLarge, .valueTooSmall, .inputTooLong, .invalidRange, .invalidDateRange, .validation:
            return .validation
        case .authenticationFailed, .authorizationDenied, .securityViolation, .cryptographicError:
            return .security
        case .invalidState, .operationNotAllowed, .businessRuleViolation:
            return .businessLogic
        case .systemOperation:
            return .system
        case .unknown, .internalError:
            return .internalError
        }
    }
    
    /// Whether this error supports automatic retry
    var isRetryable: Bool {
        switch self {
        case .cliBackendNotResponding, .networkError, .timeoutError, .connectionLost:
            return true
        case .systemStatusUnavailable, .moduleToggleFailed, .profileSwitchFailed:
            return true
        case .configurationSaveFailed, .configurationLoadFailed:
            return true
        default:
            return false
        }
    }
    
    /// Maximum number of retry attempts for retryable errors
    var maxRetryAttempts: Int {
        switch self {
        case .networkError, .timeoutError, .connectionLost:
            return 3
        case .cliBackendNotResponding:
            return 2
        default:
            return 1
        }
    }
}

// MARK: - Supporting Types

/// System operation specific errors
enum SystemOperationError: LocalizedError {
    case networkInterfaceEnumerationFailed(Error)
    case interfaceStatusRetrievalFailed(Error)
    case multipleInterfaceRestoreFailed([Error])
    case connectivityLostAfterSpoofing(String)
    case originalMACNotFound(String)
    case macRestoreFailed(String, Error)
    case interfaceNotFound(String)
    case macChangeVerificationFailed(interface: String, expected: String, actual: String)
    
    var errorDescription: String? {
        switch self {
        case .networkInterfaceEnumerationFailed(let error):
            return "Failed to enumerate network interfaces: \(error.localizedDescription)"
        case .interfaceStatusRetrievalFailed(let error):
            return "Failed to retrieve interface status: \(error.localizedDescription)"
        case .multipleInterfaceRestoreFailed(let errors):
            return "Failed to restore multiple interfaces: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        case .connectivityLostAfterSpoofing(let interface):
            return "Network connectivity lost after spoofing interface \(interface)"
        case .originalMACNotFound(let interface):
            return "Original MAC address not found for interface \(interface)"
        case .macRestoreFailed(let interface, let error):
            return "Failed to restore MAC address for interface \(interface): \(error.localizedDescription)"
        case .interfaceNotFound(let interface):
            return "Network interface not found: \(interface)"
        case .macChangeVerificationFailed(let interface, let expected, let actual):
            return "MAC change verification failed for \(interface): expected \(expected), got \(actual)"
        }
    }
}

/// Validation specific errors  
enum ValidationError: LocalizedError {
    case invalidNetworkInterface(String)
    case interfaceAlreadySpoofed(String)
    case interfaceNotSpoofed(String)
    case invalidMACFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidNetworkInterface(let interface):
            return "Invalid network interface: \(interface)"
        case .interfaceAlreadySpoofed(let interface):
            return "Interface \(interface) is already spoofed"
        case .interfaceNotSpoofed(let interface):
            return "Interface \(interface) is not currently spoofed"
        case .invalidMACFormat(let mac):
            return "Invalid MAC address format: \(mac)"
        }
    }
}

/// Error severity levels for appropriate handling and user notification
enum ErrorSeverity: String, CaseIterable {
    case critical = "critical"
    case high = "high"  
    case medium = "medium"
    case low = "low"
    
    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
    
    var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange"
        case .medium: return "yellow"
        case .low: return "blue"
        }
    }
}

/// Error categories for routing to appropriate handlers
enum ErrorCategory: String, CaseIterable {
    case system = "system"
    case module = "module"
    case profile = "profile"
    case configuration = "configuration"
    case userSettings = "userSettings"
    case network = "network"
    case data = "data"
    case validation = "validation"
    case security = "security"
    case businessLogic = "businessLogic"
    case internalError = "internalError"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .module: return "Module"
        case .profile: return "Profile"
        case .configuration: return "Configuration"
        case .userSettings: return "User Settings"
        case .network: return "Network"
        case .data: return "Data"
        case .validation: return "Validation"
        case .security: return "Security"
        case .businessLogic: return "Business Logic"
        case .internalError: return "Internal"
        }
    }
}
