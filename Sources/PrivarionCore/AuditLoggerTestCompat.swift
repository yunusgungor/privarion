import Foundation

/// Test interface compatibility types and methods for AuditLogger
public enum AuditLoggerTestCompat {
    
    // MARK: - Security Event
    
    public struct SecurityEvent {
        public let type: EventType
        public let severity: Severity
        public let source: String
        public let target: String
        public let details: [String: String]
        
        public enum EventType: String, CaseIterable {
            case accessGranted = "ACCESS_GRANTED"
            case accessDenied = "ACCESS_DENIED"
            case privilegeEscalation = "PRIVILEGE_ESCALATION"
            case suspiciousActivity = "SUSPICIOUS_ACTIVITY"
            case policyViolation = "POLICY_VIOLATION"
            case authenticationFailure = "AUTHENTICATION_FAILURE"
            case dataAccess = "DATA_ACCESS"
        }
        
        public enum Severity: String, CaseIterable {
            case low = "LOW"
            case medium = "MEDIUM"
            case high = "HIGH"
            case critical = "CRITICAL"
        }
        
        public init(
            type: EventType,
            severity: Severity,
            source: String,
            target: String,
            details: [String: String] = [:]
        ) {
            self.type = type
            self.severity = severity
            self.source = source
            self.target = target
            self.details = details
        }
    }
    
    // MARK: - System Event
    
    public struct SystemEvent {
        public let type: EventType
        public let component: String
        public let operation: String
        public let details: [String: String]
        
        public enum EventType: String, CaseIterable {
            case serviceStart = "SERVICE_START"
            case serviceStop = "SERVICE_STOP"
            case configurationChange = "CONFIGURATION_CHANGE"
            case softwareUpdate = "SOFTWARE_UPDATE"
            case errorOccurred = "ERROR_OCCURRED"
            case performanceIssue = "PERFORMANCE_ISSUE"
        }
        
        public init(
            type: EventType,
            component: String,
            operation: String,
            details: [String: String] = [:]
        ) {
            self.type = type
            self.component = component
            self.operation = operation
            self.details = details
        }
    }
    
    // MARK: - User Event
    
    public struct UserEvent {
        public let action: Action
        public let userId: String
        public let details: [String: String]
        public let sessionID: String?
        public let clientInfo: ClientInfo?
        
        public enum Action: String, CaseIterable {
            case login = "LOGIN"
            case logout = "LOGOUT"
            case dataExport = "DATA_EXPORT"
            case dataDelete = "DATA_DELETE"
            case settingsChange = "SETTINGS_CHANGE"
            case profileAccess = "PROFILE_ACCESS"
        }
        
        public init(
            userID: String,
            action: Action,
            sessionID: String? = nil,
            clientInfo: ClientInfo? = nil,
            details: [String: String] = [:]
        ) {
            self.action = action
            self.userId = userID
            self.details = details
            self.sessionID = sessionID
            self.clientInfo = clientInfo
        }
    }
    
    // MARK: - Client Info
    
    public struct ClientInfo {
        public let ipAddress: String
        public let userAgent: String
        public let deviceID: String?
        public let location: String?
        
        public init(ipAddress: String, userAgent: String, deviceID: String? = nil, location: String? = nil) {
            self.ipAddress = ipAddress
            self.userAgent = userAgent
            self.deviceID = deviceID
            self.location = location
        }
    }
    
    // MARK: - Compliance Event
    
    public struct ComplianceEvent {
        public let regulationType: RegulationType
        public let event: String
        public let details: [String: String]
        public let eventType: EventType?
        public let dataSubject: String?
        public let processingBasis: String?
        public let dataCategories: [String]?
        
        public enum RegulationType: String, CaseIterable {
            case gdpr = "GDPR"
            case ccpa = "CCPA"
            case hipaa = "HIPAA"
            case sox = "SOX"
            case pci = "PCI"
        }
        
        public enum EventType: String, CaseIterable {
            case dataProcessing = "DATA_PROCESSING"
            case dataAccess = "DATA_ACCESS"
            case dataExport = "DATA_EXPORT"
            case dataDelete = "DATA_DELETE"
            case consentChange = "CONSENT_CHANGE"
        }
        
