import Foundation
import Logging
import Combine

/// Anomaly Detection Engine for pattern-based threat detection
/// Implements behavioral analysis and machine learning-inspired detection patterns
public class AnomalyDetectionEngine {
    
    // MARK: - Types
    
    /// Anomaly detection result
    public struct AnomalyResult {
        public let id: UUID
        public let timestamp: Date
        public let anomalyType: AnomalyType
        public let severity: Severity
        public let confidence: Double
        public let source: String
        public let description: String
        public let evidence: [Evidence]
        public let suggestedActions: [String]
        public let correlatedEvents: [UUID]
        
        public enum AnomalyType: String, CaseIterable {
            case behavioralAnomaly = "BEHAVIORAL_ANOMALY"
            case statisticalOutlier = "STATISTICAL_OUTLIER"
            case patternViolation = "PATTERN_VIOLATION"
            case frequencyAnomaly = "FREQUENCY_ANOMALY"
            case sequenceAnomaly = "SEQUENCE_ANOMALY"
            case resourceAnomaly = "RESOURCE_ANOMALY"
            case networkAnomaly = "NETWORK_ANOMALY"
            case processAnomaly = "PROCESS_ANOMALY"
            case timeBasedAnomaly = "TIME_BASED_ANOMALY"
            case correlationAnomaly = "CORRELATION_ANOMALY"
        }
        
        public enum Severity: String, CaseIterable {
            case low = "LOW"
            case medium = "MEDIUM"
            case high = "HIGH"
            case critical = "CRITICAL"
        }
        
        public struct Evidence {
            public let type: String
            public let value: String
            public let baseline: String?
            public let deviation: Double?
            
            public init(type: String, value: String, baseline: String? = nil, deviation: Double? = nil) {
                self.type = type
                self.value = value
                self.baseline = baseline
                self.deviation = deviation
            }
        }
        
        public init(
            anomalyType: AnomalyType,
            severity: Severity,
            confidence: Double,
            source: String,
            description: String,
            evidence: [Evidence] = [],
            suggestedActions: [String] = [],
            correlatedEvents: [UUID] = []
        ) {
            self.id = UUID()
            self.timestamp = Date()
            self.anomalyType = anomalyType
            self.severity = severity
            self.confidence = confidence
            self.source = source
            self.description = description
            self.evidence = evidence
            self.suggestedActions = suggestedActions
            self.correlatedEvents = correlatedEvents
        }
    }
    
    /// Behavioral baseline for process/user activities
    public struct BehavioralBaseline {
        public let entityId: String
        public let entityType: EntityType
        public let learningPeriodDays: Int
        public let patterns: BehavioralPatterns
        public let lastUpdated: Date
        public let confidence: Double
        
        public enum EntityType {
            case process
            case user
            case network
            case system
        }
        
        public struct BehavioralPatterns {
            public var syscallFrequency: [String: FrequencyPattern] = [:]
            public var networkConnections: [String: FrequencyPattern] = [:]
            public var fileAccess: [String: FrequencyPattern] = [:]
            public var processSpawning: FrequencyPattern?
            public var resourceUsage: ResourcePattern?
            public var timePatterns: TimePattern?
            
            public struct FrequencyPattern {
                public let mean: Double
                public let standardDeviation: Double
                public let minimum: Double
                public let maximum: Double
                public let sampleCount: Int
                
                public init(mean: Double, standardDeviation: Double, minimum: Double, maximum: Double, sampleCount: Int) {
                    self.mean = mean
                    self.standardDeviation = standardDeviation
                    self.minimum = minimum
                    self.maximum = maximum
                    self.sampleCount = sampleCount
                }
            }
            
            public struct ResourcePattern {
                public let cpuUsageMean: Double
                public let memoryUsageMean: Double
                public let cpuUsageStdDev: Double
                public let memoryUsageStdDev: Double
                
                public init(cpuUsageMean: Double, memoryUsageMean: Double, cpuUsageStdDev: Double, memoryUsageStdDev: Double) {
                    self.cpuUsageMean = cpuUsageMean
                    self.memoryUsageMean = memoryUsageMean
                    self.cpuUsageStdDev = cpuUsageStdDev
                    self.memoryUsageStdDev = memoryUsageStdDev
                }
            }
            
