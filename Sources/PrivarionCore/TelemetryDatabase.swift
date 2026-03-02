import Foundation

// MARK: - Telemetry Database

/// Database for managing known telemetry endpoints and patterns
/// Requirement: 10.1, 10.10
public class TelemetryDatabase {
    // MARK: - Properties
    
    /// Known telemetry endpoints (domains)
    private var endpoints: Set<String>
    
    /// Telemetry patterns for detection
    private var patterns: [TelemetryPattern]
    
    /// Thread-safe access queue
    private let queue = DispatchQueue(label: "com.privarion.telemetry-database", attributes: .concurrent)
    
    /// Remote source URL for database updates
    private let remoteSourceURL: URL?
    
    // MARK: - Initialization
    
    /// Initialize telemetry database with optional endpoints and patterns
    /// - Parameters:
    ///   - endpoints: Initial set of known telemetry endpoints
    ///   - patterns: Initial telemetry patterns
    ///   - remoteSourceURL: Optional URL for remote database updates
    public init(
        endpoints: Set<String> = [],
        patterns: [TelemetryPattern] = [],
        remoteSourceURL: URL? = nil
    ) {
        self.endpoints = endpoints
        self.patterns = patterns
        self.remoteSourceURL = remoteSourceURL
    }
    
    /// Initialize with default telemetry endpoints and patterns
    public static func defaultDatabase() -> TelemetryDatabase {
        let defaultEndpoints: Set<String> = [
            // Analytics services
            "google-analytics.com",
            "analytics.google.com",
            "googletagmanager.com",
            "doubleclick.net",
            
            // Microsoft telemetry
            "telemetry.microsoft.com",
            "vortex.data.microsoft.com",
            "watson.telemetry.microsoft.com",
            
            // Mozilla telemetry
            "telemetry.mozilla.org",
            "incoming.telemetry.mozilla.org",
            
            // Apple analytics
            "metrics.apple.com",
            "metrics.icloud.com",
            
            // Adobe analytics
            "omtrdc.net",
            "2o7.net",
            
            // Other common telemetry
            "mixpanel.com",
            "segment.io",
            "amplitude.com",
            "hotjar.com",
            "fullstory.com"
        ]
        
        let defaultPatterns: [TelemetryPattern] = [
            // Analytics patterns
            TelemetryPattern(
                type: .analytics,
                domainPattern: "*.analytics.*",
                pathPattern: nil,
                headerPatterns: [:],
                payloadPattern: nil
            ),
            TelemetryPattern(
                type: .analytics,
                domainPattern: "*.google-analytics.*",
                pathPattern: nil,
                headerPatterns: [:],
                payloadPattern: nil
            ),
            
            // Tracking patterns
            TelemetryPattern(
                type: .tracking,
                domainPattern: "*.tracking.*",
                pathPattern: nil,
                headerPatterns: [:],
                payloadPattern: nil
            ),
            TelemetryPattern(
                type: .tracking,
                domainPattern: "*",
                pathPattern: "/track",
                headerPatterns: [:],
                payloadPattern: nil
            ),
            TelemetryPattern(
                type: .tracking,
                domainPattern: "*",
                pathPattern: "/collect",
                headerPatterns: [:],
                payloadPattern: nil
            ),
            
            // Telemetry patterns
            TelemetryPattern(
                type: .analytics,
                domainPattern: "*.telemetry.*",
                pathPattern: nil,
                headerPatterns: [:],
                payloadPattern: nil
            ),
            TelemetryPattern(
                type: .analytics,
                domainPattern: "*",
                pathPattern: "/api/analytics",
                headerPatterns: [:],
                payloadPattern: nil
            ),
            
            // Header-based detection
            TelemetryPattern(
                type: .analytics,
                domainPattern: "*",
                pathPattern: nil,
                headerPatterns: ["X-Analytics-Id": "*"],
                payloadPattern: nil
            ),
            TelemetryPattern(
                type: .tracking,
                domainPattern: "*",
                pathPattern: nil,
                headerPatterns: ["X-Tracking-Id": "*"],
                payloadPattern: nil
            )
        ]
        
        return TelemetryDatabase(
            endpoints: defaultEndpoints,
            patterns: defaultPatterns,
            remoteSourceURL: nil
        )
    }
    
