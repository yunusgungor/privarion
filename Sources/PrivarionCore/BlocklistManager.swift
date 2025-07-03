import Foundation
import Network
import Logging

/// Advanced blocklist manager for DNS filtering with support for domains, IPs, and categories
/// Implements PATTERN-2025-047: DNS Filtering Engine Pattern
@available(macOS 10.14, *)
internal class BlocklistManager: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger: Logger
    
    /// Configuration manager
    private let configManager: ConfigurationManager
    
    /// Domain blocklist cache
    private var domainBlocklist: Set<String> = []
    
    /// IP address blocklist cache
    private var ipBlocklist: Set<String> = []
    
    /// Category-based blocklist
    private var categoryBlocklists: [BlocklistCategory: Set<String>] = [:]
    
    /// Whitelist (domains that should never be blocked)
    private var whitelist: Set<String> = []
    
    /// Cache access queue
    private let cacheQueue = DispatchQueue(label: "privarion.blocklist.cache", attributes: .concurrent)
    
    /// Update queue for blocklist modifications
    private let updateQueue = DispatchQueue(label: "privarion.blocklist.update", qos: .utility)
    
    /// Blocklist statistics
    private var statistics: BlocklistStatistics = BlocklistStatistics()
    
    // MARK: - Initialization
    
    internal init() {
        self.logger = Logger(label: "privarion.blocklist")
        self.configManager = ConfigurationManager.shared
        
        loadBlocklistsFromConfiguration()
        loadBuiltInBlocklists()
    }
    
    // MARK: - Public Interface
    
    /// Check if a domain should be blocked
    /// - Parameter domain: The domain to check
    /// - Returns: True if the domain should be blocked
    internal func shouldBlockDomain(_ domain: String) -> Bool {
        let normalizedDomain = normalizeDomain(domain)
        
        return cacheQueue.sync {
            // Check whitelist first
            if isWhitelisted(normalizedDomain) {
                statistics.whitelistHits += 1
                return false
            }
            
            // Check domain blocklist
            if domainBlocklist.contains(normalizedDomain) || isSubdomainBlocked(normalizedDomain) {
                statistics.domainBlocks += 1
                return true
            }
            
            // Check category blocklists
            for (category, blocklist) in categoryBlocklists {
                if blocklist.contains(normalizedDomain) || 
                   blocklist.contains(where: { normalizedDomain.hasSuffix(".\($0)") }) {
                    statistics.categoryBlocks[category, default: 0] += 1
                    return true
                }
            }
            
            statistics.allowedQueries += 1
            return false
        }
    }
    
    /// Check if an IP address should be blocked
    /// - Parameter ipAddress: The IP address to check
    /// - Returns: True if the IP should be blocked
    internal func shouldBlockIP(_ ipAddress: String) -> Bool {
        return cacheQueue.sync {
            let blocked = ipBlocklist.contains(ipAddress) || isIPRangeBlocked(ipAddress)
            if blocked {
                statistics.ipBlocks += 1
            }
            return blocked
        }
    }
    
    /// Add domain to blocklist
    /// - Parameters:
    ///   - domain: Domain to block
    ///   - category: Optional category for the domain
    internal func addBlockedDomain(_ domain: String, category: BlocklistCategory? = nil) {
        let normalizedDomain = normalizeDomain(domain)
        
        updateQueue.async {
            self.cacheQueue.async(flags: .barrier) {
                if let category = category {
                    self.categoryBlocklists[category, default: []].insert(normalizedDomain)
                } else {
                    self.domainBlocklist.insert(normalizedDomain)
                }
            }
            
            self.persistBlocklists()
            self.logger.info("Added domain to blocklist: \(normalizedDomain)")
        }
    }
    
    /// Add IP address to blocklist
    /// - Parameter ipAddress: IP address to block
    internal func addBlockedIP(_ ipAddress: String) {
        updateQueue.async {
            self.cacheQueue.async(flags: .barrier) {
                self.ipBlocklist.insert(ipAddress)
            }
            
            self.persistBlocklists()
            self.logger.info("Added IP to blocklist: \(ipAddress)")
        }
    }
    
    /// Add domain to whitelist
    /// - Parameter domain: Domain to whitelist
    internal func addWhitelistedDomain(_ domain: String) {
        let normalizedDomain = normalizeDomain(domain)
        
        updateQueue.async {
            self.cacheQueue.async(flags: .barrier) {
                self.whitelist.insert(normalizedDomain)
            }
            
            self.persistBlocklists()
            self.logger.info("Added domain to whitelist: \(normalizedDomain)")
        }
    }
    
    /// Remove domain from blocklist
    /// - Parameters:
    ///   - domain: Domain to remove
    ///   - category: Optional category to remove from
    internal func removeBlockedDomain(_ domain: String, category: BlocklistCategory? = nil) {
        let normalizedDomain = normalizeDomain(domain)
        
        updateQueue.async {
            self.cacheQueue.async(flags: .barrier) {
                if let category = category {
                    self.categoryBlocklists[category]?.remove(normalizedDomain)
                } else {
                    self.domainBlocklist.remove(normalizedDomain)
                    // Also remove from all categories
                    for category in BlocklistCategory.allCases {
                        self.categoryBlocklists[category]?.remove(normalizedDomain)
                    }
                }
            }
            
            self.persistBlocklists()
            self.logger.info("Removed domain from blocklist: \(normalizedDomain)")
        }
    }
    
    /// Get current blocklist statistics
    /// - Returns: Current statistics
    internal func getStatistics() -> BlocklistStatistics {
        return cacheQueue.sync { statistics }
    }
    
    /// Reset statistics
    internal func resetStatistics() {
        cacheQueue.async(flags: .barrier) {
            self.statistics = BlocklistStatistics()
        }
    }
    
    /// Load blocklist from external source
    /// - Parameters:
    ///   - url: URL to load blocklist from
    ///   - category: Category for the loaded domains
    internal func loadBlocklistFromURL(_ url: URL, category: BlocklistCategory) async throws {
        logger.info("Loading blocklist from URL: \(url)")
        
        let data = try Data(contentsOf: url)
        let content = String(data: data, encoding: .utf8) ?? ""
        
        let domains = parseBlocklistContent(content)
        
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.cacheQueue.async(flags: .barrier) {
                for domain in domains {
                    self.categoryBlocklists[category, default: []].insert(self.normalizeDomain(domain))
                }
            }
            
            self.persistBlocklists()
            self.logger.info("Loaded \(domains.count) domains from URL for category: \(category)")
        }
    }
    
    // MARK: - Private Methods
    
    private func loadBlocklistsFromConfiguration() {
        let config = configManager.getCurrentConfiguration().modules.networkFilter
        
        cacheQueue.async(flags: .barrier) {
            // Load basic blocked domains
            self.domainBlocklist = Set(config.blockedDomains.map { self.normalizeDomain($0) })
            
            // Load category-based blocklists from configuration if available
            // TODO: Extend configuration to support category-based blocklists
        }
        
        logger.info("Loaded \(domainBlocklist.count) domains from configuration")
    }
    
    private func loadBuiltInBlocklists() {
        // Load built-in blocklists for common categories
        loadBuiltInTrackingBlocklist()
        loadBuiltInAdvertisingBlocklist()
        loadBuiltInMalwareBlocklist()
    }
    
    private func loadBuiltInTrackingBlocklist() {
        let trackingDomains = [
            "google-analytics.com",
            "googletagmanager.com", 
            "facebook.com",
            "connect.facebook.net",
            "doubleclick.net",
            "googlesyndication.com",
            "googleadservices.com",
            "amazon-adsystem.com",
            "adsystem.amazon.com",
            "mixpanel.com",
            "segment.com",
            "amplitude.com",
            "hotjar.com",
            "fullstory.com",
            "loggly.com",
            "bugsnag.com",
            "sentry.io"
        ]
        
        cacheQueue.async(flags: .barrier) {
            self.categoryBlocklists[.tracking] = Set(trackingDomains.map { self.normalizeDomain($0) })
        }
        
        logger.debug("Loaded \(trackingDomains.count) built-in tracking domains")
    }
    
    private func loadBuiltInAdvertisingBlocklist() {
        let adDomains = [
            "googlesyndication.com",
            "googleadservices.com", 
            "doubleclick.net",
            "amazon-adsystem.com",
            "facebook.com",
            "instagram.com",
            "twitter.com",
            "linkedin.com",
            "pinterest.com",
            "snapchat.com",
            "tiktok.com"
        ]
        
        cacheQueue.async(flags: .barrier) {
            self.categoryBlocklists[.advertising] = Set(adDomains.map { self.normalizeDomain($0) })
        }
        
        logger.debug("Loaded \(adDomains.count) built-in advertising domains")
    }
    
    private func loadBuiltInMalwareBlocklist() {
        // In a real implementation, this would be loaded from a threat intelligence feed
        let malwareDomains = [
            "malware-example.com",
            "phishing-example.com",
            "suspicious-domain.com"
        ]
        
        cacheQueue.async(flags: .barrier) {
            self.categoryBlocklists[.malware] = Set(malwareDomains.map { self.normalizeDomain($0) })
        }
        
        logger.debug("Loaded \(malwareDomains.count) built-in malware domains")
    }
    
    private func persistBlocklists() {
        // TODO: Persist blocklists to configuration
        // This would save the current state back to the configuration system
    }
    
    private func normalizeDomain(_ domain: String) -> String {
        return domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func isWhitelisted(_ domain: String) -> Bool {
        return whitelist.contains(domain) || 
               whitelist.contains(where: { domain.hasSuffix(".\($0)") })
    }
    
    private func isSubdomainBlocked(_ domain: String) -> Bool {
        // Check if any parent domain is blocked
        let components = domain.components(separatedBy: ".")
        for i in 1..<components.count {
            let parentDomain = components[i...].joined(separator: ".")
            if domainBlocklist.contains(parentDomain) {
                return true
            }
        }
        return false
    }
    
    private func isIPRangeBlocked(_ ipAddress: String) -> Bool {
        // TODO: Implement IP range blocking (CIDR notation support)
        // This would check if the IP falls within any blocked IP ranges
        return false
    }
    
    private func parseBlocklistContent(_ content: String) -> [String] {
        return content
            .components(separatedBy: .newlines)
            .map { line in
                // Remove comments and trim whitespace
                let cleanLine = line.components(separatedBy: "#").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return cleanLine
            }
            .filter { !$0.isEmpty && isValidDomain($0) }
    }
    
    private func isValidDomain(_ domain: String) -> Bool {
        // Basic domain validation
        let domainRegex = "^[a-zA-Z0-9][a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9]?\\.[a-zA-Z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", domainRegex)
        return predicate.evaluate(with: domain)
    }
}

// MARK: - Supporting Types

/// Blocklist categories for organization
internal enum BlocklistCategory: String, CaseIterable, Codable {
    case advertising = "advertising"
    case tracking = "tracking"
    case malware = "malware"
    case phishing = "phishing"
    case cryptomining = "cryptomining"
    case socialMedia = "social_media"
    case gaming = "gaming"
    case adult = "adult"
    case news = "news"
    case gambling = "gambling"
    case custom = "custom"
}

/// Statistics for blocklist performance monitoring
internal struct BlocklistStatistics: Codable {
    var domainBlocks: Int = 0
    var ipBlocks: Int = 0
    var categoryBlocks: [BlocklistCategory: Int] = [:]
    var whitelistHits: Int = 0
    var allowedQueries: Int = 0
    
    var totalBlocks: Int {
        return domainBlocks + ipBlocks + categoryBlocks.values.reduce(0, +)
    }
    
    var totalQueries: Int {
        return totalBlocks + whitelistHits + allowedQueries
    }
    
    var blockRate: Double {
        guard totalQueries > 0 else { return 0.0 }
        return Double(totalBlocks) / Double(totalQueries)
    }
}
