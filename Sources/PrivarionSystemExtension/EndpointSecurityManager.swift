// PrivarionSystemExtension - Endpoint Security Manager
// Manages Endpoint Security Framework client lifecycle and event subscriptions
// Requirements: 2.1-2.10, 14.6

import Foundation
import CEndpointSecurity
import Logging
import PrivarionSharedModels
import PrivarionCore

/// Manages the Endpoint Security Framework client lifecycle
/// Handles initialization, event subscription, and cleanup of ES client
public class EndpointSecurityManager {
    // MARK: - Properties
    
    /// ES client handle (opaque pointer to es_client_t)
    private var client: OpaquePointer?
    
    /// Logger for ES operations
    private let logger: Logger
    
    /// Security event processor for handling events
    private let eventProcessor: SecurityEventProcessor
    
    /// Protection policy engine for policy evaluation
    private let policyEngine: ProtectionPolicyEngine
    
    /// Thread-safe access to client
    private let queue = DispatchQueue(label: "com.privarion.endpointsecurity", attributes: .concurrent)
    
    /// Flag indicating if client is active
    private var isActive: Bool = false
    
    // MARK: - Initialization
    
    /// Initialize the Endpoint Security Manager
    /// - Parameters:
    ///   - policyEngine: Protection policy engine for policy evaluation
    ///   - logger: Optional logger instance (creates default if not provided)
    ///   - eventProcessor: Optional event processor (creates default if not provided)
    public init(policyEngine: ProtectionPolicyEngine, logger: Logger? = nil, eventProcessor: SecurityEventProcessor? = nil) {
        self.policyEngine = policyEngine
        self.logger = logger ?? Logger(label: "com.privarion.endpointsecurity")
        self.eventProcessor = eventProcessor ?? SecurityEventProcessor(policyEngine: policyEngine, logger: self.logger)
    }
    
    // MARK: - Public Methods
    
    /// Initialize the Endpoint Security client
    /// Creates a new ES client using es_new_client()
    /// Requires Full Disk Access permission
    /// - Throws: EndpointSecurityError if initialization fails
    public func initialize() throws {
        try queue.sync(flags: .barrier) {
            // Check if already initialized
            guard client == nil else {
                logger.warning("ES client already initialized")
                return
            }
            
            logger.info("Initializing Endpoint Security client")
            
            // Create ES client with event handler
            var newClient: OpaquePointer?
            let result = es_new_client(&newClient) { [weak self] client, message in
                // Event handler callback - will be implemented in SecurityEventProcessor
                // For now, just log that we received an event
                self?.handleEvent(client: client, message: message)
            }
            
            // Check initialization result
            switch result {
            case ES_NEW_CLIENT_RESULT_SUCCESS:
                self.client = newClient
                self.isActive = true
                logger.info("Endpoint Security client initialized successfully")
                
            case ES_NEW_CLIENT_RESULT_ERR_NOT_ENTITLED:
                logger.error("ES client initialization failed: Not entitled (missing com.apple.developer.endpoint-security.client entitlement)")
                throw EndpointSecurityError.clientInitializationFailed(Int32(result.rawValue))
                
            case ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED:
                logger.error("ES client initialization failed: Not permitted (Full Disk Access required)")
                throw EndpointSecurityError.fullDiskAccessDenied
                
            case ES_NEW_CLIENT_RESULT_ERR_NOT_PRIVILEGED:
                logger.error("ES client initialization failed: Not privileged (must run as root)")
                throw EndpointSecurityError.clientInitializationFailed(Int32(result.rawValue))
                
            case ES_NEW_CLIENT_RESULT_ERR_TOO_MANY_CLIENTS:
                logger.error("ES client initialization failed: Too many clients")
                throw EndpointSecurityError.clientInitializationFailed(Int32(result.rawValue))
                
            case ES_NEW_CLIENT_RESULT_ERR_INTERNAL:
                logger.error("ES client initialization failed: Internal error")
                throw EndpointSecurityError.clientInitializationFailed(Int32(result.rawValue))
                
            default:
                logger.error("ES client initialization failed with unknown result: \(result.rawValue)")
                throw EndpointSecurityError.clientInitializationFailed(Int32(result.rawValue))
            }
        }
    }
    
