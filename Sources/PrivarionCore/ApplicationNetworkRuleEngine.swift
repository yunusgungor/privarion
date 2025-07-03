import Foundation
import Network
import Logging

/// Engine for managing and evaluating per-application network rules
/// Implements PATTERN-2025-048: Application Network Rule Pattern
@available(macOS 10.14, *)
internal class ApplicationNetworkRuleEngine {
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger: Logger
    
    /// Configuration manager
    private let configManager: ConfigurationManager
    
    /// Application rules cache
    private var rulesCache: [String: ApplicationNetworkRule] = [:]
    
    /// Process information cache
    private var processCache: [Int32: ProcessInfo] = [:]
    
    /// Cache access queue
    private let cacheQueue = DispatchQueue(label: "privarion.network.rules.cache", attributes: .concurrent)
    
    /// Rule evaluation queue
    private let evaluationQueue = DispatchQueue(label: "privarion.network.rules.evaluation", qos: .userInitiated)
    
    // MARK: - Initialization
    
    internal init() {
        self.logger = Logger(label: "privarion.network.rules")
        self.configManager = ConfigurationManager.shared
        
        loadRulesFromConfiguration()
        setupConfigurationObserver()
    }
    
    // MARK: - Public Interface
    
    /// Evaluate if a DNS query should be blocked for a specific client
    /// - Parameters:
    ///   - domain: The domain being queried
    ///   - clientConnection: The client connection making the request
    /// - Returns: True if the query should be blocked, false otherwise
    internal func shouldBlockQuery(domain: String, from clientConnection: NWConnection) -> Bool {
        return evaluationQueue.sync {
            do {
                // Get process information for the connection
                guard let processInfo = try getProcessInfo(for: clientConnection) else {
                    logger.debug("Could not identify process for connection, allowing query for: \(domain)")
                    return false
                }
                
                // Find applicable rules for the process
                let applicableRules = findApplicableRules(for: processInfo)
                
                // Evaluate rules in priority order
                for rule in applicableRules.sorted(by: { $0.priority > $1.priority }) {
                    if let blockDecision = evaluateRule(rule, for: domain, process: processInfo) {
                        logger.debug("Rule \(rule.applicationId) decided: \(blockDecision ? "BLOCK" : "ALLOW") for \(domain)")
                        return blockDecision
                    }
                }
                
                // No rules matched, use default behavior
                logger.debug("No applicable rules found for \(processInfo.bundleId ?? processInfo.processName), allowing query for: \(domain)")
                return false
                
            } catch {
                logger.error("Error evaluating network rule: \(error)")
                return false
            }
        }
    }
    
    /// Add or update an application network rule
    /// - Parameter rule: The rule to add or update
    internal func addRule(_ rule: ApplicationNetworkRule) throws {
        cacheQueue.async(flags: .barrier) {
            self.rulesCache[rule.applicationId] = rule
        }
        
        // Persist to configuration
        try persistRulesToConfiguration()
        
        logger.info("Added network rule for application: \(rule.applicationId)")
    }
    
    /// Remove an application network rule
    /// - Parameter applicationId: The application ID to remove rules for
    internal func removeRule(for applicationId: String) throws {
        cacheQueue.async(flags: .barrier) {
            self.rulesCache.removeValue(forKey: applicationId)
        }
        
        // Persist to configuration
        try persistRulesToConfiguration()
        
        logger.info("Removed network rule for application: \(applicationId)")
    }
    
    /// Get all current rules
    /// - Returns: Dictionary of all current rules
    internal func getAllRules() -> [String: ApplicationNetworkRule] {
        return cacheQueue.sync {
            return rulesCache
        }
    }
    
    // MARK: - Private Methods
    
    private func loadRulesFromConfiguration() {
        let config = configManager.getCurrentConfiguration().modules.networkFilter
        
        cacheQueue.async(flags: .barrier) {
            self.rulesCache = config.applicationRules
        }
        
        logger.debug("Loaded \(config.applicationRules.count) application network rules from configuration")
    }
    
    private func persistRulesToConfiguration() throws {
        var config = configManager.getCurrentConfiguration()
        
        let rules = cacheQueue.sync { rulesCache }
        config.modules.networkFilter.applicationRules = rules
        
        try configManager.updateConfiguration(config)
    }
    
    private func setupConfigurationObserver() {
        // TODO: Implement configuration change observer
        // This would listen for configuration updates and reload rules accordingly
    }
    
    private func getProcessInfo(for connection: NWConnection) throws -> ProcessInfo? {
        // Extract endpoint from connection to identify process
        _ = connection.endpoint
        
        // In a real implementation, we would need to:
        // 1. Get the source port from the NWConnection
        // 2. Use system calls to find which process owns that port
        // 3. Get process information (PID, bundle ID, etc.)
        
        // For now, return a placeholder implementation
        // This would need platform-specific implementation using libproc
        return try getProcessInfoFromConnection(connection)
    }
    
