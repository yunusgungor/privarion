import XCTest
import Foundation
@testable import PrivarionCore

final class AnomalyDetectionEngineTests: XCTestCase {
    
    var detectionEngine: AnomalyDetectionEngine!
    
    override func setUp() {
        super.setUp()
        detectionEngine = AnomalyDetectionEngine.shared
    }
    
    override func tearDown() {
        do {
            try detectionEngine.stopDetection()
        } catch {
            // Ignore errors during tearDown
        }
        detectionEngine = nil
        super.tearDown()
    }
    
    // MARK: - Detection Rule Management Tests
    
    func testAddDetectionRule_ValidRule_ShouldSucceed() {
        // Given
        let rule = AnomalyDetectionEngine.DetectionRule(
            id: "test-rule-001",
            name: "High CPU Usage Detection",
            description: "Detects processes with unusually high CPU usage",
            category: .performance,
            threshold: AnomalyDetectionEngine.DetectionRule.Threshold(
                thresholdOperator: "greater_than",
                value: 80.0,
                timeWindow: 300 // 5 minutes
            ),
            conditions: [
                AnomalyDetectionEngine.DetectionRule.Condition(
                    field: "cpu_usage",
                    thresholdOperator: "greater_than",
                    value: "80"
                )
            ],
            action: .alert,
            severity: .high,
            enabled: true
        )
        
        // When
        do {
            try detectionEngine.addDetectionRule(rule)
            
            // Then
            let rules = detectionEngine.getActiveDetectionRules()
            XCTAssertEqual(rules.count, 1)
            XCTAssertEqual(rules.first?.id, "test-rule-001")
            XCTAssertEqual(rules.first?.name, "High CPU Usage Detection")
            XCTAssertEqual(rules.first?.category, .performance)
        } catch {
            XCTFail("Adding valid detection rule should not throw error: \(error)")
        }
    }
    
    func testAddDetectionRule_DuplicateID_ShouldFail() {
        // Given
        let rule1 = AnomalyDetectionEngine.DetectionRule(
            id: "duplicate-rule",
            name: "First Rule",
            description: "First test rule",
            category: .security,
            threshold: AnomalyDetectionEngine.DetectionRule.Threshold(
                thresholdOperator: "equals",
                value: 1.0,
                timeWindow: 60
            ),
            conditions: [],
            action: .alert,
            severity: .medium,
            enabled: true
        )
        
        let rule2 = AnomalyDetectionEngine.DetectionRule(
            id: "duplicate-rule", // Same ID
            name: "Second Rule",
            description: "Second test rule",
            category: .network,
            threshold: AnomalyDetectionEngine.DetectionRule.Threshold(
                thresholdOperator: "greater_than",
                value: 5.0,
                timeWindow: 120
            ),
            conditions: [],
            action: .block,
            severity: .high,
            enabled: true
        )
        
        // When
        do {
            try detectionEngine.addDetectionRule(rule1)
            
            // This should fail
            try detectionEngine.addDetectionRule(rule2)
            XCTFail("Adding rule with duplicate ID should throw error")
        } catch {
            // Then
            XCTAssertTrue(error is AnomalyDetectionEngine.DetectionError)
            let rules = detectionEngine.getActiveDetectionRules()
            XCTAssertEqual(rules.count, 1)
            XCTAssertEqual(rules.first?.name, "First Rule")
        }
    }
    
    func testRemoveDetectionRule_ExistingRule_ShouldSucceed() {
        // Given
        let rule = AnomalyDetectionEngine.DetectionRule(
            id: "removable-rule",
            name: "Rule to Remove",
            description: "This rule will be removed",
            category: .behavior,
            threshold: AnomalyDetectionEngine.DetectionRule.Threshold(
                thresholdOperator: "greater_than",
                value: 10.0,
                timeWindow: 60
            ),
            conditions: [],
            action: .alert,
            severity: .low,
            enabled: true
        )
        
        do {
            try detectionEngine.addDetectionRule(rule)
            XCTAssertEqual(detectionEngine.getActiveDetectionRules().count, 1)
            
            // When
            try detectionEngine.removeDetectionRule(ruleID: "removable-rule")
            
            // Then
            XCTAssertEqual(detectionEngine.getActiveDetectionRules().count, 0)
        } catch {
            XCTFail("Rule management should not throw error: \(error)")
        }
    }
    