    /// Subscribe to specific event types
    /// - Parameter events: Array of event types to subscribe to
    /// - Throws: EndpointSecurityError if subscription fails
    public func subscribe(to events: [es_event_type_t]) throws {
        try queue.sync(flags: .barrier) {
            guard let client = self.client else {
                logger.error("Cannot subscribe: ES client not initialized")
                throw EndpointSecurityError.clientInitializationFailed(-1)
            }
            
            guard isActive else {
                logger.error("Cannot subscribe: ES client not active")
                throw EndpointSecurityError.clientDisconnected
            }
            
            logger.info("Subscribing to \(events.count) event types")
            
            // Subscribe to events
            let result = es_subscribe(client, events, UInt32(events.count))
            
            switch result {
            case ES_RETURN_SUCCESS:
                logger.info("Successfully subscribed to events: \(events.map { $0.rawValue })")
                
            case ES_RETURN_ERROR:
                logger.error("Failed to subscribe to events")
                throw EndpointSecurityError.subscriptionFailed(0)
                
            default:
                logger.error("Subscription failed with unknown result: \(result.rawValue)")
                throw EndpointSecurityError.subscriptionFailed(UInt32(result.rawValue))
            }
        }
    }
    
    /// Unsubscribe from all events and cleanup ES client
    /// - Throws: EndpointSecurityError if cleanup fails
    public func unsubscribe() throws {
        try queue.sync(flags: .barrier) {
            guard let client = self.client else {
                logger.warning("Cannot unsubscribe: ES client not initialized")
                return
            }
            
            logger.info("Unsubscribing from all events and cleaning up ES client")
            
            // Unsubscribe from all events
            let unsubscribeResult = es_unsubscribe_all(client)
            
            if unsubscribeResult != ES_RETURN_SUCCESS {
                logger.warning("Failed to unsubscribe from events: \(unsubscribeResult.rawValue)")
            }
            
            // Delete the client
            let deleteResult = es_delete_client(client)
            
            if deleteResult != ES_RETURN_SUCCESS {
                logger.error("Failed to delete ES client: \(deleteResult.rawValue)")
                throw EndpointSecurityError.clientInitializationFailed(Int32(deleteResult.rawValue))
            }
            
            self.client = nil
            self.isActive = false
            logger.info("ES client cleaned up successfully")
        }
    }
    
    /// Get the event processor for registering handlers
    /// - Returns: Security event processor instance
    public func getEventProcessor() -> SecurityEventProcessor {
        return eventProcessor
    }
    
    /// Check if the ES client is active
    /// - Returns: True if client is initialized and active
    public func isClientActive() -> Bool {
        return queue.sync {
            return isActive && client != nil
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle incoming ES events
    /// Delegates to SecurityEventProcessor for async processing
    /// - Parameters:
    ///   - client: ES client pointer
    ///   - message: ES message pointer
    private func handleEvent(client: OpaquePointer, message: UnsafePointer<es_message_t>) {
        // Extract event type for logging
        let eventType = message.pointee.event_type
        let processID = audit_token_to_pid(message.pointee.process.pointee.audit_token)
        
        logger.debug("Received ES event: type=\(eventType), pid=\(processID)")
        
        // Process event asynchronously using SecurityEventProcessor
        Task {
            await eventProcessor.processEvent(client: client, message: message)
        }
    }
    
    // MARK: - Deinitialization
    
    deinit {
        // Cleanup on deallocation
        if client != nil {
            do {
                try unsubscribe()
            } catch {
                logger.error("Failed to cleanup ES client in deinit: \(error)")
            }
        }
    }
}

// MARK: - Helper Extensions

extension es_event_type_t: @retroactive CustomStringConvertible {
    public var description: String {
        switch self {
        case ES_EVENT_TYPE_AUTH_EXEC:
            return "AUTH_EXEC"
        case ES_EVENT_TYPE_AUTH_OPEN:
            return "AUTH_OPEN"
        case ES_EVENT_TYPE_NOTIFY_WRITE:
            return "NOTIFY_WRITE"
        case ES_EVENT_TYPE_NOTIFY_EXIT:
            return "NOTIFY_EXIT"
        default:
            return "UNKNOWN(\(self.rawValue))"
        }
    }
}
