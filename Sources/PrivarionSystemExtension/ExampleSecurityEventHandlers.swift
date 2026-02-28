// PrivarionSystemExtension - Example Security Event Handlers
// Demonstrates extensibility of SecurityEventHandler protocol
// Requirements: 2.5

import Foundation
import Logging
import PrivarionSharedModels

// MARK: - Logging Event Handler

/// Example handler that logs all security events for audit purposes
public class LoggingSecurityEventHandler: SecurityEventHandler {
    private let logger: Logger
    
    public init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "com.privarion.handlers.logging")
    }
    
    public func canHandle(_ eventType: SecurityEventType) -> Bool {
        // This handler can process all event types
        return true
    }
    
    public func handleProcessExecution(_ event: ProcessExecutionEvent) async -> ESAuthResult {
        logger.info("""
            [AUDIT] Process Execution:
            - PID: \(event.processID)
            - Path: \(event.executablePath)
            - Parent PID: \(event.parentProcessID)
            - Arguments: \(event.arguments.joined(separator: " "))
            """)
        
        // Always allow - this is just for logging
        return .allow
    }
    
    public func handleFileAccess(_ event: FileAccessEvent) async -> ESAuthResult {
        logger.info("""
            [AUDIT] File Access:
            - PID: \(event.processID)
            - Path: \(event.filePath)
            - Type: \(event.accessType)
            """)
        
        // Always allow - this is just for logging
        return .allow
    }
    
    public func handleNetworkEvent(_ event: PrivarionSharedModels.NetworkEvent) async -> ESAuthResult {
        logger.info("""
            [AUDIT] Network Event:
            - PID: \(event.processID)
            - Source: \(event.sourceIP):\(event.sourcePort)
            - Destination: \(event.destinationIP):\(event.destinationPort)
            - Protocol: \(event.protocol)
            """)
        
        // Always allow - this is just for logging
        return .allow
    }
}

// MARK: - Suspicious Path Blocker

/// Example handler that blocks execution of binaries from suspicious paths
public class SuspiciousPathBlocker: SecurityEventHandler {
    private let logger: Logger
    private let suspiciousPaths: Set<String>
    
    public init(suspiciousPaths: [String] = [], logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "com.privarion.handlers.pathblocker")
        self.suspiciousPaths = Set(suspiciousPaths.isEmpty ? Self.defaultSuspiciousPaths : suspiciousPaths)
    }
    
    /// Default suspicious paths that should be blocked
    private static let defaultSuspiciousPaths = [
        "/tmp",
        "/var/tmp",
        "/private/tmp",
        "/private/var/tmp"
    ]
    
    public func canHandle(_ eventType: SecurityEventType) -> Bool {
        // Only handle process execution events
        return eventType == .processExecution
    }
    
    public func handleProcessExecution(_ event: ProcessExecutionEvent) async -> ESAuthResult {
        // Check if executable is in a suspicious path
        for suspiciousPath in suspiciousPaths {
            if event.executablePath.hasPrefix(suspiciousPath) {
                logger.warning("""
                    [SECURITY] Blocked execution from suspicious path:
                    - PID: \(event.processID)
                    - Path: \(event.executablePath)
                    - Suspicious Path: \(suspiciousPath)
                    """)
                return .deny
            }
        }
        
        // Allow if not in suspicious path
        return .allow
    }
    
    public func handleFileAccess(_ event: FileAccessEvent) async -> ESAuthResult {
        // Not handled by this handler
        return .allow
    }
    
    public func handleNetworkEvent(_ event: PrivarionSharedModels.NetworkEvent) async -> ESAuthResult {
        // Not handled by this handler
        return .allow
    }
}

// MARK: - Sensitive File Access Monitor

/// Example handler that monitors access to sensitive files
public class SensitiveFileAccessMonitor: SecurityEventHandler {
    private let logger: Logger
    private let sensitivePatterns: [String]
    
    public init(sensitivePatterns: [String] = [], logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "com.privarion.handlers.filemonitor")
        self.sensitivePatterns = sensitivePatterns.isEmpty ? Self.defaultSensitivePatterns : sensitivePatterns
    }
    
    /// Default patterns for sensitive files
    private static let defaultSensitivePatterns = [
        ".ssh/",
        ".aws/",
        ".gnupg/",
        "Keychain",
        "password",
        "secret",
        "private_key"
    ]
    
    public func canHandle(_ eventType: SecurityEventType) -> Bool {
        // Only handle file access events
        return eventType == .fileAccess
    }
    
    public func handleProcessExecution(_ event: ProcessExecutionEvent) async -> ESAuthResult {
        // Not handled by this handler
        return .allow
    }
    
    public func handleFileAccess(_ event: FileAccessEvent) async -> ESAuthResult {
        // Check if file path matches sensitive patterns
        for pattern in sensitivePatterns {
            if event.filePath.contains(pattern) {
                logger.warning("""
                    [SECURITY] Sensitive file access detected:
                    - PID: \(event.processID)
                    - Path: \(event.filePath)
                    - Type: \(event.accessType)
                    - Pattern: \(pattern)
                    """)
                
                // For write access to sensitive files, we could deny
                // For now, just log and allow
                if event.accessType == .write {
                    logger.critical("Write access to sensitive file: \(event.filePath)")
                }
            }
        }
        
        // Allow but log
        return .allow
    }
    
    public func handleNetworkEvent(_ event: PrivarionSharedModels.NetworkEvent) async -> ESAuthResult {
        // Not handled by this handler
        return .allow
    }
}

