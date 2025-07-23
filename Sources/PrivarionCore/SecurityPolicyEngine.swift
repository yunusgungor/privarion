import Foundation
import os

/// Security policy engine that evaluates threats and applies policies using async patterns
/// Inspired by Falco security framework patterns adapted for Swift concurrency
actor SecurityPolicyEngine {
    
    // MARK: - Types
    
    /// Represents a security policy with conditions and actions
    struct SecurityPolicy: Sendable {
        let id: String
        let name: String
        let description: String
        let condition: PolicyCondition
        let action: PolicyAction
        let severity: ThreatSeverity
        let enabled: Bool
        
        init(id: String, name: String, description: String, condition: PolicyCondition, action: PolicyAction, severity: ThreatSeverity, enabled: Bool = true) {
            self.id = id
            self.name = name
            self.description = description
            self.condition = condition
            self.action = action
            self.severity = severity
            self.enabled = enabled
        }
    }
    
    /// Policy condition that can be evaluated against security events
    indirect enum PolicyCondition: Sendable {
        case processName(matches: String)
        case processPath(startsWith: String)
        case fileAccess(path: String, type: FileAccessType)
        case networkConnection(host: String, port: Int?)
        case and([PolicyCondition])
        case or([PolicyCondition])
        case not(PolicyCondition)
        
        enum FileAccessType: Sendable {
            case read, write, execute, delete
        }
    }
    
    /// Action to take when a policy is triggered
    enum PolicyAction: Sendable {
        case log(level: LogLevel)
        case alert(message: String)
        case isolate(processID: Int32)
        case terminate(processID: Int32)
        case quarantine(path: String)
        
        enum LogLevel: Sendable {
            case info, warning, error, critical
        }
    }
    
    /// Threat severity levels
    enum ThreatSeverity: Int, Sendable, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        var description: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }
    }
    
    /// Request for policy evaluation
    struct PolicyEvaluationRequest: Sendable {
        let eventID: String
        let timestamp: Date
        let processID: Int32
        let processName: String
        let processPath: String
        let fileOperations: [FileOperation]
        let networkConnections: [NetworkConnection]
        
        struct FileOperation: Sendable {
            let path: String
            let operation: PolicyCondition.FileAccessType
            let timestamp: Date
        }
        
        struct NetworkConnection: Sendable {
            let host: String
            let port: Int
            let networkProtocol: String
            let timestamp: Date
        }
    }
    
    /// Result of policy evaluation
    struct PolicyEvaluationResult: Sendable {
        let requestID: String
        let triggered: Bool
        let matchedPolicies: [String] // Policy IDs
        let recommendedActions: [PolicyAction]
        let evaluationTime: TimeInterval
        let severity: ThreatSeverity?
        
        init(requestID: String, triggered: Bool, matchedPolicies: [String], recommendedActions: [PolicyAction], evaluationTime: TimeInterval, severity: ThreatSeverity? = nil) {
            self.requestID = requestID
            self.triggered = triggered
            self.matchedPolicies = matchedPolicies
            self.recommendedActions = recommendedActions
            self.evaluationTime = evaluationTime
            self.severity = severity
        }
    }
    
    // MARK: - Properties
    
    private var policies: [SecurityPolicy] = []
    private let logger: os.Logger
    private let performanceMonitor: PolicyPerformanceMonitor
    
    // AsyncSequence for policy evaluation (simplified implementation)
    private var evaluationRequests: [PolicyEvaluationRequest] = []
    private var evaluationResults: [PolicyEvaluationResult] = []
    
    // Performance targets from Context7 research
    private let maxEvaluationTime: TimeInterval = 0.05 // <50ms target
    
    // MARK: - Initialization
    
    init(logger: os.Logger = os.Logger(subsystem: "com.privarion.security", category: "PolicyEngine"), loadDefaults: Bool = true) {
        self.logger = logger
        self.performanceMonitor = PolicyPerformanceMonitor()
        
        // Load default security policies unless disabled (for testing)
        if loadDefaults {
            Task { await loadDefaultPolicies() }
        }
        
        // Start policy evaluation processor
        Task {
            await startEvaluationProcessor()
        }
    }
    
    // MARK: - Public Interface
    
    /// Add a new security policy
    func addPolicy(_ policy: SecurityPolicy) {
        policies.append(policy)
        logger.info("Added security policy: \(policy.name) (ID: \(policy.id))")
    }
    
    /// Remove a security policy by ID
    func removePolicy(id: String) {
        policies.removeAll { $0.id == id }
        logger.info("Removed security policy with ID: \(id)")
    }
    
    /// Enable or disable a policy
    func setPolicy(id: String, enabled: Bool) {
        if let index = policies.firstIndex(where: { $0.id == id }) {
            let oldPolicy = policies[index]
            policies[index] = SecurityPolicy(
                id: oldPolicy.id,
                name: oldPolicy.name,
                description: oldPolicy.description,
                condition: oldPolicy.condition,
                action: oldPolicy.action,
                severity: oldPolicy.severity,
                enabled: enabled
            )
            logger.info("Policy \(id) \(enabled ? "enabled" : "disabled")")
        }
    }
    
    /// Evaluate a security event against all active policies
    func evaluateEvent(_ request: PolicyEvaluationRequest) async throws -> PolicyEvaluationResult {
        let startTime = Date()
        
        // Process request directly (simplified approach for compilation)
        let result = await processEvaluationRequest(request)
        
        let totalTime = Date().timeIntervalSince(startTime)
        let maxTime = maxEvaluationTime
        if totalTime > maxTime {
            logger.warning("Policy evaluation exceeded target time: \(totalTime)ms (target: \(maxTime * 1000)ms)")
        }
        
        return result
    }
    
    /// Get all currently loaded policies
    func getAllPolicies() -> [SecurityPolicy] {
        return policies
    }
    
    /// Get policies filtered by severity
    func getPolicies(severity: ThreatSeverity) -> [SecurityPolicy] {
        return policies.filter { $0.severity == severity }
    }
    
    /// Validate a policy configuration
    func validatePolicy(_ policy: SecurityPolicy) -> PolicyValidationResult {
        var issues: [String] = []
        
        // Validate policy structure
        if policy.name.isEmpty {
            issues.append("Policy name cannot be empty")
        }
        
        if policy.description.isEmpty {
            issues.append("Policy description cannot be empty")
        }
        
        // Validate condition complexity
        let conditionComplexity = calculateConditionComplexity(policy.condition)
        if conditionComplexity > 10 {
            issues.append("Condition complexity too high (\(conditionComplexity)), may impact performance")
        }
        
        return PolicyValidationResult(
            valid: issues.isEmpty,
            issues: issues,
            complexity: conditionComplexity
        )
    }
    
    // MARK: - Private Implementation
    
    /// Process policy evaluation requests asynchronously (simplified for compilation)
    private func startEvaluationProcessor() async {
        // Simplified implementation - process requests from array
        // In a full implementation, this would use AsyncChannel
    }
    
    /// Process a single evaluation request
    private func processEvaluationRequest(_ request: PolicyEvaluationRequest) async -> PolicyEvaluationResult {
        let startTime = Date()
        var matchedPolicies: [String] = []
        var recommendedActions: [PolicyAction] = []
        var maxSeverity: ThreatSeverity = .low
        
        // Evaluate against all enabled policies
        for policy in policies where policy.enabled {
            if await evaluateCondition(policy.condition, against: request) {
                matchedPolicies.append(policy.id)
                recommendedActions.append(policy.action)
                
                if policy.severity.rawValue > maxSeverity.rawValue {
                    maxSeverity = policy.severity
                }
                
                logger.info("Policy triggered: \(policy.name) for process \(request.processName)")
            }
        }
        
        let evaluationTime = Date().timeIntervalSince(startTime)
        let triggered = !matchedPolicies.isEmpty
        
        // Record performance metrics
        await performanceMonitor.recordEvaluation(
            time: evaluationTime,
            policiesEvaluated: policies.count,
            triggered: triggered
        )
        
        return PolicyEvaluationResult(
            requestID: request.eventID,
            triggered: triggered,
            matchedPolicies: matchedPolicies,
            recommendedActions: recommendedActions,
            evaluationTime: evaluationTime,
            severity: triggered ? maxSeverity : nil
        )
    }
    
    /// Evaluate a condition against a security event
    private func evaluateCondition(_ condition: PolicyCondition, against request: PolicyEvaluationRequest) async -> Bool {
        switch condition {
        case .processName(let pattern):
            return request.processName.contains(pattern)
            
        case .processPath(let prefix):
            return request.processPath.hasPrefix(prefix)
            
        case .fileAccess(let path, let type):
            return request.fileOperations.contains { operation in
                operation.path.hasPrefix(path) && operation.operation == type
            }
            
        case .networkConnection(let host, let port):
            return request.networkConnections.contains { connection in
                connection.host == host && (port == nil || connection.port == port)
            }
            
        case .and(let conditions):
            for condition in conditions {
                if !(await evaluateCondition(condition, against: request)) {
                    return false
                }
            }
            return true
            
        case .or(let conditions):
            for condition in conditions {
                if await evaluateCondition(condition, against: request) {
                    return true
                }
            }
            return false
            
        case .not(let condition):
            return !(await evaluateCondition(condition, against: request))
        }
    }
    
    /// Calculate the complexity of a policy condition
    private func calculateConditionComplexity(_ condition: PolicyCondition) -> Int {
        switch condition {
        case .processName, .processPath, .fileAccess, .networkConnection:
            return 1
        case .and(let conditions), .or(let conditions):
            return conditions.reduce(1) { $0 + calculateConditionComplexity($1) }
        case .not(let condition):
            return 1 + calculateConditionComplexity(condition)
        }
    }
    
    /// Load default security policies based on common threat patterns
    private func loadDefaultPolicies() {
        // Suspicious process execution policy
        let suspiciousProcessPolicy = SecurityPolicy(
            id: "suspicious-process-execution",
            name: "Suspicious Process Execution",
            description: "Detects execution of potentially malicious processes",
            condition: .or([
                .processName(matches: "nc"),
                .processName(matches: "netcat"),
                .processName(matches: "nmap"),
                .processPath(startsWith: "/tmp/"),
                .processPath(startsWith: "/var/tmp/")
            ]),
            action: .isolate(processID: 0), // Process ID will be filled at runtime
            severity: .high
        )
        
        // Unauthorized file access policy
        let unauthorizedFilePolicy = SecurityPolicy(
            id: "unauthorized-file-access",
            name: "Unauthorized File Access",
            description: "Detects access to sensitive system files",
            condition: .or([
                .fileAccess(path: "/etc/passwd", type: .read),
                .fileAccess(path: "/etc/shadow", type: .read),
                .fileAccess(path: "/private/var/db", type: .write),
                .fileAccess(path: "/System/Library", type: .write)
            ]),
            action: .alert(message: "Unauthorized file access detected"),
            severity: .medium
        )
        
        // Suspicious network activity policy
        let suspiciousNetworkPolicy = SecurityPolicy(
            id: "suspicious-network-activity",
            name: "Suspicious Network Activity",
            description: "Detects potentially malicious network connections",
            condition: .or([
                .networkConnection(host: "127.0.0.1", port: 4444), // Common reverse shell port
                .networkConnection(host: "0.0.0.0", port: 1337),   // Common backdoor port
                .networkConnection(host: "localhost", port: 31337) // Another common backdoor port
            ]),
            action: .terminate(processID: 0),
            severity: .critical
        )
        
        policies = [suspiciousProcessPolicy, unauthorizedFilePolicy, suspiciousNetworkPolicy]
        logger.info("Loaded \(self.policies.count) default security policies")
    }
}

