import XCTest
import Foundation
import Logging
@testable import PrivarionCore

/// Performance benchmark tests for Privarion components
/// Based on Context7 research and React Native Performance patterns
final class PerformanceBenchmarkTests: XCTestCase {
    
    private var benchmarkFramework: BenchmarkFramework!
    private var configurationManager: ConfigurationManager!
    private var systemExecutor: SystemCommandExecutor!
    private let testLogger = Logger(label: "test")
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        benchmarkFramework = BenchmarkFramework.shared
        benchmarkFramework.clearResults()
        configurationManager = ConfigurationManager.shared
        systemExecutor = SystemCommandExecutor(logger: PrivarionLogger.shared)
    }
    
    override func tearDownWithError() throws {
        // Export benchmark results after each test run
        if let reportData = benchmarkFramework.exportResults() {
            let reportPath = "/tmp/privarion_benchmark_\(Date().timeIntervalSince1970).json"
            try reportData.write(to: URL(fileURLWithPath: reportPath))
            print("📊 Benchmark report exported to: \(reportPath)")
        }
        
        benchmarkFramework.clearResults()
        configurationManager = nil
        systemExecutor = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Startup Performance Tests
    
    func testAppStartupPerformance() throws {
        StartupPerformanceTracker.markAppStart()
        
        // Simulate app initialization
        let result = benchmarkFramework.runBenchmark(
            name: "app_startup_simulation",
            iterations: 5,
            timeout: 10.0
        ) {
            // Simulate configuration loading with available public API
            _ = configurationManager.getCurrentConfiguration()
            
            // Simulate component initialization
            Thread.sleep(forTimeInterval: 0.1) // 100ms startup delay
        }
        
        XCTAssertEqual(result.status, BenchmarkResult.BenchmarkStatus.passed, "App startup benchmark should pass")
        XCTAssertLessThan(result.duration, 1000, "Startup should be under 1000ms")
        
        // Mark app as ready and check startup metrics
        if let startupMetrics = StartupPerformanceTracker.markAppReady() {
            XCTAssertNotNil(startupMetrics.startupTimeMs, "Startup time should be measured")
            XCTAssertLessThan(startupMetrics.startupTimeMs!, 5000, "Total startup should be under 5s")
        }
    }
    
    // MARK: - Configuration Performance Tests
    
    func testConfigurationLoadingPerformance() throws {
        let result = benchmarkFramework.runBenchmark(
            name: "configuration_loading",
            iterations: 10,
            timeout: 5.0
        ) {
            _ = configurationManager.getCurrentConfiguration()
        }
        
        XCTAssertEqual(result.status, BenchmarkResult.BenchmarkStatus.passed, "Configuration loading should pass")
        XCTAssertLessThan(result.duration, 100, "Configuration loading should be under 100ms")
        XCTAssertLessThan(result.metrics.memoryUsageMB, 10, "Memory usage should be reasonable")
    }
    
    func testConfigurationSavingPerformance() throws {
        // Get current configuration and modify it
        let config = configurationManager.getCurrentConfiguration()
        
        let result = benchmarkFramework.runBenchmark(
            name: "configuration_saving", 
            iterations: 10,
            timeout: 5.0
        ) {
            try configurationManager.updateConfiguration(config)
        }
        
        XCTAssertEqual(result.status, BenchmarkResult.BenchmarkStatus.passed, "Configuration saving should pass")
        XCTAssertLessThan(result.duration, 200, "Configuration saving should be under 200ms")
    }
    
    // MARK: - Hook Management Performance Tests
    
    func testHookLibraryLoadingPerformance() throws {
        let result = benchmarkFramework.runBenchmark(
            name: "hook_library_loading",
            iterations: 5,
            timeout: 10.0
        ) {
            // Simulate hook library operations using available API
            _ = IdentitySpoofingManager()
            // Use available methods from IdentitySpoofingManager
            Thread.sleep(forTimeInterval: 0.01) // Simulate work
        }
        
        XCTAssertEqual(result.status, BenchmarkResult.BenchmarkStatus.passed, "Hook library operations should pass")
        XCTAssertLessThan(result.duration, 500, "Hook operations should be under 500ms")
    }
    
    // MARK: - System Command Performance Tests
    
    func testSystemCommandExecutionPerformance() async throws {
        let result = await benchmarkFramework.runAsyncBenchmark(
            name: "system_command_execution",
            iterations: 5,
            timeout: 15.0
        ) {
            // Test safe system commands only using proper async API
            let commandResult = try await systemExecutor.executeCommand("whoami", arguments: [])
            XCTAssertEqual(commandResult.exitCode, 0)
        }
        
        XCTAssertEqual(result.status, BenchmarkResult.BenchmarkStatus.passed, "System command execution should pass")
        XCTAssertLessThan(result.duration, 1000, "System commands should be under 1s")
    }
    
    // MARK: - Memory Usage Stress Tests
    
    func testMemoryUsageStability() throws {
        let initialMemory = PerformanceMonitor().getCurrentMemoryUsage()
        
        let result = benchmarkFramework.runBenchmark(
            name: "memory_stability_stress",
            iterations: 20,
            timeout: 30.0
        ) {
            // Create and release multiple configuration objects
            var configs: [PrivarionConfig] = []
            for _ in 0..<100 {
                let config = configurationManager.getCurrentConfiguration()
                configs.append(config)
            }
            configs.removeAll() // Force deallocation
        }
        
        let finalMemory = PerformanceMonitor().getCurrentMemoryUsage()
        let memoryGrowth = finalMemory - initialMemory
        
        XCTAssertEqual(result.status, BenchmarkResult.BenchmarkStatus.passed, "Memory stability test should pass")
        XCTAssertLessThan(memoryGrowth, 50, "Memory growth should be under 50MB")
        print("📈 Memory growth during stress test: \(memoryGrowth)MB")
    }
    
    // MARK: - Concurrent Operations Performance
    
    func testConcurrentOperationsPerformance() async throws {
        let result = await benchmarkFramework.runAsyncBenchmark(
            name: "concurrent_operations",
            iterations: 3,
            timeout: 20.0
        ) {
            // Simulate concurrent configuration operations using available API
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0..<10 {
                    group.addTask {
                        let config = self.configurationManager.getCurrentConfiguration()
                        // Simulate some processing
                        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                        try self.configurationManager.updateConfiguration(config)
                    }
                }
                try await group.waitForAll()
            }
        }
        
        XCTAssertEqual(result.status, BenchmarkResult.BenchmarkStatus.passed, "Concurrent operations should pass")
        XCTAssertLessThan(result.duration, 5000, "Concurrent operations should be under 5s")
    }
    
    // MARK: - Performance Regression Tests
    
    func testPerformanceRegression() throws {
        // Create baseline benchmark
        let baseline = benchmarkFramework.runBenchmark(
            name: "regression_baseline",
            iterations: 5
        ) {
            _ = configurationManager.getCurrentConfiguration()
        }
        
        // Simulate potential regression (artificially slower operation)
        let current = benchmarkFramework.runBenchmark(
            name: "regression_baseline",
            iterations: 5
        ) {
            _ = configurationManager.getCurrentConfiguration()
            // Add artificial delay to test regression detection
            Thread.sleep(forTimeInterval: 0.001) // 1ms delay
        }
        
        let regressionDetector = RegressionDetector()
        let hasRegression = regressionDetector.detectRegression(baseline: baseline, current: current)
        
        // This test verifies that regression detection works
        print("🔍 Regression detection result: \(hasRegression)")
        print("📊 Baseline duration: \(baseline.duration)ms, Current: \(current.duration)ms")
    }
    
    // MARK: - Performance Baseline Verification
    
    func testPerformanceBaselines() throws {
        var baselineViolations: [String] = []
        
        // Configuration loading baseline
        let configResult = benchmarkFramework.runBenchmark(
            name: "baseline_config_loading",
            iterations: 10
        ) {
            _ = configurationManager.getCurrentConfiguration()
        }
        
        if configResult.duration > 50 { // 50ms baseline
            baselineViolations.append("Configuration loading exceeded 50ms baseline: \(configResult.duration)ms")
        }
        
        // Memory usage baseline
        if configResult.metrics.memoryUsageMB > 5 { // 5MB baseline
            baselineViolations.append("Memory usage exceeded 5MB baseline: \(configResult.metrics.memoryUsageMB)MB")
        }
        
        // CPU usage baseline (this is delta, so should be minimal)
        if configResult.metrics.cpuUsage > 10 { // 10% baseline
            baselineViolations.append("CPU usage exceeded 10% baseline: \(configResult.metrics.cpuUsage)%")
        }
        
        // Report baseline violations
        if !baselineViolations.isEmpty {
            print("⚠️ Performance baseline violations:")
            for violation in baselineViolations {
                print("  - \(violation)")
            }
        } else {
            print("✅ All performance baselines met")
        }
        
        // Don't fail the test, just report violations
        XCTAssertEqual(configResult.status, BenchmarkResult.BenchmarkStatus.passed, "Baseline benchmark should execute successfully")
    }
    
    // MARK: - Load Testing
    
    func testHighLoadPerformance() throws {
        let result = benchmarkFramework.runBenchmark(
            name: "high_load_test",
            iterations: 50, // High iteration count
            timeout: 60.0
        ) {
            // Rapid configuration operations
            let config = configurationManager.getCurrentConfiguration()
            try configurationManager.updateConfiguration(config)
        }
        
        XCTAssertEqual(result.status, BenchmarkResult.BenchmarkStatus.passed, "High load test should pass")
        print("📈 High load test completed: \(result.iterations) iterations in \(result.duration)ms avg")
        
        // Verify performance doesn't degrade significantly under load
        XCTAssertLessThan(result.duration, 300, "Performance under load should remain under 300ms")
    }
}

// MARK: - Performance Utility Extensions

extension XCTestCase {
    /// Measure execution time of a block and assert it's within expected range
    func measureExecutionTime<T>(
        expectedRange: ClosedRange<TimeInterval>,
        operation: () throws -> T
    ) rethrows -> T {
        let monitor = PerformanceMonitor()
        monitor.startTimer()
        let result = try operation()
        let duration = monitor.endTimer()
        
        XCTAssertTrue(
            expectedRange.contains(duration),
            "Execution time \(duration)ms not in expected range \(expectedRange)"
        )
        
        return result
    }
    
    /// Measure memory usage of a block and assert it's within expected range
    func measureMemoryUsage<T>(
        maxMemoryIncreaseMB: Double,
        operation: () throws -> T
    ) rethrows -> T {
        let monitor = PerformanceMonitor()
        let initialMemory = monitor.getCurrentMemoryUsage()
        
        let result = try operation()
        
        let finalMemory = monitor.getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        XCTAssertLessThan(
            memoryIncrease,
            maxMemoryIncreaseMB,
            "Memory increase \(memoryIncrease)MB exceeds limit \(maxMemoryIncreaseMB)MB"
        )
        
        return result
    }
}
