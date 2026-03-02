import Foundation
import PrivarionSharedModels

// MARK: - Telemetry Blocker

/// Identifies and blocks application telemetry and analytics traffic
/// Requirements: 10.2-10.3, 10.9
public class TelemetryBlocker {
    // MARK: - Properties
    
    /// Telemetry database containing known endpoints and patterns
    private let telemetryDatabase: TelemetryDatabase
    
    /// Pattern matcher for detecting telemetry in requests
    private let patternMatcher: TelemetryPatternMatcher
    
    /// Thread-safe access queue
    private let queue = DispatchQueue(label: "com.privarion.telemetry-blocker", attributes: .concurrent)
    
    /// User-defined telemetry patterns
    private var userDefinedPatterns: [TelemetryPattern]
    
    // MARK: - Initialization
    
    /// Initialize telemetry blocker with database and pattern matcher
    /// - Parameters:
    ///   - telemetryDatabase: The telemetry database to use
    ///   - patternMatcher: The pattern matcher to use
    ///   - userDefinedPatterns: Optional user-defined patterns
    public init(
        telemetryDatabase: TelemetryDatabase,
        patternMatcher: TelemetryPatternMatcher,
        userDefinedPatterns: [TelemetryPattern] = []
    ) {
        self.telemetryDatabase = telemetryDatabase
        self.patternMatcher = patternMatcher
        self.userDefinedPatterns = userDefinedPatterns
    }
    
    /// Initialize with default database and pattern matcher
    public convenience init() {
        let database = TelemetryDatabase.defaultDatabase()
        let matcher = TelemetryPatternMatcher(database: database)
        self.init(telemetryDatabase: database, patternMatcher: matcher)
    }
    
    // MARK: - Request Evaluation
    
    /// Evaluate a network request to determine if it should be blocked
    /// Requirements: 10.2-10.3
    /// - Parameter request: The network request to evaluate
    /// - Returns: True if the request should be blocked
    public func shouldBlock(_ request: NetworkRequest) -> Bool {
        return queue.sync {
            // Check if domain is a known telemetry endpoint
            if let domain = request.domain {
                if telemetryDatabase.isKnownTelemetryEndpoint(domain) {
                    return true
                }
                
                // Check against pattern matcher
                if patternMatcher.matchesTelemetryDomain(domain) {
                    return true
                }
                
                // Check against user-defined patterns
                if matchesUserDefinedPattern(domain: domain) {
                    return true
                }
            }
            
            return false
        }
    }
    
    /// Evaluate a network request with additional context
    /// Requirements: 10.2-10.3
    /// - Parameters:
    ///   - request: The network request to evaluate
    ///   - path: Optional URL path
    ///   - headers: Optional HTTP headers
    ///   - payload: Optional request payload
    /// - Returns: True if the request should be blocked
    public func shouldBlock(
        _ request: NetworkRequest,
        path: String? = nil,
        headers: [String: String]? = nil,
        payload: Data? = nil
    ) -> Bool {
        return queue.sync {
            guard let domain = request.domain else {
                return false
            }
            
            // Check if domain is a known telemetry endpoint
            if telemetryDatabase.isKnownTelemetryEndpoint(domain) {
                return true
            }
            
            // Check against pattern matcher with full context
            if patternMatcher.shouldBlockRequest(
                domain: domain,
                path: path,
                headers: headers,
                payload: payload
            ) {
                return true
            }
            
            // Check against user-defined patterns
            if matchesUserDefinedPattern(
                domain: domain,
                path: path,
                headers: headers,
                payload: payload
            ) {
                return true
            }
            
            return false
        }
    }
    
    // MARK: - Pattern Detection
    
