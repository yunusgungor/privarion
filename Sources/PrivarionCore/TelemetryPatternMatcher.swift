import Foundation

// MARK: - Telemetry Pattern Matcher

/// Matches network requests against telemetry patterns
/// Requirements: 10.4-10.7
public class TelemetryPatternMatcher {
    // MARK: - Properties
    
    /// Telemetry database containing patterns
    private let database: TelemetryDatabase
    
    /// Thread-safe access queue
    private let queue = DispatchQueue(label: "com.privarion.telemetry-pattern-matcher", attributes: .concurrent)
    
    // MARK: - Initialization
    
    /// Initialize pattern matcher with telemetry database
    /// - Parameter database: The telemetry database to use for pattern matching
    public init(database: TelemetryDatabase) {
        self.database = database
    }
    
    // MARK: - Pattern Matching
    
    /// Check if a network request matches any telemetry pattern
    /// Requirements: 10.4-10.7
    /// - Parameters:
    ///   - domain: The domain of the request
    ///   - path: The path of the request (optional)
    ///   - headers: The HTTP headers of the request (optional)
    ///   - payload: The request payload data (optional)
    /// - Returns: The matching telemetry pattern, or nil if no match
    public func matchRequest(
        domain: String,
        path: String? = nil,
        headers: [String: String]? = nil,
        payload: Data? = nil
    ) -> TelemetryPattern? {
        return queue.sync {
            let patterns = database.getAllPatterns()
            
            for pattern in patterns {
                if matches(pattern: pattern, domain: domain, path: path, headers: headers, payload: payload) {
                    return pattern
                }
            }
            
            return nil
        }
    }
    
    /// Check if a domain matches telemetry domain patterns
    /// Requirement: 10.4
    /// Supports patterns: *.analytics.*, *.telemetry.*, *.tracking.*
    /// - Parameter domain: The domain to check
    /// - Returns: True if the domain matches any telemetry domain pattern
    public func matchesTelemetryDomain(_ domain: String) -> Bool {
        return queue.sync {
            let patterns = database.getAllPatterns()
            
            for pattern in patterns {
                if pattern.matchesDomain(domain) {
                    return true
                }
            }
            
            return false
        }
    }
    
    /// Check if a path matches telemetry path patterns
    /// Requirement: 10.5
    /// Supports patterns: /api/analytics, /track, /collect
    /// - Parameter path: The path to check
    /// - Returns: True if the path matches any telemetry path pattern
    public func matchesTelemetryPath(_ path: String) -> Bool {
        return queue.sync {
            let patterns = database.getAllPatterns()
            
            for pattern in patterns {
                // Only check patterns that have path patterns defined
                if pattern.pathPattern != nil && pattern.matchesPath(path) {
                    return true
                }
            }
            
            return false
        }
    }
    
    /// Inspect HTTP headers for telemetry indicators
    /// Requirement: 10.6
    /// Detects headers: X-Analytics-*, X-Tracking-*
    /// - Parameter headers: The HTTP headers to inspect
    /// - Returns: True if headers contain telemetry indicators
    public func inspectHeadersForTelemetry(_ headers: [String: String]) -> Bool {
        return queue.sync {
            let patterns = database.getAllPatterns()
            
            for pattern in patterns {
                // Only check patterns that have header patterns defined
                if !pattern.headerPatterns.isEmpty && pattern.matchesHeaders(headers) {
                    return true
                }
            }
            
            // Also check for common telemetry header prefixes
            for (key, _) in headers {
                let lowercaseKey = key.lowercased()
                if lowercaseKey.hasPrefix("x-analytics-") ||
                   lowercaseKey.hasPrefix("x-tracking-") ||
                   lowercaseKey.hasPrefix("x-telemetry-") {
                    return true
                }
            }
            
            return false
        }
    }
    
    /// Inspect request payload for telemetry JSON structures
    /// Requirement: 10.7
    /// - Parameter payload: The request payload data
    /// - Returns: True if payload contains telemetry JSON structures
    public func inspectPayloadForTelemetry(_ payload: Data) -> Bool {
        return queue.sync {
            let patterns = database.getAllPatterns()
            
            // Check patterns with payload patterns
            for pattern in patterns {
                if let payloadPattern = pattern.payloadPattern {
                    if matchesPayloadPattern(payload, pattern: payloadPattern) {
                        return true
                    }
                }
            }
            
            // Try to parse as JSON and check for telemetry-related keys
            if let json = try? JSONSerialization.jsonObject(with: payload, options: []) {
                if containsTelemetryKeys(json) {
                    return true
                }
            }
            
            // Check for telemetry-related strings in payload
            if let payloadString = String(data: payload, encoding: .utf8) {
                return containsTelemetryStrings(payloadString)
            }
            
            return false
        }
    }
    