    // MARK: - Endpoint Management
    
    /// Check if a domain is a known telemetry endpoint
    /// Requirement: 10.1
    /// - Parameter domain: The domain to check
    /// - Returns: True if the domain is a known telemetry endpoint
    public func isKnownTelemetryEndpoint(_ domain: String) -> Bool {
        return queue.sync {
            // Direct match
            if endpoints.contains(domain) {
                return true
            }
            
            // Check for subdomain matches
            for endpoint in endpoints {
                if domain.hasSuffix(".\(endpoint)") || domain == endpoint {
                    return true
                }
            }
            
            return false
        }
    }
    
    /// Add a telemetry endpoint to the database
    /// Requirement: 10.1
    /// - Parameter domain: The domain to add
    public func addEndpoint(_ domain: String) {
        queue.async(flags: .barrier) {
            self.endpoints.insert(domain)
        }
    }
    
    /// Remove a telemetry endpoint from the database
    /// Requirement: 10.1
    /// - Parameter domain: The domain to remove
    public func removeEndpoint(_ domain: String) {
        queue.async(flags: .barrier) {
            self.endpoints.remove(domain)
        }
    }
    
    /// Get all known telemetry endpoints
    /// - Returns: Set of all telemetry endpoints
    public func getAllEndpoints() -> Set<String> {
        return queue.sync {
            return endpoints
        }
    }
    
    // MARK: - Pattern Management
    
    /// Get all telemetry patterns
    /// - Returns: Array of telemetry patterns
    public func getAllPatterns() -> [TelemetryPattern] {
        return queue.sync {
            return patterns
        }
    }
    
    /// Add a telemetry pattern to the database
    /// - Parameter pattern: The pattern to add
    public func addPattern(_ pattern: TelemetryPattern) {
        queue.async(flags: .barrier) {
            self.patterns.append(pattern)
        }
    }
    
    /// Remove a telemetry pattern from the database
    /// - Parameter pattern: The pattern to remove
    public func removePattern(_ pattern: TelemetryPattern) {
        queue.async(flags: .barrier) {
            self.patterns.removeAll { $0 == pattern }
        }
    }
    
    // MARK: - Remote Updates
    
    /// Load telemetry database from remote source
    /// Requirement: 10.10
    /// - Throws: Error if remote loading fails
    public func loadFromRemote() async throws {
        guard let remoteURL = remoteSourceURL else {
            throw TelemetryDatabaseError.noRemoteSourceConfigured
        }
        
        // Fetch data from remote source
        let (data, response) = try await URLSession.shared.data(from: remoteURL)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TelemetryDatabaseError.remoteLoadFailed("Invalid HTTP response")
        }
        
        // Parse JSON response
        let decoder = JSONDecoder()
        let remoteDatabase = try decoder.decode(RemoteTelemetryDatabase.self, from: data)
        
        // Update local database
        queue.async(flags: .barrier) {
            self.endpoints = remoteDatabase.endpoints
            self.patterns = remoteDatabase.patterns
        }
    }
    
    // MARK: - Persistence
    
    /// Save database to file
    /// - Parameter url: File URL to save to
    /// - Throws: Error if saving fails
    public func save(to url: URL) throws {
        let database = queue.sync {
            RemoteTelemetryDatabase(endpoints: endpoints, patterns: patterns)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(database)
        try data.write(to: url)
    }
    
    /// Load database from file
    /// - Parameter url: File URL to load from
    /// - Throws: Error if loading fails
    public func load(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let database = try decoder.decode(RemoteTelemetryDatabase.self, from: data)
        
        queue.async(flags: .barrier) {
            self.endpoints = database.endpoints
            self.patterns = database.patterns
        }
    }
}

