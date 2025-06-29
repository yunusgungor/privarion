import Foundation
import SwiftUI
import Combine
import Logging

/// Central error management system for Privarion application
/// Handles error logging, user notification, recovery attempts, and analytics
/// Following Clean Architecture and Combine reactive patterns
@MainActor
final class ErrorManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current error alerts to display to user
    @Published var currentAlerts: [ErrorAlert] = []
    
    /// Error banners for non-critical notifications
    @Published var errorBanners: [ErrorBanner] = []
    
    /// Whether error recovery is in progress
    @Published var isRecovering: Bool = false
    
    /// Error statistics for monitoring
    @Published var errorStatistics: ErrorStatistics = ErrorStatistics()
    
    // MARK: - Private Properties
    
    private let logger = Logger(label: "ErrorManager")
    private var cancellables = Set<AnyCancellable>()
    private var retryAttempts: [String: Int] = [:]
    private var errorHistory: [ErrorRecord] = []
    private let maxHistorySize = 100
    
    // MARK: - Singleton
    
    static let shared = ErrorManager()
    
    private init() {
        setupErrorAnalytics()
        logger.info("ErrorManager initialized")
    }
    
    // MARK: - Public Methods
    
    /// Handle an error with automatic classification and user notification
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Additional context about where the error occurred
    ///   - operation: The operation that was being performed when error occurred
    func handleError(
        _ error: Error,
        context: String? = nil,
        operation: String? = nil
    ) {
        let privarionError = convertToPrivarionError(error)
        let errorId = generateErrorId()
        
        // Create error record for analytics
        let record = ErrorRecord(
            id: errorId,
            error: privarionError,
            context: context,
            operation: operation,
            timestamp: Date(),
            handled: false
        )
        
        addToHistory(record)
        logError(record)
        updateStatistics(for: privarionError)
        
        // Determine how to present error to user
        switch privarionError.severity {
        case .critical:
            showCriticalAlert(for: privarionError, errorId: errorId)
        case .high:
            showErrorAlert(for: privarionError, errorId: errorId)
        case .medium:
            showErrorBanner(for: privarionError, errorId: errorId)
        case .low:
            // Log only, no user notification needed
            break
        }
        
        // Attempt automatic recovery if applicable
        if privarionError.isRetryable && shouldAttemptRetry(for: errorId) {
            Task {
                await attemptRecovery(for: privarionError, errorId: errorId)
            }
        }
        
        markAsHandled(errorId)
    }
    
    /// Manually retry a failed operation
    /// - Parameters:
    ///   - errorId: The ID of the error to retry
    ///   - operation: The operation to retry
    func retryOperation(errorId: String, operation: @escaping () async throws -> Void) async {
        guard let record = errorHistory.first(where: { $0.id == errorId }) else {
            logger.warning("Cannot retry: Error record not found for ID \(errorId)")
            return
        }
        
        isRecovering = true
        
        do {
            try await operation()
            logger.info("Retry successful for error \(errorId)")
            dismissError(errorId)
            updateRetrySuccess(for: errorId)
        } catch {
            logger.error("Retry failed for error \(errorId): \(error)")
            handleError(error, context: "Retry attempt failed", operation: record.operation)
            incrementRetryAttempt(for: errorId)
        }
        
        isRecovering = false
    }
    
    /// Dismiss a specific error alert or banner
    /// - Parameter errorId: The ID of the error to dismiss
    func dismissError(_ errorId: String) {
        currentAlerts.removeAll { $0.id == errorId }
        errorBanners.removeAll { $0.id == errorId }
        
        logger.debug("Dismissed error \(errorId)")
    }
    
    /// Dismiss all current error notifications
    func dismissAllErrors() {
        currentAlerts.removeAll()
        errorBanners.removeAll()
        
        logger.debug("Dismissed all error notifications")
    }
    
    /// Get error statistics for monitoring and analytics
    func getErrorStatistics() -> ErrorStatistics {
        return errorStatistics
    }
    
    /// Get recent error history for debugging
    func getRecentErrors(limit: Int = 20) -> [ErrorRecord] {
        return Array(errorHistory.suffix(limit))
    }
    
    /// Clear error history (useful for testing or privacy)
    func clearErrorHistory() {
        errorHistory.removeAll()
        retryAttempts.removeAll()
        errorStatistics = ErrorStatistics()
        
        logger.info("Error history cleared")
    }
    
    // MARK: - Private Methods
    
    private func convertToPrivarionError(_ error: Error) -> PrivarionError {
        if let privarionError = error as? PrivarionError {
            return privarionError
        }
        
        // Convert common system errors to appropriate PrivarionError types
        switch error {
        case is URLError:
            return .networkError(underlying: error)
        case is DecodingError:
            return .dataCorruption(component: "JSON parsing")
        case is CancellationError:
            return .timeoutError(operation: "unknown", timeout: 30.0)
        default:
            return .unknown(underlying: error)
        }
    }
    
    private func generateErrorId() -> String {
        return "ERR-\(Date().timeIntervalSince1970)-\(UUID().uuidString.prefix(8))"
    }
    
    private func addToHistory(_ record: ErrorRecord) {
        errorHistory.append(record)
        
        // Maintain maximum history size
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst(errorHistory.count - maxHistorySize)
        }
    }
    
    private func logError(_ record: ErrorRecord) {
        let severity = record.error.severity
        let category = record.error.category
        let context = record.context ?? "unknown"
        let operation = record.operation ?? "unknown"
        
        switch severity {
        case .critical:
            logger.critical("CRITICAL ERROR [\(category.rawValue)] in \(context) during \(operation): \(record.error.localizedDescription)")
        case .high:
            logger.error("HIGH SEVERITY [\(category.rawValue)] in \(context) during \(operation): \(record.error.localizedDescription)")
        case .medium:
            logger.warning("MEDIUM SEVERITY [\(category.rawValue)] in \(context) during \(operation): \(record.error.localizedDescription)")
        case .low:
            logger.info("LOW SEVERITY [\(category.rawValue)] in \(context) during \(operation): \(record.error.localizedDescription)")
        }
    }
    
    private func updateStatistics(for error: PrivarionError) {
        errorStatistics.totalErrors += 1
        
        switch error.severity {
        case .critical:
            errorStatistics.criticalErrors += 1
        case .high:
            errorStatistics.highSeverityErrors += 1
        case .medium:
            errorStatistics.mediumSeverityErrors += 1
        case .low:
            errorStatistics.lowSeverityErrors += 1
        }
        
        errorStatistics.errorsByCategory[error.category, default: 0] += 1
        errorStatistics.lastErrorTimestamp = Date()
    }
    
    private func showCriticalAlert(for error: PrivarionError, errorId: String) {
        let alert = ErrorAlert(
            id: errorId,
            title: "Critical Error",
            message: error.localizedDescription,
            severity: .critical,
            category: error.category,
            primaryAction: AlertAction(title: "OK", style: .destructive) {
                self.dismissError(errorId)
            },
            secondaryAction: error.isRetryable ? AlertAction(title: "Retry", style: .default) {
                // Retry action will be handled by the view
            } : nil
        )
        
        currentAlerts.append(alert)
    }
    
    private func showErrorAlert(for error: PrivarionError, errorId: String) {
        let alert = ErrorAlert(
            id: errorId,
            title: "\(error.severity.displayName) Error",
            message: error.localizedDescription,
            severity: error.severity,
            category: error.category,
            primaryAction: AlertAction(title: "OK", style: .default) {
                self.dismissError(errorId)
            },
            secondaryAction: error.isRetryable ? AlertAction(title: "Retry", style: .cancel) {
                // Retry action will be handled by the view
            } : nil,
            recoveryMessage: error.recoverySuggestion
        )
        
        currentAlerts.append(alert)
    }
    
    private func showErrorBanner(for error: PrivarionError, errorId: String) {
        let banner = ErrorBanner(
            id: errorId,
            message: error.localizedDescription,
            severity: error.severity,
            category: error.category,
            isRetryable: error.isRetryable,
            autoDismissAfter: 5.0
        )
        
        errorBanners.append(banner)
        
        // Auto-dismiss after specified time
        if let dismissTime = banner.autoDismissAfter {
            DispatchQueue.main.asyncAfter(deadline: .now() + dismissTime) {
                self.dismissError(errorId)
            }
        }
    }
    
    private func shouldAttemptRetry(for errorId: String) -> Bool {
        let currentAttempts = retryAttempts[errorId, default: 0]
        let record = errorHistory.first { $0.id == errorId }
        let maxAttempts = record?.error.maxRetryAttempts ?? 1
        
        return currentAttempts < maxAttempts
    }
    
    private func attemptRecovery(for error: PrivarionError, errorId: String) async {
        logger.info("Attempting automatic recovery for error \(errorId)")
        
        isRecovering = true
        
        // Add delay before retry (exponential backoff)
        let attemptNumber = retryAttempts[errorId, default: 0]
        let delay = min(pow(2.0, Double(attemptNumber)), 10.0) // Max 10 seconds
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Recovery logic based on error type
        switch error.category {
        case .network:
            await attemptNetworkRecovery(errorId: errorId)
        case .system:
            await attemptSystemRecovery(errorId: errorId)
        case .module:
            await attemptModuleRecovery(errorId: errorId)
        case .configuration:
            await attemptConfigurationRecovery(errorId: errorId)
        default:
            logger.debug("No automatic recovery available for category \(error.category)")
        }
        
        isRecovering = false
    }
    
    private func attemptNetworkRecovery(errorId: String) async {
        // Try to re-establish network connection or check backend availability
        logger.info("Attempting network recovery for error \(errorId)")
        // Implementation depends on network layer
    }
    
    private func attemptSystemRecovery(errorId: String) async {
        // Try to reinitialize system components
        logger.info("Attempting system recovery for error \(errorId)")
        // Implementation depends on system architecture
    }
    
    private func attemptModuleRecovery(errorId: String) async {
        // Try to refresh module state
        logger.info("Attempting module recovery for error \(errorId)")
        // Implementation depends on module management
    }
    
    private func attemptConfigurationRecovery(errorId: String) async {
        // Try to reload configuration from defaults
        logger.info("Attempting configuration recovery for error \(errorId)")
        // Implementation depends on configuration management
    }
    
    private func incrementRetryAttempt(for errorId: String) {
        retryAttempts[errorId, default: 0] += 1
    }
    
    private func updateRetrySuccess(for errorId: String) {
        retryAttempts.removeValue(forKey: errorId)
        errorStatistics.successfulRetries += 1
    }
    
    private func markAsHandled(_ errorId: String) {
        if let index = errorHistory.firstIndex(where: { $0.id == errorId }) {
            errorHistory[index].handled = true
        }
    }
    
    private func setupErrorAnalytics() {
        // Set up periodic analytics reporting or cleanup
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { _ in
                self.performPeriodicMaintenance()
            }
            .store(in: &cancellables)
    }
    
    private func performPeriodicMaintenance() {
        // Clean up old banners
        let now = Date()
        errorBanners.removeAll { banner in
            if let dismissTime = banner.autoDismissAfter {
                return now.timeIntervalSince(banner.timestamp) > dismissTime
            }
            return false
        }
        
        // Log statistics if there were errors in the last period
        if errorStatistics.totalErrors > 0 {
            logger.debug("Error statistics: \(errorStatistics)")
        }
    }
}

