// MARK: - Performance Benchmark Framework
// Context7-inspired benchmark system adapted for Swift/macOS
// Based on research from @shopify/react-native-performance patterns

import Foundation
import os.log
import System

// MARK: - Performance Metrics Types

public struct PerformanceMetrics: Codable {
    public let reportId: UUID
    public let timestamp: TimeInterval
    public let cpuUsage: Double
    public let memoryUsageMB: Double
    public let startupTimeMs: Double?
    public let renderTimeMs: Double?
    public let operationName: String
    public let interactive: Bool
    
    public init(
        reportId: UUID = UUID(),
        timestamp: TimeInterval = Date().timeIntervalSince1970,
        cpuUsage: Double,
        memoryUsageMB: Double,
        startupTimeMs: Double? = nil,
        renderTimeMs: Double? = nil,
        operationName: String,
        interactive: Bool = true
    ) {
        self.reportId = reportId
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.memoryUsageMB = memoryUsageMB
        self.startupTimeMs = startupTimeMs
        self.renderTimeMs = renderTimeMs
        self.operationName = operationName
        self.interactive = interactive
    }
}

public struct BenchmarkResult: Codable {
    public let testName: String
    public let duration: TimeInterval
    public let metrics: PerformanceMetrics
    public let status: BenchmarkStatus
    public let iterations: Int
    
    public enum BenchmarkStatus: String, Codable {
        case passed = "PASSED"
        case failed = "FAILED"  
        case timeout = "TIMEOUT"
        case regression = "REGRESSION"
    }
}

// MARK: - Performance Monitor

public class PerformanceMonitor {
    private let logger = os.Logger(subsystem: "com.privarion.core", category: "performance")
    private var startTime: DispatchTime?
    private let queue = DispatchQueue(label: "performance.monitor", qos: .utility)
    
    public init() {}
    
    // MARK: - Timing Measurements
    
    public func startTimer() {
        startTime = DispatchTime.now()
    }
    
    public func endTimer() -> TimeInterval {
        guard let start = startTime else { return 0 }
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        return Double(nanoTime) / 1_000_000 // Convert to milliseconds
    }
    
    // MARK: - System Metrics
    
    public func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0.0 }
        
        // Get CPU usage percentage (simplified calculation)
        let totalTime = info.user_time.seconds + info.user_time.microseconds / 1_000_000 +
                       info.system_time.seconds + info.system_time.microseconds / 1_000_000
        
        return Double(totalTime) * 100.0 / Double(ProcessInfo.processInfo.systemUptime)
    }
    
    public func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return 0.0 }
        
        return Double(info.resident_size) / (1024 * 1024) // Convert to MB
    }
    
    // MARK: - Performance Measurement
    
    public func measureOperation<T>(
        name: String,
        operation: () throws -> T
    ) throws -> (result: T, metrics: PerformanceMetrics) {
        let startCPU = getCurrentCPUUsage()
        let startMemory = getCurrentMemoryUsage()
        
        startTimer()
        let result = try operation()
        let duration = endTimer()
        
        let endCPU = getCurrentCPUUsage()
        let endMemory = getCurrentMemoryUsage()
        
        let metrics = PerformanceMetrics(
            cpuUsage: endCPU - startCPU,
            memoryUsageMB: endMemory - startMemory,
            renderTimeMs: duration,
            operationName: name
        )
        
        logger.info("Performance: \(name) completed in \(duration)ms, CPU: \(metrics.cpuUsage)%, Memory: \(metrics.memoryUsageMB)MB")
        
        return (result, metrics)
    }
    
    public func measureAsyncOperation<T>(
        name: String,
        operation: () async throws -> T
    ) async throws -> (result: T, metrics: PerformanceMetrics) {
        let startCPU = getCurrentCPUUsage()
        let startMemory = getCurrentMemoryUsage()
        
        startTimer()
        let result = try await operation()
        let duration = endTimer()
        
        let endCPU = getCurrentCPUUsage()
        let endMemory = getCurrentMemoryUsage()
        
        let metrics = PerformanceMetrics(
            cpuUsage: endCPU - startCPU,
            memoryUsageMB: endMemory - startMemory,
            renderTimeMs: duration,
            operationName: name
        )
        
        logger.info("Async Performance: \(name) completed in \(duration)ms, CPU: \(metrics.cpuUsage)%, Memory: \(metrics.memoryUsageMB)MB")
        
        return (result, metrics)
    }
}

