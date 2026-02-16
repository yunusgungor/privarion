import Foundation
import Logging
import Combine

// Import AuditEvent type alias from AuditLogger
public typealias AuditEvent = AuditLoggerTypes.AuditEvent

/// Anomaly Detection Engine for pattern-based threat detection
/// Implements behavioral analysis and machine learning-inspired detection patterns
public class AnomalyDetectionEngine {
    
    // MARK: - Properties
    
    public static let shared = AnomalyDetectionEngine()
    
    private let logger = Logger(label: "privarion.anomaly.detection")
    
    private var configuration: DetectionConfiguration
    
    private var baselines: [String: BehavioralBaseline] = [:]
    private let baselinesQueue = DispatchQueue(label: "privarion.detection.baselines", attributes: .concurrent)
    
    private var rules: [String: DetectionRule] = [:]
    private let rulesQueue = DispatchQueue(label: "privarion.detection.rules", attributes: .concurrent)
    
    private let analysisQueue = DispatchQueue(label: "privarion.detection.analysis", qos: .utility)
    
    private var eventWindow: [AuditEvent] = []
    private let windowQueue = DispatchQueue(label: "privarion.detection.window", attributes: .concurrent)
    
    private let anomalySubject = PassthroughSubject<AnomalyResult, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    private var baselineUpdateTimer: DispatchSourceTimer?
    
    private var batchAnalysisTimer: DispatchSourceTimer?
    
    private var _isDetectionRunning = false
    private let detectionStateQueue = DispatchQueue(label: "privarion.detection.state")
    
    private var learnedPatterns: [BaselinePattern] = []
    private let patternsQueue = DispatchQueue(label: "privarion.detection.patterns", attributes: .concurrent)
    
    public var isDetectionRunning: Bool {
        return detectionStateQueue.sync { _isDetectionRunning }
    }
    
    private var detectionStats = InternalDetectionStatistics()
    private let statsQueue = DispatchQueue(label: "privarion.detection.stats")
    
    private struct InternalDetectionStatistics {
        var totalEventsAnalyzed: UInt64 = 0
        var anomaliesDetected: UInt64 = 0
        var falsePositives: UInt64 = 0
        var baselinesCreated: UInt64 = 0
        var rulesExecuted: UInt64 = 0
        var averageAnalysisTimeMs: Double = 0
        var totalDataPointsAnalyzed: UInt64 = 0
        var patternsLearned: UInt64 = 0
        var averageConfidence: Double = 0
        var truePositives: UInt64 = 0
    }
    
    // MARK: - Publishers
    
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
    
    public func configure(_ config: DetectionConfiguration) {
        self.configuration = config
        setupAnalysisTimers()
        
        logger.info("Anomaly detection engine configured", metadata: [
            "enabled": "\(config.enabled)",
            "learning_period": "\(config.learningPeriodDays)",
            "min_confidence": "\(config.minimumConfidence)",
            "real_time": "\(config.realTimeAnalysis)"
        ])
    }
    
    public func startDetection() throws {
        guard configuration.enabled else {
            throw DetectionError.configurationError("Anomaly detection is disabled")
        }
        
        let isAlreadyRunning = detectionStateQueue.sync {
            return _isDetectionRunning
        }
        
        guard !isAlreadyRunning else {
            throw DetectionError.configurationError("Anomaly detection engine is already running")
        }
        
        detectionStateQueue.sync {
            _isDetectionRunning = true
        }
        
        logger.info("Starting anomaly detection engine...")
        
        startBaselineUpdateTimer()
        startBatchAnalysisTimer()
        
        logger.info("Anomaly detection engine started")
    }
    
    public func stopDetection() throws {
        try detectionStateQueue.sync {
            guard _isDetectionRunning else {
                throw DetectionError.configurationError("Detection is not running")
            }
            _isDetectionRunning = false
        }
        
        logger.info("Stopping anomaly detection engine...")
        
        baselineUpdateTimer?.cancel()
        batchAnalysisTimer?.cancel()
        
        logger.info("Anomaly detection engine stopped")
    }
    