// MARK: - Supporting Types

/// Represents an error alert to be shown to the user
struct ErrorAlert: Identifiable {
    let id: String
    let title: String
    let message: String
    let severity: ErrorSeverity
    let category: ErrorCategory
    let primaryAction: AlertAction
    let secondaryAction: AlertAction?
    let recoveryMessage: String?
    let timestamp: Date
    
    init(
        id: String,
        title: String,
        message: String,
        severity: ErrorSeverity,
        category: ErrorCategory,
        primaryAction: AlertAction,
        secondaryAction: AlertAction? = nil,
        recoveryMessage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.severity = severity
        self.category = category
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.recoveryMessage = recoveryMessage
        self.timestamp = Date()
    }
}

/// Represents an error banner for non-critical notifications
struct ErrorBanner: Identifiable {
    let id: String
    let message: String
    let severity: ErrorSeverity
    let category: ErrorCategory
    let isRetryable: Bool
    let autoDismissAfter: TimeInterval?
    let timestamp: Date
    
    init(
        id: String,
        message: String,
        severity: ErrorSeverity,
        category: ErrorCategory,
        isRetryable: Bool = false,
        autoDismissAfter: TimeInterval? = nil
    ) {
        self.id = id
        self.message = message
        self.severity = severity
        self.category = category
        self.isRetryable = isRetryable
        self.autoDismissAfter = autoDismissAfter
        self.timestamp = Date()
    }
}

/// Action for error alerts
struct AlertAction {
    let title: String
    let style: AlertActionStyle
    let action: () -> Void
    
    enum AlertActionStyle {
        case `default`
        case cancel
        case destructive
    }
}

/// Error record for history and analytics
struct ErrorRecord {
    let id: String
    let error: PrivarionError
    let context: String?
    let operation: String?
    let timestamp: Date
    var handled: Bool
}

/// Error statistics for monitoring and analytics
struct ErrorStatistics: CustomStringConvertible {
    var totalErrors: Int = 0
    var criticalErrors: Int = 0
    var highSeverityErrors: Int = 0
    var mediumSeverityErrors: Int = 0
    var lowSeverityErrors: Int = 0
    var successfulRetries: Int = 0
    var errorsByCategory: [ErrorCategory: Int] = [:]
    var lastErrorTimestamp: Date?
    
    var description: String {
        return """
        ErrorStatistics(
            total: \(totalErrors),
            critical: \(criticalErrors),
            high: \(highSeverityErrors),
            medium: \(mediumSeverityErrors),
            low: \(lowSeverityErrors),
            retries: \(successfulRetries),
            lastError: \(lastErrorTimestamp?.description ?? "none")
        )
        """
    }
}
