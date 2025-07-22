import Foundation
import NIOCore
import NIOHTTP1
import NIOWebSocket
import os.log

/// Enterprise-grade security monitoring engine
/// Provides real-time threat detection, anomaly analysis, and security event management
public final class SecurityMonitoringEngine: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public struct SecurityConfig: Sendable {
        public let anomalyThreshold: Double // Z-score threshold for statistical anomalies
        public let maxEventHistory: Int // Maximum security events to retain
        public let threatDetectionInterval: TimeInterval // Interval for threat analysis
        public let alertRateLimit: TimeInterval // Minimum time between same alerts
        public let severityLevels: [SecuritySeverity] // Enabled severity levels
        
        public init(
            anomalyThreshold: Double = 3.0, // 3 standard deviations
            maxEventHistory: Int = 10000,
            threatDetectionInterval: TimeInterval = 1.0, // 1 second
            alertRateLimit: TimeInterval = 30.0, // 30 seconds
            severityLevels: [SecuritySeverity] = SecuritySeverity.allCases
        ) {
            self.anomalyThreshold = anomalyThreshold
            self.maxEventHistory = maxEventHistory
            self.threatDetectionInterval = threatDetectionInterval
            self.alertRateLimit = alertRateLimit
            self.severityLevels = severityLevels
        }
    }
    
    // MARK: - Security Event Types
    
    public enum SecuritySeverity: String, Codable, CaseIterable, Sendable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case critical = "critical"
        case emergency = "emergency"
        
        public var priority: Int {
            switch self {
            case .low: return 1
            case .medium: return 2
            case .high: return 3
            case .critical: return 4
            case .emergency: return 5
            }
        }
        
        public var color: String {
            switch self {
            case .low: return "#28a745"      // Green
            case .medium: return "#ffc107"   // Yellow
            case .high: return "#fd7e14"     // Orange
            case .critical: return "#dc3545" // Red
            case .emergency: return "#6f42c1" // Purple
            }
        }
    }
    
    public enum SecurityEventType: String, Codable, CaseIterable, Sendable {
        case suspiciousTraffic = "suspicious_traffic"
        case anomalousConnection = "anomalous_connection"
        case threatDetected = "threat_detected"
        case attackPattern = "attack_pattern"
        case dataExfiltration = "data_exfiltration"
        case maliciousIP = "malicious_ip"
        case portScan = "port_scan"
        case bruteForce = "brute_force"
        case dnsTunneling = "dns_tunneling"
        case commandAndControl = "command_and_control"
        
        public var description: String {
            switch self {
            case .suspiciousTraffic: return "Suspicious Network Traffic"
            case .anomalousConnection: return "Anomalous Connection Detected"
            case .threatDetected: return "Security Threat Detected"
            case .attackPattern: return "Attack Pattern Identified"
            case .dataExfiltration: return "Potential Data Exfiltration"
            case .maliciousIP: return "Malicious IP Address"
            case .portScan: return "Port Scanning Activity"
            case .bruteForce: return "Brute Force Attack"
            case .dnsTunneling: return "DNS Tunneling Detected"
            case .commandAndControl: return "C2 Communication"
            }
        }
    }
    
    public struct SecurityEvent: Codable, Sendable {
        public let id: String
        public let eventType: SecurityEventType
        public let severity: SecuritySeverity
        public let timestamp: Date
        public let sourceIP: String?
        public let destinationIP: String?
        public let port: Int?
        public let networkProtocol: String?
        public let description: String
        public let evidence: [String: String] // Key-value pairs of supporting evidence
        public let confidence: Double // Confidence score 0.0-1.0
        public let mitigationSuggestion: String?
        
        public init(
            eventType: SecurityEventType,
            severity: SecuritySeverity,
            sourceIP: String? = nil,
            destinationIP: String? = nil,
            port: Int? = nil,
            networkProtocol: String? = nil,
            description: String,
            evidence: [String: String] = [:],
            confidence: Double = 1.0,
            mitigationSuggestion: String? = nil
        ) {
            self.id = UUID().uuidString
            self.eventType = eventType
            self.severity = severity
            self.timestamp = Date()
            self.sourceIP = sourceIP
            self.destinationIP = destinationIP
            self.port = port
            self.networkProtocol = networkProtocol
            self.description = description
            self.evidence = evidence
            self.confidence = confidence
            self.mitigationSuggestion = mitigationSuggestion
        }
    }
    
    // MARK: - Detection Rules
    
    public struct DetectionRule: Codable, Sendable {
        public let id: String
        public let name: String
        public let eventType: SecurityEventType
        public let severity: SecuritySeverity
        public let enabled: Bool
        public let conditions: [DetectionCondition]
        public let description: String
        
        public init(
            name: String,
            eventType: SecurityEventType,
            severity: SecuritySeverity,
            enabled: Bool = true,
            conditions: [DetectionCondition],
            description: String
        ) {
            self.id = UUID().uuidString
            self.name = name
            self.eventType = eventType
            self.severity = severity
            self.enabled = enabled
            self.conditions = conditions
            self.description = description
        }
    }
    
    public struct DetectionCondition: Codable, Sendable {
        public let field: String // e.g., "connections_per_minute", "bytes_transferred"
        public let comparisonOperator: ComparisonOperator
        public let threshold: Double
        public let timeWindow: TimeInterval? // For time-based conditions
        
        public enum ComparisonOperator: String, Codable, Sendable {
            case greaterThan = ">"
            case lessThan = "<"
            case equals = "=="
            case greaterThanOrEqual = ">="
            case lessThanOrEqual = "<="
            case notEquals = "!="
        }
        
        public init(field: String, operator: ComparisonOperator, threshold: Double, timeWindow: TimeInterval? = nil) {
            self.field = field
            self.comparisonOperator = `operator`
            self.threshold = threshold
            self.timeWindow = timeWindow
        }
    }
    
    // MARK: - Properties
    
    private let config: SecurityConfig
    private var securityEvents: [SecurityEvent] = []
    private var detectionRules: [DetectionRule] = []
    private var lastAlertTimes: [String: Date] = [:]
    private var metricHistory: [String: [MetricDataPoint]] = [:]
    private var activeThreats: Set<String> = []
    
    // MARK: - Initialization
    
    public init(config: SecurityConfig = SecurityConfig()) {
        self.config = config
        
        // Initialize default detection rules
        initializeDefaultRules()
        
        os_log("SecurityMonitoringEngine initialized with %d detection rules", 
               log: OSLog.default, type: .info, detectionRules.count)
    }
    
    // MARK: - Core Detection Methods
    
    /// Process network metrics for security analysis
    public func processNetworkMetrics(_ metrics: [String: Double]) {
        // Store metrics for historical analysis
        storeMetricData(metrics)
        
        // Run detection rules
        for rule in detectionRules where rule.enabled {
            checkDetectionRule(rule, against: metrics)
        }
        
        // Perform anomaly detection
        performAnomalyDetection(metrics)
    }
    
    /// Check a specific detection rule against current metrics
    private func checkDetectionRule(_ rule: DetectionRule, against metrics: [String: Double]) {
        var conditionsMet = 0
        
        for condition in rule.conditions {
            guard let value = metrics[condition.field] else { continue }
            
            let isConditionMet = evaluateCondition(condition, value: value)
            if isConditionMet {
                conditionsMet += 1
            }
        }
        
        // If all conditions are met, trigger security event
        if conditionsMet == rule.conditions.count {
            triggerSecurityEvent(for: rule, evidence: formatEvidence(rule.conditions, metrics: metrics))
        }
    }
    
    /// Evaluate a single detection condition
    private func evaluateCondition(_ condition: DetectionCondition, value: Double) -> Bool {
        switch condition.comparisonOperator {
        case .greaterThan:
            return value > condition.threshold
        case .lessThan:
            return value < condition.threshold
        case .equals:
            return abs(value - condition.threshold) < 0.001 // Float comparison
        case .greaterThanOrEqual:
            return value >= condition.threshold
        case .lessThanOrEqual:
            return value <= condition.threshold
        case .notEquals:
            return abs(value - condition.threshold) >= 0.001
        }
    }
    
    /// Perform statistical anomaly detection using Z-score analysis
    private func performAnomalyDetection(_ metrics: [String: Double]) {
        for (metricName, currentValue) in metrics {
            guard let history = metricHistory[metricName],
                  history.count >= 10 else { continue } // Need sufficient history
            
            let values = history.map { $0.value }
            let (mean, stdDev) = calculateStatistics(values)
            
            guard stdDev > 0 else { continue } // Avoid division by zero
            
            let zScore = abs((currentValue - mean) / stdDev)
            
            if zScore > config.anomalyThreshold {
                let severity: SecuritySeverity = zScore > config.anomalyThreshold * 1.5 ? .critical : .high
                
                let event = SecurityEvent(
                    eventType: .anomalousConnection,
                    severity: severity,
                    description: "Statistical anomaly detected in \(metricName): value \(currentValue) (Z-score: \(String(format: "%.2f", zScore)))",
                    evidence: [
                        "metric": metricName,
                        "current_value": String(currentValue),
                        "mean": String(format: "%.2f", mean),
                        "std_dev": String(format: "%.2f", stdDev),
                        "z_score": String(format: "%.2f", zScore)
                    ],
                    confidence: min(1.0, zScore / config.anomalyThreshold),
                    mitigationSuggestion: "Investigate unusual activity patterns for \(metricName)"
                )
                
                addSecurityEvent(event)
            }
        }
    }
    
    /// Store metric data for historical analysis
    private func storeMetricData(_ metrics: [String: Double]) {
        let timestamp = Date()
        
        for (metricName, value) in metrics {
            let dataPoint = MetricDataPoint(timestamp: timestamp, value: value)
            
            if metricHistory[metricName] == nil {
                metricHistory[metricName] = []
            }
            
            metricHistory[metricName]?.append(dataPoint)
            
            // Trim history if needed
            if let count = metricHistory[metricName]?.count, count > config.maxEventHistory {
                metricHistory[metricName]?.removeFirst(count - config.maxEventHistory)
            }
        }
    }
    
    /// Trigger a security event based on detection rule
    private func triggerSecurityEvent(for rule: DetectionRule, evidence: [String: String]) {
        // Check rate limiting
        let ruleKey = rule.id
        if let lastAlert = lastAlertTimes[ruleKey],
           Date().timeIntervalSince(lastAlert) < config.alertRateLimit {
            return
        }
        
        let event = SecurityEvent(
            eventType: rule.eventType,
            severity: rule.severity,
            description: "\(rule.name): \(rule.description)",
            evidence: evidence,
            confidence: 1.0,
            mitigationSuggestion: generateMitigationSuggestion(for: rule.eventType)
        )
        
        addSecurityEvent(event)
        lastAlertTimes[ruleKey] = Date()
    }
    
    /// Add a security event to the system
    private func addSecurityEvent(_ event: SecurityEvent) {
        securityEvents.append(event)
        
        // Trim event history if needed
        if securityEvents.count > config.maxEventHistory {
            securityEvents.removeFirst(securityEvents.count - config.maxEventHistory)
        }
        
        // Track active threats
        activeThreats.insert(event.eventType.rawValue)
        
        os_log("Security event triggered: %{public}@ - %{public}@", 
               log: OSLog.default, type: .error, 
               event.severity.rawValue.uppercased(), event.description)
    }
    
    // MARK: - Statistics and Analysis
    
    /// Calculate mean and standard deviation for a set of values
    private func calculateStatistics(_ values: [Double]) -> (mean: Double, stdDev: Double) {
        guard !values.isEmpty else { return (0.0, 0.0) }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        let stdDev = sqrt(variance)
        
        return (mean, stdDev)
    }
    
    /// Format evidence for security events
    private func formatEvidence(_ conditions: [DetectionCondition], metrics: [String: Double]) -> [String: String] {
        var evidence: [String: String] = [:]
        
        for condition in conditions {
            if let value = metrics[condition.field] {
                evidence[condition.field] = String(value)
                evidence["\(condition.field)_threshold"] = String(condition.threshold)
                evidence["\(condition.field)_operator"] = condition.comparisonOperator.rawValue
            }
        }
        
        return evidence
    }
    
    /// Generate mitigation suggestions based on event type
    private func generateMitigationSuggestion(for eventType: SecurityEventType) -> String {
        switch eventType {
        case .suspiciousTraffic:
            return "Monitor traffic patterns and consider blocking suspicious sources"
        case .anomalousConnection:
            return "Investigate connection source and verify legitimacy"
        case .threatDetected:
            return "Immediately isolate affected systems and conduct forensic analysis"
        case .attackPattern:
            return "Enable additional security measures and monitor for related activities"
        case .dataExfiltration:
            return "Block data transfer and investigate potential data breach"
        case .maliciousIP:
            return "Block IP address and scan for related malicious activity"
        case .portScan:
            return "Block scanning source and review firewall rules"
        case .bruteForce:
            return "Implement rate limiting and account lockout policies"
        case .dnsTunneling:
            return "Monitor DNS queries and block suspicious domains"
        case .commandAndControl:
            return "Block C2 communication and perform malware analysis"
        }
    }
    
    // MARK: - Default Detection Rules
    
    private func initializeDefaultRules() {
        detectionRules = [
            // High connection rate detection
            DetectionRule(
                name: "High Connection Rate",
                eventType: .suspiciousTraffic,
                severity: .medium,
                conditions: [
                    DetectionCondition(field: "connections_per_minute", operator: .greaterThan, threshold: 100)
                ],
                description: "Unusually high connection rate detected"
            ),
            
            // Large data transfer detection
            DetectionRule(
                name: "Large Data Transfer",
                eventType: .dataExfiltration,
                severity: .high,
                conditions: [
                    DetectionCondition(field: "bytes_transferred_per_minute", operator: .greaterThan, threshold: 100_000_000) // 100MB
                ],
                description: "Large volume of data transfer detected"
            ),
            
            // Port scanning detection
            DetectionRule(
                name: "Port Scanning Activity",
                eventType: .portScan,
                severity: .medium,
                conditions: [
                    DetectionCondition(field: "unique_ports_accessed", operator: .greaterThan, threshold: 50),
                    DetectionCondition(field: "connection_failures_per_minute", operator: .greaterThan, threshold: 20)
                ],
                description: "Port scanning activity detected"
            ),
            
            // DNS tunneling detection
            DetectionRule(
                name: "DNS Tunneling",
                eventType: .dnsTunneling,
                severity: .high,
                conditions: [
                    DetectionCondition(field: "dns_queries_per_minute", operator: .greaterThan, threshold: 200),
                    DetectionCondition(field: "average_dns_query_length", operator: .greaterThan, threshold: 50)
                ],
                description: "Potential DNS tunneling activity detected"
            )
        ]
    }
    
    // MARK: - Query Methods
    
    /// Get recent security events
    public func getSecurityEvents(limit: Int = 100, severity: SecuritySeverity? = nil) -> [SecurityEvent] {
        var events = securityEvents
        
        if let severity = severity {
            events = events.filter { $0.severity == severity }
        }
        
        return Array(events.suffix(limit))
    }
    
    /// Get security statistics
    public func getSecurityStatistics() -> SecurityStatistics {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-86400) // 24 hours ago
        
        let recentEvents = securityEvents.filter { $0.timestamp >= last24Hours }
        
        let eventsBySeverity = Dictionary(grouping: recentEvents) { $0.severity }
        let eventsByType = Dictionary(grouping: recentEvents) { $0.eventType }
        
        let totalEvents = securityEvents.count
        let recentEventsCount = recentEvents.count
        let activeThreatsCount = activeThreats.count
        let avgConfidence = recentEvents.isEmpty ? 0.0 : recentEvents.map { $0.confidence }.reduce(0, +) / Double(recentEvents.count)
        
        return SecurityStatistics(
            totalEvents: totalEvents,
            recentEvents: recentEventsCount,
            activeThreats: activeThreatsCount,
            eventsBySeverity: eventsBySeverity.mapValues { $0.count },
            eventsByType: eventsByType.mapValues { $0.count },
            averageConfidence: avgConfidence
        )
    }
    
    /// Get active detection rules
    public func getDetectionRules() -> [DetectionRule] {
        return detectionRules
    }
    
    /// Add or update a detection rule
    public func updateDetectionRule(_ rule: DetectionRule) {
        if let index = detectionRules.firstIndex(where: { $0.id == rule.id }) {
            detectionRules[index] = rule
        } else {
            detectionRules.append(rule)
        }
        
        os_log("Detection rule updated: %{public}@", log: OSLog.default, type: .info, rule.name)
    }
    
    /// Remove a detection rule
    public func removeDetectionRule(id: String) {
        detectionRules.removeAll { $0.id == id }
        os_log("Detection rule removed: %{public}@", log: OSLog.default, type: .info, id)
    }
}

// MARK: - Supporting Types

public struct SecurityStatistics: Codable, Sendable {
    public let totalEvents: Int
    public let recentEvents: Int
    public let activeThreats: Int
    public let eventsBySeverity: [String: Int] // Use String keys for Codable compatibility
    public let eventsByType: [String: Int] // Use String keys for Codable compatibility
    public let averageConfidence: Double
    
    public init(
        totalEvents: Int,
        recentEvents: Int,
        activeThreats: Int,
        eventsBySeverity: [SecurityMonitoringEngine.SecuritySeverity: Int],
        eventsByType: [SecurityMonitoringEngine.SecurityEventType: Int],
        averageConfidence: Double
    ) {
        self.totalEvents = totalEvents
        self.recentEvents = recentEvents
        self.activeThreats = activeThreats
        self.eventsBySeverity = Dictionary(uniqueKeysWithValues: eventsBySeverity.map { ($0.key.rawValue, $0.value) })
        self.eventsByType = Dictionary(uniqueKeysWithValues: eventsByType.map { ($0.key.rawValue, $0.value) })
        self.averageConfidence = averageConfidence
    }
}

private struct MetricDataPoint: Sendable {
    let timestamp: Date
    let value: Double
}