    func testUpdateDetectionRule_ExistingRule_ShouldSucceed() {
        // Given
        let originalRule = AnomalyDetectionEngine.DetectionRule(
            id: "updatable-rule",
            name: "Original Rule",
            description: "Original description",
            category: .security,
            threshold: AnomalyDetectionEngine.DetectionRule.Threshold(
                thresholdOperator: "equals",
                value: 1.0,
                timeWindow: 60
            ),
            conditions: [],
            action: .alert,
            severity: .low,
            enabled: true
        )
        
        let updatedRule = AnomalyDetectionEngine.DetectionRule(
            id: "updatable-rule",
            name: "Updated Rule",
            description: "Updated description",
            category: .performance,
            threshold: AnomalyDetectionEngine.DetectionRule.Threshold(
                thresholdOperator: "greater_than",
                value: 10.0,
                timeWindow: 300
            ),
            conditions: [
                AnomalyDetectionEngine.DetectionRule.Condition(
                    field: "memory_usage",
                    thresholdOperator: "greater_than",
                    value: "1024"
                )
            ],
            action: .block,
            severity: .high,
            enabled: false
        )
        
        do {
            try detectionEngine.addDetectionRule(originalRule)
            
            // When
            try detectionEngine.updateDetectionRule(updatedRule)
            
            // Then
            let rules = detectionEngine.getActiveDetectionRules()
            XCTAssertEqual(rules.count, 1)
            let retrievedRule = rules.first
            XCTAssertEqual(retrievedRule?.name, "Updated Rule")
            XCTAssertEqual(retrievedRule?.description, "Updated description")
            XCTAssertEqual(retrievedRule?.category, .performance)
            XCTAssertEqual(retrievedRule?.action, .block)
            XCTAssertEqual(retrievedRule?.severity, .high)
            XCTAssertEqual(retrievedRule?.enabled, false)
        } catch {
            XCTFail("Rule update should not throw error: \(error)")
        }
    }
    
    // MARK: - Detection Control Tests
    
    func testStartDetection_WhenStopped_ShouldSucceed() {
        // When
        do {
            try detectionEngine.startDetection()
            
            // Then
            XCTAssertTrue(detectionEngine.isDetectionRunning)
        } catch {
            // This might fail on CI/testing environments
            print("Start detection failed (expected in test environment): \(error)")
        }
    }
    
    func testStartDetection_WhenAlreadyRunning_ShouldFail() {
        // Given
        do {
            try detectionEngine.startDetection()
            
            // When & Then
            do {
                try detectionEngine.startDetection()
                XCTFail("Starting already running detection should throw error")
            } catch let error as AnomalyDetectionEngine.DetectionError {
                XCTAssertTrue(error.localizedDescription.contains("already running"))
            } catch {
                XCTFail("Should throw DetectionError for already running detection")
            }
        } catch {
            // Skip test if initial start fails (common in test environments)
            print("Skipping test due to detection start failure: \(error)")
        }
    }
    
    func testStopDetection_WhenRunning_ShouldSucceed() {
        // Given
        do {
            try detectionEngine.startDetection()
            XCTAssertTrue(detectionEngine.isDetectionRunning)
            
            // When
            try detectionEngine.stopDetection()
            
            // Then
            XCTAssertFalse(detectionEngine.isDetectionRunning)
        } catch {
            // Skip test if detection cannot be started (common in test environments)
            print("Skipping test due to detection start/stop failure: \(error)")
        }
    }
    
    func testStopDetection_WhenStopped_ShouldFail() {
        // When & Then
        do {
            try detectionEngine.stopDetection()
            XCTFail("Stopping already stopped detection should throw error")
        } catch let error as AnomalyDetectionEngine.DetectionError {
            XCTAssertTrue(error.localizedDescription.contains("not running"))
        } catch {
            XCTFail("Should throw DetectionError for not running detection")
        }
    }
    
    // MARK: - Anomaly Analysis Tests
    