// MARK: - Benchmark Framework

public class BenchmarkFramework {
    private let monitor = PerformanceMonitor()
    private let logger = os.Logger(subsystem: "com.privarion.core", category: "benchmark")
    private var results: [BenchmarkResult] = []
    private let reportQueue = DispatchQueue(label: "benchmark.reports", qos: .utility)
    
    public static let shared = BenchmarkFramework()
    
    private init() {}
    
    // MARK: - Benchmark Execution
    
    public func runBenchmark(
        name: String,
        iterations: Int = 1,
        timeout: TimeInterval = 30.0,
        operation: () throws -> Void
    ) -> BenchmarkResult {
        logger.info("Starting benchmark: \(name) with \(iterations) iterations")
        
        var totalDuration: TimeInterval = 0
        var lastMetrics: PerformanceMetrics?
        var status: BenchmarkResult.BenchmarkStatus = .passed
        
        let benchmarkStart = DispatchTime.now()
        
        for i in 0..<iterations {
            do {
                let (_, metrics) = try monitor.measureOperation(name: "\(name)_iter_\(i+1)") {
                    try operation()
                }
                
                totalDuration += metrics.renderTimeMs ?? 0
                lastMetrics = metrics
                
                // Check for timeout
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - benchmarkStart.uptimeNanoseconds) / 1_000_000_000
                if elapsed > timeout {
                    status = .timeout
                    logger.warning("Benchmark \(name) timed out after \(elapsed)s")
                    break
                }
                
            } catch {
                status = .failed
                logger.error("Benchmark \(name) failed at iteration \(i+1): \(error.localizedDescription)")
                break
            }
        }
        
        let avgDuration = totalDuration / Double(iterations)
        let finalMetrics = lastMetrics ?? PerformanceMetrics(
            cpuUsage: 0,
            memoryUsageMB: 0,
            operationName: name,
            interactive: false
        )
        
        let result = BenchmarkResult(
            testName: name,
            duration: avgDuration,
            metrics: finalMetrics,
            status: status,
            iterations: iterations
        )
        
        results.append(result)
        logger.info("Benchmark \(name) completed: \(status.rawValue), avg duration: \(avgDuration)ms")
        
        return result
    }
    
    public func runAsyncBenchmark(
        name: String,
        iterations: Int = 1,
        timeout: TimeInterval = 30.0,
        operation: () async throws -> Void
    ) async -> BenchmarkResult {
        logger.info("Starting async benchmark: \(name) with \(iterations) iterations")
        
        var totalDuration: TimeInterval = 0
        var lastMetrics: PerformanceMetrics?
        var status: BenchmarkResult.BenchmarkStatus = .passed
        
        let benchmarkStart = DispatchTime.now()
        
        for i in 0..<iterations {
            do {
                let (_, metrics) = try await monitor.measureAsyncOperation(name: "\(name)_iter_\(i+1)") {
                    try await operation()
                }
                
                totalDuration += metrics.renderTimeMs ?? 0
                lastMetrics = metrics
                
                // Check for timeout
                let elapsed = Double(DispatchTime.now().uptimeNanoseconds - benchmarkStart.uptimeNanoseconds) / 1_000_000_000
                if elapsed > timeout {
                    status = .timeout
                    logger.warning("Async benchmark \(name) timed out after \(elapsed)s")
                    break
                }
                
            } catch {
                status = .failed
                logger.error("Async benchmark \(name) failed at iteration \(i+1): \(error.localizedDescription)")
                break
            }
        }
        
        let avgDuration = totalDuration / Double(iterations)
        let finalMetrics = lastMetrics ?? PerformanceMetrics(
            cpuUsage: 0,
            memoryUsageMB: 0,
            operationName: name,
            interactive: false
        )
        
        let result = BenchmarkResult(
            testName: name,
            duration: avgDuration,
            metrics: finalMetrics,
            status: status,
            iterations: iterations
        )
        
        results.append(result)
        logger.info("Async benchmark \(name) completed: \(status.rawValue), avg duration: \(avgDuration)ms")
        
        return result
    }
    
    // MARK: - Reporting
    
    public func getAllResults() -> [BenchmarkResult] {
        return reportQueue.sync { results }
    }
    
    public func clearResults() {
        reportQueue.sync { results.removeAll() }
    }
    
    public func exportResults() -> Data? {
        let reportData = reportQueue.sync {
            [
                "timestamp": Date().timeIntervalSince1970,
                "results": results,
                "summary": generateSummary()
            ] as [String: Any]
        }
        
        return try? JSONSerialization.data(withJSONObject: reportData, options: .prettyPrinted)
    }
    
    private func generateSummary() -> [String: Any] {
        let totalTests = results.count
        let passedTests = results.filter { $0.status == .passed }.count
        let failedTests = results.filter { $0.status == .failed }.count
        let timeoutTests = results.filter { $0.status == .timeout }.count
        
        let avgDuration = results.isEmpty ? 0 : results.map { $0.duration }.reduce(0, +) / Double(results.count)
        let avgCPU = results.isEmpty ? 0 : results.map { $0.metrics.cpuUsage }.reduce(0, +) / Double(results.count)
        let avgMemory = results.isEmpty ? 0 : results.map { $0.metrics.memoryUsageMB }.reduce(0, +) / Double(results.count)
        
        return [
            "total_tests": totalTests,
            "passed_tests": passedTests,
            "failed_tests": failedTests,
            "timeout_tests": timeoutTests,
            "success_rate": totalTests > 0 ? Double(passedTests) / Double(totalTests) * 100 : 0,
            "avg_duration_ms": avgDuration,
            "avg_cpu_usage": avgCPU,
            "avg_memory_usage_mb": avgMemory
        ]
    }
}