        public init(
            regulationType: RegulationType,
            eventType: EventType? = nil,
            dataSubject: String? = nil,
            processingBasis: String? = nil,
            dataCategories: [String]? = nil,
            details: [String: String] = [:]
        ) {
            self.regulationType = regulationType
            self.event = eventType?.rawValue ?? "UNKNOWN"
            self.details = details
            self.eventType = eventType
            self.dataSubject = dataSubject
            self.processingBasis = processingBasis
            self.dataCategories = dataCategories
        }
    }
    
    // MARK: - Configuration
    
    public struct Configuration {
        public let logLevel: LogLevel
        public let enableFileLogging: Bool
        public let enableSystemLogging: Bool
        public let enableNetworkLogging: Bool
        public let logFilePath: String
        public let logDirectory: String?
        public let maxLogFileSize: Int
        public let maxLogFiles: Int
        public let rotationInterval: TimeInterval
        public let logRotationEnabled: Bool?
        public let compressionEnabled: Bool
        public let encryptionEnabled: Bool
        public let bufferSize: Int?
        public let retentionDays: Int
        public let flushInterval: TimeInterval
        public let includeStackTrace: Bool
        public let timestampFormat: TimestampFormat
        public let structuredLogging: Bool
        
        public enum LogLevel: String, CaseIterable {
            case debug = "DEBUG"
            case info = "INFO"
            case warning = "WARNING"
            case error = "ERROR"
            case critical = "CRITICAL"
        }
        
        public enum TimestampFormat: String, CaseIterable {
            case iso8601 = "ISO8601"
            case rfc3339 = "RFC3339"
            case unix = "UNIX"
        }
        
        public init(
            logLevel: LogLevel = .info,
            enableFileLogging: Bool = true,
            enableSystemLogging: Bool = false,
            enableNetworkLogging: Bool = false,
            logFilePath: String = "/tmp/audit.log",
            logDirectory: String? = nil,
            maxLogFileSize: Int = 10485760,
            maxLogFiles: Int = 5,
            rotationInterval: TimeInterval = 86400,
            logRotationEnabled: Bool? = nil,
            compressionEnabled: Bool = true,
            encryptionEnabled: Bool = false,
            bufferSize: Int? = nil,
            retentionDays: Int = 30,
            flushInterval: TimeInterval = 1.0,
            includeStackTrace: Bool = false,
            timestampFormat: TimestampFormat = .iso8601,
            structuredLogging: Bool = true
        ) {
            self.logLevel = logLevel
            self.enableFileLogging = enableFileLogging
            self.enableSystemLogging = enableSystemLogging
            self.enableNetworkLogging = enableNetworkLogging
            self.logFilePath = logFilePath
            self.logDirectory = logDirectory
            self.maxLogFileSize = maxLogFileSize
            self.maxLogFiles = maxLogFiles
            self.rotationInterval = rotationInterval
            self.logRotationEnabled = logRotationEnabled
            self.compressionEnabled = compressionEnabled
            self.encryptionEnabled = encryptionEnabled
            self.bufferSize = bufferSize
            self.retentionDays = retentionDays
            self.flushInterval = flushInterval
            self.includeStackTrace = includeStackTrace
            self.timestampFormat = timestampFormat
            self.structuredLogging = structuredLogging
        }
    }
    
    // MARK: - Query Parameters
    
    public struct QueryParameters {
        public let startTime: Date
        public let endTime: Date
        public let eventTypes: [EventType]
        public let severityLevels: [Severity]?
        public let sources: [String]?
        public let limit: Int
        public let offset: Int
        
        public enum EventType: String, CaseIterable {
            case security = "SECURITY"
            case system = "SYSTEM"
            case user = "USER"
            case compliance = "COMPLIANCE"
        }
        
        public enum Severity: String, CaseIterable {
            case low = "LOW"
            case medium = "MEDIUM"
            case high = "HIGH"
            case critical = "CRITICAL"
        }
        
