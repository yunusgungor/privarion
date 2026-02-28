// PrivarionNetworkExtension - DNS Filter
// DNS query filtering with blocklist and fingerprinting detection
// Requirements: 4.1-4.12

import Foundation
import Logging
import PrivarionSharedModels

/// DNS filter for processing queries and applying privacy protection rules
/// Blocks tracking domains and returns fake responses for fingerprinting domains
@available(macOS 10.14, *)
public class DNSFilter {
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger: Logger
    
    /// File logger for network extension logs
    private let fileLogger: FileLogger
    
    /// Blocklist manager for domain checking
    private let blocklistManager: BlocklistManager
    
    /// DNS cache for response caching
    private let cache: DNSCache
    
    /// Fingerprinting domain patterns
    private let fingerprintingPatterns: [String] = [
        "fingerprint",
        "tracking",
        "analytics",
        "telemetry",
        "metrics",
        "stats",
        "beacon",
        "collector"
    ]
    
    /// Fake IP addresses to return for fingerprinting domains
    private let fakeIPAddresses: [String] = [
        "127.0.0.1",
        "0.0.0.0",
        "192.0.2.1",  // TEST-NET-1 (RFC 5737)
        "198.51.100.1", // TEST-NET-2 (RFC 5737)
        "203.0.113.1"  // TEST-NET-3 (RFC 5737)
    ]
    
    // MARK: - Initialization
    
    /// Initialize DNS filter with dependencies
    /// - Parameters:
    ///   - blocklistManager: Manager for domain blocklists
    ///   - cache: DNS response cache
    internal init(blocklistManager: BlocklistManager, cache: DNSCache) {
        self.logger = Logger(label: "privarion.dnsfilter")
        self.fileLogger = FileLogger(logFilePath: "/var/log/privarion/network-extension.log")
        self.blocklistManager = blocklistManager
        self.cache = cache
    }
    
    /// Convenience initializer with default dependencies
    public convenience init() {
        self.init(
            blocklistManager: BlocklistManager(),
            cache: DNSCache()
        )
    }
    
    // MARK: - Public Interface
    
    /// Filter a DNS query and return appropriate response
    /// - Parameter query: The DNS query to filter
    /// - Returns: DNS response (NXDOMAIN for blocked, fake IP for fingerprinting, or nil to forward)
    /// - Requirement: 4.2, 4.3, 4.4, 4.5, 4.6, 4.10, 17.3, 17.5
    public func filterDNSQuery(_ query: DNSQuery) -> DNSResponse? {
        return filterDNSQuery(query, processInfo: nil)
    }
    
    /// Filter a DNS query with process information and return appropriate response
    /// - Parameters:
    ///   - query: The DNS query to filter
    ///   - processInfo: Optional process information (PID or process name)
    /// - Returns: DNS response (NXDOMAIN for blocked, fake IP for fingerprinting, or nil to forward)
    /// - Requirement: 4.2, 4.3, 4.4, 4.5, 4.6, 4.10, 17.3, 17.5
    public func filterDNSQuery(_ query: DNSQuery, processInfo: String?) -> DNSResponse? {
        let domain = query.domain.lowercased()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        logger.debug("Filtering DNS query for domain: \(domain)")
        
        // Check cache first for performance (Requirement 4.9, 4.11)
        if let cachedResponse = cache.get(domain), cachedResponse.isValid {
            logger.debug("Cache hit for domain: \(domain)")
            logDNSQuery(
                timestamp: timestamp,
                domain: domain,
                queryType: query.queryType,
                action: "allowed",
                reason: "cached",
                processInfo: processInfo
            )
            return cachedResponse
        }
        
        // Check if domain is blocked (Requirement 4.3, 4.4)
        if isBlocked(domain) {
            logger.info("Blocked tracking domain: \(domain)")
            let response = createNXDOMAINResponse(for: query)
            cache.set(domain, response: response, ttl: 300)
            
            // Log blocked domain (Requirement 4.10, 17.5)
            logDNSQuery(
                timestamp: timestamp,
                domain: domain,
                queryType: query.queryType,
                action: "blocked",
                reason: "tracking domain",
                processInfo: processInfo
            )
            
            return response
        }
        
        // Check if domain is fingerprinting (Requirement 4.5, 4.6)
        if isFingerprintingDomain(domain) {
            logger.info("Detected fingerprinting domain: \(domain)")
            let response = createFakeResponse(for: query)
            cache.set(domain, response: response, ttl: 300)
            
            // Log faked domain (Requirement 4.10, 17.5)
            logDNSQuery(
                timestamp: timestamp,
                domain: domain,
                queryType: query.queryType,
                action: "faked",
                reason: "fingerprinting domain",
                processInfo: processInfo
            )
            
            return response
        }
        
        // Domain is allowed, return nil to indicate forwarding needed (Requirement 4.7)
        logger.debug("Allowing domain: \(domain)")
        logDNSQuery(
            timestamp: timestamp,
            domain: domain,
            queryType: query.queryType,
            action: "allowed",
            reason: "forwarded to upstream",
            processInfo: processInfo
        )
        
        return nil
    }
    