            public struct TimePattern {
                public let activeHours: Set<Int>
                public let activeDays: Set<Int>
                public let sessionDurationMean: Double
                public let sessionDurationStdDev: Double
                
                public init(activeHours: Set<Int>, activeDays: Set<Int>, sessionDurationMean: Double, sessionDurationStdDev: Double) {
                    self.activeHours = activeHours
                    self.activeDays = activeDays
                    self.sessionDurationMean = sessionDurationMean
                    self.sessionDurationStdDev = sessionDurationStdDev
                }
            }
            
            public init() {}
        }
        
        public init(
            entityId: String,
            entityType: EntityType,
            learningPeriodDays: Int,
            patterns: BehavioralPatterns,
            confidence: Double
        ) {
            self.entityId = entityId
            self.entityType = entityType
            self.learningPeriodDays = learningPeriodDays
            self.patterns = patterns
            self.lastUpdated = Date()
            self.confidence = confidence
        }
    }
    
    /// Detection rule for specific anomaly patterns
    public struct DetectionRule {
        public let id: String
        public let name: String
        public let description: String
        public let ruleType: RuleType
        public let threshold: Threshold
        public let enabled: Bool
        public let sensitivity: Double
        public let conditions: [RuleCondition]
        
        public enum RuleType {
            case statistical
            case behavioral
            case pattern
            case threshold
            case correlation
        }
        
        public struct Threshold {
            public let value: Double
            public let thresholdOperator: ThresholdOperator
            public let timeWindow: TimeInterval
            
            public enum ThresholdOperator {
                case greaterThan
                case lessThan
                case equal
                case notEqual
                case deviationFromMean(factor: Double)
            }
            
            public init(value: Double, thresholdOperator: ThresholdOperator, timeWindow: TimeInterval = 300) {
                self.value = value
                self.thresholdOperator = thresholdOperator
                self.timeWindow = timeWindow
            }
        }
        
        public struct RuleCondition {
            public let field: String
            public let condition: String
            public let expectedValue: String?
            
            public init(field: String, condition: String, expectedValue: String? = nil) {
                self.field = field
                self.condition = condition
                self.expectedValue = expectedValue
            }
        }
        
        public init(
            id: String,
            name: String,
            description: String,
            ruleType: RuleType,
            threshold: Threshold,
            enabled: Bool = true,
            sensitivity: Double = 0.8,
            conditions: [RuleCondition] = []
        ) {
            self.id = id
            self.name = name
            self.description = description
            self.ruleType = ruleType
            self.threshold = threshold
            self.enabled = enabled
            self.sensitivity = sensitivity
            self.conditions = conditions
        }
    }
    
    /// Detection configuration
    public struct DetectionConfiguration {
        public var enabled: Bool = true
        public var learningPeriodDays: Int = 7
        public var minimumConfidence: Double = 0.7
        public var baselineUpdateInterval: TimeInterval = 3600 // 1 hour
        public var maxBaselines: Int = 1000
        public var analysisWindowSize: Int = 100
        public var realTimeAnalysis: Bool = true
        public var batchAnalysisInterval: TimeInterval = 300 // 5 minutes
        
        public init() {}
    }
    
    /// Anomaly detection errors
    public enum DetectionError: Error, LocalizedError {
        case configurationError(String)
        case baselineNotFound(String)
        case analysisError(String)
        case storageError(String)
        case invalidData(String)
        
        public var errorDescription: String? {
            switch self {
            case .configurationError(let detail):
                return "Detection configuration error: \(detail)"
            case .baselineNotFound(let entityId):
                return "Behavioral baseline not found for entity: \(entityId)"
            case .analysisError(let detail):
                return "Analysis error: \(detail)"
            case .storageError(let detail):
                return "Storage error: \(detail)"
            case .invalidData(let detail):
                return "Invalid data: \(detail)"
            }
        }
    }
    
    // MARK: - Properties
    
