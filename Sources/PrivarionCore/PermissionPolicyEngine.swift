import Foundation
import os

/// Permission-specific policy engine that integrates TCC authorization with SecurityPolicyEngine
/// Implements Spring Security resource-based authorization patterns adapted for macOS TCC system
actor PermissionPolicyEngine {
    
    // MARK: - Types
    
    /// TCC permission-specific policy request
    struct PermissionPolicyRequest: Sendable {
        let requestID: String
        let bundleIdentifier: String
        let serviceName: String
        let requestOrigin: RequestOrigin
        let timestamp: Date
        let context: PermissionContext
        
        init(requestID: String = UUID().uuidString, bundleIdentifier: String, serviceName: String, requestOrigin: RequestOrigin, context: PermissionContext = .userInitiated) {
            self.requestID = requestID
            self.bundleIdentifier = bundleIdentifier
            self.serviceName = serviceName
            self.requestOrigin = requestOrigin
            self.timestamp = Date()
            self.context = context
        }
    }
    
    /// Origin of permission request
    enum RequestOrigin: Sendable {
        case userInterface
        case backgroundTask
        case systemCall
        case thirdPartyAPI
        case unknown
    }
    
    /// Context in which permission is requested
    enum PermissionContext: Sendable {
        case userInitiated
        case automatic
        case scheduled
        case emergency
    }
    
    /// TCC permission-specific policy condition (extends SecurityPolicyEngine patterns)
    indirect enum PermissionPolicyCondition: Sendable {
        case serviceName(matches: String)
        case bundleIdentifier(matches: String)
        case permissionStatus(TCCPermissionEngine.TCCPermissionStatus)
        case requestOrigin(RequestOrigin)
        case context(PermissionContext)
        case timeWindow(start: Date, end: Date)
        case frequencyLimit(maxRequests: Int, timeWindow: TimeInterval)
        case and([PermissionPolicyCondition])
        case or([PermissionPolicyCondition])
        case not(PermissionPolicyCondition)
    }
    
    /// Threat severity levels (shared with SecurityPolicyEngine)
    enum ThreatSeverity: Int, Sendable, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
    }
    
    /// Permission-specific actions (adapts Spring Security authorization decisions)
    enum PermissionPolicyAction: Sendable {
        case allow
        case deny
        case allowTemporary(duration: TimeInterval)
        case requireUserConsent
        case requireAuthentication
        case logAndAlert(severity: ThreatSeverity)
        case quarantine(bundleIdentifier: String)
        case rateLimit(maxRequests: Int, timeWindow: TimeInterval)
    }
    
    /// Permission policy definition
    struct PermissionPolicy: Sendable {
        let id: String
        let name: String
        let description: String
        let condition: PermissionPolicyCondition
        let action: PermissionPolicyAction
        let priority: PolicyPriority
        let enabled: Bool
        
        init(id: String, name: String, description: String, condition: PermissionPolicyCondition, action: PermissionPolicyAction, priority: PolicyPriority = .medium, enabled: Bool = true) {
            self.id = id
            self.name = name
            self.description = description
            self.condition = condition
            self.action = action
            self.priority = priority
            self.enabled = enabled
        }
    }
    
    /// Policy priority for conflict resolution
    enum PolicyPriority: Int, Sendable, CaseIterable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
    }
    
    /// Result of permission policy evaluation
    struct PermissionPolicyResult: Sendable {
        let requestID: String
        let decision: PermissionDecision
        let matchedPolicies: [String]
        let appliedActions: [PermissionPolicyAction]
        let evaluationTime: TimeInterval
        let confidence: Double // 0.0 - 1.0
        let reasoning: String
        
        init(requestID: String, decision: PermissionDecision, matchedPolicies: [String], appliedActions: [PermissionPolicyAction], evaluationTime: TimeInterval, confidence: Double = 1.0, reasoning: String = "") {
            self.requestID = requestID
            self.decision = decision
            self.matchedPolicies = matchedPolicies
            self.appliedActions = appliedActions
            self.evaluationTime = evaluationTime
            self.confidence = confidence
            self.reasoning = reasoning
        }
    }
    
    /// Final permission decision
    enum PermissionDecision: Sendable {
        case allow
        case deny
        case allowTemporary(expiresAt: Date)
        case requireUserConsent
        case requireAuthentication
        case blocked(reason: String)
    }
    
    /// Temporary permission grant
    struct TemporaryGrant: Sendable {
        let id: String
        let bundleIdentifier: String
        let serviceName: String
        let grantedAt: Date
        let expiresAt: Date
        let autoRevoke: Bool
        
        var isExpired: Bool {
            Date() > expiresAt
        }
        
        var remainingTime: TimeInterval {
            max(0, expiresAt.timeIntervalSinceNow)
        }
    }
    
    // MARK: - Properties
    
    private var policies: [PermissionPolicy] = []
    private var temporaryGrants: [String: TemporaryGrant] = [:]
    private var requestHistory: [String: [PermissionPolicyRequest]] = [:]
    private let logger: os.Logger
    private let tccEngine: TCCPermissionEngine
    private let securityEngine: SecurityPolicyEngine
    private let performanceMonitor: PermissionPolicyPerformanceMonitor
    
    // Performance targets
    private let maxEvaluationTime: TimeInterval = 0.05 // <50ms target
    private let maxConcurrentEvaluations = 10
    
    // MARK: - Initialization
    
    init(tccEngine: TCCPermissionEngine, securityEngine: SecurityPolicyEngine, logger: os.Logger = os.Logger(subsystem: "com.privarion.security", category: "PermissionPolicy")) {
        self.tccEngine = tccEngine
        self.securityEngine = securityEngine
        self.logger = logger
        self.performanceMonitor = PermissionPolicyPerformanceMonitor()
        
        // Load default permission policies
        Task {
            await loadDefaultPermissionPolicies()
            await startTemporaryGrantCleanup()
        }
    }
    
    // MARK: - Public Interface
    
    /// Evaluate permission request against policies
    func evaluatePermissionRequest(_ request: PermissionPolicyRequest) async throws -> PermissionPolicyResult {
        let startTime = Date()
        
        // Check performance constraints
        guard await performanceMonitor.canAcceptRequest() else {
            throw PermissionPolicyError.systemOverloaded
        }
        
        // Record request in history for frequency analysis
        await recordRequest(request)
        
        // Get current TCC permission status
        let tccService = TCCPermissionEngine.TCCService(rawValue: request.serviceName) ?? .camera
        let currentStatus = try await tccEngine.getPermissionStatus(
            for: request.bundleIdentifier,
            service: tccService
        )
        
        // Evaluate policies
        let matchedPolicies = await evaluatePolicies(for: request, currentStatus: currentStatus)
        
        // Resolve policy conflicts by priority
        let decision = await resolveDecision(from: matchedPolicies, request: request)
        
        // Apply actions
        let appliedActions = await applyActions(from: matchedPolicies, request: request)
        
        // Calculate evaluation time
        let evaluationTime = Date().timeIntervalSince(startTime)
        
        // Log performance warning if exceeded target
        if evaluationTime > maxEvaluationTime {
            logger.warning("Permission policy evaluation exceeded target time: \(evaluationTime * 1000)ms for request \(request.requestID)")
        }
        
        // Create result
        let result = PermissionPolicyResult(
            requestID: request.requestID,
            decision: decision,
            matchedPolicies: matchedPolicies.map { $0.id },
            appliedActions: appliedActions,
            evaluationTime: evaluationTime,
            confidence: calculateConfidence(matchedPolicies: matchedPolicies),
            reasoning: generateReasoning(matchedPolicies: matchedPolicies, decision: decision)
        )
        
        // Update performance metrics
        await performanceMonitor.recordEvaluation(evaluationTime: evaluationTime, success: true)
        
        logger.info("Permission policy evaluation completed: \(String(describing: decision)) for \(request.bundleIdentifier):\(request.serviceName)")
        
        return result
    }
    
    /// Grant temporary permission with automatic expiration
    func grantTemporaryPermission(bundleIdentifier: String, serviceName: String, duration: TimeInterval) async throws -> TemporaryGrant {
        let grant = TemporaryGrant(
            id: UUID().uuidString,
            bundleIdentifier: bundleIdentifier,
            serviceName: serviceName,
            grantedAt: Date(),
            expiresAt: Date().addingTimeInterval(duration),
            autoRevoke: true
        )
        
        temporaryGrants[grant.id] = grant
        
        logger.info("Granted temporary permission: \(bundleIdentifier):\(serviceName) for \(duration)s")
        
        return grant
    }
    
    /// Check if temporary permission is active
    func hasActiveTemporaryPermission(bundleIdentifier: String, serviceName: String) async -> Bool {
        return temporaryGrants.values.contains { grant in
            grant.bundleIdentifier == bundleIdentifier &&
            grant.serviceName == serviceName &&
            !grant.isExpired
        }
    }
    
    /// Revoke temporary permission
    func revokeTemporaryPermission(grantID: String) async -> Bool {
        guard temporaryGrants.removeValue(forKey: grantID) != nil else {
            return false
        }
        
        logger.info("Revoked temporary permission: \(grantID)")
        return true
    }
    
    /// Get all active temporary grants
    func getActiveTemporaryGrants() async -> [TemporaryGrant] {
        return temporaryGrants.values.filter { !$0.isExpired }
    }
    
    /// Add permission policy
    func addPolicy(_ policy: PermissionPolicy) async {
        policies.append(policy)
        logger.debug("Added permission policy: \(policy.id)")
    }
    
    /// Remove permission policy
    func removePolicy(id: String) async -> Bool {
        guard let index = policies.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        policies.remove(at: index)
        logger.debug("Removed permission policy: \(id)")
        return true
    }
    
    /// Get all policies
    func getPolicies() async -> [PermissionPolicy] {
        return policies
    }
    
    /// Get permission request history for bundle
    func getRequestHistory(bundleIdentifier: String) async -> [PermissionPolicyRequest] {
        return requestHistory[bundleIdentifier] ?? []
    }
    
    // MARK: - Private Implementation
    
    private func loadDefaultPermissionPolicies() async {
        // Camera access policies
        await addPolicy(PermissionPolicy(
            id: "camera-suspicious-background",
            name: "Suspicious Camera Access",
            description: "Deny camera access from background processes without user consent",
            condition: .and([
                .serviceName(matches: "kTCCServiceCamera"),
                .requestOrigin(.backgroundTask)
            ]),
            action: .requireUserConsent,
            priority: .high
        ))
        
        // Microphone access policies
        await addPolicy(PermissionPolicy(
            id: "microphone-rate-limit",
            name: "Microphone Rate Limiting",
            description: "Rate limit microphone access requests",
            condition: .and([
                .serviceName(matches: "kTCCServiceMicrophone"),
                .frequencyLimit(maxRequests: 5, timeWindow: 300) // 5 requests per 5 minutes
            ]),
            action: .rateLimit(maxRequests: 5, timeWindow: 300),
            priority: .medium
        ))
        
        // Screen recording policies
        await addPolicy(PermissionPolicy(
            id: "screen-recording-critical",
            name: "Critical Screen Recording Protection",
            description: "Require authentication for screen recording access",
            condition: .serviceName(matches: "kTCCServiceScreenCapture"),
            action: .requireAuthentication,
            priority: .critical
        ))
        
        // Accessibility policies
        await addPolicy(PermissionPolicy(
            id: "accessibility-temp-allow",
            name: "Temporary Accessibility Access",
            description: "Allow temporary accessibility access for known apps",
            condition: .and([
                .serviceName(matches: "kTCCServiceAccessibility"),
                .context(.userInitiated)
            ]),
            action: .allowTemporary(duration: 3600), // 1 hour
            priority: .medium
        ))
        
        logger.info("Loaded \(self.policies.count) default permission policies")
    }
    
    private func evaluatePolicies(for request: PermissionPolicyRequest, currentStatus: TCCPermissionEngine.TCCPermissionStatus?) async -> [PermissionPolicy] {
        var matchedPolicies: [PermissionPolicy] = []
        
        for policy in policies where policy.enabled {
            if await evaluateCondition(policy.condition, request: request, currentStatus: currentStatus) {
                matchedPolicies.append(policy)
            }
        }
        
        // Sort by priority (highest first)
        return matchedPolicies.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    private func evaluateCondition(_ condition: PermissionPolicyCondition, request: PermissionPolicyRequest, currentStatus: TCCPermissionEngine.TCCPermissionStatus?) async -> Bool {
        switch condition {
        case .serviceName(let pattern):
            return request.serviceName.contains(pattern)
            
        case .bundleIdentifier(let pattern):
            return request.bundleIdentifier.contains(pattern)
            
        case .permissionStatus(let status):
            return currentStatus == status
            
        case .requestOrigin(let origin):
            return request.requestOrigin == origin
            
        case .context(let context):
            return request.context == context
            
        case .timeWindow(let start, let end):
            return request.timestamp >= start && request.timestamp <= end
            
        case .frequencyLimit(let maxRequests, let timeWindow):
            return await checkFrequencyLimit(
                bundleIdentifier: request.bundleIdentifier,
                serviceName: request.serviceName,
                maxRequests: maxRequests,
                timeWindow: timeWindow
            )
            
        case .and(let conditions):
            for subCondition in conditions {
                let result = await evaluateCondition(subCondition, request: request, currentStatus: currentStatus)
                if !result {
                    return false
                }
            }
            return true
            
        case .or(let conditions):
            for subCondition in conditions {
                let result = await evaluateCondition(subCondition, request: request, currentStatus: currentStatus)
                if result {
                    return true
                }
            }
            return false
            
        case .not(let subCondition):
            let result = await evaluateCondition(subCondition, request: request, currentStatus: currentStatus)
            return !result
        }
    }
    
    private func resolveDecision(from policies: [PermissionPolicy], request: PermissionPolicyRequest) async -> PermissionDecision {
        // If no policies matched, default to allow with existing TCC status
        guard !policies.isEmpty else {
            return .allow
        }
        
        // Process policies by priority
        for policy in policies {
            switch policy.action {
            case .deny:
                return .deny
                
            case .allow:
                return .allow
                
            case .allowTemporary(let duration):
                let expiresAt = Date().addingTimeInterval(duration)
                return .allowTemporary(expiresAt: expiresAt)
                
            case .requireUserConsent:
                return .requireUserConsent
                
            case .requireAuthentication:
                return .requireAuthentication
                
            case .quarantine(let bundleId):
                if bundleId == request.bundleIdentifier {
                    return .blocked(reason: "Application quarantined by security policy")
                }
                
            case .logAndAlert, .rateLimit:
                // These don't directly affect the decision, continue to next policy
                continue
            }
        }
        
        // If no decisive action found, default to allow
        return .allow
    }
    
    private func applyActions(from policies: [PermissionPolicy], request: PermissionPolicyRequest) async -> [PermissionPolicyAction] {
        var appliedActions: [PermissionPolicyAction] = []
        
        for policy in policies {
            switch policy.action {
            case .logAndAlert(let severity):
                logger.log(level: logLevel(for: severity), "Permission policy triggered: \(policy.name) for \(request.bundleIdentifier):\(request.serviceName)")
                appliedActions.append(policy.action)
                
            case .allowTemporary(let duration):
                do {
                    _ = try await grantTemporaryPermission(
                        bundleIdentifier: request.bundleIdentifier,
                        serviceName: request.serviceName,
                        duration: duration
                    )
                    appliedActions.append(policy.action)
                } catch {
                    logger.error("Failed to grant temporary permission: \(error)")
                }
                
            case .rateLimit:
                // Rate limiting is handled in condition evaluation
                appliedActions.append(policy.action)
                
            default:
                appliedActions.append(policy.action)
            }
        }
        
        return appliedActions
    }
    
    private func recordRequest(_ request: PermissionPolicyRequest) async {
        if requestHistory[request.bundleIdentifier] == nil {
            requestHistory[request.bundleIdentifier] = []
        }
        
        requestHistory[request.bundleIdentifier]?.append(request)
        
        // Keep only last 100 requests per bundle
        if let history = requestHistory[request.bundleIdentifier], history.count > 100 {
            requestHistory[request.bundleIdentifier] = Array(history.suffix(100))
        }
    }
    
    private func checkFrequencyLimit(bundleIdentifier: String, serviceName: String, maxRequests: Int, timeWindow: TimeInterval) async -> Bool {
        guard let history = requestHistory[bundleIdentifier] else {
            return false // No previous requests, so not over limit
        }
        
        let cutoffTime = Date().addingTimeInterval(-timeWindow)
        let recentRequests = history.filter { request in
            request.serviceName == serviceName && request.timestamp > cutoffTime
        }
        
        return recentRequests.count >= maxRequests
    }
    
    private func calculateConfidence(matchedPolicies: [PermissionPolicy]) -> Double {
        guard !matchedPolicies.isEmpty else { return 0.5 }
        
        let totalPriority = matchedPolicies.reduce(0) { $0 + $1.priority.rawValue }
        let maxPossiblePriority = matchedPolicies.count * PolicyPriority.critical.rawValue
        
        return Double(totalPriority) / Double(maxPossiblePriority)
    }
    
    private func generateReasoning(matchedPolicies: [PermissionPolicy], decision: PermissionDecision) -> String {
        guard !matchedPolicies.isEmpty else {
            return "No policies matched - using default decision"
        }
        
        let policyNames = matchedPolicies.prefix(3).map(\.name).joined(separator: ", ")
        return "Decision based on policies: \(policyNames)"
    }
    
    private func startTemporaryGrantCleanup() async {
        // Background task to clean up expired temporary grants
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                await cleanupExpiredGrants()
            }
        }
    }
    
    private func cleanupExpiredGrants() async {
        let expiredGrants = temporaryGrants.filter { _, grant in grant.isExpired }
        
        for (id, _) in expiredGrants {
            temporaryGrants.removeValue(forKey: id)
        }
        
        if !expiredGrants.isEmpty {
            logger.info("Cleaned up \(expiredGrants.count) expired temporary grants")
        }
    }
    
    private func logLevel(for severity: ThreatSeverity) -> OSLogType {
        switch severity {
        case .low: return .debug
        case .medium: return .info
        case .high: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Supporting Types

/// Performance monitoring for permission policy evaluations
actor PermissionPolicyPerformanceMonitor {
    private var evaluationTimes: [TimeInterval] = []
    private var currentLoad = 0
    private let maxLoad = 10
    
    func canAcceptRequest() async -> Bool {
        return currentLoad < maxLoad
    }
    
    func recordEvaluation(evaluationTime: TimeInterval, success: Bool) async {
        evaluationTimes.append(evaluationTime)
        
        // Keep only last 100 measurements
        if evaluationTimes.count > 100 {
            evaluationTimes.removeFirst()
        }
    }
    
    func getAverageEvaluationTime() async -> TimeInterval {
        guard !evaluationTimes.isEmpty else { return 0 }
        return evaluationTimes.reduce(0, +) / Double(evaluationTimes.count)
    }
}

/// Permission policy errors
enum PermissionPolicyError: Error, LocalizedError {
    case systemOverloaded
    case policyConflict
    case invalidRequest
    case temporaryGrantFailed
    
    var errorDescription: String? {
        switch self {
        case .systemOverloaded:
            return "Permission policy system is overloaded"
        case .policyConflict:
            return "Conflicting policies detected"
        case .invalidRequest:
            return "Invalid permission request"
        case .temporaryGrantFailed:
            return "Failed to grant temporary permission"
        }
    }
}