// MARK: - Rate Limiting Handler

/// Example handler that rate-limits process executions to prevent fork bombs
/// Note: Simplified implementation without async to avoid lock issues
public class RateLimitingHandler: SecurityEventHandler {
    private let logger: Logger
    private let maxExecutionsPerSecond: Int
    private var executionTimestamps: [pid_t: [Date]] = [:]
    
    public init(maxExecutionsPerSecond: Int = 100, logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "com.privarion.handlers.ratelimit")
        self.maxExecutionsPerSecond = maxExecutionsPerSecond
    }
    
    public func canHandle(_ eventType: SecurityEventType) -> Bool {
        // Only handle process execution events
        return eventType == .processExecution
    }
    
    public func handleProcessExecution(_ event: ProcessExecutionEvent) async -> ESAuthResult {
        // Note: In production, this should use proper async-safe synchronization
        // For demonstration purposes, we use a simplified approach
        let now = Date()
        let oneSecondAgo = now.addingTimeInterval(-1.0)
        
        // Get or create timestamp array for parent process
        var timestamps = executionTimestamps[event.parentProcessID] ?? []
        
        // Remove timestamps older than 1 second
        timestamps.removeAll { $0 < oneSecondAgo }
        
        // Check if rate limit exceeded
        if timestamps.count >= maxExecutionsPerSecond {
            logger.warning("""
                [SECURITY] Rate limit exceeded:
                - Parent PID: \(event.parentProcessID)
                - Executions in last second: \(timestamps.count)
                - Limit: \(maxExecutionsPerSecond)
                - Blocked: \(event.executablePath)
                """)
            return .deny
        }
        
        // Add current timestamp
        timestamps.append(now)
        executionTimestamps[event.parentProcessID] = timestamps
        
        // Clean up old entries periodically
        if executionTimestamps.count > 1000 {
            cleanupOldEntries()
        }
        
        return .allow
    }
    
    public func handleFileAccess(_ event: FileAccessEvent) async -> ESAuthResult {
        // Not handled by this handler
        return .allow
    }
    
    public func handleNetworkEvent(_ event: PrivarionSharedModels.NetworkEvent) async -> ESAuthResult {
        // Not handled by this handler
        return .allow
    }
    
    /// Clean up old entries from the tracking dictionary
    private func cleanupOldEntries() {
        let oneSecondAgo = Date().addingTimeInterval(-1.0)
        
        for (pid, timestamps) in executionTimestamps {
            let recentTimestamps = timestamps.filter { $0 >= oneSecondAgo }
            if recentTimestamps.isEmpty {
                executionTimestamps.removeValue(forKey: pid)
            } else {
                executionTimestamps[pid] = recentTimestamps
            }
        }
        
        logger.debug("Cleaned up rate limiting entries, remaining: \(executionTimestamps.count)")
    }
}

// MARK: - Composite Handler

/// Example handler that combines multiple handlers
public class CompositeSecurityEventHandler: SecurityEventHandler {
    private let handlers: [SecurityEventHandler]
    private let logger: Logger
    
    public init(handlers: [SecurityEventHandler], logger: Logger? = nil) {
        self.handlers = handlers
        self.logger = logger ?? Logger(label: "com.privarion.handlers.composite")
    }
    
    public func canHandle(_ eventType: SecurityEventType) -> Bool {
        // Can handle if any child handler can handle
        return handlers.contains { $0.canHandle(eventType) }
    }
    
    public func handleProcessExecution(_ event: ProcessExecutionEvent) async -> ESAuthResult {
        // Execute all handlers that can handle this event
        for handler in handlers where handler.canHandle(.processExecution) {
            let result = await handler.handleProcessExecution(event)
            if result != .allow {
                logger.info("Handler \(type(of: handler)) denied process execution")
                return result
            }
        }
        
        return .allow
    }
    
    public func handleFileAccess(_ event: FileAccessEvent) async -> ESAuthResult {
        // Execute all handlers that can handle this event
        for handler in handlers where handler.canHandle(.fileAccess) {
            let result = await handler.handleFileAccess(event)
            if result != .allow {
                logger.info("Handler \(type(of: handler)) denied file access")
                return result
            }
        }
        
        return .allow
    }
    
    public func handleNetworkEvent(_ event: PrivarionSharedModels.NetworkEvent) async -> ESAuthResult {
        // Execute all handlers that can handle this event
        for handler in handlers where handler.canHandle(.networkConnection) {
            let result = await handler.handleNetworkEvent(event)
            if result != .allow {
                logger.info("Handler \(type(of: handler)) denied network event")
                return result
            }
        }
        
        return .allow
    }
}