// MARK: - Supporting Types

/// Policy validation result
struct PolicyValidationResult: Sendable {
    let valid: Bool
    let issues: [String]
    let complexity: Int
}

/// Security policy errors
enum SecurityPolicyError: Error, Sendable {
    case evaluationTimeout
    case invalidPolicy(String)
    case policyNotFound(String)
}

/// Performance monitoring for policy evaluation
actor PolicyPerformanceMonitor {
    private var evaluations: [EvaluationMetric] = []
    
    struct EvaluationMetric {
        let timestamp: Date
        let evaluationTime: TimeInterval
        let policiesEvaluated: Int
        let triggered: Bool
    }
    
    func recordEvaluation(time: TimeInterval, policiesEvaluated: Int, triggered: Bool) {
        let metric = EvaluationMetric(
            timestamp: Date(),
            evaluationTime: time,
            policiesEvaluated: policiesEvaluated,
            triggered: triggered
        )
        evaluations.append(metric)
        
        // Keep only last 1000 evaluations for memory management
        if evaluations.count > 1000 {
            evaluations.removeFirst(evaluations.count - 1000)
        }
    }
    
    func getAverageEvaluationTime() -> TimeInterval {
        guard !evaluations.isEmpty else { return 0 }
        return evaluations.map(\.evaluationTime).reduce(0, +) / Double(evaluations.count)
    }
    
    func getThreatDetectionRate() -> Double {
        guard !evaluations.isEmpty else { return 0 }
        let triggeredCount = evaluations.filter(\.triggered).count
        return Double(triggeredCount) / Double(evaluations.count)
    }
}

// MARK: - Async Utilities

/// Timeout utility for async operations
func withTimeout<T>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw SecurityPolicyError.evaluationTimeout
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// MARK: - AsyncChannel Implementation

/// Simple AsyncChannel implementation for policy evaluation
/// Based on Swift Async Algorithms research patterns
final class AsyncChannel<Element: Sendable>: Sendable {
    private let continuation: AsyncStream<Element>.Continuation
    private let stream: AsyncStream<Element>
    
    init() {
        var continuation: AsyncStream<Element>.Continuation!
        stream = AsyncStream<Element> { cont in
            continuation = cont
        }
        self.continuation = continuation
    }
    
    func send(_ element: Element) async throws {
        continuation.yield(element)
    }
    
    func finish() {
        continuation.finish()
    }
}

extension AsyncChannel: AsyncSequence {
    typealias AsyncIterator = AsyncStream<Element>.AsyncIterator
    
    func makeAsyncIterator() -> AsyncIterator {
        return stream.makeAsyncIterator()
    }
}