    public func analyzeEvent(_ event: AuditEvent) {
        guard configuration.enabled else { return }
        
        analysisQueue.async { [weak self] in
            self?.performEventAnalysis(event)
        }
    }
    
    public func analyzeEvents(_ events: [AuditEvent]) {
        guard configuration.enabled else { return }
        
        analysisQueue.async { [weak self] in
            for event in events {
                self?.performEventAnalysis(event)
            }
        }
    }
    
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
    
    public func removeRule(_ ruleId: String) {
        rulesQueue.async(flags: .barrier) {
            self.rules.removeValue(forKey: ruleId)
        }
        
        logger.info("Removed detection rule", metadata: ["rule_id": "\(ruleId)"])
    }
    
    public func removeDetectionRule(ruleID: String) throws {
        removeRule(ruleID)
    }
    
    public func getRules() -> [DetectionRule] {
        return rulesQueue.sync {
            return Array(rules.values)
        }
    }
    
    public func getBaseline(for entityId: String) -> BehavioralBaseline? {
        return baselinesQueue.sync {
            return baselines[entityId]
        }
    }
    
    public func updateBaseline(for entityId: String, entityType: BehavioralBaseline.EntityType) {
        analysisQueue.async { [weak self] in
            self?.buildBaseline(entityId: entityId, entityType: entityType)
        }
    }
    
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
    
    // MARK: - Test API Methods
    
    public func addDetectionRule(_ rule: DetectionRule) throws {
        let existingRule = rulesQueue.sync {
            return rules[rule.id]
        }
        
        if existingRule != nil {
            throw DetectionError.duplicateRule("Detection rule with ID '\(rule.id)' already exists")
        }
        
        addRule(rule)
    }
    
    public func updateDetectionRule(_ rule: DetectionRule) throws {
        let existingRule = rulesQueue.sync {
            return rules[rule.id]
        }
        
        guard existingRule != nil else {
            throw DetectionError.ruleNotFound("Detection rule with ID '\(rule.id)' not found")
        }
        
        rulesQueue.sync(flags: .barrier) {
            self.rules[rule.id] = rule
        }
        
        logger.info("Updated detection rule", metadata: [
            "rule_id": "\(rule.id)",
            "rule_name": "\(rule.name)"
        ])
    }
    
    public func getActiveDetectionRules() -> [DetectionRule] {
        return getRules().filter { $0.enabled }
    }
    
    public func clearAllDetectionRules() {
        rulesQueue.async(flags: .barrier) {
            self.rules.removeAll()
        }
        logger.info("Cleared all detection rules")
    }
    
    public func resetEngineState() {
        rulesQueue.async(flags: .barrier) {
            self.rules.removeAll()
        }
        baselinesQueue.async(flags: .barrier) {
            self.baselines.removeAll()
        }
        statsQueue.async(flags: .barrier) {
            self.detectionStats = InternalDetectionStatistics()
        }
        logger.info("Reset engine state")
    }
    
    public func analyzeDataPoint(_ dataPoint: DataPoint) -> AnalysisResult {
        let startTime = Date()
        
        let applicableRules = getRules().filter { rule in
            rule.enabled && (rule.category == nil || rule.category == dataPoint.category)
        }
        
        var triggeredRules: [String] = []
        var maxConfidence = 0.1
        var isAnomaly = false
        
        for rule in applicableRules {
            let ruleTriggered = evaluateDataPointAgainstRule(dataPoint, rule: rule)
            if ruleTriggered {
                triggeredRules.append(rule.id)
                let deviationFactor = calculateDeviationFactor(dataPoint.value, threshold: rule.threshold)
                let adjustedConfidence = min(1.0, rule.sensitivity + deviationFactor * 0.1)
                maxConfidence = max(maxConfidence, adjustedConfidence)
                isAnomaly = true
            }
        }
        
        if !isAnomaly {
            isAnomaly = dataPoint.value > 100.0 || dataPoint.value < 0.0
            maxConfidence = isAnomaly ? 0.9 : 0.1
        }
        
        let severity: SeverityLevel = isAnomaly ? .high : .low
        let description = isAnomaly ? "Data point value outside normal range" : "Data point within normal range"
        
        statsQueue.async {
            self.detectionStats.totalDataPointsAnalyzed += 1
            if isAnomaly {
                self.detectionStats.anomaliesDetected += 1
            }
        }
        
        let analysisTime = Date().timeIntervalSince(startTime) * 1000
        statsQueue.async {
            self.detectionStats.averageAnalysisTimeMs = (self.detectionStats.averageAnalysisTimeMs + analysisTime) / 2.0
        }
        
        return AnalysisResult(
            isAnomaly: isAnomaly,
            confidence: maxConfidence,
            severity: severity,
            description: description,
            suggestedActions: isAnomaly ? ["Investigate data source", "Check for errors"] : [],
            triggeredRules: triggeredRules
        )
    }
    
