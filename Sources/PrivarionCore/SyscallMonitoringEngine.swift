import Foundation
import Logging
import Combine

/// Syscall Monitoring Engine with Falco-inspired rule-based detection
/// Implements PATTERN-2025-051: Syscall Hook Integration Pattern
/// Extends existing SyscallHookManager with advanced monitoring capabilities
public class SyscallMonitoringEngine {
    
    // MARK: - Types
    
    /// Monitoring rule definition (Falco-inspired)
    public struct MonitoringRule {
        public let id: String
        public let name: String
        public let description: String
        public let condition: RuleCondition
        public let output: String
        public let priority: Priority
        public let enabled: Bool
        public let exceptions: [RuleException]
        
        public enum Priority: String, CaseIterable {
            case emergency = "EMERGENCY"
            case alert = "ALERT"
            case critical = "CRITICAL"
            case error = "ERROR"
            case warning = "WARNING"
            case notice = "NOTICE"
            case info = "INFO"
            case debug = "DEBUG"
        }
        
        public struct RuleException {
            public let name: String
            public let fields: [String]
            public let values: [String]
            public let condition: String?
            
            public init(name: String, fields: [String], values: [String], condition: String? = nil) {
                self.name = name
                self.fields = fields
                self.values = values
                self.condition = condition
            }
        }
        
        public init(
            id: String,
            name: String,
            description: String,
            condition: RuleCondition,
            output: String,
            priority: Priority = .warning,
            enabled: Bool = true,
            exceptions: [RuleException] = []
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.condition = condition
            self.output = output
            self.priority = priority
            self.enabled = enabled
            self.exceptions = exceptions
        }
    }
    
    /// Rule condition for syscall matching
    public struct RuleCondition {
        public let syscalls: [String]
        public let processFilters: ProcessFilters?
        public let pathFilters: PathFilters?
        public let networkFilters: NetworkFilters?
        public let customCondition: String?
        
        public struct ProcessFilters {
            public let allowedProcesses: [String]
            public let blockedProcesses: [String]
            public let allowedUIDs: [UInt32]
            public let blockedUIDs: [UInt32]
            
            public init(
                allowedProcesses: [String] = [],
                blockedProcesses: [String] = [],
                allowedUIDs: [UInt32] = [],
                blockedUIDs: [UInt32] = []
            ) {
                self.allowedProcesses = allowedProcesses
                self.blockedProcesses = blockedProcesses
                self.allowedUIDs = allowedUIDs
                self.blockedUIDs = blockedUIDs
            }
        }
        
        public struct PathFilters {
            public let allowedPaths: [String]
            public let blockedPaths: [String]
            public let pathPatterns: [String]
            
            public init(allowedPaths: [String] = [], blockedPaths: [String] = [], pathPatterns: [String] = []) {
                self.allowedPaths = allowedPaths
                self.blockedPaths = blockedPaths
                self.pathPatterns = pathPatterns
            }
        }
        
        public struct NetworkFilters {
            public let allowedPorts: [Int]
            public let blockedPorts: [Int]
            public let allowedIPs: [String]
            public let blockedIPs: [String]
            
            public init(
                allowedPorts: [Int] = [],
                blockedPorts: [Int] = [],
                allowedIPs: [String] = [],
                blockedIPs: [String] = []
            ) {
                self.allowedPorts = allowedPorts
                self.blockedPorts = blockedPorts
                self.allowedIPs = allowedIPs
                self.blockedIPs = blockedIPs
            }
        }
        
        public init(
            syscalls: [String],
            processFilters: ProcessFilters? = nil,
            pathFilters: PathFilters? = nil,
            networkFilters: NetworkFilters? = nil,
            customCondition: String? = nil
        ) {
            self.syscalls = syscalls
            self.processFilters = processFilters
            self.pathFilters = pathFilters
            self.networkFilters = networkFilters
            self.customCondition = customCondition
        }
    }
    
    /// Syscall monitoring event
    public struct SyscallEvent {
        public let id: UUID
        public let timestamp: Date
        public let syscallName: String
        public let processID: Int32
        public let processName: String
        public let userID: UInt32
        public let groupID: UInt32
        public let arguments: [String]
        public let returnValue: Int32
        public let filePath: String?
        public let networkInfo: NetworkInfo?
        public let triggeredRules: [MonitoringRule]
        