    private func getProcessInfoFromConnection(_ connection: NWConnection) throws -> ProcessInfo? {
        // Platform-specific implementation needed here
        // This is a simplified version for demonstration
        
        // In real implementation:
        // 1. Use lsof or netstat equivalent system calls
        // 2. Match connection details to process ID
        // 3. Use proc_pidinfo to get process details
        
        // For testing, we'll create a mock process info
        let mockProcessInfo = ProcessInfo(
            pid: 12345,
            processName: "TestApp",
            bundleId: "com.example.testapp",
            executablePath: "/Applications/TestApp.app/Contents/MacOS/TestApp"
        )
        
        return mockProcessInfo
    }
    
    private func findApplicableRules(for processInfo: ProcessInfo) -> [ApplicationNetworkRule] {
        return cacheQueue.sync {
            var applicableRules: [ApplicationNetworkRule] = []
            
            for (_, rule) in rulesCache {
                guard rule.enabled else { continue }
                
                // Check if rule applies to this process
                if ruleApplies(rule, to: processInfo) {
                    applicableRules.append(rule)
                }
            }
            
            return applicableRules
        }
    }
    
    private func ruleApplies(_ rule: ApplicationNetworkRule, to processInfo: ProcessInfo) -> Bool {
        // Check bundle ID match
        if let bundleId = processInfo.bundleId,
           rule.applicationId == bundleId {
            return true
        }
        
        // Check process name match
        if rule.applicationId == processInfo.processName {
            return true
        }
        
        // Check executable path match
        if rule.applicationId == processInfo.executablePath {
            return true
        }
        
        // Check for wildcard patterns
        if rule.applicationId.contains("*") {
            return matchesWildcardPattern(rule.applicationId, processInfo)
        }
        
        return false
    }
    
    private func matchesWildcardPattern(_ pattern: String, _ processInfo: ProcessInfo) -> Bool {
        // Simple wildcard matching implementation
        let regex = pattern
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")
        
        guard let bundleId = processInfo.bundleId else { return false }
        
        do {                let regexObject = try NSRegularExpression(pattern: "^\(regex)$")
            let range = NSRange(location: 0, length: bundleId.count)
            return regexObject.firstMatch(in: bundleId, range: range) != nil
        } catch {
            logger.warning("Invalid wildcard pattern: \(pattern)")
            return false
        }
    }
    
    private func evaluateRule(_ rule: ApplicationNetworkRule, for domain: String, process: ProcessInfo) -> Bool? {
        switch rule.ruleType {
        case .blocklist:
            return evaluateBlocklistRule(rule, for: domain)
        case .allowlist:
            return evaluateAllowlistRule(rule, for: domain)
        case .monitor:
            // Monitor rules don't block, they just log
            logMonitoringEvent(rule: rule, domain: domain, process: process)
            return nil
        }
    }
    
    private func evaluateBlocklistRule(_ rule: ApplicationNetworkRule, for domain: String) -> Bool {
        for blockedDomain in rule.blockedDomains {
            if domainMatches(domain, pattern: blockedDomain) {
                return true // Block the request
            }
        }
        return false // Allow the request
    }
    
    private func evaluateAllowlistRule(_ rule: ApplicationNetworkRule, for domain: String) -> Bool {
        // For allowlist rules, block if domain is NOT in the allowed list
        for allowedDomain in rule.allowedDomains {
            if domainMatches(domain, pattern: allowedDomain) {
                return false // Allow the request
            }
        }
        return true // Block the request (not in allowlist)
    }
    
    private func domainMatches(_ domain: String, pattern: String) -> Bool {
        let normalizedDomain = domain.lowercased()
        let normalizedPattern = pattern.lowercased()
        
        // Exact match
        if normalizedDomain == normalizedPattern {
            return true
        }
        
        // Subdomain match (pattern starts with .)
        if normalizedPattern.hasPrefix(".") {
            return normalizedDomain.hasSuffix(normalizedPattern) || 
                   normalizedDomain == String(normalizedPattern.dropFirst())
        }
        
        // Wildcard match
        if normalizedPattern.contains("*") {
            let regex = normalizedPattern
                .replacingOccurrences(of: ".", with: "\\\\.")
                .replacingOccurrences(of: "*", with: ".*")
            
            do {
                let regexObject = try NSRegularExpression(pattern: "^\(regex)$")
                let range = NSRange(location: 0, length: normalizedDomain.count)
                return regexObject.firstMatch(in: normalizedDomain, range: range) != nil
            } catch {
                logger.warning("Invalid domain pattern: \(normalizedPattern)")
                return false
            }
        }
        
        return false
    }
    
    private func logMonitoringEvent(rule: ApplicationNetworkRule, domain: String, process: ProcessInfo) {
        logger.info("Monitoring DNS query", metadata: [
            "application_id": "\(rule.applicationId)",
            "process_name": "\(process.processName)",
            "bundle_id": "\(process.bundleId ?? "unknown")",
            "domain": "\(domain)",
            "rule_type": "monitor"
        ])
    }
}

// MARK: - Supporting Types

/// Process information structure
internal struct ProcessInfo {
    let pid: Int32
    let processName: String
    let bundleId: String?
    let executablePath: String
}

/// Application network rule engine errors
internal enum ApplicationNetworkRuleEngineError: Error, LocalizedError {
    case failedToGetProcessInfo(String)
    case invalidRule(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .failedToGetProcessInfo(let details):
            return "Failed to get process information: \(details)"
        case .invalidRule(let details):
            return "Invalid network rule: \(details)"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        }
    }
}
