import Foundation
import Network
import Logging

// MARK: - Supporting Types

/// Filtering statistics for CLI and GUI display
public struct FilteringStatistics {
    public let isActive: Bool
    public let uptime: TimeInterval
    public let totalQueries: Int
    public let blockedQueries: Int
    public let allowedQueries: Int
    public let averageLatency: TimeInterval
    public let cacheHitRate: Double
    
    public init(isActive: Bool, uptime: TimeInterval, totalQueries: Int, blockedQueries: Int, allowedQueries: Int, averageLatency: TimeInterval, cacheHitRate: Double) {
        self.isActive = isActive
        self.uptime = uptime
        self.totalQueries = totalQueries
        self.blockedQueries = blockedQueries
        self.allowedQueries = allowedQueries
        self.averageLatency = averageLatency
        self.cacheHitRate = cacheHitRate
    }
}

/// Network filtering manager for DNS-level domain blocking and traffic monitoring
public class NetworkFilteringManager {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    public static let shared = NetworkFilteringManager()
    
    /// Logger instance
    private let logger = Logger(label: "privarion.network.filtering")
    
    /// Configuration manager
    private let configManager: ConfigurationManager
    
    /// DNS proxy server
    private var dnsProxy: DNSProxyServer?
    
    /// Network monitoring engine
    private var networkMonitor: NetworkMonitoringEngine?
    
    /// Blocklist manager
    private var blocklistManager: BlocklistManager?
    
    /// Traffic monitoring service
    private var trafficMonitor: TrafficMonitoringService?
    
    /// Application network rule engine
    private var ruleEngine: ApplicationNetworkRuleEngine?
    
    /// Current filtering status
    private var isActive: Bool = false
    
    /// Start time for uptime calculation
    private var startTime: Date?
    
    /// DNS query cache
    private var dnsCache: [String: DNSCacheEntry] = [:]
    
    /// Cache access queue
    private let cacheQueue = DispatchQueue(label: "privarion.network.cache", attributes: .concurrent)
    
    /// Network processing queue
    private let networkQueue = DispatchQueue(label: "privarion.network.processing", qos: .userInitiated)
    
    // MARK: - Initialization
    
    private init() {
        self.configManager = ConfigurationManager.shared
        setupLogging()
        initializeServices()
    }
    
    /// Initialize all filtering services
    private func initializeServices() {
        self.blocklistManager = BlocklistManager()
        self.trafficMonitor = TrafficMonitoringService()
        self.ruleEngine = ApplicationNetworkRuleEngine()
    }
    
    // MARK: - Public Interface
    
    /// Start network filtering with current configuration
    public func startFiltering() throws {
        logger.info("Starting network filtering...")
        
        guard !isActive else {
            logger.warning("Network filtering is already active")
            return
        }
        
        let config = configManager.getCurrentConfiguration().modules.networkFilter
        
        guard config.enabled else {
            throw NetworkFilteringError.filteringDisabled
        }
        
        try startDNSProxy(config: config.dnsProxy)
        
        if config.monitoring.enabled {
            try startNetworkMonitoring(config: config.monitoring)
        }
        
        isActive = true
        logger.info("Network filtering started successfully")
    }
    
    /// Stop network filtering
    public func stopFiltering() {
        logger.info("Stopping network filtering...")
        
        guard isActive else {
            logger.warning("Network filtering is not active")
            return
        }
        
        stopDNSProxy()
        stopNetworkMonitoring()
        
        isActive = false
        logger.info("Network filtering stopped")
    }
    
    /// Check if network filtering is currently active
    public var isFilteringActive: Bool {
        return isActive
    }
    
    // MARK: - Domain Management
    
    /// Get blocked domains (use configuration for now)
    public func getBlockedDomains() -> [String] {
        return configManager.getCurrentConfiguration().modules.networkFilter.blockedDomains
    }
    
    /// Add domain to blocklist
    public func addBlockedDomain(_ domain: String) throws {
        logger.info("Adding domain to blocklist: \\(domain)")
        
        blocklistManager?.addBlockedDomain(domain)
        
        // Also update configuration for backward compatibility
        let normalizedDomain = normalizeDomain(domain)
        var config = configManager.getCurrentConfiguration()
        
        if !config.modules.networkFilter.blockedDomains.contains(normalizedDomain) {
            config.modules.networkFilter.blockedDomains.append(normalizedDomain)
            try configManager.updateConfiguration(config)
        }
        
        logger.info("Domain added to blocklist: \\(normalizedDomain)")
    }
    
