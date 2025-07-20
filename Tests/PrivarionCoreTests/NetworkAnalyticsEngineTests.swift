import XCTest
import Combine
import Foundation
@testable import PrivarionCore

/// Simplified test suite for NetworkAnalyticsEngine
/// Validates STORY-2025-010 acceptance criteria
final class NetworkAnalyticsEngineTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var analyticsEngine: NetworkAnalyticsEngine!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Initialize analytics engine
        analyticsEngine = NetworkAnalyticsEngine.shared
        cancellables = Set<AnyCancellable>()
        
        // Enable analytics for testing
        try enableAnalyticsForTesting()
        
        print("🧪 NetworkAnalyticsEngineTests: Test setup completed")
    }
    
    /// Enable analytics for testing by updating configuration
    private func enableAnalyticsForTesting() throws {
        let configManager = ConfigurationManager.shared
        var config = configManager.getCurrentConfiguration()
        
        // Enable network analytics for testing
        config.modules.networkAnalytics.enabled = true
        config.modules.networkAnalytics.realTimeProcessing = true
        config.modules.networkAnalytics.maxEventsInMemory = 100 // Reduced for testing
        
        // Update configuration
        try configManager.updateConfiguration(config)
        
        print("🔧 Analytics enabled for testing")
    }
    
    override func tearDownWithError() throws {
        // Clean up analytics session
        cancellables?.removeAll()
        cancellables = nil
        analyticsEngine = nil
        
        try super.tearDownWithError()
        print("🧪 NetworkAnalyticsEngineTests: Test cleanup completed")
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAnalyticsEngineInitialization() throws {
        // Test that analytics engine initializes properly
        XCTAssertNotNil(analyticsEngine, "Analytics engine should initialize")
        
        // Test that publishers are available
        XCTAssertNotNil(analyticsEngine.analyticsEventPublisher, "Analytics event publisher should be available")
        XCTAssertNotNil(analyticsEngine.metricsPublisher, "Metrics publisher should be available")
        
        print("✅ Analytics engine initialization test passed")
    }
    
    func testAnalyticsEngineStart() throws {
        // Test starting analytics collection
        XCTAssertNoThrow(try analyticsEngine.startAnalytics(), "Analytics should start without throwing")
        
        print("✅ Analytics engine start test passed")
    }
    
    func testAnalyticsEngineStop() throws {
        // Test starting and stopping analytics
        try analyticsEngine.startAnalytics()
        XCTAssertNoThrow(analyticsEngine.stopAnalytics(), "Analytics should stop without throwing")
        
        print("✅ Analytics engine stop test passed")
    }
    
    func testCurrentMetricsRetrieval() throws {
        // Test getting current analytics metrics
        let metrics = analyticsEngine.getCurrentMetrics()
        XCTAssertNotNil(metrics, "Current metrics should be retrievable")
        XCTAssertNotNil(metrics.timestamp, "Metrics should have timestamp")
        
        print("✅ Current metrics retrieval test passed")
    }
    
    func testEventPublisherSubscription() throws {
        let expectation = XCTestExpectation(description: "Event publisher should emit events")
        expectation.expectedFulfillmentCount = 1
        
        // Subscribe to analytics events
        analyticsEngine.analyticsEventPublisher
            .sink { event in
                XCTAssertNotNil(event.id, "Event should have ID")
                XCTAssertNotNil(event.timestamp, "Event should have timestamp")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Start analytics to enable event publishing
        try analyticsEngine.startAnalytics()
        
        // Create and publish a test event
        let testEvent = AnalyticsEvent(
            id: UUID(),
            timestamp: Date(),
            sessionId: UUID(),
            type: .connection,
            source: NetworkEndpoint(address: "127.0.0.1", port: 8080, hostname: "localhost"),
            destination: NetworkEndpoint(address: "example.com", port: 443, hostname: "example.com"),
            protocol: .tcp,
            dataSize: 1024,
            duration: 0.1,
            application: "test.app",
            metadata: [
                "test": "true",
                "bytes": "1024"
            ]
        )
        
        // Publish the event
        analyticsEngine.analyticsEventPublisher.send(testEvent)
        
        wait(for: [expectation], timeout: 5.0)
        print("✅ Event publisher subscription test passed")
    }
    
    func testAnalyticsConfiguration() throws {
        // Test that analytics configuration is accessible
        let config = analyticsEngine.getCurrentConfiguration()
        XCTAssertNotNil(config, "Analytics configuration should be available")
        
        print("✅ Analytics configuration test passed")
    }
    
    // MARK: - Performance Tests (STORY-2025-010 Acceptance Criteria)
    
    func testAnalyticsPerformanceBenchmark() throws {
        // Test that analytics operations meet performance requirements (< 500ms)
        let startTime = Date()
        
        // Start analytics and process events
        try analyticsEngine.startAnalytics()
        
        // Process multiple events to test performance
        for i in 0..<50 {
            let testEvent = AnalyticsEvent(
                id: UUID(),
                timestamp: Date(),
                sessionId: UUID(),
                type: .connection,
                source: NetworkEndpoint(address: "192.168.1.\(i % 255)", port: UInt16(8000 + i), hostname: "host\(i)"),
                destination: NetworkEndpoint(address: "8.8.8.8", port: 443, hostname: "dns.google"),
                protocol: .tcp,
                dataSize: UInt64(1024 * (i + 1)),
                duration: 0.1,
                application: "test.app.\(i)",
                metadata: ["request_id": "req_\(i)"]
            )
            
            analyticsEngine.analyticsEventPublisher.send(testEvent)
        }
        
        // Get metrics to ensure processing completed
        let metrics = analyticsEngine.getCurrentMetrics()
        XCTAssertNotNil(metrics)
        
        let endTime = Date()
        let processingTime = endTime.timeIntervalSince(startTime)
        
        // Verify performance requirement: < 500ms for batch processing
        XCTAssertLessThan(processingTime, 0.5, "Analytics processing should complete within 500ms")
        
        analyticsEngine.stopAnalytics()
        
        print("✅ Performance benchmark: \(String(format: "%.3f", processingTime))s (< 500ms required)")
    }
    
    func testRealTimeMetricsLatency() throws {
        // Test real-time metrics retrieval latency
        try analyticsEngine.startAnalytics()
        
        let measurements = (0..<10).map { _ in
            let startTime = Date()
            let _ = analyticsEngine.getCurrentMetrics()
            let endTime = Date()
            return endTime.timeIntervalSince(startTime)
        }
        
        let averageLatency = measurements.reduce(0, +) / Double(measurements.count)
        let maxLatency = measurements.max() ?? 0
        
        // Verify latency requirements
        XCTAssertLessThan(averageLatency, 0.010, "Average metrics latency should be < 10ms")
        XCTAssertLessThan(maxLatency, 0.050, "Maximum metrics latency should be < 50ms")
        
        analyticsEngine.stopAnalytics()
        
        print("✅ Real-time metrics latency: avg=\(String(format: "%.3f", averageLatency * 1000))ms, max=\(String(format: "%.3f", maxLatency * 1000))ms")
    }
}

// MARK: - Helper Extensions

extension NetworkAnalyticsEngine {
    /// Get current analytics configuration for testing
    func getCurrentConfiguration() -> NetworkAnalyticsConfig? {
        let configManager = ConfigurationManager.shared
        return configManager.getCurrentConfiguration().modules.networkAnalytics
    }
}
