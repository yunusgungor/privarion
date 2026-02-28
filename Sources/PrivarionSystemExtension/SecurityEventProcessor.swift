// PrivarionSystemExtension - Security Event Processor
// Processes Endpoint Security events with async handling and policy enforcement
// Requirements: 2.5-2.8, 18.1

import Foundation
import CEndpointSecurity
import Logging
import PrivarionSharedModels
import PrivarionCore

/// Processes incoming Endpoint Security events with thread-safe concurrent handling
/// Responds to AUTH events within 100ms to avoid system slowdown
public actor SecurityEventProcessor {
    // MARK: - Properties
    
    /// Logger for event processing
    private let logger: Logger
    
    /// File logger for comprehensive event logging
    private let fileLogger: FileLogger
    
    /// Event processing timeout (100ms as per requirements)
    private let processingTimeout: TimeInterval = 0.1
    
    /// Event handler for extensibility
    private var eventHandlers: [SecurityEventHandler] = []
    
    /// Protection policy engine for policy evaluation
    private let policyEngine: ProtectionPolicyEngine
    
    // MARK: - Initialization
    
    /// Initialize the Security Event Processor
    /// - Parameters:
    ///   - policyEngine: Protection policy engine for policy evaluation
    ///   - logger: Optional logger instance
    public init(policyEngine: ProtectionPolicyEngine, logger: Logger? = nil) {
        self.policyEngine = policyEngine
        self.logger = logger ?? Logger(label: "com.privarion.eventprocessor")
        self.fileLogger = FileLogger(logFilePath: "/var/log/privarion/system-extension.log")
    }
    
    // MARK: - Public Methods
    
    /// Register an event handler for processing
    /// - Parameter handler: Event handler to register
    public func registerHandler(_ handler: SecurityEventHandler) {
        eventHandlers.append(handler)
        logger.info("Registered event handler: \(type(of: handler))")
    }
    
    /// Process an incoming Endpoint Security event
    /// Must complete within 100ms for AUTH events
    /// - Parameters:
    ///   - client: ES client pointer
    ///   - message: ES message pointer
    public func processEvent(client: OpaquePointer, message: UnsafePointer<es_message_t>) async {
        let startTime = Date()
        let eventType = message.pointee.event_type
        let actionType = message.pointee.action_type
        
        // Extract process ID for logging
        let process = message.pointee.process
        let processID = audit_token_to_pid(process.pointee.audit_token)
        
        logger.debug("Processing event: type=\(eventType), action=\(actionType)")
        
        // Process based on event type
        let result: ESAuthResult
        
        switch eventType {
        case ES_EVENT_TYPE_AUTH_EXEC:
            result = await handleProcessExecution(message)
            
        case ES_EVENT_TYPE_AUTH_OPEN:
            result = await handleFileAccess(message)
            
        case ES_EVENT_TYPE_NOTIFY_WRITE, ES_EVENT_TYPE_NOTIFY_EXIT:
            // NOTIFY events don't require response
            await handleNotifyEvent(message)
            return
            
        default:
            // Default to allow for unknown event types
            logger.warning("Unknown event type: \(eventType.rawValue)")
            result = .allow
        }
        
        // Respond to AUTH events
        if actionType == ES_ACTION_TYPE_AUTH {
            let esResult = result.toESAuthResult()
            _ = es_respond_auth_result(client, message, esResult, false)
            
            // Log the event with comprehensive details (Requirement 2.10, 17.4)
            logSecurityEvent(
                eventType: eventType,
                processID: processID,
                action: result,
                message: message
            )
            
            // Check processing time
            let processingTime = Date().timeIntervalSince(startTime)
            if processingTime > processingTimeout {
                logger.warning("Event processing exceeded timeout: \(processingTime * 1000)ms")
            } else {
                logger.debug("Event processed in \(processingTime * 1000)ms")
            }
        }
    }
    
    /// Handle process execution events (ES_EVENT_TYPE_AUTH_EXEC)
    /// - Parameter message: ES message pointer
    /// - Returns: Authorization result
    public func handleProcessExecution(_ message: UnsafePointer<es_message_t>) async -> ESAuthResult {
        // Extract process information
        let process = message.pointee.process
        let processID = audit_token_to_pid(process.pointee.audit_token)
        
        // Extract executable path
        guard let executablePath = extractExecutablePath(from: process) else {
            logger.error("Failed to extract executable path")
            return .allow
        }
        
        // Extract arguments
        let arguments = extractArguments(from: message)
        
        // Extract environment (limited for performance)
        let environment: [String: String] = [:]
        
        // Extract parent process ID
        let parentProcessID = extractParentProcessID(from: process)
        
        // Create event
        let event = ProcessExecutionEvent(
            processID: processID,
            executablePath: executablePath,
            arguments: arguments,
            environment: environment,
            parentProcessID: parentProcessID
        )
        
        logger.info("Process execution: pid=\(processID), path=\(executablePath)")
        
        // Query protection policy engine for policy matching
        let policy = policyEngine.evaluatePolicy(for: executablePath)
        logger.debug("Policy evaluated: identifier=\(policy.identifier), level=\(policy.protectionLevel), vmIsolation=\(policy.requiresVMIsolation)")
        
        // Apply protection rules based on policy
        let result = applyProtectionPolicy(policy, for: event)
        
        // Log policy application decision
        logPolicyDecision(policy: policy, event: event, result: result)
        
        // Check registered handlers
        for handler in eventHandlers {
            if handler.canHandle(.processExecution) {
                let handlerResult = await handler.handleProcessExecution(event)
                if handlerResult != .allow {
                    logger.info("Handler denied process execution: \(executablePath)")
                    return handlerResult
                }
            }
        }
        
        return result
    }
    
    /// Apply protection policy to process execution event
    /// - Parameters:
    ///   - policy: Protection policy to apply
    ///   - event: Process execution event
    /// - Returns: Authorization result based on policy
    private func applyProtectionPolicy(_ policy: ProtectionPolicy, for event: ProcessExecutionEvent) -> ESAuthResult {
        // Check if VM isolation is required
        if policy.requiresVMIsolation {
            logger.info("VM isolation required for: \(event.executablePath)")
            // For now, we deny execution and expect the caller to launch in VM
            // In a full implementation, this would trigger VM creation and app installation
            // TODO: Integrate with VMManager to launch application in isolated VM
            return .deny
        }
        
        // Apply protection level rules
        switch policy.protectionLevel {
        case .none:
            // No protection, allow execution
            return .allow
            
        case .basic:
            // Basic protection, allow with monitoring
            return .allow
            
        case .standard:
            // Standard protection, allow with filtering
            return .allow
            
        case .strict:
            // Strict protection, check network filtering rules
            if policy.networkFiltering.action == .block {
                logger.info("Strict policy blocks execution: \(event.executablePath)")
                return .deny
            }
            return .allow
            
        case .paranoid:
            // Paranoid protection, deny by default unless explicitly allowed
            if policy.networkFiltering.action == .allow && !policy.networkFiltering.allowedDomains.isEmpty {
                return .allow
            }
            logger.info("Paranoid policy denies execution: \(event.executablePath)")
            return .deny
        }
    }
    
    /// Log policy application decision
    /// - Parameters:
    ///   - policy: Applied protection policy
    ///   - event: Process execution event
    ///   - result: Authorization result
    private func logPolicyDecision(policy: ProtectionPolicy, event: ProcessExecutionEvent, result: ESAuthResult) {
        let action = result == .allow ? "ALLOW" : "DENY"
        logger.info("""
            Policy Decision: \(action)
            - Process: \(event.executablePath) (PID: \(event.processID))
            - Policy: \(policy.identifier)
            - Protection Level: \(policy.protectionLevel)
            - VM Isolation: \(policy.requiresVMIsolation)
            - Network Action: \(policy.networkFiltering.action)
            - Hardware Spoofing: \(policy.hardwareSpoofing)
            """)
    }
    
    /// Handle file access events (ES_EVENT_TYPE_AUTH_OPEN)
    /// - Parameter message: ES message pointer
    /// - Returns: Authorization result
    public func handleFileAccess(_ message: UnsafePointer<es_message_t>) async -> ESAuthResult {
        // Extract process information
        let process = message.pointee.process
        let processID = audit_token_to_pid(process.pointee.audit_token)
        
        // Extract file path from AUTH_OPEN event
        guard let filePath = extractFilePath(from: message) else {
            logger.error("Failed to extract file path")
            return .allow
        }
        
        // Determine access type from flags
        let accessType = extractAccessType(from: message)
        
        // Create event
        let event = FileAccessEvent(
            processID: processID,
            filePath: filePath,
            accessType: accessType
        )
        
        logger.debug("File access: pid=\(processID), path=\(filePath), type=\(accessType)")
        
        // Check registered handlers
        for handler in eventHandlers {
            if handler.canHandle(.fileAccess) {
                let result = await handler.handleFileAccess(event)
                if result != .allow {
                    logger.info("Handler denied file access: \(filePath)")
                    return result
                }
            }
        }
        
        // Default to allow
        return .allow
    }
    
    /// Handle network events (placeholder for future network event support)
    /// - Parameter message: ES message pointer
    /// - Returns: Authorization result
    public func handleNetworkEvent(_ message: UnsafePointer<es_message_t>) async -> ESAuthResult {
        // Network events are not directly supported by Endpoint Security Framework
        // This is a placeholder for future integration with Network Extension
        logger.debug("Network event handling not yet implemented")
        return .allow
    }
    
    // MARK: - Private Methods
    
    /// Handle NOTIFY events (no response required)
    /// - Parameter message: ES message pointer
    private func handleNotifyEvent(_ message: UnsafePointer<es_message_t>) async {
        let eventType = message.pointee.event_type
        let process = message.pointee.process
        let processID = audit_token_to_pid(process.pointee.audit_token)
        
        switch eventType {
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            logger.debug("File write notification: pid=\(processID)")
            
        case ES_EVENT_TYPE_NOTIFY_EXIT:
            logger.debug("Process exit notification: pid=\(processID)")
            
        default:
            logger.debug("Notify event: type=\(eventType.rawValue), pid=\(processID)")
        }
        
        // Log NOTIFY events with comprehensive details (Requirement 2.10, 17.4)
        logSecurityEvent(
            eventType: eventType,
            processID: processID,
            action: .allow, // NOTIFY events are informational
            message: message
        )
    }
    
    /// Log security event with comprehensive details
    /// Requirements: 2.10, 17.4
    /// - Parameters:
    ///   - eventType: The type of security event
    ///   - processID: The process ID
    ///   - action: The action taken (allow/deny)
    ///   - message: The ES message pointer for extracting additional details
    private func logSecurityEvent(
        eventType: es_event_type_t,
        processID: pid_t,
        action: ESAuthResult,
        message: UnsafePointer<es_message_t>
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let process = message.pointee.process
        let executablePath = extractExecutablePath(from: process) ?? "unknown"
        
        // Determine event type string
        let eventTypeString: String
        switch eventType {
        case ES_EVENT_TYPE_AUTH_EXEC:
            eventTypeString = "EXEC"
        case ES_EVENT_TYPE_AUTH_OPEN:
            eventTypeString = "OPEN"
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            eventTypeString = "WRITE"
        case ES_EVENT_TYPE_NOTIFY_EXIT:
            eventTypeString = "EXIT"
        default:
            eventTypeString = "UNKNOWN(\(eventType.rawValue))"
        }
        
        // Determine action string
        let actionString: String
        switch action {
        case .allow:
            actionString = "ALLOW"
        case .deny:
            actionString = "DENY"
        case .allowWithModification:
            actionString = "ALLOW_MODIFIED"
        }
        
        // Format comprehensive log entry
        // Format: [timestamp] [event_type] pid=<pid> path=<executable_path> action=<action> result=<result>
        let logMessage = "[\(timestamp)] [\(eventTypeString)] pid=\(processID) path=\(executablePath) action=\(actionString) result=\(actionString)"
        
        // Write to file log
        fileLogger.log(logMessage)
        
        // Also log to structured logger for debugging
        logger.info("Security event logged", metadata: [
            "event_type": .string(eventTypeString),
            "process_id": .stringConvertible(processID),
            "executable_path": .string(executablePath),
            "action": .string(actionString)
        ])
    }
    
    /// Extract executable path from process
    /// - Parameter process: ES process pointer
    /// - Returns: Executable path string or nil
    private func extractExecutablePath(from process: UnsafePointer<es_process_t>) -> String? {
        let executable = process.pointee.executable
        let path = executable.pointee.path
        
        return String(cString: path.data)
    }
    
    /// Extract arguments from exec event
    /// - Parameter message: ES message pointer
    /// - Returns: Array of argument strings
    private func extractArguments(from message: UnsafePointer<es_message_t>) -> [String] {
        guard message.pointee.event_type == ES_EVENT_TYPE_AUTH_EXEC else {
            return []
        }
        
        // Simplified: return empty array for now
        // Full implementation requires proper C union handling
        return []
    }
    
    /// Extract parent process ID
    /// - Parameter process: ES process pointer
    /// - Returns: Parent process ID
    private func extractParentProcessID(from process: UnsafePointer<es_process_t>) -> pid_t {
        // Access parent audit token directly
        let parent = process.pointee.parent_audit_token
        return audit_token_to_pid(parent)
    }
    
    /// Extract file path from AUTH_OPEN event
    /// - Parameter message: ES message pointer
    /// - Returns: File path string or nil
    private func extractFilePath(from message: UnsafePointer<es_message_t>) -> String? {
        guard message.pointee.event_type == ES_EVENT_TYPE_AUTH_OPEN else {
            return nil
        }
        
        // Simplified: return nil for now
        // Full implementation requires proper C union handling
        return nil
    }
    
    /// Extract access type from AUTH_OPEN event
    /// - Parameter message: ES message pointer
    /// - Returns: File access type
    private func extractAccessType(from message: UnsafePointer<es_message_t>) -> FileAccessType {
        guard message.pointee.event_type == ES_EVENT_TYPE_AUTH_OPEN else {
            return .read
        }
        
        // Simplified: default to read for now
        // Full implementation requires proper C union handling
        return .read
    }
}