    /// Shared singleton instance
    public static let shared = AnomalyDetectionEngine()
    
    /// Logger instance
    private let logger = Logger(label: "privarion.anomaly.detection")
    
    /// Configuration
    private var configuration: DetectionConfiguration
    
    /// Behavioral baselines storage
    private var baselines: [String: BehavioralBaseline] = [:]
    private let baselinesQueue = DispatchQueue(label: "privarion.detection.baselines", attributes: .concurrent)
    
    /// Detection rules
    private var rules: [String: DetectionRule] = [:]
    private let rulesQueue = DispatchQueue(label: "privarion.detection.rules", attributes: .concurrent)
    
    /// Event analysis queue
    private let analysisQueue = DispatchQueue(label: "privarion.detection.analysis", qos: .utility)
    
    /// Event window for analysis
    private var eventWindow: [AuditLogger.AuditEvent] = []
    private let windowQueue = DispatchQueue(label: "privarion.detection.window", attributes: .concurrent)
    
    /// Anomaly results publisher
    private let anomalySubject = PassthroughSubject<AnomalyResult, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    /// Baseline update timer
    private var baselineUpdateTimer: DispatchSourceTimer?
    
    /// Batch analysis timer
    private var batchAnalysisTimer: DispatchSourceTimer?
    
    /// Statistics
    private var detectionStats = DetectionStatistics()
    private let statsQueue = DispatchQueue(label: "privarion.detection.stats")
    
    private struct DetectionStatistics {
        var totalEventsAnalyzed: UInt64 = 0
        var anomaliesDetected: UInt64 = 0
        var falsePositives: UInt64 = 0
        var baselinesCreated: UInt64 = 0
        var rulesExecuted: UInt64 = 0
        var averageAnalysisTimeMs: Double = 0
    }
    
    // MARK: - Publishers
    