    /// Get all patterns that match a given request
    /// - Parameters:
    ///   - domain: The domain of the request
    ///   - path: The path of the request (optional)
    ///   - headers: The HTTP headers of the request (optional)
    ///   - payload: The request payload data (optional)
    /// - Returns: Array of all matching telemetry patterns
    public func getAllMatchingPatterns(
        domain: String,
        path: String? = nil,
        headers: [String: String]? = nil,
        payload: Data? = nil
    ) -> [TelemetryPattern] {
        return queue.sync {
            let patterns = database.getAllPatterns()
            
            return patterns.filter { pattern in
                matches(pattern: pattern, domain: domain, path: path, headers: headers, payload: payload)
            }
        }
    }
    
    // MARK: - Private Helpers
    
    /// Check if a pattern matches all provided request components
    /// - Parameters:
    ///   - pattern: The telemetry pattern to check
    ///   - domain: The domain of the request
    ///   - path: The path of the request (optional)
    ///   - headers: The HTTP headers of the request (optional)
    ///   - payload: The request payload data (optional)
    /// - Returns: True if all components match the pattern
    private func matches(
        pattern: TelemetryPattern,
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
    
    /// Check if JSON object contains telemetry-related keys
    /// - Parameter json: The JSON object to check
    /// - Returns: True if JSON contains telemetry keys
    private func containsTelemetryKeys(_ json: Any) -> Bool {
        let telemetryKeys = [
            "analytics", "tracking", "telemetry", "metrics",
            "event", "events", "track", "collect",
            "user_id", "session_id", "device_id",
            "ga", "gtm", "utm", "pixel"
        ]
        
        if let dict = json as? [String: Any] {
            for key in dict.keys {
                let lowercaseKey = key.lowercased()
                for telemetryKey in telemetryKeys {
                    if lowercaseKey.contains(telemetryKey) {
                        return true
                    }
                }
                
                // Recursively check nested objects
                if let value = dict[key] {
                    if containsTelemetryKeys(value) {
                        return true
                    }
                }
            }
        } else if let array = json as? [Any] {
            for item in array {
                if containsTelemetryKeys(item) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Check if string contains telemetry-related keywords
    /// - Parameter string: The string to check
    /// - Returns: True if string contains telemetry keywords
    private func containsTelemetryStrings(_ string: String) -> Bool {
        let lowercaseString = string.lowercased()
        let telemetryKeywords = [
            "analytics", "tracking", "telemetry", "metrics",
            "event", "track", "collect", "beacon",
            "user_id", "session_id", "device_id",
            "ga(", "gtm", "utm_", "_ga", "_gid"
        ]
        
        for keyword in telemetryKeywords {
            if lowercaseString.contains(keyword) {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Convenience Extensions

extension TelemetryPatternMatcher {
    /// Check if a network request should be blocked based on telemetry patterns
    /// - Parameters:
    ///   - domain: The domain of the request
    ///   - path: The path of the request (optional)
    ///   - headers: The HTTP headers of the request (optional)
    ///   - payload: The request payload data (optional)
    /// - Returns: True if the request matches telemetry patterns and should be blocked
    public func shouldBlockRequest(
        domain: String,
        path: String? = nil,
        headers: [String: String]? = nil,
        payload: Data? = nil
    ) -> Bool {
        return matchRequest(domain: domain, path: path, headers: headers, payload: payload) != nil
    }
    
    /// Get the telemetry type of a matching request
    /// - Parameters:
    ///   - domain: The domain of the request
    ///   - path: The path of the request (optional)
    ///   - headers: The HTTP headers of the request (optional)
    ///   - payload: The request payload data (optional)
    /// - Returns: The telemetry type if matched, or nil
    public func getTelemetryType(
        domain: String,
        path: String? = nil,
        headers: [String: String]? = nil,
        payload: Data? = nil
    ) -> TelemetryType? {
        return matchRequest(domain: domain, path: path, headers: headers, payload: payload)?.type
    }
}