    /// Remove domain from blocklist
    public func removeBlockedDomain(_ domain: String) throws {
        logger.info("Removing domain from blocklist: \\(domain)")
        
        blocklistManager?.removeBlockedDomain(domain)
        
        // Also update configuration for backward compatibility
        let normalizedDomain = normalizeDomain(domain)
        var config = configManager.getCurrentConfiguration()
        
        if let index = config.modules.networkFilter.blockedDomains.firstIndex(of: normalizedDomain) {
            config.modules.networkFilter.blockedDomains.remove(at: index)
            try configManager.updateConfiguration(config)
        }
        
        logger.info("Domain removed from blocklist: \\(normalizedDomain)")
    }
    
    /// Check if a domain is blocked
    public func isDomainBlocked(_ domain: String) -> Bool {
        let normalizedDomain = normalizeDomain(domain)
        let blockedDomains = configManager.getCurrentConfiguration().modules.networkFilter.blockedDomains
        
        // Check exact match
        if blockedDomains.contains(normalizedDomain) {
            return true
        }
        
        // Check subdomain blocking (e.g., "ads.example.com" blocked by "example.com")
        for blockedDomain in blockedDomains {
            if normalizedDomain.hasSuffix(".\(blockedDomain)") {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Application Rules Management
    
    /// Add or update application network rule
    public func setApplicationRule(_ rule: ApplicationNetworkRule) throws {
        logger.info("Setting application rule for: \\(rule.applicationId)")
        
        var config = configManager.getCurrentConfiguration()
        config.modules.networkFilter.applicationRules[rule.applicationId] = rule
        
        try configManager.updateConfiguration(config)
        
        logger.info("Application rule set for: \\(rule.applicationId)")
    }
    
    /// Remove application network rule
    public func removeApplicationRule(for applicationId: String) throws {
        logger.info("Removing application rule for: \\(applicationId)")
        
        var config = configManager.getCurrentConfiguration()
        config.modules.networkFilter.applicationRules.removeValue(forKey: applicationId)
        
        try configManager.updateConfiguration(config)
        
        logger.info("Application rule removed for: \\(applicationId)")
    }
    
    /// Get application network rule
    public func getApplicationRule(for applicationId: String) -> ApplicationNetworkRule? {
        return configManager.getCurrentConfiguration().modules.networkFilter.applicationRules[applicationId]
    }
    
    /// Get all application rules
    public func getAllApplicationRules() -> [String: ApplicationNetworkRule] {
        return configManager.getCurrentConfiguration().modules.networkFilter.applicationRules
    }
    
    // MARK: - Statistics and Monitoring
    
    /// Get network filtering statistics
    public func getFilteringStatistics() -> FilteringStatistics {
        let stats = trafficMonitor?.getCurrentStatistics()
        let uptime = startTime.map { Date().timeIntervalSince($0) } ?? 0
        return FilteringStatistics(
            isActive: isActive,
            uptime: uptime,
            totalQueries: stats?.totalQueries ?? 0,
            blockedQueries: stats?.blockedQueries ?? 0,
            allowedQueries: stats?.allowedQueries ?? 0,
            averageLatency: stats?.averageLatency ?? 0,
            cacheHitRate: 0.0 // Calculate from cache statistics if available
        )
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        // Logger level is configured globally, not per instance
        // Log level is managed by the logging system configuration
    }
    
    private func startDNSProxy(config: DNSProxyConfig) throws {
        logger.info("Starting DNS proxy on port \\(config.proxyPort)")
        
        dnsProxy = DNSProxyServer(
            port: config.proxyPort,
            upstreamServers: config.upstreamServers,
            queryTimeout: config.queryTimeout
        )
        
        dnsProxy?.delegate = self
        
        try dnsProxy?.start()
        
        logger.info("DNS proxy started successfully")
    }
    
    private func stopDNSProxy() {
        logger.info("Stopping DNS proxy")
        dnsProxy?.stop()
        dnsProxy = nil
    }
    
    private func startNetworkMonitoring(config: NetworkMonitoringConfig) throws {
        logger.info("Starting network monitoring")
        
        networkMonitor = NetworkMonitoringEngine(config: config)
        networkMonitor?.start()
        
        logger.info("Network monitoring started successfully")
    }
    
    private func stopNetworkMonitoring() {
        logger.info("Stopping network monitoring")
        networkMonitor?.stop()
        networkMonitor = nil
    }
    
    private func normalizeDomain(_ domain: String) -> String {
        return domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func isValidDomain(_ domain: String) -> Bool {
        // Basic domain validation
        let domainRegex = #"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", domainRegex)
        return predicate.evaluate(with: domain)
    }
    
    private func clearDNSCache(for domain: String) {
        cacheQueue.async(flags: .barrier) {
            self.dnsCache.removeValue(forKey: domain)
        }
    }
    
    private func calculateCacheHitRate() -> Double {
        // Implementation would track cache hits vs misses
        return 0.0 // Placeholder
    }
}

// MARK: - DNS Proxy Delegate

extension NetworkFilteringManager: DNSProxyServerDelegate {
    
    internal func dnsProxy(_ proxy: DNSProxyServer, shouldBlockDomain domain: String, for applicationId: String?) -> Bool {
        // Check global domain blocking
        if isDomainBlocked(domain) {
            logger.info("Blocking domain (global rule): \\(domain)")
            return true
        }
        
        // Check application-specific rules
        if let appId = applicationId,
           let rule = getApplicationRule(for: appId) {
            
            switch rule.ruleType {
            case .blocklist:
                if rule.blockedDomains.contains(where: { domain.hasSuffix($0) }) {
                    logger.info("Blocking domain (app rule): \\(domain) for \\(appId)")
                    return true
                }
                
            case .allowlist:
                if !rule.allowedDomains.contains(where: { domain.hasSuffix($0) }) {
                    logger.info("Blocking domain (allowlist): \\(domain) for \\(appId)")
                    return true
                }
                
            case .monitor:
                // Monitor only, don't block
                logger.info("Monitoring domain: \\(domain) for \\(appId)")
                break
            }
        }
        
        return false
    }
    
    internal func dnsProxy(_ proxy: DNSProxyServer, didProcessQuery domain: String, blocked: Bool, latency: TimeInterval) {
        networkMonitor?.recordDNSQuery(domain: domain, blocked: blocked, latency: latency)
        
        if blocked {
            logger.info("DNS query blocked: \\(domain) (latency: \\(Int(latency * 1000))ms)")
        } else {
            logger.debug("DNS query allowed: \\(domain) (latency: \\(Int(latency * 1000))ms)")
        }
    }
}

// MARK: - Extensions

extension LogLevel {
    func toFoundationLogLevel() -> Logger.Level {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}

/// Network Monitoring Engine placeholder
internal class NetworkMonitoringEngine {
    var totalQueries: Int = 0
    var blockedQueries: Int = 0
    var allowedQueries: Int = 0
    var averageLatency: TimeInterval = 0.0
    var uptime: TimeInterval = 0.0
    
    init(config: NetworkMonitoringConfig) {
        // Placeholder implementation
    }
    
    func start() {
        // Placeholder implementation
    }
    
    func stop() {
        // Placeholder implementation
    }
    
    func recordDNSQuery(domain: String, blocked: Bool, latency: TimeInterval) {
        // Placeholder implementation
        totalQueries += 1
        if blocked {
            blockedQueries += 1
        } else {
            allowedQueries += 1
        }
    }
}

/// Network filtering statistics
public class NetworkFilteringStatistics {
    public var totalQueries: Int = 0
    public var blockedQueries: Int = 0
    public var allowedQueries: Int = 0
    public var averageLatency: TimeInterval = 0.0
    public var cacheHitRate: Double = 0.0
    public var isActive: Bool = false
    public var uptime: TimeInterval = 0.0
}

/// DNS cache entry
private struct DNSCacheEntry {
    let response: Data
    let timestamp: Date
    let ttl: TimeInterval
    
    var isExpired: Bool {
        return Date().timeIntervalSince(timestamp) > ttl
    }
}

/// Network filtering errors
public enum NetworkFilteringError: Error, LocalizedError {
    case filteringDisabled
    case invalidDomain(String)
    case proxyStartFailed(String)
    case configurationError(String)
    
    public var errorDescription: String? {
        switch self {
        case .filteringDisabled:
            return "Network filtering is disabled in configuration"
        case .invalidDomain(let domain):
            return "Invalid domain format: \(domain)"
        case .proxyStartFailed(let reason):
            return "Failed to start DNS proxy: \(reason)"
        case .configurationError(let reason):
            return "Configuration error: \(reason)"
        }
    }
}