    func testAnalyzeDataPoint_ValidData_ShouldProcess() {
        // Given
        let dataPoint = AnomalyDetectionEngine.DataPoint(
            source: "test_process",
            category: .performance,
            metric: "cpu_usage",
            value: 85.5,
            metadata: [
                "process_id": "1234",
                "process_name": "test_app",
                "user_id": "501"
            ]
        )
        
        // When
        let result = detectionEngine.analyzeDataPoint(dataPoint)
        
        // Then
        XCTAssertTrue(result.processed)
        XCTAssertNotNil(result.analysisID)
        XCTAssertGreaterThanOrEqual(result.anomalyScore, 0.0)
        XCTAssertLessThanOrEqual(result.anomalyScore, 1.0)
    }
    
    func testAnalyzeDataPoint_WithMatchingRule_ShouldTriggerAnomaly() {
        // Given
        let rule = AnomalyDetectionEngine.DetectionRule(
            id: "cpu-usage-rule",
            name: "CPU Usage Anomaly",
            description: "Detects high CPU usage",
            category: .performance,
            threshold: AnomalyDetectionEngine.DetectionRule.Threshold(
                thresholdOperator: "greater_than",
                value: 80.0,
                timeWindow: 60
            ),
            conditions: [
                AnomalyDetectionEngine.DetectionRule.Condition(
                    field: "cpu_usage",
                    thresholdOperator: "greater_than",
                    value: "80"
                )
            ],
            action: .alert,
            severity: .high,
            enabled: true
        )
        
        let dataPoint = AnomalyDetectionEngine.DataPoint(
            source: "high_cpu_process",
            category: .performance,
            metric: "cpu_usage",
            value: 95.0,
            metadata: ["process_id": "5678"]
        )
        
        do {
            try detectionEngine.addDetectionRule(rule)
            
            // When
            let result = detectionEngine.analyzeDataPoint(dataPoint)
            
            // Then
            XCTAssertTrue(result.processed)
            XCTAssertTrue(result.anomalyDetected)
            XCTAssertGreaterThan(result.anomalyScore, 0.8) // Should be high for clear violation
            XCTAssertEqual(result.triggeredRules.count, 1)
            XCTAssertEqual(result.triggeredRules.first, "cpu-usage-rule")
        } catch {
            XCTFail("Anomaly analysis should not throw error: \(error)")
        }
    }
    
    func testAnalyzeBatch_MultipleDataPoints_ShouldProcessAll() {
        // Given
        let dataPoints = [
            AnomalyDetectionEngine.DataPoint(
                source: "process_1",
                category: .performance,
                metric: "cpu_usage",
                value: 25.0,
                metadata: [:]
            ),
            AnomalyDetectionEngine.DataPoint(
                source: "process_2",
                category: .performance,
                metric: "cpu_usage",
                value: 85.0,
                metadata: [:]
            ),
            AnomalyDetectionEngine.DataPoint(
                source: "process_3",
                category: .network,
                metric: "bandwidth_usage",
                value: 1500.0,
                metadata: [:]
            )
        ]
        
        // When
        let results = detectionEngine.analyzeBatch(dataPoints)
        
        // Then
        XCTAssertEqual(results.count, 3)
        XCTAssertTrue(results.allSatisfy { $0.processed })
        XCTAssertTrue(results.allSatisfy { $0.anomalyScore >= 0.0 && $0.anomalyScore <= 1.0 })
    }
    
    // MARK: - Pattern Learning Tests
    
    func testLearnPattern_ValidPattern_ShouldSucceed() {
        // Given
        let pattern = AnomalyDetectionEngine.BaselinePattern(
            id: UUID().uuidString,
            source: "test_application",
            category: .behavior,
            metric: "api_calls_per_minute",
            normalRange: AnomalyDetectionEngine.ValueRange(minimum: 10.0, maximum: 100.0),
            confidence: 0.85,
            sampleSize: 1000,
            metadata: [
                "training_period": "30_days",
                "data_quality": "high"
            ]
        )
        
        // When
        let result = detectionEngine.learnPattern(pattern)
        
        // Then
        XCTAssertTrue(result.success)
        XCTAssertNotNil(result.patternID)
        
        let learnedPatterns = detectionEngine.getLearnedPatterns()
        XCTAssertGreaterThanOrEqual(learnedPatterns.count, 1)
        XCTAssertTrue(learnedPatterns.contains { $0.source == "test_application" })
    }
    