    /// Publisher for anomaly detection results
    public var anomalyPublisher: AnyPublisher<AnomalyResult, Never> {
        return anomalySubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    private init() {
        self.configuration = DetectionConfiguration()
        
        setupLogging()
        loadDefaultRules()
        setupAnalysisTimers()
        setupEventProcessing()
    }
    
    // MARK: - Public Interface
    
    /// Configure anomaly detection engine
    public func configure(_ config: DetectionConfiguration) {
        self.configuration = config
        
        // Restart timers with new configuration
        setupAnalysisTimers()
        
        logger.info("Anomaly detection engine configured", metadata: [
            "enabled": "\(config.enabled)",
            "learning_period": "\(config.learningPeriodDays)",
            "min_confidence": "\(config.minimumConfidence)",
            "real_time": "\(config.realTimeAnalysis)"
        ])
    }
    
    /// Start anomaly detection
    public func startDetection() throws {
        guard configuration.enabled else {
            throw DetectionError.configurationError("Anomaly detection is disabled")
        }
        
        logger.info("Starting anomaly detection engine...")
        
        // Start timers
        startBaselineUpdateTimer()
        startBatchAnalysisTimer()
        
        logger.info("Anomaly detection engine started")
    }
    
    /// Stop anomaly detection
    public func stopDetection() {
        logger.info("Stopping anomaly detection engine...")
        
        baselineUpdateTimer?.cancel()
        batchAnalysisTimer?.cancel()
        
        logger.info("Anomaly detection engine stopped")
    }
    
    /// Analyze audit event for anomalies
    public func analyzeEvent(_ event: AuditLogger.AuditEvent) {
        guard configuration.enabled else { return }
        
        analysisQueue.async { [weak self] in
            self?.performEventAnalysis(event)
        }
    }
    
    /// Analyze batch of events
    public func analyzeEvents(_ events: [AuditLogger.AuditEvent]) {
        guard configuration.enabled else { return }
        
        analysisQueue.async { [weak self] in
            for event in events {
                self?.performEventAnalysis(event)
            }
        }
    }
    
    /// Add detection rule
    public func addRule(_ rule: DetectionRule) {
        rulesQueue.async(flags: .barrier) {
            self.rules[rule.id] = rule
        }
        
        logger.info("Added detection rule", metadata: [
            "rule_id": "\(rule.id)",
            "rule_name": "\(rule.name)",
            "rule_type": "\(rule.ruleType)"
        ])
    }
    
    /// Remove detection rule
    public func removeRule(_ ruleId: String) {
        rulesQueue.async(flags: .barrier) {
            self.rules.removeValue(forKey: ruleId)
        }
        
        logger.info("Removed detection rule", metadata: ["rule_id": "\(ruleId)"])
    }
    
    /// Get all detection rules
    public func getRules() -> [DetectionRule] {
        return rulesQueue.sync {
            return Array(rules.values)
        }
    }
    
    /// Get behavioral baseline for entity
    public func getBaseline(for entityId: String) -> BehavioralBaseline? {
        return baselinesQueue.sync {
            return baselines[entityId]
        }
    }
    
    /// Force baseline update for entity
    public func updateBaseline(for entityId: String, entityType: BehavioralBaseline.EntityType) {
        analysisQueue.async { [weak self] in
            self?.buildBaseline(entityId: entityId, entityType: entityType)
        }
    }
    
    /// Get detection statistics
    public func getStatistics() -> [String: Any] {
        return statsQueue.sync {
            return [
                "total_events_analyzed": detectionStats.totalEventsAnalyzed,
                "anomalies_detected": detectionStats.anomaliesDetected,
                "false_positives": detectionStats.falsePositives,
                "baselines_created": detectionStats.baselinesCreated,
                "rules_executed": detectionStats.rulesExecuted,
                "average_analysis_time_ms": detectionStats.averageAnalysisTimeMs,
                "active_baselines": baselines.count,
                "active_rules": rules.count
            ]
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        logger.info("Initializing anomaly detection engine", metadata: [
            "version": "1.0.0"
        ])
    }
    
    private func loadDefaultRules() {
        let defaultRules = createDefaultRules()
        
        rulesQueue.async(flags: .barrier) {
            for rule in defaultRules {
                self.rules[rule.id] = rule
            }
        }
        
        logger.info("Loaded default detection rules", metadata: ["count": "\(defaultRules.count)"])
    }
    
    private func createDefaultRules() -> [DetectionRule] {
        var rules: [DetectionRule] = []
        
        // High frequency syscall rule
        let highFrequencyRule = DetectionRule(
            id: "high-frequency-syscalls",
            name: "High Frequency Syscall Anomaly",
            description: "Detect unusually high frequency of system calls",
            ruleType: .statistical,
            threshold: DetectionRule.Threshold(
                value: 1000,
                thresholdOperator: .greaterThan,
                timeWindow: 60
            ),
            sensitivity: 0.8
        )
        
        // Unusual network activity rule
        let networkAnomalyRule = DetectionRule(
            id: "unusual-network-activity",
            name: "Unusual Network Activity",
            description: "Detect unusual network connection patterns",
            ruleType: .behavioral,
            threshold: DetectionRule.Threshold(
                value: 3.0,
                thresholdOperator: .deviationFromMean(factor: 3.0),
                timeWindow: 300
            ),
            sensitivity: 0.7
        )
        
        // Process spawning anomaly
        let processSpawningRule = DetectionRule(
            id: "process-spawning-anomaly",
            name: "Process Spawning Anomaly",
            description: "Detect unusual process creation patterns",
            ruleType: .pattern,
            threshold: DetectionRule.Threshold(
                value: 10,
                thresholdOperator: .greaterThan,
                timeWindow: 60
            ),
            sensitivity: 0.9
        )
        
        // Resource usage anomaly
        let resourceAnomalyRule = DetectionRule(
            id: "resource-usage-anomaly",
            name: "Resource Usage Anomaly",
            description: "Detect unusual CPU or memory usage patterns",
            ruleType: .threshold,
            threshold: DetectionRule.Threshold(
                value: 90.0,
                thresholdOperator: .greaterThan,
                timeWindow: 120
            ),
            sensitivity: 0.8
        )
        
        // Off-hours activity
        let offHoursRule = DetectionRule(
            id: "off-hours-activity",
            name: "Off-Hours Activity",
            description: "Detect activity during unusual hours",
            ruleType: .behavioral,
            threshold: DetectionRule.Threshold(
                value: 1.0,
                thresholdOperator: .greaterThan,
                timeWindow: 3600
            ),
            sensitivity: 0.6
        )
        
        rules.append(highFrequencyRule)
        rules.append(networkAnomalyRule)
        rules.append(processSpawningRule)
        rules.append(resourceAnomalyRule)
        rules.append(offHoursRule)
        
        return rules
    }
    
    private func setupAnalysisTimers() {
        // Cancel existing timers
        baselineUpdateTimer?.cancel()
        batchAnalysisTimer?.cancel()
    }
    
    private func setupEventProcessing() {
        // Subscribe to audit events (would integrate with AuditLogger)
        // For now, this is a placeholder for the integration
    }
    
    private func startBaselineUpdateTimer() {
        let timer = DispatchSource.makeTimerSource(queue: analysisQueue)
        timer.schedule(deadline: .now() + configuration.baselineUpdateInterval, repeating: configuration.baselineUpdateInterval)
        
        timer.setEventHandler { [weak self] in
            self?.updateAllBaselines()
        }
        
        timer.resume()
        baselineUpdateTimer = timer
    }
    
    private func startBatchAnalysisTimer() {
        guard !configuration.realTimeAnalysis else { return }
        
        let timer = DispatchSource.makeTimerSource(queue: analysisQueue)
        timer.schedule(deadline: .now() + configuration.batchAnalysisInterval, repeating: configuration.batchAnalysisInterval)
        
        timer.setEventHandler { [weak self] in
            self?.performBatchAnalysis()
        }
        
        timer.resume()
        batchAnalysisTimer = timer
    }
    
    private func performEventAnalysis(_ event: AuditLogger.AuditEvent) {
        let startTime = Date()
        
        // Add event to analysis window
        addEventToWindow(event)
        
        // Update statistics
        statsQueue.async {
            self.detectionStats.totalEventsAnalyzed += 1
        }
        
        // Perform real-time analysis if enabled
        if configuration.realTimeAnalysis {
            analyzeEventForAnomalies(event)
        }
        
        // Update analysis time statistics
        let analysisTime = Date().timeIntervalSince(startTime) * 1000 // ms
        statsQueue.async {
            self.detectionStats.averageAnalysisTimeMs = (self.detectionStats.averageAnalysisTimeMs + analysisTime) / 2.0
        }
    }
    
    private func addEventToWindow(_ event: AuditLogger.AuditEvent) {
        windowQueue.async(flags: .barrier) {
            self.eventWindow.append(event)
            
            // Keep window size manageable
            if self.eventWindow.count > self.configuration.analysisWindowSize {
                self.eventWindow.removeFirst()
            }
        }
    }
    
    private func analyzeEventForAnomalies(_ event: AuditLogger.AuditEvent) {
        // Get entity ID for baseline lookup
        let entityId = extractEntityId(from: event)
        
        // Get or create baseline
        let baseline = getOrCreateBaseline(entityId: entityId, event: event)
        
        // Apply detection rules
        let enabledRules = rulesQueue.sync {
            return rules.values.filter { $0.enabled }
        }
        
        for rule in enabledRules {
            if let anomaly = evaluateRule(rule, for: event, baseline: baseline) {
                reportAnomaly(anomaly)
            }
        }
    }
    
    private func extractEntityId(from event: AuditLogger.AuditEvent) -> String {
        // Extract entity ID based on event type
        switch event.eventType {
        case .systemCall, .processActivity:
            return "process_\(event.process?.name ?? "unknown")"
        case .networkActivity:
            return "network_\(event.network?.remoteAddress ?? "unknown")"
        case .fileSystemActivity:
            return "file_\(event.resource ?? "unknown")"
        default:
            return "system_\(event.source)"
        }
    }
    
    private func getOrCreateBaseline(entityId: String, event: AuditLogger.AuditEvent) -> BehavioralBaseline? {
        if let existingBaseline = getBaseline(for: entityId) {
            return existingBaseline
        }
        
        // Create new baseline if we have enough historical data
        let entityType: BehavioralBaseline.EntityType = {
            switch event.eventType {
            case .systemCall, .processActivity:
                return .process
            case .networkActivity:
                return .network
            default:
                return .system
            }
        }()
        
        buildBaseline(entityId: entityId, entityType: entityType)
        return getBaseline(for: entityId)
    }
    
    private func buildBaseline(entityId: String, entityType: BehavioralBaseline.EntityType) {
        // This would implement actual baseline building from historical data
        // For now, create a simple baseline
        
        let patterns = BehavioralBaseline.BehavioralPatterns()
        let baseline = BehavioralBaseline(
            entityId: entityId,
            entityType: entityType,
            learningPeriodDays: configuration.learningPeriodDays,
            patterns: patterns,
            confidence: 0.8
        )
        
        baselinesQueue.async(flags: .barrier) {
            self.baselines[entityId] = baseline
        }
        
        statsQueue.async {
            self.detectionStats.baselinesCreated += 1
        }
        
        logger.debug("Created baseline for entity", metadata: [
            "entity_id": "\(entityId)",
            "entity_type": "\(entityType)"
        ])
    }
    
    private func evaluateRule(_ rule: DetectionRule, for event: AuditLogger.AuditEvent, baseline: BehavioralBaseline?) -> AnomalyResult? {
        statsQueue.async {
            self.detectionStats.rulesExecuted += 1
        }
        
        // Evaluate rule based on type
        switch rule.ruleType {
        case .statistical:
            return evaluateStatisticalRule(rule, for: event)
        case .behavioral:
            return evaluateBehavioralRule(rule, for: event, baseline: baseline)
        case .pattern:
            return evaluatePatternRule(rule, for: event)
        case .threshold:
            return evaluateThresholdRule(rule, for: event)
        case .correlation:
            return evaluateCorrelationRule(rule, for: event)
        }
    }
    
    private func evaluateStatisticalRule(_ rule: DetectionRule, for event: AuditLogger.AuditEvent) -> AnomalyResult? {
        // Simple statistical analysis
        let recentEvents = getRecentEvents(timeWindow: rule.threshold.timeWindow)
        let eventCount = Double(recentEvents.count)
        
        switch rule.threshold.thresholdOperator {
        case .greaterThan:
            if eventCount > rule.threshold.value {
                return createAnomalyResult(
                    type: .statisticalOutlier,
                    severity: .medium,
                    confidence: rule.sensitivity,
                    source: event.source,
                    description: "Statistical threshold exceeded: \(eventCount) > \(rule.threshold.value)",
                    rule: rule
                )
            }
        case .lessThan:
            if eventCount < rule.threshold.value {
                return createAnomalyResult(
                    type: .statisticalOutlier,
                    severity: .low,
                    confidence: rule.sensitivity,
                    source: event.source,
                    description: "Statistical threshold under-run: \(eventCount) < \(rule.threshold.value)",
                    rule: rule
                )
            }
        default:
            break
        }
        
        return nil
    }
    
    private func evaluateBehavioralRule(_ rule: DetectionRule, for event: AuditLogger.AuditEvent, baseline: BehavioralBaseline?) -> AnomalyResult? {
        guard let baseline = baseline else { return nil }
        
        // Compare event against behavioral baseline
        // This is a simplified implementation
        
        let confidence = min(baseline.confidence, rule.sensitivity)
        
        if confidence >= configuration.minimumConfidence {
            return createAnomalyResult(
                type: .behavioralAnomaly,
                severity: .medium,
                confidence: confidence,
                source: event.source,
                description: "Behavioral deviation detected for \(baseline.entityId)",
                rule: rule
            )
        }
        
        return nil
    }
    
    private func evaluatePatternRule(_ rule: DetectionRule, for event: AuditLogger.AuditEvent) -> AnomalyResult? {
        // Pattern-based detection
        // This would implement specific pattern matching logic
        return nil
    }
    
    private func evaluateThresholdRule(_ rule: DetectionRule, for event: AuditLogger.AuditEvent) -> AnomalyResult? {
        // Simple threshold-based detection
        // This would check specific event properties against thresholds
        return nil
    }
    
    private func evaluateCorrelationRule(_ rule: DetectionRule, for event: AuditLogger.AuditEvent) -> AnomalyResult? {
        // Correlation-based detection
        // This would analyze relationships between events
        return nil
    }
    
    private func createAnomalyResult(
        type: AnomalyResult.AnomalyType,
        severity: AnomalyResult.Severity,
        confidence: Double,
        source: String,
        description: String,
        rule: DetectionRule
    ) -> AnomalyResult {
        
        let evidence = [
            AnomalyResult.Evidence(
                type: "rule_triggered",
                value: rule.name,
                baseline: nil,
                deviation: nil
            )
        ]
        
        let suggestedActions = generateSuggestedActions(for: type, severity: severity)
        
        return AnomalyResult(
            anomalyType: type,
            severity: severity,
            confidence: confidence,
            source: source,
            description: description,
            evidence: evidence,
            suggestedActions: suggestedActions
        )
    }
    
    private func generateSuggestedActions(for type: AnomalyResult.AnomalyType, severity: AnomalyResult.Severity) -> [String] {
        var actions: [String] = []
        
        switch severity {
        case .critical:
            actions.append("Immediately investigate the source")
            actions.append("Consider blocking the activity")
            actions.append("Alert security team")
        case .high:
            actions.append("Investigate within 1 hour")
            actions.append("Monitor closely")
        case .medium:
            actions.append("Review during next security review")
            actions.append("Update monitoring rules if needed")
        case .low:
            actions.append("Log for trend analysis")
        }
        
        switch type {
        case .networkAnomaly:
            actions.append("Check network connections")
            actions.append("Verify DNS queries")
        case .processAnomaly:
            actions.append("Check process genealogy")
            actions.append("Verify process signatures")
        case .behavioralAnomaly:
            actions.append("Compare with user's typical behavior")
            actions.append("Check for account compromise")
        default:
            break
        }
        
        return actions
    }
    
    private func getRecentEvents(timeWindow: TimeInterval) -> [AuditLogger.AuditEvent] {
        return windowQueue.sync {
            let cutoffTime = Date().addingTimeInterval(-timeWindow)
            return eventWindow.filter { $0.timestamp >= cutoffTime }
        }
    }
    
    private func reportAnomaly(_ anomaly: AnomalyResult) {
        // Publish anomaly
        anomalySubject.send(anomaly)
        
        // Log anomaly
        let logLevel: Logger.Level = {
            switch anomaly.severity {
            case .critical:
                return .critical
            case .high:
                return .error
            case .medium:
                return .warning
            case .low:
                return .info
            }
        }()
        
        logger.log(level: logLevel, "Anomaly detected", metadata: [
            "anomaly_id": "\(anomaly.id)",
            "type": "\(anomaly.anomalyType.rawValue)",
            "severity": "\(anomaly.severity.rawValue)",
            "confidence": "\(anomaly.confidence)",
            "source": "\(anomaly.source)",
            "description": "\(anomaly.description)"
        ])
        
        // Update statistics
        statsQueue.async {
            self.detectionStats.anomaliesDetected += 1
        }
    }
    
    private func performBatchAnalysis() {
        let events = windowQueue.sync { return eventWindow }
        
        logger.debug("Performing batch analysis", metadata: ["event_count": "\(events.count)"])
        
        for event in events {
            analyzeEventForAnomalies(event)
        }
    }
    
    private func updateAllBaselines() {
        let currentBaselines = baselinesQueue.sync { return baselines }
        
        logger.debug("Updating behavioral baselines", metadata: ["baseline_count": "\(currentBaselines.count)"])
        
        for (entityId, baseline) in currentBaselines {
            // Check if baseline needs updating
            let timeSinceUpdate = Date().timeIntervalSince(baseline.lastUpdated)
            if timeSinceUpdate > configuration.baselineUpdateInterval {
                buildBaseline(entityId: entityId, entityType: baseline.entityType)
            }
        }
    }
}