        public struct NetworkInfo {
            public let localAddress: String
            public let remoteAddress: String
            public let localPort: Int
            public let remotePort: Int
            public let networkProtocol: String
            
            public init(localAddress: String, remoteAddress: String, localPort: Int, remotePort: Int, networkProtocol: String) {
                self.localAddress = localAddress
                self.remoteAddress = remoteAddress
                self.localPort = localPort
                self.remotePort = remotePort
                self.networkProtocol = networkProtocol
            }
        }
        
        public init(
            syscallName: String,
            processID: Int32,
            processName: String,
            userID: UInt32,
            groupID: UInt32,
            arguments: [String],
            returnValue: Int32,
            filePath: String? = nil,
            networkInfo: NetworkInfo? = nil,
            triggeredRules: [MonitoringRule] = []
        ) {
            self.id = UUID()
            self.timestamp = Date()
            self.syscallName = syscallName
            self.processID = processID
            self.processName = processName
            self.userID = userID
            self.groupID = groupID
            self.arguments = arguments
            self.returnValue = returnValue
            self.filePath = filePath
            self.networkInfo = networkInfo
            self.triggeredRules = triggeredRules
        }
    }
    
    /// Monitoring statistics
    public struct MonitoringStatistics {
        public var totalEvents: UInt64 = 0
        public var ruleMatches: UInt64 = 0
        public var blockedEvents: UInt64 = 0
        public var allowedEvents: UInt64 = 0
        public var averageProcessingTimeMs: Double = 0.0
        public var peakEventsPerSecond: UInt64 = 0
        public var uptime: TimeInterval = 0
        public var lastEventTime: Date? = nil
        
        public init() {}
    }
    
    /// Monitoring errors
    public enum MonitoringError: Error, LocalizedError {
        case syscallHookManagerNotAvailable
        case ruleCompilationFailed(String)
        case invalidRuleCondition(String)
        case monitoringAlreadyActive
        case monitoringNotActive
        case ruleNotFound(String)
        case configurationError(String)
        
        public var errorDescription: String? {
            switch self {
            case .syscallHookManagerNotAvailable:
                return "SyscallHookManager is not available or initialized"
            case .ruleCompilationFailed(let rule):
                return "Failed to compile monitoring rule: \(rule)"
            case .invalidRuleCondition(let condition):
                return "Invalid rule condition: \(condition)"
            case .monitoringAlreadyActive:
                return "Syscall monitoring is already active"
            case .monitoringNotActive:
                return "Syscall monitoring is not active"
            case .ruleNotFound(let ruleId):
                return "Monitoring rule not found: \(ruleId)"
            case .configurationError(let detail):
                return "Configuration error: \(detail)"
            }
        }
    }
    
    // MARK: - Properties
    
    /// Shared singleton instance
    public static let shared = SyscallMonitoringEngine()
    
    /// Logger instance
    private let logger = Logger(label: "privarion.syscall.monitoring")
    
    /// Configuration manager
    private let configManager: ConfigurationManager
    
    /// Syscall hook manager for low-level integration
    private let syscallHookManager: SyscallHookManager
    
    /// Active monitoring rules
    private var rules: [String: MonitoringRule] = [:]
    private let rulesQueue = DispatchQueue(label: "privarion.monitoring.rules", attributes: .concurrent)
    
    /// Event processing
    private let eventProcessor = PassthroughSubject<SyscallEvent, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    /// Monitoring state
    private var isMonitoring: Bool = false
    private let monitoringQueue = DispatchQueue(label: "privarion.monitoring.events", qos: .userInitiated)
    
    /// Statistics
    private var statistics = MonitoringStatistics()
    private let statisticsQueue = DispatchQueue(label: "privarion.monitoring.stats")
    
    /// Performance tracking
    private var eventTimestamps: [Date] = []
    private let maxTimestampHistory = 1000
    
    /// Configuration
    private var config: SyscallMonitoringConfig {
        return configManager.getCurrentConfiguration().modules.syscallMonitoring
    }
    
    // MARK: - Publishers
    
