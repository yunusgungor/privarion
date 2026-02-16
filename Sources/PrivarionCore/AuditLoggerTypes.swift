import Foundation
import Logging
import os.log

/// Types for the Audit Logger system
public enum AuditLoggerTypes {
    
    // MARK: - Audit Event
    
    /// Security audit event
    public struct AuditEvent {
        public let id: UUID
        public let timestamp: Date
        public let eventType: EventType
        public let severity: Severity
        public let source: String
        public let action: String
        public let resource: String?
        public let user: UserContext?
        public let process: ProcessContext?
        public let network: NetworkContext?
        public let outcome: Outcome
        public let details: [String: String]
        public let correlationId: String?
        
        public enum EventType: String, CaseIterable, Codable {
            case authentication = "AUTHENTICATION"
            case authorization = "AUTHORIZATION"
            case dataAccess = "DATA_ACCESS"
            case systemCall = "SYSTEM_CALL"
            case networkActivity = "NETWORK_ACTIVITY"
            case processActivity = "PROCESS_ACTIVITY"
            case fileSystemActivity = "FILESYSTEM_ACTIVITY"
            case configurationChange = "CONFIGURATION_CHANGE"
            case securityViolation = "SECURITY_VIOLATION"
            case anomalyDetection = "ANOMALY_DETECTION"
            case sandboxActivity = "SANDBOX_ACTIVITY"
            case privacyEvent = "PRIVACY_EVENT"
            case userActivity = "USER_ACTIVITY"
            case complianceEvent = "COMPLIANCE_EVENT"
        }
        
        public enum Severity: String, CaseIterable, Codable {
            case emergency = "EMERGENCY"
            case alert = "ALERT"
            case critical = "CRITICAL"
            case error = "ERROR"
            case warning = "WARNING"
            case notice = "NOTICE"
            case info = "INFO"
            case debug = "DEBUG"
        }
        
        public enum Outcome: String, CaseIterable, Codable {
            case success = "SUCCESS"
            case failure = "FAILURE"
            case blocked = "BLOCKED"
            case allowed = "ALLOWED"
            case unknown = "UNKNOWN"
        }
        
        public struct UserContext {
            public let uid: UInt32
            public let gid: UInt32
            public let username: String?
            public let sessionId: String?
            
            public init(uid: UInt32, gid: UInt32, username: String? = nil, sessionId: String? = nil) {
                self.uid = uid
                self.gid = gid
                self.username = username
                self.sessionId = sessionId
            }
        }
        
        public struct ProcessContext {
            public let pid: Int32
            public let ppid: Int32
            public let name: String
            public let path: String?
            public let arguments: [String]
            public let environment: [String: String]?
            
            public init(
                pid: Int32,
                ppid: Int32,
                name: String,
                path: String? = nil,
                arguments: [String] = [],
                environment: [String: String]? = nil
            ) {
                self.pid = pid
                self.ppid = ppid
                self.name = name
                self.path = path
                self.arguments = arguments
                self.environment = environment
            }
        }
        
        public struct NetworkContext {
            public let localAddress: String
            public let remoteAddress: String
            public let localPort: Int
            public let remotePort: Int
            public let networkProtocol: String
            public let dataSize: UInt64?
            
            public init(
                localAddress: String,
                remoteAddress: String,
                localPort: Int,
                remotePort: Int,
                networkProtocol: String,
                dataSize: UInt64? = nil
            ) {
                self.localAddress = localAddress
                self.remoteAddress = remoteAddress
                self.localPort = localPort
                self.remotePort = remotePort
                self.networkProtocol = networkProtocol
                self.dataSize = dataSize
            }
        }
        
        public init(
            eventType: EventType,
            severity: Severity,
            source: String,
            action: String,
            resource: String? = nil,
            user: UserContext? = nil,
            process: ProcessContext? = nil,
            network: NetworkContext? = nil,
            outcome: Outcome,
            details: [String: String] = [:],
            correlationId: String? = nil
        ) {
            self.id = UUID()
            self.timestamp = Date()
            self.eventType = eventType
            self.severity = severity
            self.source = source
            self.action = action
            self.resource = resource
            self.user = user
            self.process = process
            self.network = network
            self.outcome = outcome
            self.details = details
            self.correlationId = correlationId
        }
    }
    
    // MARK: - Audit Configuration
    
    /// Audit configuration
    public struct AuditConfiguration {
        public var enabled: Bool = true
        public var logLevel: AuditEvent.Severity = .info
        public var destinations: [LogDestination] = [.file, .system]
        public var retentionDays: Int = 90
        public var maxFileSizeMB: Int = 100
        public var rotationPolicy: RotationPolicy = .daily
        public var encryptionEnabled: Bool = false
        public var compressionEnabled: Bool = true
        public var realTimeAlerts: Bool = true
        public var structuredLogging: Bool = true
        
        public enum LogDestination: Equatable {
            case file
            case system
            case syslog
            case network(url: URL)
            case database
        }
        
        public enum RotationPolicy {
            case hourly
            case daily
            case weekly
            case size(Int) // MB
        }
        
        public enum ExportFormat {
            case json
            case csv
            case xml
        }
        
        public init() {}
    }
    
    // MARK: - Audit Statistics
    
    /// Audit statistics
    public struct AuditStatistics {
        public var totalEvents: UInt64 = 0
        public var eventsByType: [AuditEvent.EventType: UInt64] = [:]
        public var eventsBySeverity: [AuditEvent.Severity: UInt64] = [:]
        public var eventsPerHour: UInt64 = 0
        public var averageEventsPerDay: Double = 0.0
        public var lastEventTime: Date? = nil
        public var uptime: TimeInterval = 0
        public var storageUsedMB: Double = 0
        
        public init() {}
    }
    
    // MARK: - Audit Errors
    
    /// Audit logger errors
    public enum AuditError: Error, LocalizedError {
        case configurationError(String)
        case storageError(String)
        case encryptionError(String)
        case networkError(String)
        case validationError(String)
        case retentionError(String)
        
        public var errorDescription: String? {
            switch self {
            case .configurationError(let detail):
                return "Audit configuration error: \(detail)"
            case .storageError(let detail):
                return "Audit storage error: \(detail)"
            case .encryptionError(let detail):
                return "Audit encryption error: \(detail)"
            case .networkError(let detail):
                return "Audit network error: \(detail)"
            case .validationError(let detail):
                return "Audit validation error: \(detail)"
            case .retentionError(let detail):
                return "Audit retention error: \(detail)"
            }
        }
    }
}

// MARK: - Codable Extensions

extension AuditLoggerTypes.AuditEvent: Codable {
    enum CodingKeys: String, CodingKey {
        case id, timestamp, eventType, severity, source, action, resource
        case user, process, network, outcome, details, correlationId
    }
}

extension AuditLoggerTypes.AuditEvent.UserContext: Codable {}
extension AuditLoggerTypes.AuditEvent.ProcessContext: Codable {}
extension AuditLoggerTypes.AuditEvent.NetworkContext: Codable {}

// Type aliases for backward compatibility
public typealias AuditEvent = AuditLoggerTypes.AuditEvent
public typealias AuditConfiguration = AuditLoggerTypes.AuditConfiguration
public typealias AuditStatistics = AuditLoggerTypes.AuditStatistics
public typealias AuditError = AuditLoggerTypes.AuditError
