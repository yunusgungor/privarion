// PrivarionSharedModels - Network Data Models
// Data structures for network filtering and DNS operations
// Requirements: 3.1-3.12, 4.1-4.12

import Foundation

/// Network request structure with connection details
public struct NetworkRequest: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let processID: pid_t
    public let sourceIP: String
    public let sourcePort: Int
    public let destinationIP: String
    public let destinationPort: Int
    public let `protocol`: NetworkProtocol
    public let domain: String?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        processID: pid_t,
        sourceIP: String,
        sourcePort: Int,
        destinationIP: String,
        destinationPort: Int,
        protocol: NetworkProtocol,
        domain: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.processID = processID
        self.sourceIP = sourceIP
        self.sourcePort = sourcePort
        self.destinationIP = destinationIP
        self.destinationPort = destinationPort
        self.protocol = `protocol`
        self.domain = domain
    }
}

/// DNS query type enumeration
public enum DNSQueryType: UInt16, Codable {
    case A = 1
    case AAAA = 28
    case CNAME = 5
    case MX = 15
}

/// DNS query structure
public struct DNSQuery: Codable {
    public let id: UInt16
    public let domain: String
    public let queryType: DNSQueryType
    public let timestamp: Date
    
    public init(
        id: UInt16,
        domain: String,
        queryType: DNSQueryType,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.domain = domain
        self.queryType = queryType
        self.timestamp = timestamp
    }
}

/// DNS response structure with caching support
public struct DNSResponse: Codable {
    public let id: UInt16
    public let domain: String
    public let addresses: [String]
    public let ttl: TimeInterval
    public let cached: Bool
    public let timestamp: Date
    
    public init(
        id: UInt16,
        domain: String,
        addresses: [String],
        ttl: TimeInterval,
        cached: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.domain = domain
        self.addresses = addresses
        self.ttl = ttl
        self.cached = cached
        self.timestamp = timestamp
    }
    
    /// Check if the response is still valid based on TTL
    public var isValid: Bool {
        return Date().timeIntervalSince(timestamp) < ttl
    }
}