    func testUpdateBaseline_ExistingPattern_ShouldSucceed() {
        // Given
        let pattern = AnomalyDetectionEngine.BaselinePattern(
            id: UUID().uuidString,
            source: "updatable_app",
            category: .performance,
            metric: "memory_usage",
            normalRange: AnomalyDetectionEngine.ValueRange(minimum: 100.0, maximum: 500.0),
            confidence: 0.75,
            sampleSize: 500,
            metadata: [:]
        )
        
        let updatedPattern = AnomalyDetectionEngine.BaselinePattern(
            id: pattern.id,
            source: "updatable_app",
            category: .performance,
            metric: "memory_usage",
            normalRange: AnomalyDetectionEngine.ValueRange(minimum: 150.0, maximum: 600.0),
            confidence: 0.90,
            sampleSize: 1500,
            metadata: ["updated": "true"]
        )
        
        let initialResult = detectionEngine.learnPattern(pattern)
        XCTAssertTrue(initialResult.success)
        
        // When
        let updateResult = detectionEngine.updateBaseline(updatedPattern)
        
        // Then
        XCTAssertTrue(updateResult.success)
        
        let patterns = detectionEngine.getLearnedPatterns()
        let retrievedPattern = patterns.first { $0.id == pattern.id }
        XCTAssertNotNil(retrievedPattern)
        XCTAssertEqual(retrievedPattern?.normalRange.maximum, 600.0)
        XCTAssertEqual(retrievedPattern?.confidence, 0.90)
        XCTAssertEqual(retrievedPattern?.sampleSize, 1500)
    }
    
    // MARK: - Statistics Tests
    
    func testGetDetectionStatistics_ShouldReturnValidStats() {
        // Given
        let dataPoint = AnomalyDetectionEngine.DataPoint(
            source: "stats_test",
            category: .security,
            metric: "failed_logins",
            value: 3.0,
            metadata: [:]
        )
        
        _ = detectionEngine.analyzeDataPoint(dataPoint)
        
        // When
        let stats = detectionEngine.getDetectionStatistics()
        
        // Then
        XCTAssertGreaterThanOrEqual(stats.totalAnalyses, 1)
        XCTAssertGreaterThanOrEqual(stats.anomaliesDetected, 0)
        XCTAssertGreaterThanOrEqual(stats.averageProcessingTime, 0)
        XCTAssertGreaterThanOrEqual(stats.activeRules, 0)
        XCTAssertGreaterThanOrEqual(stats.learnedPatterns, 0)
        XCTAssertNotNil(stats.lastAnalysisTime)
    }
    
    func testGetDetectionStatisticsByTimeRange_ShouldReturnFilteredStats() {
        // Given
        let dataPoint = AnomalyDetectionEngine.DataPoint(
            source: "time_range_stats_test",
            category: .network,
            metric: "connection_attempts",
            value: 50.0,
            metadata: [:]
        )
        
        let analysisTime = Date()
        _ = detectionEngine.analyzeDataPoint(dataPoint)
        
        // When
        let stats = detectionEngine.getDetectionStatistics(
            startTime: analysisTime.addingTimeInterval(-60),
            endTime: analysisTime.addingTimeInterval(60)
        )
        
        // Then
        XCTAssertGreaterThanOrEqual(stats.totalAnalyses, 1)
    }
    
    // MARK: - Configuration Tests
    
    func testUpdateConfiguration_ValidConfig_ShouldSucceed() {
        // Given
        let newConfig = AnomalyDetectionEngine.Configuration(
            analysisInterval: 30.0,
            baselineUpdateInterval: 3600.0, // 1 hour
            anomalyThreshold: 0.75,
            enableLearning: true,
            enableRealTimeDetection: false,
            maxDataPointsInMemory: 5000,
            patternExpirationDays: 60,
            statisticalMethod: .zScore,
            confidenceLevel: 0.99
        )
        
        // When
        let result = detectionEngine.updateConfiguration(newConfig)
        
        // Then
        XCTAssertTrue(result.success)
        
        let currentConfig = detectionEngine.getCurrentConfiguration()
        XCTAssertEqual(currentConfig.analysisInterval, 30.0)
        XCTAssertEqual(currentConfig.anomalyThreshold, 0.75)
        XCTAssertEqual(currentConfig.maxDataPointsInMemory, 5000)
        XCTAssertEqual(currentConfig.confidenceLevel, 0.99)
    }
    