    /// Detect telemetry pattern in network data
    /// Requirement: 10.2
    /// - Parameter data: The data to inspect
    /// - Returns: The detected telemetry pattern, or nil if none found
    public func detectTelemetryPattern(in data: Data) -> TelemetryPattern? {
        return queue.sync {
            // Check if payload contains telemetry indicators
            if patternMatcher.inspectPayloadForTelemetry(data) {
                // Try to find the specific matching pattern
                // Since we don't have domain/path context, we check all patterns with payload patterns
                let allPatterns = telemetryDatabase.getAllPatterns() + userDefinedPatterns
                
                for pattern in allPatterns {
                    if let payloadPattern = pattern.payloadPattern {
                        if matchesPayloadPattern(data, pattern: payloadPattern) {
                            return pattern
                        }
                    }
                }
                
                // Return a generic telemetry pattern if we detected telemetry but no specific pattern matched
                return TelemetryPattern(
                    type: .analytics,
                    domainPattern: "*",
                    pathPattern: nil,
                    headerPatterns: [:],
                    payloadPattern: nil
                )
            }
            
            return nil
        }
    }
    
    /// Detect telemetry pattern in a complete request
    /// Requirement: 10.2
    /// - Parameters:
    ///   - domain: The request domain
    ///   - path: Optional URL path
    ///   - headers: Optional HTTP headers
    ///   - payload: Optional request payload
    /// - Returns: The detected telemetry pattern, or nil if none found
    public func detectTelemetryPattern(
        domain: String,
        path: String? = nil,
        headers: [String: String]? = nil,
        payload: Data? = nil
    ) -> TelemetryPattern? {
        return queue.sync {
            // Check pattern matcher first
            if let pattern = patternMatcher.matchRequest(
                domain: domain,
                path: path,
                headers: headers,
                payload: payload
            ) {
                return pattern
            }
            
            // Check user-defined patterns
            for pattern in userDefinedPatterns {
                if matchesPattern(
                    pattern,
                    domain: domain,
                    path: path,
                    headers: headers,
                    payload: payload
                ) {
                    return pattern
                }
            }
            
            return nil
        }
    }
    
    // MARK: - User-Defined Patterns
    
    /// Add a user-defined telemetry pattern
    /// Requirement: 10.9
    /// - Parameter pattern: The pattern to add
    public func addUserDefinedPattern(_ pattern: TelemetryPattern) {
        queue.async(flags: .barrier) {
            self.userDefinedPatterns.append(pattern)
        }
    }
    
    /// Remove a user-defined telemetry pattern
    /// Requirement: 10.9
    /// - Parameter pattern: The pattern to remove
    public func removeUserDefinedPattern(_ pattern: TelemetryPattern) {
        queue.async(flags: .barrier) {
            self.userDefinedPatterns.removeAll { $0 == pattern }
        }
    }
    
    /// Get all user-defined patterns
    /// Requirement: 10.9
    /// - Returns: Array of user-defined patterns
    public func getUserDefinedPatterns() -> [TelemetryPattern] {
        return queue.sync {
            return userDefinedPatterns
        }
    }
    
    /// Clear all user-defined patterns
    /// Requirement: 10.9
    public func clearUserDefinedPatterns() {
        queue.async(flags: .barrier) {
            self.userDefinedPatterns.removeAll()
        }
    }
    
    // MARK: - Database Updates
    
    /// Update telemetry database from remote source
    /// Requirement: 10.10
    /// - Throws: Error if update fails
    public func updateDatabase() async throws {
        try await telemetryDatabase.loadFromRemote()
    }
    
    // MARK: - Private Helpers
    
    /// Check if domain matches any user-defined pattern
    /// - Parameter domain: The domain to check
    /// - Returns: True if domain matches a user-defined pattern
    private func matchesUserDefinedPattern(domain: String) -> Bool {
        for pattern in userDefinedPatterns {
            if pattern.matchesDomain(domain) {
                return true
            }
        }
        return false
    }
    
