// PrivarionSharedModels - Security Event Data Models
// Data structures for Endpoint Security Framework events
// Requirements: 2.1-2.10

import Foundation

/// Type of security event captured by Endpoint Security Framework
public enum SecurityEventType: String, Codable {
    case processExecution
    case fileAccess
    case networkConnection
    case dnsQuery
}

/// Action taken on a security event
public enum SecurityAction: String, Codable {
    case allow
    case deny
    case monitor
    case modify
}

/// Result of event authorization
public enum ESAuthResult: String, Codable {
    case allow
    case deny
    case allowWithModification
}

/// Type of file access operation
public enum FileAccessType: String, Codable {
    case read
    case write
    case execute
}

/// Core security event structure
public struct SecurityEvent: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let type: SecurityEventType
    public let processID: pid_t
    public let executablePath: String
    public let action: SecurityAction
    public let result: ESAuthResult
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: SecurityEventType,
        processID: pid_t,
        executablePath: String,
        action: SecurityAction,
        result: ESAuthResult
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.processID = processID
        self.executablePath = executablePath
        self.action = action
        self.result = result
    }
}

/// Process execution event with detailed process information
public struct ProcessExecutionEvent: Codable {
    public let processID: pid_t
    public let executablePath: String
    public let arguments: [String]
    public let environment: [String: String]
    public let parentProcessID: pid_t
    public let timestamp: Date
    
    public init(
        processID: pid_t,
        executablePath: String,
        arguments: [String],
        environment: [String: String],
        parentProcessID: pid_t,
        timestamp: Date = Date()
    ) {
        self.processID = processID
        self.executablePath = executablePath
        self.arguments = arguments
        self.environment = environment
        self.parentProcessID = parentProcessID
        self.timestamp = timestamp
    }
}

/// File access event with path and access type
public struct FileAccessEvent: Codable {
    public let processID: pid_t
    public let filePath: String
    public let accessType: FileAccessType
    public let timestamp: Date
    
    public init(
        processID: pid_t,
        filePath: String,
        accessType: FileAccessType,
        timestamp: Date = Date()
    ) {
        self.processID = processID
        self.filePath = filePath
        self.accessType = accessType
        self.timestamp = timestamp
    }
}

/// Network event with connection details
public struct NetworkEvent: Codable {
    public let processID: pid_t
    public let sourceIP: String
    public let sourcePort: Int
    public let destinationIP: String
    public let destinationPort: Int
    public let `protocol`: NetworkProtocol
    public let timestamp: Date
    
    public init(
        processID: pid_t,
        sourceIP: String,
        sourcePort: Int,
        destinationIP: String,
        destinationPort: Int,
        protocol: NetworkProtocol,
        timestamp: Date = Date()
    ) {
        self.processID = processID
        self.sourceIP = sourceIP
        self.sourcePort = sourcePort
        self.destinationIP = destinationIP
        self.destinationPort = destinationPort
        self.protocol = `protocol`
        self.timestamp = timestamp
    }
}

/// Network protocol types
public enum NetworkProtocol: String, Codable {
    case tcp
    case udp
    case icmp
}