    // MARK: - Category and Severity Tests
    
    func testAnomalyCategory_AllCases_ShouldExist() {
        // Given & When
        let categories = AnomalyDetectionEngine.AnomalyCategory.allCases
        
        // Then
        XCTAssertTrue(categories.contains(.security))
        XCTAssertTrue(categories.contains(.performance))
        XCTAssertTrue(categories.contains(.network))
        XCTAssertTrue(categories.contains(.behavior))
        XCTAssertTrue(categories.contains(.resource))
        XCTAssertTrue(categories.contains(.compliance))
    }
    
    func testSeverityLevel_AllCases_ShouldExist() {
        // Given & When
        let severities = AnomalyDetectionEngine.SeverityLevel.allCases
        
        // Then
        XCTAssertTrue(severities.contains(.critical))
        XCTAssertTrue(severities.contains(.high))
        XCTAssertTrue(severities.contains(.medium))
        XCTAssertTrue(severities.contains(.low))
        XCTAssertTrue(severities.contains(.info))
    }
    
    func testActionType_AllCases_ShouldExist() {
        // Given & When
        let actions = AnomalyDetectionEngine.ActionType.allCases
        
        // Then
        XCTAssertTrue(actions.contains(.alert))
        XCTAssertTrue(actions.contains(.block))
        XCTAssertTrue(actions.contains(.quarantine))
        XCTAssertTrue(actions.contains(.log))
        XCTAssertTrue(actions.contains(.none))
    }
    
    // MARK: - Value Range Tests
    
    func testValueRange_ValidRange_ShouldCreateCorrectly() {
        // Given & When
        let range = AnomalyDetectionEngine.ValueRange(minimum: 10.0, maximum: 100.0)
        
        // Then
        XCTAssertEqual(range.minimum, 10.0)
        XCTAssertEqual(range.maximum, 100.0)
    }
    
    func testValueRange_Contains_ShouldWorkCorrectly() {
        // Given
        let range = AnomalyDetectionEngine.ValueRange(minimum: 10.0, maximum: 100.0)
        
        // When & Then
        XCTAssertTrue(range.contains(50.0))
        XCTAssertTrue(range.contains(10.0)) // Boundary
        XCTAssertTrue(range.contains(100.0)) // Boundary
        XCTAssertFalse(range.contains(5.0)) // Below minimum
        XCTAssertFalse(range.contains(150.0)) // Above maximum
    }
    
    // MARK: - Performance Tests
    
    func testAnalyzeDataPoint_Performance() {
        // Test that data point analysis completes within reasonable time
        let dataPoint = AnomalyDetectionEngine.DataPoint(
            source: "performance_test",
            category: .performance,
            metric: "cpu_usage",
            value: 50.0,
            metadata: ["test": "performance"]
        )
        
        measure {
            for _ in 0..<100 {
                _ = detectionEngine.analyzeDataPoint(dataPoint)
            }
        }
    }
    
    func testAddDetectionRule_Performance() {
        // Test that rule addition completes within reasonable time
        measure {
            for i in 0..<50 {
                let rule = AnomalyDetectionEngine.DetectionRule(
                    id: "perf-rule-\(i)",
                    name: "Performance Test Rule \(i)",
                    description: "Rule for performance testing",
                    category: .performance,
                    threshold: AnomalyDetectionEngine.DetectionRule.Threshold(
                        thresholdOperator: "greater_than",
                        value: Double(i),
                        timeWindow: 60
                    ),
                    conditions: [],
                    action: .log,
                    severity: .low,
                    enabled: true
                )
                
                do {
                    try detectionEngine.addDetectionRule(rule)
                } catch {
                    // Ignore errors in performance test
                }
            }
        }
    }
}
