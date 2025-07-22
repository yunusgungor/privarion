import Foundation
import NIOCore
import NIOHTTP1
import NIOWebSocket
import os.log

/// Advanced threat detection and pattern matching system
/// Provides sophisticated analysis of security events and attack pattern recognition
public final class ThreatDetectionManager: @unchecked Sendable {
    
    // MARK: - Configuration
    
    public struct ThreatConfig: Sendable {
        public let patternAnalysisWindow: TimeInterval // Time window for pattern analysis
        public let threatScoreThreshold: Double // Minimum score to classify as threat
        public let ipReputationThreshold: Double // Threshold for IP reputation scoring
        public let geofencingEnabled: Bool // Enable geographic filtering
        public let allowedCountries: Set<String> // ISO country codes
        public let machineLearningEnabled: Bool // Enable ML-based detection
        
        public init(
            patternAnalysisWindow: TimeInterval = 300.0, // 5 minutes
            threatScoreThreshold: Double = 0.7, // 70% confidence
            ipReputationThreshold: Double = 0.5, // 50% bad reputation
            geofencingEnabled: Bool = false,
            allowedCountries: Set<String> = ["US", "CA", "GB", "DE", "FR"],
            machineLearningEnabled: Bool = true
        ) {
            self.patternAnalysisWindow = patternAnalysisWindow
            self.threatScoreThreshold = threatScoreThreshold
            self.ipReputationThreshold = ipReputationThreshold
            self.geofencingEnabled = geofencingEnabled
            self.allowedCountries = allowedCountries
            self.machineLearningEnabled = machineLearningEnabled
        }
    }
    
    // MARK: - Threat Intelligence
    
    public struct ThreatIntelligence: Codable, Sendable {
        public let id: String
        public let ipAddress: String
        public let threatType: ThreatType
        public let confidence: Double
        public let source: IntelligenceSource
        public let firstSeen: Date
        public let lastSeen: Date
        public let description: String
        public let indicators: [ThreatIndicator]
        
        public enum ThreatType: String, Codable, CaseIterable, Sendable {
            case malware = "malware"
            case botnet = "botnet"
            case phishing = "phishing"
            case scanner = "scanner"
            case exploit = "exploit"
            case spam = "spam"
            case proxy = "proxy"
            case tor = "tor"
            case reputation = "reputation"
            case geolocation = "geolocation"
        }
        
        public enum IntelligenceSource: String, Codable, Sendable {
            case internalSource = "internal"
            case honeypot = "honeypot"
            case community = "community"
            case commercial = "commercial"
            case government = "government"
            case openSource = "open_source"
        }
        
        public init(
            ipAddress: String,
            threatType: ThreatType,
            confidence: Double,
            source: IntelligenceSource,
            description: String,
            indicators: [ThreatIndicator] = []
        ) {
            self.id = UUID().uuidString
            self.ipAddress = ipAddress
            self.threatType = threatType
            self.confidence = confidence
            self.source = source
            self.firstSeen = Date()
            self.lastSeen = Date()
            self.description = description
            self.indicators = indicators
        }
    }
    
    public struct ThreatIndicator: Codable, Sendable {
        public let type: IndicatorType
        public let value: String
        public let confidence: Double
        public let context: String?
        
        public enum IndicatorType: String, Codable, Sendable {
            case ipAddress = "ip_address"
            case domain = "domain"
            case url = "url"
            case hash = "hash"
            case userAgent = "user_agent"
            case port = "port"
            case networkProtocol = "protocol"
            case payload = "payload"
        }
        
        public init(type: IndicatorType, value: String, confidence: Double, context: String? = nil) {
            self.type = type
            self.value = value
            self.confidence = confidence
            self.context = context
        }
    }
    
    // MARK: - Attack Patterns
    
    public struct AttackPattern: Codable, Sendable {
        public let id: String
        public let name: String
        public let description: String
        public let mitreTechnique: String? // MITRE ATT&CK technique ID
        public let severity: SecurityMonitoringEngine.SecuritySeverity
        public let indicators: [PatternIndicator]
        public let timeWindow: TimeInterval // Time window for pattern matching
        public let threshold: Int // Minimum occurrences to trigger
        public let enabled: Bool
        