    /// Check if request matches any user-defined pattern
    /// - Parameters:
    ///   - domain: The request domain
    ///   - path: Optional URL path
    ///   - headers: Optional HTTP headers
    ///   - payload: Optional request payload
    /// - Returns: True if request matches a user-defined pattern
    private func matchesUserDefinedPattern(
        domain: String,
        path: String? = nil,
        headers: [String: String]? = nil,
        payload: Data? = nil
    ) -> Bool {
        for pattern in userDefinedPatterns {
            if matchesPattern(pattern, domain: domain, path: path, headers: headers, payload: payload) {
                return true
            }
        }
        return false
    }
    
    /// Check if a pattern matches all provided request components
    /// - Parameters:
    ///   - pattern: The telemetry pattern to check
    ///   - domain: The domain of the request
    ///   - path: The path of the request (optional)
    ///   - headers: The HTTP headers of the request (optional)
    ///   - payload: The request payload data (optional)
    /// - Returns: True if all components match the pattern
    private func matchesPattern(
        _ pattern: TelemetryPattern,
        domain: String,
        path: String?,
        headers: [String: String]?,
        payload: Data?
    ) -> Bool {
        // Domain must always match
        guard pattern.matchesDomain(domain) else {
            return false
        }
        
        // If pattern has path requirement, check it
        if pattern.pathPattern != nil {
            guard let path = path, pattern.matchesPath(path) else {
                return false
            }
        }
        
        // If pattern has header requirements, check them
        if !pattern.headerPatterns.isEmpty {
            guard let headers = headers, pattern.matchesHeaders(headers) else {
                return false
            }
        }
        
        // If pattern has payload requirement, check it
        if let payloadPattern = pattern.payloadPattern {
            guard let payload = payload, matchesPayloadPattern(payload, pattern: payloadPattern) else {
                return false
            }
        }
        
        return true
    }
    
    /// Check if payload matches a pattern
    /// - Parameters:
    ///   - payload: The payload data
    ///   - pattern: The pattern to match (regex or substring)
    /// - Returns: True if payload matches pattern
    private func matchesPayloadPattern(_ payload: Data, pattern: String) -> Bool {
        guard let payloadString = String(data: payload, encoding: .utf8) else {
            return false
        }
        
        // Try regex match first
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(payloadString.startIndex..., in: payloadString)
            return regex.firstMatch(in: payloadString, options: [], range: range) != nil
        }
        
        // Fall back to substring match
        return payloadString.localizedCaseInsensitiveContains(pattern)
    }
}

// MARK: - Convenience Extensions

extension TelemetryBlocker {
    /// Get blocking reason for a request
    /// - Parameters:
    ///   - request: The network request
    ///   - path: Optional URL path
    ///   - headers: Optional HTTP headers
    ///   - payload: Optional request payload
    /// - Returns: Description of why the request should be blocked, or nil if not blocked
    public func getBlockingReason(
        _ request: NetworkRequest,
        path: String? = nil,
        headers: [String: String]? = nil,
        payload: Data? = nil
    ) -> String? {
        guard shouldBlock(request, path: path, headers: headers, payload: payload) else {
            return nil
        }
        
        guard let domain = request.domain else {
            return "Unknown domain"
        }
        
        if telemetryDatabase.isKnownTelemetryEndpoint(domain) {
            return "Known telemetry endpoint: \(domain)"
        }
        
        if let pattern = detectTelemetryPattern(domain: domain, path: path, headers: headers, payload: payload) {
            return "Matched telemetry pattern: \(pattern.type.rawValue) - \(pattern.domainPattern)"
        }
        
        return "Telemetry detected"
    }
    
    /// Get telemetry type for a request
    /// - Parameters:
    ///   - request: The network request
    ///   - path: Optional URL path
    ///   - headers: Optional HTTP headers
    ///   - payload: Optional request payload
    /// - Returns: The telemetry type if detected, or nil
    public func getTelemetryType(
        _ request: NetworkRequest,
        path: String? = nil,
        headers: [String: String]? = nil,
        payload: Data? = nil
    ) -> TelemetryType? {
        guard let domain = request.domain else {
            return nil
        }
        
        return detectTelemetryPattern(domain: domain, path: path, headers: headers, payload: payload)?.type
    }
}