    /// Check if a domain should be blocked
    /// - Parameter domain: The domain to check
    /// - Returns: True if the domain is in the blocklist
    /// - Requirement: 4.3
    public func isBlocked(_ domain: String) -> Bool {
        let normalizedDomain = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return blocklistManager.shouldBlockDomain(normalizedDomain)
    }
    
    /// Check if a domain is a fingerprinting domain
    /// - Parameter domain: The domain to check
    /// - Returns: True if the domain matches fingerprinting patterns
    /// - Requirement: 4.5
    public func isFingerprintingDomain(_ domain: String) -> Bool {
        let normalizedDomain = domain.lowercased()
        
        // Check against fingerprinting patterns
        for pattern in fingerprintingPatterns {
            if normalizedDomain.contains(pattern) {
                return true
            }
        }
        
        // Check for common fingerprinting subdomains
        let fingerprintingSubdomains = ["fp", "track", "pixel", "tag", "collect"]
        let components = normalizedDomain.components(separatedBy: ".")
        
        for subdomain in fingerprintingSubdomains {
            if components.contains(subdomain) {
                return true
            }
        }
        
        return false
    }
    
    /// Create a fake DNS response for fingerprinting domains
    /// - Parameter query: The original DNS query
    /// - Returns: DNS response with fake IP address
    /// - Requirement: 4.6
    public func createFakeResponse(for query: DNSQuery) -> DNSResponse {
        // Select a fake IP based on query ID for consistency
        let fakeIP = fakeIPAddresses[Int(query.id) % fakeIPAddresses.count]
        
        return DNSResponse(
            id: query.id,
            domain: query.domain,
            addresses: [fakeIP],
            ttl: 300, // 5 minutes
            cached: false,
            timestamp: Date()
        )
    }
    
    // MARK: - Private Methods
    
    /// Log DNS query with comprehensive details
    /// - Parameters:
    ///   - timestamp: ISO8601 formatted timestamp
    ///   - domain: The queried domain
    ///   - queryType: The DNS query type
    ///   - action: Action taken (blocked, allowed, faked)
    ///   - reason: Reason for the action
    ///   - processInfo: Optional process information
    /// - Requirement: 4.10, 17.3, 17.5
    private func logDNSQuery(
        timestamp: String,
        domain: String,
        queryType: DNSQueryType,
        action: String,
        reason: String,
        processInfo: String?
    ) {
        let processString = processInfo.map { " process=\($0)" } ?? ""
        let logMessage = "[\(timestamp)] DNS query: domain=\(domain) type=\(queryType.rawValue) action=\(action) reason=\(reason)\(processString)"
        
        fileLogger.log(logMessage)
    }
    
    /// Create an NXDOMAIN response for blocked domains
    /// - Parameter query: The original DNS query
    /// - Returns: DNS response indicating domain does not exist
    /// - Requirement: 4.4
    private func createNXDOMAINResponse(for query: DNSQuery) -> DNSResponse {
        return DNSResponse(
            id: query.id,
            domain: query.domain,
            addresses: [], // Empty addresses indicates NXDOMAIN
            ttl: 300, // 5 minutes
            cached: false,
            timestamp: Date()
        )
    }
}

/// DNS cache for storing and retrieving DNS responses
/// Implements caching with TTL support for performance optimization
@available(macOS 10.14, *)
public class DNSCache {
    
    // MARK: - Properties
    
    /// Cache storage
    private var cache: [String: DNSResponse] = [:]
    