        public init(
            startTime: Date,
            endTime: Date,
            eventTypes: [EventType] = [],
            severityLevels: [Severity]? = nil,
            sources: [String]? = nil,
            limit: Int = 100,
            offset: Int = 0
        ) {
            self.startTime = startTime
            self.endTime = endTime
            self.eventTypes = eventTypes
            self.severityLevels = severityLevels
            self.sources = sources
            self.limit = limit
            self.offset = offset
        }
    }
    
    // MARK: - Query Result
    
    public struct QueryResult {
        public let source: String
        public let severity: SecurityEvent.Severity
        public let timestamp: Date
        public let details: [String: String]
        
        public let type: SecurityEvent.EventType?
        
        public let component: String?
        public let operation: String?
        
        public let userID: String?
        public let action: UserEvent.Action?
        public let sessionID: String?
        
        public let regulationType: ComplianceEvent.RegulationType?
        public let eventType: ComplianceEvent.EventType?
        public let dataSubject: String?
        
        public init(
            source: String,
            severity: SecurityEvent.Severity,
            timestamp: Date,
            details: [String: String] = [:],
            type: SecurityEvent.EventType? = nil,
            component: String? = nil,
            operation: String? = nil,
            userID: String? = nil,
            action: UserEvent.Action? = nil,
            sessionID: String? = nil,
            regulationType: ComplianceEvent.RegulationType? = nil,
            eventType: ComplianceEvent.EventType? = nil,
            dataSubject: String? = nil
        ) {
            self.source = source
            self.severity = severity
            self.timestamp = timestamp
            self.details = details
            self.type = type
            self.component = component
            self.operation = operation
            self.userID = userID
            self.action = action
            self.sessionID = sessionID
            self.regulationType = regulationType
            self.eventType = eventType
            self.dataSubject = dataSubject
        }
    }
    
    // MARK: - Operation Result
    
    public struct OperationResult {
        public let success: Bool
        public let message: String?
        public let error: Error?
        public let logEntryID: String?
        public let timestamp: Date?
        
        public init(success: Bool, message: String? = nil, error: Error? = nil, logEntryID: String? = nil, timestamp: Date? = nil) {
            self.success = success
            self.message = message
            self.error = error
            self.logEntryID = logEntryID
            self.timestamp = timestamp
        }
    }
    
    // MARK: - Test Statistics
    
    public struct TestStatistics {
        public let totalEvents: Int
        public let eventsByType: [String: Int]
        public let eventsBySeverity: [String: Int]
        public let averageProcessingTime: Double
        public let storageUsage: Double
        public let securityEvents: Int
        public let systemEvents: Int
        public let eventsToday: Int
        public let uniqueSources: Int
        public let lastEventTime: Date?
        
        public init(
            totalEvents: Int = 0,
            eventsByType: [String: Int] = [:],
            eventsBySeverity: [String: Int] = [:],
            averageProcessingTime: Double = 0.0,
            storageUsage: Double = 0.0,
            securityEvents: Int = 0,
            systemEvents: Int = 0,
            eventsToday: Int = 0,
            uniqueSources: Int = 0,
            lastEventTime: Date? = nil
        ) {
            self.totalEvents = totalEvents
            self.eventsByType = eventsByType
            self.eventsBySeverity = eventsBySeverity
            self.averageProcessingTime = averageProcessingTime
            self.storageUsage = storageUsage
            self.securityEvents = securityEvents
            self.systemEvents = systemEvents
            self.eventsToday = eventsToday
            self.uniqueSources = uniqueSources
            self.lastEventTime = lastEventTime
        }
    }
}

// Type aliases for backward compatibility (excluding Configuration to avoid conflict with existing type)
public typealias SecurityEvent = AuditLoggerTestCompat.SecurityEvent
public typealias SystemEvent = AuditLoggerTestCompat.SystemEvent
public typealias UserEvent = AuditLoggerTestCompat.UserEvent
public typealias ClientInfo = AuditLoggerTestCompat.ClientInfo
public typealias ComplianceEvent = AuditLoggerTestCompat.ComplianceEvent
public typealias QueryParameters = AuditLoggerTestCompat.QueryParameters
public typealias QueryResult = AuditLoggerTestCompat.QueryResult
public typealias OperationResult = AuditLoggerTestCompat.OperationResult
public typealias TestStatistics = AuditLoggerTestCompat.TestStatistics
