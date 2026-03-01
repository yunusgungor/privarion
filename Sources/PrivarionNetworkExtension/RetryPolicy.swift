// PrivarionNetworkExtension
// Retry policy for handling transient failures with exponential backoff
// Requirements: 19.1, 19.2

import Foundation
import Logging

/// Retry policy with exponential backoff for handling transient failures
/// Implements automatic retry logic with configurable attempts and delays
/// - Requirement: 19.1, 19.2
public class RetryPolicy {
    /// Maximum number of retry attempts
    public let maxAttempts: Int
    
    /// Base delay between retries in seconds
    public let baseDelay: TimeInterval
    
    /// Maximum delay between retries in seconds
    public let maxDelay: TimeInterval
    
    /// Logger instance
    private let logger = Logger(label: "com.privarion.network-extension.retry-policy")
    
    /// Initialize retry policy with configuration
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts (default: 3)
    ///   - baseDelay: Base delay between retries in seconds (default: 1.0)
    ///   - maxDelay: Maximum delay between retries in seconds (default: 30.0)
    public init(maxAttempts: Int = 3, baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 30.0) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }
    
    /// Execute an operation with retry logic and exponential backoff
    /// - Parameter operation: Async throwing operation to execute
    /// - Returns: Result of the operation
    /// - Throws: Last error encountered if all retries fail
    /// - Requirement: 19.1
    public func execute<T>(_ operation: () async throws -> T) async throws -> T {
        var attempt = 0
        var delay = baseDelay
        var lastError: Error?
        
        while attempt < maxAttempts {
            do {
                let result = try await operation()
                
                // Log successful execution if this was a retry
                if attempt > 0 {
                    logger.info("Operation succeeded after retry", metadata: [
                        "attempt": "\(attempt + 1)",
                        "total_attempts": "\(maxAttempts)"
                    ])
                }
                
                return result
            } catch {
                lastError = error
                attempt += 1
                
                // If this was the last attempt, throw the error
                if attempt >= maxAttempts {
                    logger.error("Operation failed after all retry attempts", metadata: [
                        "attempts": "\(maxAttempts)",
                        "error": "\(error.localizedDescription)"
                    ])
                    throw error
                }
                
                // Log retry attempt
                logger.warning("Operation failed, will retry", metadata: [
                    "attempt": "\(attempt)",
                    "max_attempts": "\(maxAttempts)",
                    "delay_seconds": "\(delay)",
                    "error": "\(error.localizedDescription)"
                ])
                
                // Wait before retrying with exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Calculate next delay with exponential backoff
                delay = min(delay * 2, maxDelay)
            }
        }
        
        // This should never be reached, but throw last error if it somehow is
        throw lastError ?? RetryPolicyError.maxAttemptsExceeded
    }
}

/// Errors specific to retry policy
public enum RetryPolicyError: Error, LocalizedError {
    case maxAttemptsExceeded
    
    public var errorDescription: String? {
        switch self {
        case .maxAttemptsExceeded:
            return "Maximum retry attempts exceeded"
        }
    }
}