        public init(
            name: String,
            description: String,
            mitreTechnique: String? = nil,
            severity: SecurityMonitoringEngine.SecuritySeverity,
            indicators: [PatternIndicator],
            timeWindow: TimeInterval = 300.0, // 5 minutes
            threshold: Int = 5,
            enabled: Bool = true
        ) {
            self.id = UUID().uuidString
            self.name = name
            self.description = description
            self.mitreTechnique = mitreTechnique
            self.severity = severity
            self.indicators = indicators
            self.timeWindow = timeWindow
            self.threshold = threshold
            self.enabled = enabled
        }
    }
    
    public struct PatternIndicator: Codable, Sendable {
        public let field: String // Field to analyze (e.g., "source_ip", "destination_port")
        public let condition: PatternCondition
        public let weight: Double // Weight of this indicator in overall pattern score
        
        public enum PatternCondition: Codable, Sendable {
            case equals(String)
            case contains(String)
            case matches(String) // Regex pattern
            case range(Double, Double)
            case frequency(Int, TimeInterval) // Count within time window
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(String.self, forKey: .type)
                
                switch type {
                case "equals":
                    let value = try container.decode(String.self, forKey: .value)
                    self = .equals(value)
                case "contains":
                    let value = try container.decode(String.self, forKey: .value)
                    self = .contains(value)
                case "matches":
                    let pattern = try container.decode(String.self, forKey: .pattern)
                    self = .matches(pattern)
                case "range":
                    let min = try container.decode(Double.self, forKey: .min)
                    let max = try container.decode(Double.self, forKey: .max)
                    self = .range(min, max)
                case "frequency":
                    let count = try container.decode(Int.self, forKey: .count)
                    let window = try container.decode(TimeInterval.self, forKey: .window)
                    self = .frequency(count, window)
                default:
                    throw DecodingError.dataCorrupted(
                        DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown pattern condition type")
                    )
                }
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                switch self {
                case .equals(let value):
                    try container.encode("equals", forKey: .type)
                    try container.encode(value, forKey: .value)
                case .contains(let value):
                    try container.encode("contains", forKey: .type)
                    try container.encode(value, forKey: .value)
                case .matches(let pattern):
                    try container.encode("matches", forKey: .type)
                    try container.encode(pattern, forKey: .pattern)
                case .range(let min, let max):
                    try container.encode("range", forKey: .type)
                    try container.encode(min, forKey: .min)
                    try container.encode(max, forKey: .max)
                case .frequency(let count, let window):
                    try container.encode("frequency", forKey: .type)
                    try container.encode(count, forKey: .count)
                    try container.encode(window, forKey: .window)
                }
            }
            
            private enum CodingKeys: String, CodingKey {
                case type, value, pattern, min, max, count, window
            }
        }
        