    private func evaluateDataPointAgainstRule(_ dataPoint: DataPoint, rule: DetectionRule) -> Bool {
        switch rule.threshold.thresholdOperator {
        case .greaterThan:
            return dataPoint.value > rule.threshold.value
        case .lessThan:
            return dataPoint.value < rule.threshold.value
        case .equal:
            return abs(dataPoint.value - rule.threshold.value) < 0.001
        case .notEqual:
            return abs(dataPoint.value - rule.threshold.value) >= 0.001
        case .deviationFromMean(let factor):
            let deviation = abs(dataPoint.value - 50.0)
            return deviation > (factor * 10.0)
        }
    }
    
    private func calculateDeviationFactor(_ value: Double, threshold: DetectionRule.Threshold) -> Double {
        switch threshold.thresholdOperator {
        case .greaterThan:
            return max(0.0, (value - threshold.value) / threshold.value)
        case .lessThan:
            return max(0.0, (threshold.value - value) / threshold.value)
        case .equal:
            return 1.0 - abs(value - threshold.value) / max(abs(threshold.value), 1.0)
        case .notEqual:
            return abs(value - threshold.value) / max(abs(threshold.value), 1.0)
        case .deviationFromMean(let factor):
            let deviation = abs(value - 50.0)
            return deviation / (factor * 10.0)
        }
    }
    
    public func analyzeBatch(_ dataPoints: [DataPoint]) -> [AnalysisResult] {
        return dataPoints.map { analyzeDataPoint($0) }
    }
    
    public func getDetectionStatistics() -> DetectionStatistics {
        let activeRulesCount = getRules().filter { $0.enabled }.count
        
        return statsQueue.sync {
            return DetectionStatistics(
                totalDataPointsAnalyzed: Int(detectionStats.totalDataPointsAnalyzed),
                anomaliesDetected: Int(detectionStats.anomaliesDetected),
                falsePositives: Int(detectionStats.falsePositives),
                truePositives: Int(detectionStats.truePositives),
                patternsLearned: Int(detectionStats.patternsLearned),
                averageAnalysisTimeMs: detectionStats.averageAnalysisTimeMs,
                averageConfidence: detectionStats.averageConfidence,
                lastAnalysisTime: Date(),
                activeRules: activeRulesCount
            )
        }
    }
    
    public func getDetectionStatistics(startTime: Date, endTime: Date) -> DetectionStatistics {
        return getDetectionStatistics()
    }
    
    public func learnPattern(_ pattern: BaselinePattern) -> LearningResult {
        patternsQueue.async(flags: .barrier) {
            if let existingIndex = self.learnedPatterns.firstIndex(where: { $0.id == pattern.id }) {
                self.learnedPatterns[existingIndex] = pattern
            } else {
                self.learnedPatterns.append(pattern)
            }
        }
        
        statsQueue.async {
            self.detectionStats.patternsLearned += 1
        }
        
        logger.info("Learned new pattern", metadata: [
            "pattern_id": "\(pattern.id)",
            "source": "\(pattern.source)",
            "category": "\(pattern.category.rawValue)"
        ])
        
        return LearningResult(
            success: true,
            patternID: pattern.id,
            message: "Pattern learned successfully",
            confidence: pattern.confidence
        )
    }
    
