import Foundation
import Combine

/// Types for Anomaly Detection Engine
public enum AnomalyDetectionTypes {
    
    // MARK: - Anomaly Result
    
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
    
    // MARK: - Behavioral Baseline
    
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
    
    // MARK: - Detection Rule
    
    public struct DetectionRule {
        public let id: String
        public let name: String
        public let description: String
        public let ruleType: RuleType
        public let threshold: Threshold
        public let enabled: Bool
        public let sensitivity: Double
        public let conditions: [RuleCondition]
        public let category: AnomalyCategory?
        public let action: ActionType?
        public let severity: SeverityLevel?
        
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
                
                public init(from string: String) {
                    switch string.lowercased() {
                    case "greater_than", "greaterthan", ">":
                        self = .greaterThan
                    case "less_than", "lessthan", "<":
                        self = .lessThan
                    case "equals", "equal", "==":
                        self = .equal
                    case "not_equal", "notequal", "!=":
                        self = .notEqual
                    default:
                        self = .greaterThan
                    }
                }
            }
            
            public init(value: Double, thresholdOperator: ThresholdOperator, timeWindow: TimeInterval = 300) {
                self.value = value
                self.thresholdOperator = thresholdOperator
                self.timeWindow = timeWindow
            }
            
            public init(value: Double, thresholdOperator: String, timeWindow: TimeInterval = 300) {
                self.value = value
                self.thresholdOperator = ThresholdOperator(from: thresholdOperator)
                self.timeWindow = timeWindow
            }
        }
        
        public struct RuleCondition {
            public let field: String
            public let condition: String
            public let expectedValue: String?
            public let thresholdOperator: String?
            public let value: String?
            
            public init(field: String, condition: String, expectedValue: String? = nil) {
                self.field = field
                self.condition = condition
                self.expectedValue = expectedValue
                self.thresholdOperator = nil
                self.value = nil
            }
            
            public init(field: String, thresholdOperator: String, value: String) {
                self.field = field
                self.condition = thresholdOperator
                self.expectedValue = nil
                self.thresholdOperator = thresholdOperator
                self.value = value
            }
        }
        
        public typealias Condition = RuleCondition
        
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
            self.category = nil
            self.action = nil
            self.severity = nil
        }
        
        public init(
            id: String,
            name: String,
            description: String,
            ruleType: RuleType,
            threshold: Threshold,
            category: AnomalyCategory,
            action: ActionType,
            severity: SeverityLevel,
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
            self.category = category
            self.action = action
            self.severity = severity
        }
    }
    
    // MARK: - Detection Configuration
    
    public struct DetectionConfiguration {
        public var enabled: Bool = true
        public var learningPeriodDays: Int = 7
        public var minimumConfidence: Double = 0.7
        public var baselineUpdateInterval: TimeInterval = 3600
        public var maxBaselines: Int = 1000
        public var analysisWindowSize: Int = 100
        public var realTimeAnalysis: Bool = true
        public var batchAnalysisInterval: TimeInterval = 300
        public var analysisInterval: Double = 60.0
        public var anomalyThreshold: Double = 0.8
        public var maxDataPointsInMemory: Int = 10000
        public var patternExpirationDays: Int = 30
        public var statisticalMethod: StatisticalMethod = .isolation
        public var confidenceLevel: Double = 0.95
        
        public enum StatisticalMethod: String, CaseIterable {
            case zScore = "Z_SCORE"
            case isolation = "ISOLATION_FOREST"
            case clustering = "CLUSTERING"
            case regression = "REGRESSION"
        }
        
        public init() {}
        
        public init(
            analysisInterval: Double,
            baselineUpdateInterval: TimeInterval,
            anomalyThreshold: Double,
            maxDataPointsInMemory: Int,
            patternExpirationDays: Int,
            statisticalMethod: StatisticalMethod,
            confidenceLevel: Double
        ) {
            self.enabled = true
            self.analysisInterval = analysisInterval
            self.baselineUpdateInterval = baselineUpdateInterval
            self.anomalyThreshold = anomalyThreshold
            self.maxDataPointsInMemory = maxDataPointsInMemory
            self.patternExpirationDays = patternExpirationDays
            self.statisticalMethod = statisticalMethod
            self.confidenceLevel = confidenceLevel
            self.learningPeriodDays = 7
            self.minimumConfidence = 0.7
            self.maxBaselines = 1000
            self.analysisWindowSize = 100
            self.realTimeAnalysis = true
            self.batchAnalysisInterval = 300
        }
    }
    
    public typealias Configuration = DetectionConfiguration
    
    // MARK: - Data Point
    
    public struct DataPoint {
        public let source: String
        public let category: AnomalyCategory
        public let metric: String
        public let value: Double
        public let timestamp: Date
        public let metadata: [String: Any]
        
        public init(
            source: String,
            category: AnomalyCategory,
            metric: String,
            value: Double,
            timestamp: Date = Date(),
            metadata: [String: Any] = [:]
        ) {
            self.source = source
            self.category = category
            self.metric = metric
            self.value = value
            self.timestamp = timestamp
            self.metadata = metadata
        }
    }
    
    // MARK: - Anomaly Category
    
    public enum AnomalyCategory: String, CaseIterable {
        case security = "SECURITY"
        case performance = "PERFORMANCE"
        case network = "NETWORK"
        case behavior = "BEHAVIOR"
        case resource = "RESOURCE"
        case compliance = "COMPLIANCE"
    }
    
    // MARK: - Severity Level
    
    public enum SeverityLevel: String, CaseIterable {
        case critical = "CRITICAL"
        case high = "HIGH"
        case medium = "MEDIUM"
        case low = "LOW"
        case info = "INFO"
    }
    
    // MARK: - Action Type
    
    public enum ActionType: String, CaseIterable {
        case alert = "ALERT"
        case block = "BLOCK"
        case quarantine = "QUARANTINE"
        case log = "LOG"
        case none = "NONE"
    }
    
    // MARK: - Value Range
    
    public struct ValueRange {
        public let minimum: Double
        public let maximum: Double
        
        public init(minimum: Double, maximum: Double) {
            self.minimum = minimum
            self.maximum = maximum
        }
        
        public func contains(_ value: Double) -> Bool {
            return value >= minimum && value <= maximum
        }
        
        public var span: Double {
            return maximum - minimum
        }
        
        public var midpoint: Double {
            return (minimum + maximum) / 2.0
        }
    }
    
    // MARK: - Baseline Pattern
    
    public struct BaselinePattern {
        public let id: String
        public let source: String
        public let category: AnomalyCategory
        public let metric: String
        public let normalRange: ValueRange
        public let confidence: Double
        public let sampleSize: Int
        public let lastUpdated: Date
        public let metadata: [String: Any]
        
        public init(
            id: String,
            source: String,
            category: AnomalyCategory,
            metric: String,
            normalRange: ValueRange,
            confidence: Double,
            sampleSize: Int,
            lastUpdated: Date = Date(),
            metadata: [String: Any] = [:]
        ) {
            self.id = id
            self.source = source
            self.category = category
            self.metric = metric
            self.normalRange = normalRange
            self.confidence = confidence
            self.sampleSize = sampleSize
            self.lastUpdated = lastUpdated
            self.metadata = metadata
        }
    }
    
    // MARK: - Analysis Result
    
    public struct AnalysisResult {
        public let isAnomaly: Bool
        public let confidence: Double
        public let severity: SeverityLevel
        public let description: String
        public let suggestedActions: [String]
        public let metadata: [String: Any]
        
        public let processed: Bool
        public let analysisID: UUID
        public let anomalyScore: Double
        public let anomalyDetected: Bool
        public let triggeredRules: [String]
        
        public init(
            isAnomaly: Bool,
            confidence: Double,
            severity: SeverityLevel,
            description: String,
            suggestedActions: [String] = [],
            metadata: [String: Any] = [:]
        ) {
            self.isAnomaly = isAnomaly
            self.confidence = confidence
            self.severity = severity
            self.description = description
            self.suggestedActions = suggestedActions
            self.metadata = metadata
            self.processed = true
            self.analysisID = UUID()
            self.anomalyScore = confidence
            self.anomalyDetected = isAnomaly
            self.triggeredRules = isAnomaly ? ["rule-triggered"] : []
        }
        
        public init(
            isAnomaly: Bool,
            confidence: Double,
            severity: SeverityLevel,
            description: String,
            suggestedActions: [String] = [],
            metadata: [String: Any] = [:],
            triggeredRules: [String] = []
        ) {
            self.isAnomaly = isAnomaly
            self.confidence = confidence
            self.severity = severity
            self.description = description
            self.suggestedActions = suggestedActions
            self.metadata = metadata
            self.processed = true
            self.analysisID = UUID()
            self.anomalyScore = confidence
            self.anomalyDetected = isAnomaly
            self.triggeredRules = triggeredRules
        }
    }
    
    // MARK: - Learning Result
    
    public struct LearningResult {
        public let success: Bool
        public let patternID: String?
        public let message: String
        public let confidence: Double?
        
        public init(success: Bool, patternID: String? = nil, message: String, confidence: Double? = nil) {
            self.success = success
            self.patternID = patternID
            self.message = message
            self.confidence = confidence
        }
    }
    
    // MARK: - Detection Statistics
    
    public struct DetectionStatistics {
        public let totalDataPointsAnalyzed: Int
        public let anomaliesDetected: Int
        public let falsePositives: Int
        public let truePositives: Int
        public let patternsLearned: Int
        public let averageAnalysisTimeMs: Double
        public let averageConfidence: Double
        public let lastAnalysisTime: Date?
        
        public let totalAnalyses: Int
        public let averageProcessingTime: Double
        public let activeRules: Int
        public let learnedPatterns: Int
        
        public init(
            totalDataPointsAnalyzed: Int = 0,
            anomaliesDetected: Int = 0,
            falsePositives: Int = 0,
            truePositives: Int = 0,
            patternsLearned: Int = 0,
            averageAnalysisTimeMs: Double = 0,
            averageConfidence: Double = 0,
            lastAnalysisTime: Date? = nil
        ) {
            self.totalDataPointsAnalyzed = totalDataPointsAnalyzed
            self.anomaliesDetected = anomaliesDetected
            self.falsePositives = falsePositives
            self.truePositives = truePositives
            self.patternsLearned = patternsLearned
            self.averageAnalysisTimeMs = averageAnalysisTimeMs
            self.averageConfidence = averageConfidence
            self.lastAnalysisTime = lastAnalysisTime
            self.totalAnalyses = totalDataPointsAnalyzed
            self.averageProcessingTime = averageAnalysisTimeMs
            self.activeRules = 0
            self.learnedPatterns = patternsLearned
        }
        
        public init(
            totalDataPointsAnalyzed: Int = 0,
            anomaliesDetected: Int = 0,
            falsePositives: Int = 0,
            truePositives: Int = 0,
            patternsLearned: Int = 0,
            averageAnalysisTimeMs: Double = 0,
            averageConfidence: Double = 0,
            lastAnalysisTime: Date? = nil,
            activeRules: Int = 0
        ) {
            self.totalDataPointsAnalyzed = totalDataPointsAnalyzed
            self.anomaliesDetected = anomaliesDetected
            self.falsePositives = falsePositives
            self.truePositives = truePositives
            self.patternsLearned = patternsLearned
            self.averageAnalysisTimeMs = averageAnalysisTimeMs
            self.averageConfidence = averageConfidence
            self.lastAnalysisTime = lastAnalysisTime
            self.totalAnalyses = totalDataPointsAnalyzed
            self.averageProcessingTime = averageAnalysisTimeMs
            self.activeRules = activeRules
            self.learnedPatterns = patternsLearned
        }
    }
    
    // MARK: - Detection Error
    
    public enum DetectionError: Error, LocalizedError {
        case configurationError(String)
        case baselineNotFound(String)
        case analysisError(String)
        case storageError(String)
        case invalidData(String)
        case duplicateRule(String)
        case ruleNotFound(String)
        
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
            case .duplicateRule(let detail):
                return "Duplicate rule error: \(detail)"
            case .ruleNotFound(let detail):
                return "Rule not found: \(detail)"
            }
        }
    }
}

// Type aliases for backward compatibility
public typealias AnomalyResult = AnomalyDetectionTypes.AnomalyResult
public typealias BehavioralBaseline = AnomalyDetectionTypes.BehavioralBaseline
public typealias DetectionRule = AnomalyDetectionTypes.DetectionRule
public typealias DetectionConfiguration = AnomalyDetectionTypes.DetectionConfiguration
public typealias DataPoint = AnomalyDetectionTypes.DataPoint
public typealias AnomalyCategory = AnomalyDetectionTypes.AnomalyCategory
public typealias SeverityLevel = AnomalyDetectionTypes.SeverityLevel
public typealias ActionType = AnomalyDetectionTypes.ActionType
public typealias ValueRange = AnomalyDetectionTypes.ValueRange
public typealias BaselinePattern = AnomalyDetectionTypes.BaselinePattern
public typealias AnalysisResult = AnomalyDetectionTypes.AnalysisResult
public typealias LearningResult = AnomalyDetectionTypes.LearningResult
public typealias DetectionStatistics = AnomalyDetectionTypes.DetectionStatistics
public typealias DetectionError = AnomalyDetectionTypes.DetectionError