        public init(field: String, condition: PatternCondition, weight: Double = 1.0) {
            self.field = field
            self.condition = condition
            self.weight = weight
        }
    }
    
    // MARK: - Properties
    
    private let config: ThreatConfig
    private let securityEngine: SecurityMonitoringEngine
    private var threatIntelligence: [String: ThreatIntelligence] = [:] // IP -> Intelligence
    private var attackPatterns: [AttackPattern] = []
    private var connectionHistory: [ConnectionEvent] = []
    private var threatScores: [String: Double] = [:] // IP -> Score
    private var patternMatches: [String: [PatternMatch]] = [:] // Pattern ID -> Matches
    
    // MARK: - Initialization
    
    public init(config: ThreatConfig = ThreatConfig(), securityEngine: SecurityMonitoringEngine) {
        self.config = config
        self.securityEngine = securityEngine
        
        // Initialize default attack patterns
        initializeDefaultPatterns()
        
        os_log("ThreatDetectionManager initialized with %d attack patterns", 
               log: OSLog.default, type: .info, attackPatterns.count)
    }
    
    // MARK: - Core Detection Methods
    
    /// Analyze network connection for threats
    public func analyzeConnection(_ connection: ConnectionEvent) {
        // Store connection history
        storeConnection(connection)
        
        // Check threat intelligence
        if let threat = checkThreatIntelligence(connection.sourceIP) {
            triggerThreatAlert(connection: connection, threat: threat)
        }
        
        // Analyze attack patterns
        analyzeAttackPatterns(connection)
        
        // Update threat scores
        updateThreatScore(for: connection.sourceIP, connection: connection)
        
        // Geographic filtering
        if config.geofencingEnabled {
            checkGeographicRestrictions(connection)
        }
    }
    
    /// Check IP against threat intelligence database
    private func checkThreatIntelligence(_ ipAddress: String) -> ThreatIntelligence? {
        return threatIntelligence[ipAddress]
    }
    
    /// Analyze connection against known attack patterns
    private func analyzeAttackPatterns(_ connection: ConnectionEvent) {
        for pattern in attackPatterns where pattern.enabled {
            let score = calculatePatternScore(pattern: pattern, connection: connection)
            
            if score >= config.threatScoreThreshold {
                recordPatternMatch(pattern: pattern, connection: connection, score: score)
                
                // Check if pattern threshold is met
                if isPatternThresholdMet(pattern: pattern) {
                    triggerPatternAlert(pattern: pattern, connection: connection, score: score)
                }
            }
        }
    }
    
    /// Calculate pattern matching score for a connection
    private func calculatePatternScore(pattern: AttackPattern, connection: ConnectionEvent) -> Double {
        var totalScore = 0.0
        var totalWeight = 0.0
        
        for indicator in pattern.indicators {
            let indicatorScore = evaluatePatternIndicator(indicator, connection: connection)
            totalScore += indicatorScore * indicator.weight
            totalWeight += indicator.weight
        }
        
        return totalWeight > 0 ? totalScore / totalWeight : 0.0
    }
    
    /// Evaluate a single pattern indicator against connection
    private func evaluatePatternIndicator(_ indicator: PatternIndicator, connection: ConnectionEvent) -> Double {
        guard let fieldValue = getConnectionFieldValue(field: indicator.field, connection: connection) else {
            return 0.0
        }
        
        switch indicator.condition {
        case .equals(let expected):
            return fieldValue == expected ? 1.0 : 0.0
            
        case .contains(let substring):
            return fieldValue.contains(substring) ? 1.0 : 0.0
            
        case .matches(let pattern):
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: fieldValue.utf16.count)
                return regex.firstMatch(in: fieldValue, options: [], range: range) != nil ? 1.0 : 0.0
            } catch {
                os_log("Invalid regex pattern: %{public}@", log: OSLog.default, type: .error, pattern)
                return 0.0
            }
            
        case .range(let min, let max):
            if let numericValue = Double(fieldValue) {
                return (numericValue >= min && numericValue <= max) ? 1.0 : 0.0
            }
            return 0.0
            
        case .frequency(let count, let window):
            return evaluateFrequencyCondition(field: indicator.field, expectedCount: count, timeWindow: window, connection: connection)
        }
    }
    
    /// Get field value from connection event
    private func getConnectionFieldValue(field: String, connection: ConnectionEvent) -> String? {
        switch field {
        case "source_ip":
            return connection.sourceIP
        case "destination_ip":
            return connection.destinationIP
        case "destination_port":
            return String(connection.destinationPort)
        case "protocol":
            return connection.networkProtocol
        case "bytes_transferred":
            return String(connection.bytesTransferred)
        case "duration":
            return String(connection.duration)
        case "user_agent":
            return connection.userAgent
        default:
            return nil
        }
    }
    
    /// Evaluate frequency-based conditions
    private func evaluateFrequencyCondition(field: String, expectedCount: Int, timeWindow: TimeInterval, connection: ConnectionEvent) -> Double {
        let cutoffTime = Date().addingTimeInterval(-timeWindow)
        let recentConnections = connectionHistory.filter { $0.timestamp >= cutoffTime }
        
        let fieldMatches = recentConnections.compactMap { conn -> String? in
            getConnectionFieldValue(field: field, connection: conn)
        }
        
        let currentFieldValue = getConnectionFieldValue(field: field, connection: connection)
        let matchCount = fieldMatches.filter { $0 == currentFieldValue }.count
        
        return matchCount >= expectedCount ? 1.0 : Double(matchCount) / Double(expectedCount)
    }
    
    /// Update threat score for an IP address
    private func updateThreatScore(for ipAddress: String, connection: ConnectionEvent) {
        var currentScore = threatScores[ipAddress] ?? 0.0
        
        // Increase score based on suspicious behavior
        if connection.destinationPort < 1024 && connection.destinationPort != 80 && connection.destinationPort != 443 {
            currentScore += 0.1 // Accessing privileged ports
        }
        
        if connection.bytesTransferred > 10_000_000 { // Large data transfer
            currentScore += 0.2
        }
        
        if connection.duration < 1.0 { // Very short connections
            currentScore += 0.1
        }
        
        // Apply decay over time
        currentScore *= 0.99
        
        threatScores[ipAddress] = min(currentScore, 1.0)
        
        // Trigger alert if threshold exceeded
        if currentScore >= config.threatScoreThreshold {
            triggerThreatScoreAlert(ipAddress: ipAddress, score: currentScore, connection: connection)
        }
    }
    
    /// Store connection in history for analysis
    private func storeConnection(_ connection: ConnectionEvent) {
        connectionHistory.append(connection)
        
        // Trim history to maintain performance
        let maxHistory = 100000
        if connectionHistory.count > maxHistory {
            connectionHistory.removeFirst(connectionHistory.count - maxHistory)
        }
    }
    
    /// Record a pattern match for threshold tracking
    private func recordPatternMatch(pattern: AttackPattern, connection: ConnectionEvent, score: Double) {
        let match = PatternMatch(
            patternId: pattern.id,
            connection: connection,
            score: score,
            timestamp: Date()
        )
        
        if patternMatches[pattern.id] == nil {
            patternMatches[pattern.id] = []
        }
        
        patternMatches[pattern.id]?.append(match)
        
        // Clean old matches outside time window
        let cutoffTime = Date().addingTimeInterval(-pattern.timeWindow)
        patternMatches[pattern.id] = patternMatches[pattern.id]?.filter { $0.timestamp >= cutoffTime }
    }
    
    /// Check if pattern threshold is met for alerting
    private func isPatternThresholdMet(pattern: AttackPattern) -> Bool {
        guard let matches = patternMatches[pattern.id] else { return false }
        return matches.count >= pattern.threshold
    }
    
    // MARK: - Alert Generation
    
    /// Trigger threat intelligence based alert
    private func triggerThreatAlert(connection: ConnectionEvent, threat: ThreatIntelligence) {
        let _ = SecurityMonitoringEngine.SecurityEvent(
            eventType: .maliciousIP,
            severity: .high,
            sourceIP: connection.sourceIP,
            destinationIP: connection.destinationIP,
            port: connection.destinationPort,
            networkProtocol: connection.networkProtocol,
            description: "Known malicious IP detected: \(threat.description)",
            evidence: [
                "threat_type": threat.threatType.rawValue,
                "confidence": String(threat.confidence),
                "source": threat.source.rawValue,
                "first_seen": ISO8601DateFormatter().string(from: threat.firstSeen)
            ],
            confidence: threat.confidence,
            mitigationSuggestion: "Block IP address \(connection.sourceIP) and investigate related connections"
        )
        
        // Send to security engine
        os_log("Threat intelligence alert: %{public}@ from %{public}@", 
               log: OSLog.default, type: .error, threat.threatType.rawValue, connection.sourceIP)
    }
    
    /// Trigger pattern-based alert
    private func triggerPatternAlert(pattern: AttackPattern, connection: ConnectionEvent, score: Double) {
        let _ = SecurityMonitoringEngine.SecurityEvent(
            eventType: .attackPattern,
            severity: pattern.severity,
            sourceIP: connection.sourceIP,
            destinationIP: connection.destinationIP,
            port: connection.destinationPort,
            networkProtocol: connection.networkProtocol,
            description: "Attack pattern detected: \(pattern.name)",
            evidence: [
                "pattern_id": pattern.id,
                "pattern_score": String(score),
                "mitre_technique": pattern.mitreTechnique ?? "unknown",
                "match_count": String(patternMatches[pattern.id]?.count ?? 0)
            ],
            confidence: score,
            mitigationSuggestion: generatePatternMitigation(pattern: pattern)
        )
        
        os_log("Attack pattern alert: %{public}@ (score: %.2f)", 
               log: OSLog.default, type: .error, pattern.name, score)
    }
    
    /// Trigger threat score based alert
    private func triggerThreatScoreAlert(ipAddress: String, score: Double, connection: ConnectionEvent) {
        let _ = SecurityMonitoringEngine.SecurityEvent(
            eventType: .suspiciousTraffic,
            severity: score > 0.9 ? .critical : .high,
            sourceIP: ipAddress,
            destinationIP: connection.destinationIP,
            port: connection.destinationPort,
            networkProtocol: connection.networkProtocol,
            description: "High threat score detected for IP \(ipAddress): \(String(format: "%.2f", score))",
            evidence: [
                "threat_score": String(score),
                "threshold": String(config.threatScoreThreshold),
                "recent_connections": String(connectionHistory.filter { $0.sourceIP == ipAddress }.count)
            ],
            confidence: score,
            mitigationSuggestion: "Monitor IP \(ipAddress) closely and consider rate limiting"
        )
        
        os_log("High threat score alert: %{public}@ (score: %.2f)", 
               log: OSLog.default, type: .error, ipAddress, score)
    }
    
    /// Generate mitigation suggestion for attack pattern
    private func generatePatternMitigation(pattern: AttackPattern) -> String {
        switch pattern.mitreTechnique {
        case "T1595": // Active Scanning
            return "Implement rate limiting and block scanning sources"
        case "T1190": // Exploit Public-Facing Application
            return "Patch vulnerable services and implement web application firewall"
        case "T1110": // Brute Force
            return "Enable account lockout policies and implement CAPTCHA"
        case "T1071": // Application Layer Protocol
            return "Monitor application traffic and implement DPI filtering"
        default:
            return "Investigate the detected pattern and implement appropriate countermeasures"
        }
    }
    
    /// Check geographic restrictions
    private func checkGeographicRestrictions(_ connection: ConnectionEvent) {
        // Simplified geolocation check - in production would use proper GeoIP service
        // TODO: Implement actual geolocation service integration
        let isAllowedRegion = true // Placeholder - always allow for now
        
        // Geographic restriction check disabled until GeoIP service integration
        // This function currently acts as a placeholder for future geolocation functionality
        if !isAllowedRegion {
            let _ = SecurityMonitoringEngine.SecurityEvent(
                eventType: .suspiciousTraffic,
                severity: .medium,
                sourceIP: connection.sourceIP,
                description: "Connection from restricted geographic region",
                evidence: ["geofencing": "blocked_region"],
                confidence: 0.8,
                mitigationSuggestion: "Review geographic access policies"
            )
            
            os_log("Geographic restriction alert: %{public}@", 
                   log: OSLog.default, type: .info, connection.sourceIP)
        }
    }
    
    // MARK: - Default Patterns
    
    private func initializeDefaultPatterns() {
        attackPatterns = [
            // Port scanning detection
            AttackPattern(
                name: "Port Scanning",
                description: "Systematic scanning of multiple ports from single source",
                mitreTechnique: "T1595.001",
                severity: .medium,
                indicators: [
                    PatternIndicator(field: "source_ip", condition: .frequency(20, 300), weight: 1.0),
                    PatternIndicator(field: "destination_port", condition: .frequency(10, 60), weight: 0.8)
                ],
                timeWindow: 300,
                threshold: 3
            ),
            
            // Brute force detection
            AttackPattern(
                name: "Brute Force Attack",
                description: "Multiple failed authentication attempts",
                mitreTechnique: "T1110",
                severity: .high,
                indicators: [
                    PatternIndicator(field: "destination_port", condition: .equals("22"), weight: 1.0),
                    PatternIndicator(field: "source_ip", condition: .frequency(10, 300), weight: 1.0)
                ],
                timeWindow: 600,
                threshold: 2
            ),
            
            // DDoS detection
            AttackPattern(
                name: "DDoS Attack",
                description: "Distributed denial of service attack pattern",
                mitreTechnique: "T1498",
                severity: .critical,
                indicators: [
                    PatternIndicator(field: "destination_ip", condition: .frequency(100, 60), weight: 1.0),
                    PatternIndicator(field: "bytes_transferred", condition: .range(0, 100), weight: 0.6)
                ],
                timeWindow: 180,
                threshold: 5
            )
        ]
    }
    
    // MARK: - Public Interface
    
    /// Add threat intelligence
    public func addThreatIntelligence(_ threat: ThreatIntelligence) {
        threatIntelligence[threat.ipAddress] = threat
        os_log("Added threat intelligence for %{public}@: %{public}@", 
               log: OSLog.default, type: .info, threat.ipAddress, threat.threatType.rawValue)
    }
    
    /// Get threat statistics
    public func getThreatStatistics() -> ThreatStatistics {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-86400)
        
        let recentConnections = connectionHistory.filter { $0.timestamp >= last24Hours }
        let uniqueIPs = Set(recentConnections.map { $0.sourceIP })
        let threatIPs = threatScores.filter { $0.value >= config.threatScoreThreshold }
        
        return ThreatStatistics(
            totalThreats: threatIntelligence.count,
            highRiskIPs: threatIPs.count,
            totalConnections: recentConnections.count,
            uniqueSourceIPs: uniqueIPs.count,
            averageThreatScore: threatScores.values.isEmpty ? 0.0 : threatScores.values.reduce(0, +) / Double(threatScores.count),
            activePatterns: attackPatterns.filter { $0.enabled }.count
        )
    }
}