// MARK: - Telemetry Pattern

/// Pattern for detecting telemetry traffic
/// Requirement: 10.2, 10.4-10.7
public struct TelemetryPattern: Codable, Equatable, Sendable {
    /// Type of telemetry
    public let type: TelemetryType
    
    /// Domain pattern (supports wildcards)
    public let domainPattern: String
    
    /// Optional path pattern
    public let pathPattern: String?
    
    /// Optional header patterns (key-value pairs, supports wildcards in values)
    public let headerPatterns: [String: String]
    
    /// Optional payload pattern (regex or substring)
    public let payloadPattern: String?
    
    public init(
        type: TelemetryType,
        domainPattern: String,
        pathPattern: String? = nil,
        headerPatterns: [String: String] = [:],
        payloadPattern: String? = nil
    ) {
        self.type = type
        self.domainPattern = domainPattern
        self.pathPattern = pathPattern
        self.headerPatterns = headerPatterns
        self.payloadPattern = payloadPattern
    }
    
    /// Check if a domain matches this pattern
    /// - Parameter domain: The domain to check
    /// - Returns: True if the domain matches the pattern
    public func matchesDomain(_ domain: String) -> Bool {
        return wildcardMatch(pattern: domainPattern, string: domain)
    }
    
    /// Check if a path matches this pattern
    /// - Parameter path: The path to check
    /// - Returns: True if the path matches the pattern
    public func matchesPath(_ path: String) -> Bool {
        guard let pathPattern = pathPattern else {
            return true // No path pattern means any path matches
        }
        return wildcardMatch(pattern: pathPattern, string: path)
    }
    
    /// Check if headers match this pattern
    /// - Parameter headers: The headers to check
    /// - Returns: True if the headers match the pattern
    public func matchesHeaders(_ headers: [String: String]) -> Bool {
        guard !headerPatterns.isEmpty else {
            return true // No header patterns means any headers match
        }
        
        for (key, pattern) in headerPatterns {
            guard let value = headers[key] else {
                return false // Required header not present
            }
            if !wildcardMatch(pattern: pattern, string: value) {
                return false // Header value doesn't match pattern
            }
        }
        
        return true
    }
    
    /// Wildcard pattern matching
    /// - Parameters:
    ///   - pattern: Pattern with wildcards (* matches any sequence)
    ///   - string: String to match against
    /// - Returns: True if string matches pattern
    private func wildcardMatch(pattern: String, string: String) -> Bool {
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")
        
        guard let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$", options: .caseInsensitive) else {
            return false
        }
        
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, options: [], range: range) != nil
    }
}

// MARK: - Telemetry Type

/// Type of telemetry traffic
/// Requirement: 10.2
public enum TelemetryType: String, Codable, CaseIterable, Equatable {
    case analytics
    case tracking
    case crashReporting
    case usageStatistics
}

// MARK: - Remote Database Structure

/// Structure for remote telemetry database (for serialization)
private struct RemoteTelemetryDatabase: Codable, Sendable {
    let endpoints: Set<String>
    let patterns: [TelemetryPattern]
}

// MARK: - Errors

/// Errors related to telemetry database operations
public enum TelemetryDatabaseError: Error, LocalizedError, Equatable {
    case noRemoteSourceConfigured
    case remoteLoadFailed(String)
    case invalidDatabaseFormat
    
    public var errorDescription: String? {
        switch self {
        case .noRemoteSourceConfigured:
            return "No remote source URL configured for telemetry database"
        case .remoteLoadFailed(let reason):
            return "Failed to load telemetry database from remote source: \(reason)"
        case .invalidDatabaseFormat:
            return "Invalid telemetry database format"
        }
    }
}