// MARK: - Security Event Handler Protocol

/// Protocol for handling security events
public protocol SecurityEventHandler {
    /// Check if handler can process this event type
    /// - Parameter eventType: Security event type
    /// - Returns: True if handler can process this event
    func canHandle(_ eventType: SecurityEventType) -> Bool
    
    /// Handle process execution event
    /// - Parameter event: Process execution event
    /// - Returns: Authorization result
    func handleProcessExecution(_ event: ProcessExecutionEvent) async -> ESAuthResult
    
    /// Handle file access event
    /// - Parameter event: File access event
    /// - Returns: Authorization result
    func handleFileAccess(_ event: FileAccessEvent) async -> ESAuthResult
    
    /// Handle network event
    /// - Parameter event: Network event
    /// - Returns: Authorization result
    func handleNetworkEvent(_ event: PrivarionSharedModels.NetworkEvent) async -> ESAuthResult
}

// MARK: - ESAuthResult Extensions

extension ESAuthResult {
    /// Convert to Endpoint Security Framework auth result
    /// - Returns: ES auth result constant
    func toESAuthResult() -> es_auth_result_t {
        switch self {
        case .allow:
            return ES_AUTH_RESULT_ALLOW
        case .deny:
            return ES_AUTH_RESULT_DENY
        case .allowWithModification:
            // Note: Modification not fully supported yet
            return ES_AUTH_RESULT_ALLOW
        }
    }
}