    /// Publisher for monitoring events
    public var eventPublisher: AnyPublisher<SyscallEvent, Never> {
        return eventProcessor.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    private init() {
        self.configManager = ConfigurationManager.shared
        self.syscallHookManager = SyscallHookManager.shared
        
        setupLogging()
        setupDefaultRules()
        setupEventProcessing()
    }
    
    // MARK: - Public Interface
    
    /// Start syscall monitoring with current rules
    public func startMonitoring() throws {
        guard !isMonitoring else {
            throw MonitoringError.monitoringAlreadyActive
        }
        
        logger.info("Starting syscall monitoring engine...")
        
        // Verify syscall hook manager is available
        guard syscallHookManager.isPlatformSupported else {
            throw MonitoringError.syscallHookManagerNotAvailable
        }
        
        // Initialize syscall hook manager if needed
        try syscallHookManager.initialize()
        
        // Start monitoring
        isMonitoring = true
        statistics = MonitoringStatistics()
        statistics.uptime = 0
        
        // Setup event interception
        try setupSyscallInterception()
        
        logger.info("Syscall monitoring engine started successfully", metadata: [
            "rules_count": "\(rules.count)",
            "enabled_rules": "\(rules.values.filter { $0.enabled }.count)"
        ])
    }
    
    /// Stop syscall monitoring
    public func stopMonitoring() throws {
        guard isMonitoring else {
            throw MonitoringError.monitoringNotActive
        }
        
        logger.info("Stopping syscall monitoring engine...")
        
        isMonitoring = false
        
        // Cleanup syscall hooks
        teardownSyscallInterception()
        
        logger.info("Syscall monitoring engine stopped")
    }
    
    /// Add monitoring rule
    public func addRule(_ rule: MonitoringRule) throws {
        logger.info("Adding monitoring rule", metadata: ["rule_id": "\(rule.id)", "rule_name": "\(rule.name)"])
        
        // Validate rule
        try validateRule(rule)
        
        rulesQueue.async(flags: .barrier) {
            self.rules[rule.id] = rule
        }
        
        // If monitoring is active, update syscall hooks
        if isMonitoring {
            try updateSyscallHooks()
        }
        
        logger.info("Successfully added monitoring rule", metadata: ["rule_id": "\(rule.id)"])
    }
    
    /// Remove monitoring rule
    public func removeRule(_ ruleId: String) throws {
        guard rules[ruleId] != nil else {
            throw MonitoringError.ruleNotFound(ruleId)
        }
        
        rulesQueue.async(flags: .barrier) {
            self.rules.removeValue(forKey: ruleId)
        }
        
        // If monitoring is active, update syscall hooks
        if isMonitoring {
            try updateSyscallHooks()
        }
        
        logger.info("Removed monitoring rule", metadata: ["rule_id": "\(ruleId)"])
    }
    
    /// Get all monitoring rules
    public func getRules() -> [MonitoringRule] {
        return rulesQueue.sync {
            return Array(rules.values)
        }
    }
    
    /// Get monitoring statistics
    public func getStatistics() -> MonitoringStatistics {
        return statisticsQueue.sync {
            var stats = statistics
            if let startTime = statistics.lastEventTime {
                stats.uptime = Date().timeIntervalSince(startTime)
            }
            return stats
        }
    }
    
    /// Enable/disable rule
    public func setRuleEnabled(_ ruleId: String, enabled: Bool) throws {
        guard let rule = rules[ruleId] else {
            throw MonitoringError.ruleNotFound(ruleId)
        }
        
        let updatedRule = MonitoringRule(
            id: rule.id,
            name: rule.name,
            description: rule.description,
            condition: rule.condition,
            output: rule.output,
            priority: rule.priority,
            enabled: enabled,
            exceptions: rule.exceptions
        )
        
        rulesQueue.async(flags: .barrier) {
            self.rules[ruleId] = updatedRule
        }
        
        logger.info("Updated rule enabled state", metadata: [
            "rule_id": "\(ruleId)",
            "enabled": "\(enabled)"
        ])
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        logger.info("Initializing syscall monitoring engine", metadata: [
            "version": "1.0.0",
            "platform_supported": "\(syscallHookManager.isPlatformSupported)"
        ])
    }
    
    private func setupDefaultRules() {
        // Privacy violation detection rule
        let privacyViolationRule = MonitoringRule(
            id: "privacy-violation-detection",
            name: "Privacy Violation Detection",
            description: "Detect potential privacy violations through system calls",
            condition: RuleCondition(
                syscalls: ["connect", "sendto", "write"],
                networkFilters: RuleCondition.NetworkFilters(
                    blockedPorts: [443, 80, 53], // HTTPS, HTTP, DNS
                    blockedIPs: ["8.8.8.8", "1.1.1.1"] // Known DNS servers
                )
            ),
            output: "Privacy violation detected: proc=%proc.name pid=%proc.pid dest=%network.dest",
            priority: .critical
        )
        
        // Privilege escalation detection
        let privilegeEscalationRule = MonitoringRule(
            id: "privilege-escalation-detection",
            name: "Privilege Escalation Detection",
            description: "Detect attempts to escalate privileges",
            condition: RuleCondition(
                syscalls: ["setuid", "setgid", "seteuid", "setegid"],
                processFilters: RuleCondition.ProcessFilters(
                    blockedProcesses: ["suspicious_app", "malware"],
                    blockedUIDs: [0] // root
                )
            ),
            output: "Privilege escalation attempt: proc=%proc.name pid=%proc.pid uid=%evt.arg.uid",
            priority: .alert
        )
        
        // File system monitoring
        let fileSystemRule = MonitoringRule(
            id: "sensitive-file-access",
            name: "Sensitive File Access",
            description: "Monitor access to sensitive files and directories",
            condition: RuleCondition(
                syscalls: ["open", "openat", "read", "write"],
                pathFilters: RuleCondition.PathFilters(
                    blockedPaths: ["/etc/passwd", "/etc/shadow", "/System/Library/Keychains"],
                    pathPatterns: ["*.pem", "*.key", "*.p12"]
                )
            ),
            output: "Sensitive file access: proc=%proc.name file=%file.path",
            priority: .warning,
            exceptions: [
                MonitoringRule.RuleException(
                    name: "system_processes",
                    fields: ["proc.name"],
                    values: ["launchd", "kernel_task", "loginwindow"]
                )
            ]
        )
        
        // Network monitoring
        let networkMonitoringRule = MonitoringRule(
            id: "network-activity-monitoring",
            name: "Network Activity Monitoring",
            description: "Monitor network connections and data transmission",
            condition: RuleCondition(
                syscalls: ["connect", "bind", "listen", "accept"],
                networkFilters: RuleCondition.NetworkFilters(
                    blockedPorts: [22, 23, 21], // SSH, Telnet, FTP
                    allowedIPs: ["127.0.0.1", "::1"] // Localhost only
                )
            ),
            output: "Network activity: proc=%proc.name proto=%network.proto dest=%network.dest port=%network.port",
            priority: .info
        )
        
        // Add default rules
        rules["privacy-violation-detection"] = privacyViolationRule
        rules["privilege-escalation-detection"] = privilegeEscalationRule
        rules["sensitive-file-access"] = fileSystemRule
        rules["network-activity-monitoring"] = networkMonitoringRule
        
        logger.debug("Initialized default monitoring rules", metadata: ["count": "\(rules.count)"])
    }
    
    private func setupEventProcessing() {
        eventProcessor
            .receive(on: monitoringQueue)
            .sink { [weak self] event in
                self?.processEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func setupSyscallInterception() throws {
        // Get all unique syscalls from enabled rules
        let monitoredSyscalls = getMonitoredSyscalls()
        
        logger.debug("Setting up syscall interception", metadata: [
            "monitored_syscalls": "\(monitoredSyscalls)"
        ])
        
        // Configure syscall hooks for monitoring
        var hookConfig = SyscallHookConfiguration()
        
        // Enable hooks for monitored syscalls
        for syscall in monitoredSyscalls {
            switch syscall {
            case "gethostname":
                hookConfig.hooks.gethostname = true
            case "getuid":
                hookConfig.hooks.getuid = true
            case "getgid":
                hookConfig.hooks.getgid = true
            case "uname":
                hookConfig.hooks.uname = true
            default:
                logger.warning("Syscall not supported for hooking", metadata: ["syscall": "\(syscall)"])
            }
        }
        
        try syscallHookManager.updateConfiguration(hookConfig)
        let installedHooks = try syscallHookManager.installConfiguredHooks()
        
        logger.info("Configured syscall hooks for monitoring", metadata: [
            "installed_hooks": "\(installedHooks.keys.sorted())"
        ])
    }
    
    private func teardownSyscallInterception() {
        do {
            try syscallHookManager.removeAllHooks()
            logger.debug("Removed all syscall hooks")
        } catch {
            logger.error("Failed to remove syscall hooks", metadata: ["error": "\(error.localizedDescription)"])
        }
    }
    
    private func updateSyscallHooks() throws {
        if isMonitoring {
            teardownSyscallInterception()
            try setupSyscallInterception()
        }
    }
    
    private func getMonitoredSyscalls() -> Set<String> {
        return rulesQueue.sync {
            let enabledRules = rules.values.filter { $0.enabled }
            var syscalls = Set<String>()
            
            for rule in enabledRules {
                syscalls.formUnion(rule.condition.syscalls)
            }
            
            return syscalls
        }
    }
    
    private func validateRule(_ rule: MonitoringRule) throws {
        // Validate syscall names
        let supportedSyscalls = ["gethostname", "getuid", "getgid", "uname", "connect", "bind", "listen", "open", "read", "write"]
        
        for syscall in rule.condition.syscalls {
            if !supportedSyscalls.contains(syscall) {
                logger.warning("Syscall not fully supported for monitoring", metadata: ["syscall": "\(syscall)"])
            }
        }
        
        // Validate rule ID
        if rule.id.isEmpty {
            throw MonitoringError.invalidRuleCondition("Rule ID cannot be empty")
        }
        
        // Validate output format
        if rule.output.isEmpty {
            throw MonitoringError.invalidRuleCondition("Rule output cannot be empty")
        }
    }
    
    private func processEvent(_ event: SyscallEvent) {
        // Update statistics
        updateStatistics(for: event)
        
        // Check if event matches any rules
        let matchingRules = evaluateRules(for: event)
        
        if !matchingRules.isEmpty {
            let eventWithRules = SyscallEvent(
                syscallName: event.syscallName,
                processID: event.processID,
                processName: event.processName,
                userID: event.userID,
                groupID: event.groupID,
                arguments: event.arguments,
                returnValue: event.returnValue,
                filePath: event.filePath,
                networkInfo: event.networkInfo,
                triggeredRules: matchingRules
            )
            
            handleRuleMatch(event: eventWithRules, rules: matchingRules)
        }
    }
    
    private func evaluateRules(for event: SyscallEvent) -> [MonitoringRule] {
        return rulesQueue.sync {
            let enabledRules = rules.values.filter { $0.enabled }
            var matchingRules: [MonitoringRule] = []
            
            for rule in enabledRules {
                if evaluateRule(rule, for: event) {
                    matchingRules.append(rule)
                }
            }
            
            return matchingRules
        }
    }
    
    private func evaluateRule(_ rule: MonitoringRule, for event: SyscallEvent) -> Bool {
        // Check syscall match
        guard rule.condition.syscalls.contains(event.syscallName) else {
            return false
        }
        
        // Check process filters
        if let processFilters = rule.condition.processFilters {
            if !processFilters.allowedProcesses.isEmpty &&
               !processFilters.allowedProcesses.contains(event.processName) {
                return false
            }
            
            if processFilters.blockedProcesses.contains(event.processName) {
                return false
            }
            
            if !processFilters.allowedUIDs.isEmpty &&
               !processFilters.allowedUIDs.contains(event.userID) {
                return false
            }
            
            if processFilters.blockedUIDs.contains(event.userID) {
                return false
            }
        }
        
        // Check path filters
        if let pathFilters = rule.condition.pathFilters,
           let filePath = event.filePath {
            
            if !pathFilters.allowedPaths.isEmpty {
                let pathAllowed = pathFilters.allowedPaths.contains { allowedPath in
                    filePath.hasPrefix(allowedPath)
                }
                if !pathAllowed {
                    return false
                }
            }
            
            let pathBlocked = pathFilters.blockedPaths.contains { blockedPath in
                filePath.hasPrefix(blockedPath)
            }
            if pathBlocked {
                return false
            }
            
            // Check pattern matching
            for pattern in pathFilters.pathPatterns {
                if matchesPattern(path: filePath, pattern: pattern) {
                    return true
                }
            }
        }
        
        // Check network filters
        if let networkFilters = rule.condition.networkFilters,
           let networkInfo = event.networkInfo {
            
            if !networkFilters.allowedPorts.isEmpty &&
               !networkFilters.allowedPorts.contains(networkInfo.remotePort) {
                return false
            }
            
            if networkFilters.blockedPorts.contains(networkInfo.remotePort) {
                return false
            }
            
            if !networkFilters.allowedIPs.isEmpty &&
               !networkFilters.allowedIPs.contains(networkInfo.remoteAddress) {
                return false
            }
            
            if networkFilters.blockedIPs.contains(networkInfo.remoteAddress) {
                return false
            }
        }
        
        // Check exceptions
        for exception in rule.exceptions {
            if evaluateException(exception, for: event) {
                return false // Exception matches, so rule doesn't apply
            }
        }
        
        return true
    }
    
    private func evaluateException(_ exception: MonitoringRule.RuleException, for event: SyscallEvent) -> Bool {
        for (index, field) in exception.fields.enumerated() {
            guard index < exception.values.count else { continue }
            
            let expectedValue = exception.values[index]
            
            switch field {
            case "proc.name":
                if event.processName == expectedValue {
                    return true
                }
            case "proc.pid":
                if String(event.processID) == expectedValue {
                    return true
                }
            case "evt.uid":
                if String(event.userID) == expectedValue {
                    return true
                }
            default:
                break
            }
        }
        
        return false
    }
    
    private func matchesPattern(path: String, pattern: String) -> Bool {
        // Simple pattern matching (could be enhanced with regex)
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return path.hasPrefix(prefix)
        } else if pattern.hasPrefix("*") {
            let suffix = String(pattern.dropFirst())
            return path.hasSuffix(suffix)
        } else if pattern.contains("*") {
            // More complex pattern matching would go here
            return false
        } else {
            return path == pattern
        }
    }
    
    private func handleRuleMatch(event: SyscallEvent, rules: [MonitoringRule]) {
        for rule in rules {
            let logLevel: Logger.Level = logLevelForPriority(rule.priority)
            let formattedOutput = formatRuleOutput(rule.output, event: event)
            
            logger.log(level: logLevel, "Rule match", metadata: [
                "rule_id": "\(rule.id)",
                "rule_name": "\(rule.name)",
                "priority": "\(rule.priority.rawValue)",
                "output": "\(formattedOutput)"
            ])
        }
        
        // Update rule match statistics
        statisticsQueue.async {
            self.statistics.ruleMatches += UInt64(rules.count)
        }
    }
    
    private func logLevelForPriority(_ priority: MonitoringRule.Priority) -> Logger.Level {
        switch priority {
        case .emergency, .alert, .critical:
            return .critical
        case .error:
            return .error
        case .warning:
            return .warning
        case .notice, .info:
            return .info
        case .debug:
            return .debug
        }
    }
    
    private func formatRuleOutput(_ output: String, event: SyscallEvent) -> String {
        var formatted = output
        
        // Replace event placeholders
        formatted = formatted.replacingOccurrences(of: "%proc.name", with: event.processName)
        formatted = formatted.replacingOccurrences(of: "%proc.pid", with: String(event.processID))
        formatted = formatted.replacingOccurrences(of: "%evt.arg.uid", with: String(event.userID))
        formatted = formatted.replacingOccurrences(of: "%evt.syscall", with: event.syscallName)
        
        if let filePath = event.filePath {
            formatted = formatted.replacingOccurrences(of: "%file.path", with: filePath)
        }
        
        if let networkInfo = event.networkInfo {
            formatted = formatted.replacingOccurrences(of: "%network.dest", with: networkInfo.remoteAddress)
            formatted = formatted.replacingOccurrences(of: "%network.port", with: String(networkInfo.remotePort))
            formatted = formatted.replacingOccurrences(of: "%network.proto", with: networkInfo.networkProtocol)
        }
        
        return formatted
    }
    
    private func updateStatistics(for event: SyscallEvent) {
        statisticsQueue.async {
            self.statistics.totalEvents += 1
            self.statistics.lastEventTime = event.timestamp
            
            // Track events per second
            let now = Date()
            self.eventTimestamps.append(now)
            
            // Keep only last second of timestamps
            let oneSecondAgo = now.addingTimeInterval(-1.0)
            self.eventTimestamps.removeAll { $0 < oneSecondAgo }
            
            let eventsPerSecond = UInt64(self.eventTimestamps.count)
            if eventsPerSecond > self.statistics.peakEventsPerSecond {
                self.statistics.peakEventsPerSecond = eventsPerSecond
            }
            
            // Update processing time (simplified - would measure actual processing time)
            let processingTime = 0.5 // Example: 0.5ms
            self.statistics.averageProcessingTimeMs = (self.statistics.averageProcessingTimeMs + processingTime) / 2.0
        }
    }
}