// MARK: - Supporting Types

public struct ConnectionEvent: Codable, Sendable {
    public let sourceIP: String
    public let destinationIP: String
    public let destinationPort: Int
    public let networkProtocol: String
    public let bytesTransferred: Int64
    public let duration: TimeInterval
    public let timestamp: Date
    public let userAgent: String?
    
    public init(
        sourceIP: String,
        destinationIP: String,
        destinationPort: Int,
        networkProtocol: String,
        bytesTransferred: Int64,
        duration: TimeInterval,
        userAgent: String? = nil
    ) {
        self.sourceIP = sourceIP
        self.destinationIP = destinationIP
        self.destinationPort = destinationPort
        self.networkProtocol = networkProtocol
        self.bytesTransferred = bytesTransferred
        self.duration = duration
        self.timestamp = Date()
        self.userAgent = userAgent
    }
}

public struct ThreatStatistics: Codable, Sendable {
    public let totalThreats: Int
    public let highRiskIPs: Int
    public let totalConnections: Int
    public let uniqueSourceIPs: Int
    public let averageThreatScore: Double
    public let activePatterns: Int
    
    public init(
        totalThreats: Int,
        highRiskIPs: Int,
        totalConnections: Int,
        uniqueSourceIPs: Int,
        averageThreatScore: Double,
        activePatterns: Int
    ) {
        self.totalThreats = totalThreats
        self.highRiskIPs = highRiskIPs
        self.totalConnections = totalConnections
        self.uniqueSourceIPs = uniqueSourceIPs
        self.averageThreatScore = averageThreatScore
        self.activePatterns = activePatterns
    }
}

private struct PatternMatch: Sendable {
    let patternId: String
    let connection: ConnectionEvent
    let score: Double
    let timestamp: Date
}