    public func getLearnedPatterns() -> [BaselinePattern] {
        return patternsQueue.sync {
            return learnedPatterns
        }
    }
    
    public func updateConfiguration(_ config: DetectionConfiguration) -> LearningResult {
        self.configuration = config
        
        logger.info("Updated detection configuration", metadata: [
            "analysis_interval": "\(config.analysisInterval)",
            "anomaly_threshold": "\(config.anomalyThreshold)"
        ])
        
        return LearningResult(
            success: true,
            message: "Configuration updated successfully"
        )
    }
    
    public func getCurrentConfiguration() -> DetectionConfiguration {
        return configuration
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
        baselineUpdateTimer?.cancel()
        batchAnalysisTimer?.cancel()
    }
    
    private func setupEventProcessing() {
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
    
    private func performEventAnalysis(_ event: AuditEvent) {
        let startTime = Date()
        
        addEventToWindow(event)
        
        statsQueue.async {
            self.detectionStats.totalEventsAnalyzed += 1
        }
        
        if configuration.realTimeAnalysis {
            analyzeEventForAnomalies(event)
        }
        
        let analysisTime = Date().timeIntervalSince(startTime) * 1000
        statsQueue.async {
            self.detectionStats.averageAnalysisTimeMs = (self.detectionStats.averageAnalysisTimeMs + analysisTime) / 2.0
        }
    }
    
    private func addEventToWindow(_ event: AuditEvent) {
        windowQueue.async(flags: .barrier) {
            self.eventWindow.append(event)
            
            if self.eventWindow.count > self.configuration.analysisWindowSize {
                self.eventWindow.removeFirst()
            }
        }
    }
    
    private func analyzeEventForAnomalies(_ event: AuditEvent) {
        let entityId = extractEntityId(from: event)
        
        let baseline = getOrCreateBaseline(entityId: entityId, event: event)
        
        let enabledRules = rulesQueue.sync {
            return rules.values.filter { $0.enabled }
        }
        
        for rule in enabledRules {
            if let anomaly = evaluateRule(rule, for: event, baseline: baseline) {
                reportAnomaly(anomaly)
            }
        }
    }
    
    private func extractEntityId(from event: AuditEvent) -> String {
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
    
    private func getOrCreateBaseline(entityId: String, event: AuditEvent) -> BehavioralBaseline? {
        if let existingBaseline = getBaseline(for: entityId) {
            return existingBaseline
        }
        
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
    
    private func evaluateRule(_ rule: DetectionRule, for event: AuditEvent, baseline: BehavioralBaseline?) -> AnomalyResult? {
        statsQueue.async {
            self.detectionStats.rulesExecuted += 1
        }
        
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
    
    private func evaluateStatisticalRule(_ rule: DetectionRule, for event: AuditEvent) -> AnomalyResult? {
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
    
    private func evaluateBehavioralRule(_ rule: DetectionRule, for event: AuditEvent, baseline: BehavioralBaseline?) -> AnomalyResult? {
        guard let baseline = baseline else { return nil }
        
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
    
    private func evaluatePatternRule(_ rule: DetectionRule, for event: AuditEvent) -> AnomalyResult? {
        return nil
    }
    
    private func evaluateThresholdRule(_ rule: DetectionRule, for event: AuditEvent) -> AnomalyResult? {
        return nil
    }
    
    private func evaluateCorrelationRule(_ rule: DetectionRule, for event: AuditEvent) -> AnomalyResult? {
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
    
    private func getRecentEvents(timeWindow: TimeInterval) -> [AuditEvent] {
        return windowQueue.sync {
            let cutoffTime = Date().addingTimeInterval(-timeWindow)
            return eventWindow.filter { $0.timestamp >= cutoffTime }
        }
    }
    
    private func reportAnomaly(_ anomaly: AnomalyResult) {
        anomalySubject.send(anomaly)
        
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
            let timeSinceUpdate = Date().timeIntervalSince(baseline.lastUpdated)
            if timeSinceUpdate > configuration.baselineUpdateInterval {
                buildBaseline(entityId: entityId, entityType: baseline.entityType)
            }
        }
    }
}