    /// Cache access queue for thread safety
    private let cacheQueue = DispatchQueue(label: "privarion.dnscache", attributes: .concurrent)
    
    /// Default TTL for cached entries (300 seconds = 5 minutes)
    private let defaultTTL: TimeInterval = 300
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Interface
    
    /// Get cached DNS response for a domain
    /// - Parameter domain: The domain to look up
    /// - Returns: Cached DNS response if available and valid, nil otherwise
    /// - Requirement: 4.9, 4.11
    public func get(_ domain: String) -> DNSResponse? {
        return cacheQueue.sync {
            guard let response = cache[domain.lowercased()] else {
                return nil
            }
            
            // Check if response is still valid based on TTL
            if response.isValid {
                return response
            } else {
                // Remove expired entry
                cache.removeValue(forKey: domain.lowercased())
                return nil
            }
        }
    }
    
    /// Store DNS response in cache
    /// - Parameters:
    ///   - domain: The domain to cache
    ///   - response: The DNS response to store
    ///   - ttl: Time to live for the cached entry
    /// - Requirement: 4.9
    public func set(_ domain: String, response: DNSResponse, ttl: TimeInterval) {
        cacheQueue.async(flags: .barrier) {
            // Create a new response with cached flag set
            let cachedResponse = DNSResponse(
                id: response.id,
                domain: response.domain,
                addresses: response.addresses,
                ttl: ttl,
                cached: true,
                timestamp: Date()
            )
            
            self.cache[domain.lowercased()] = cachedResponse
        }
    }
    
    /// Clear all cached entries
    public func clear() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
    
    /// Get cache statistics
    /// - Returns: Tuple with cache size and entry count
    public func getStatistics() -> (size: Int, count: Int) {
        return cacheQueue.sync {
            return (size: cache.count, count: cache.count)
        }
    }
}

/// Blocklist manager for DNS filtering
/// This is a simplified version for the NetworkExtension module
/// The full implementation exists in PrivarionCore
@available(macOS 10.14, *)
internal class BlocklistManager {
    
    // MARK: - Properties
    
    /// Domain blocklist
    private var blockedDomains: Set<String> = []
    
    /// Access queue for thread safety
    private let queue = DispatchQueue(label: "privarion.blocklist", attributes: .concurrent)
    
    // MARK: - Initialization
    
    internal init() {
        loadDefaultBlocklist()
    }
    
    // MARK: - Public Interface
    
    /// Check if a domain should be blocked
    /// - Parameter domain: The domain to check
    /// - Returns: True if the domain should be blocked
    internal func shouldBlockDomain(_ domain: String) -> Bool {
        let normalizedDomain = domain.lowercased()
        
        return queue.sync {
            // Check exact match
            if blockedDomains.contains(normalizedDomain) {
                return true
            }
            
            // Check if any parent domain is blocked
            let components = normalizedDomain.components(separatedBy: ".")
            for i in 1..<components.count {
                let parentDomain = components[i...].joined(separator: ".")
                if blockedDomains.contains(parentDomain) {
                    return true
                }
            }
            
            return false
        }
    }
    
    /// Add domain to blocklist
    /// - Parameter domain: Domain to block
    internal func addBlockedDomain(_ domain: String) {
        queue.async(flags: .barrier) {
            self.blockedDomains.insert(domain.lowercased())
        }
    }
    
    /// Remove domain from blocklist
    /// - Parameter domain: Domain to unblock
    internal func removeBlockedDomain(_ domain: String) {
        queue.async(flags: .barrier) {
            self.blockedDomains.remove(domain.lowercased())
        }
    }
    
    // MARK: - Private Methods
    
    private func loadDefaultBlocklist() {
        // Load common tracking and analytics domains
        let defaultBlockedDomains = [
            "google-analytics.com",
            "googletagmanager.com",
            "doubleclick.net",
            "facebook.com",
            "connect.facebook.net",
            "googlesyndication.com",
            "googleadservices.com",
            "amazon-adsystem.com",
            "mixpanel.com",
            "segment.com",
            "amplitude.com",
            "hotjar.com",
            "fullstory.com"
        ]
        
        queue.async(flags: .barrier) {
            self.blockedDomains = Set(defaultBlockedDomains.map { $0.lowercased() })
        }
    }
}