// MARK: - Startup Performance Tracker

public class StartupPerformanceTracker {
    private static let shared = StartupPerformanceTracker()
    private let monitor = PerformanceMonitor()
    private let logger = os.Logger(subsystem: "com.privarion.core", category: "startup")
    private var appStartTime: DispatchTime?
    
    private init() {}
    
    public static func markAppStart() {
        shared.appStartTime = DispatchTime.now()
        shared.logger.info("App startup time tracking started")
    }
    
    public static func markAppReady() -> PerformanceMetrics? {
        guard let startTime = shared.appStartTime else {
            shared.logger.warning("App start time not marked")
            return nil
        }
        
        let endTime = DispatchTime.now()
        let startupTime = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000 // ms
        
        let metrics = PerformanceMetrics(
            cpuUsage: shared.monitor.getCurrentCPUUsage(),
            memoryUsageMB: shared.monitor.getCurrentMemoryUsage(),
            startupTimeMs: startupTime,
            operationName: "app_startup"
        )
        
        shared.logger.info("App startup completed in \(startupTime)ms")
        return metrics
    }
}

// MARK: - Regression Detection

public class RegressionDetector {
    private let thresholds: RegressionThresholds
    private let logger = os.Logger(subsystem: "com.privarion.core", category: "regression")
    
    public struct RegressionThresholds {
        public let maxDurationIncreasePercent: Double
        public let maxMemoryIncreasePercent: Double
        public let maxCPUIncreasePercent: Double
        
        public init(
            maxDurationIncreasePercent: Double = 20.0,
            maxMemoryIncreasePercent: Double = 15.0,
            maxCPUIncreasePercent: Double = 25.0
        ) {
            self.maxDurationIncreasePercent = maxDurationIncreasePercent
            self.maxMemoryIncreasePercent = maxMemoryIncreasePercent
            self.maxCPUIncreasePercent = maxCPUIncreasePercent
        }
    }
    
    public init(thresholds: RegressionThresholds = RegressionThresholds()) {
        self.thresholds = thresholds
    }
    
    public func detectRegression(
        baseline: BenchmarkResult,
        current: BenchmarkResult
    ) -> Bool {
        let durationIncrease = (current.duration - baseline.duration) / baseline.duration * 100
        let memoryIncrease = (current.metrics.memoryUsageMB - baseline.metrics.memoryUsageMB) / baseline.metrics.memoryUsageMB * 100
        let cpuIncrease = (current.metrics.cpuUsage - baseline.metrics.cpuUsage) / baseline.metrics.cpuUsage * 100
        
        let hasRegression = durationIncrease > thresholds.maxDurationIncreasePercent ||
                           memoryIncrease > thresholds.maxMemoryIncreasePercent ||
                           cpuIncrease > thresholds.maxCPUIncreasePercent
        
        if hasRegression {
            logger.warning("Performance regression detected for \(current.testName): Duration +\(durationIncrease)%, Memory +\(memoryIncrease)%, CPU +\(cpuIncrease)%")
        }
        
        return hasRegression
    }
}
