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
        
        return Double(totalTime) * 100.0 / Double(Foundation.ProcessInfo.processInfo.systemUptime)
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
            let resultsArray = results.map { result -> [String: Any] in
                return [
                    "testName": result.testName,
                    "duration": result.duration,
                    "status": result.status.rawValue,
                    "iterations": result.iterations,
                    "metrics": [
                        "reportId": result.metrics.reportId.uuidString,
                        "timestamp": result.metrics.timestamp,
                        "cpuUsage": result.metrics.cpuUsage,
                        "memoryUsageMB": result.metrics.memoryUsageMB,
                        "startupTimeMs": result.metrics.startupTimeMs as Any,
                        "renderTimeMs": result.metrics.renderTimeMs as Any,
                        "operationName": result.metrics.operationName,
                        "interactive": result.metrics.interactive
                    ]
                ]
            }
            
            return [
                "timestamp": Date().timeIntervalSince1970,
                "results": resultsArray,
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

// MARK: - WebSocket Performance Extensions
// STORY-2025-014: WebSocket Dashboard Integration & Performance Validation
// Based on SwiftNIO performance testing patterns from Context7 research

import NIOCore
import NIOPosix
import NIOWebSocket

// MARK: - WebSocket Performance Metrics

public struct WebSocketMetrics: Codable, Sendable {
    public let connectionCount: Int
    public let averageLatencyMs: Double
    public let maxLatencyMs: Double
    public let minLatencyMs: Double
    public let allocations: AllocationMetrics
    public let backPressureEvents: Int
    public let errorCount: Int
    public let throughputMbps: Double
    public let connectionErrors: [ConnectionError]
    
    public init(
        connectionCount: Int,
        averageLatencyMs: Double,
        maxLatencyMs: Double,
        minLatencyMs: Double,
        allocations: AllocationMetrics,
        backPressureEvents: Int,
        errorCount: Int,
        throughputMbps: Double,
        connectionErrors: [ConnectionError] = []
    ) {
        self.connectionCount = connectionCount
        self.averageLatencyMs = averageLatencyMs
        self.maxLatencyMs = maxLatencyMs
        self.minLatencyMs = minLatencyMs
        self.allocations = allocations
        self.backPressureEvents = backPressureEvents
        self.errorCount = errorCount
        self.throughputMbps = throughputMbps
        self.connectionErrors = connectionErrors
    }
}

public struct AllocationMetrics: Codable, Sendable {
    public let remainingAllocations: Int  // Must be 0 (no memory leaks - SwiftNIO pattern)
    public let totalAllocations: Int
    public let totalAllocatedBytes: Int
    public let allocationRate: Double // Allocations per second
    
    public init(remainingAllocations: Int, totalAllocations: Int, totalAllocatedBytes: Int, allocationRate: Double) {
        self.remainingAllocations = remainingAllocations
        self.totalAllocations = totalAllocations
        self.totalAllocatedBytes = totalAllocatedBytes
        self.allocationRate = allocationRate
    }
    
    public var hasMemoryLeaks: Bool {
        return remainingAllocations > 0
    }
}

public struct ConnectionError: Codable, Sendable {
    public let timestamp: TimeInterval
    public let errorType: String
    public let description: String
    public let connectionIndex: Int
    
    public init(timestamp: TimeInterval, errorType: String, description: String, connectionIndex: Int) {
        self.timestamp = timestamp
        self.errorType = errorType
        self.description = description
        self.connectionIndex = connectionIndex
    }
}

// MARK: - WebSocket Performance Thresholds

public struct WebSocketPerformanceThresholds: Sendable {
    public let maxLatencyMs: Double
    public let maxAllocationRate: Double
    public let maxErrorRate: Double // Percentage of failed connections
    public let minThroughputMbps: Double
    public let maxMemoryLeakCount: Int // Should be 0
    
    public static let enterprise: WebSocketPerformanceThresholds = .init(
        maxLatencyMs: 10.0,  // <10ms as per STORY-2025-014 requirements
        maxAllocationRate: 1000.0, // Allocations per second
        maxErrorRate: 1.0, // Max 1% error rate
        minThroughputMbps: 50.0, // Minimum throughput
        maxMemoryLeakCount: 0 // Zero tolerance for memory leaks
    )
    
    public static let development: WebSocketPerformanceThresholds = .init(
        maxLatencyMs: 50.0,
        maxAllocationRate: 2000.0,
        maxErrorRate: 5.0,
        minThroughputMbps: 10.0,
        maxMemoryLeakCount: 0
    )
}

// MARK: - Allocation Tracker (SwiftNIO Pattern Implementation)

public final class AllocationTracker: @unchecked Sendable {
    private let logger = os.Logger(subsystem: "com.privarion.performance", category: "allocations")
    private let startTime: DispatchTime
    private let trackingQueue = DispatchQueue(label: "allocation.tracking", qos: .utility)
    
    private let totalAllocations = OSAllocatedUnfairLock(initialState: 0)
    private let totalBytes = OSAllocatedUnfairLock(initialState: 0)
    private let remainingCount = OSAllocatedUnfairLock(initialState: 0)
    
    public init() {
        self.startTime = DispatchTime.now()
    }
    
    public func recordAllocation(bytes: Int) {
        totalAllocations.withLock { $0 += 1 }
        totalBytes.withLock { $0 += bytes }
        remainingCount.withLock { $0 += 1 }
    }
    
    public func recordDeallocation(bytes: Int) {
        remainingCount.withLock { $0 -= 1 }
    }
    
    public func getCurrentMetrics() -> AllocationMetrics {
        let total = totalAllocations.withLock { $0 }
        let bytes = totalBytes.withLock { $0 }
        let remaining = remainingCount.withLock { $0 }
        
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        let rate = elapsed > 0 ? Double(total) / elapsed : 0
        
        return AllocationMetrics(
            remainingAllocations: remaining,
            totalAllocations: total,
            totalAllocatedBytes: bytes,
            allocationRate: rate
        )
    }
    
    public func reset() {
        totalAllocations.withLock { $0 = 0 }
        totalBytes.withLock { $0 = 0 }
        remainingCount.withLock { $0 = 0 }
    }
}

// MARK: - WebSocket Benchmark Framework

public final class WebSocketBenchmarkFramework: @unchecked Sendable {
    private let logger = os.Logger(subsystem: "com.privarion.performance", category: "websocket.benchmark")
    private let allocationTracker = AllocationTracker()
    private let thresholds: WebSocketPerformanceThresholds
    
    public init(thresholds: WebSocketPerformanceThresholds = .enterprise) {
        self.thresholds = thresholds
    }
    
    // MARK: - Concurrent Connection Testing (SwiftNIO Pattern)
    
    public func testConcurrentConnections(
        connectionCount: Int,
        host: String = "127.0.0.1",
        port: Int = 8080,
        testDurationSeconds: TimeInterval = 30.0
    ) async throws -> WebSocketMetrics {
        logger.info("Starting concurrent WebSocket connection test: \(connectionCount) connections")
        
        allocationTracker.reset()
        let latencies = OSAllocatedUnfairLock(initialState: [Double]())
        let errors = OSAllocatedUnfairLock(initialState: [ConnectionError]())
        let backPressureEvents = 0 // Will be incremented when back pressure detected
        let startTime = DispatchTime.now()
        
        // Use TaskGroup for concurrent connections (compatible with macOS 13+)
        await withTaskGroup(of: Void.self) { group in
            for connectionIndex in 0..<connectionCount {
                group.addTask { [weak self] in
                    guard let self = self else { return }
                    
                    do {
                        let latency = try await self.measureConnectionLatency(
                            host: host,
                            port: port,
                            connectionIndex: connectionIndex,
                            durationSeconds: testDurationSeconds
                        )
                        
                        latencies.withLock { $0.append(latency) }
                    } catch {
                        let connectionError = ConnectionError(
                            timestamp: Date().timeIntervalSince1970,
                            errorType: String(describing: type(of: error)),
                            description: error.localizedDescription,
                            connectionIndex: connectionIndex
                        )
                        
                        errors.withLock { $0.append(connectionError) }
                    }
                }
            }
        }
        
        let endTime = DispatchTime.now()
        let totalDuration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        
        let allocations = allocationTracker.getCurrentMetrics()
        let finalLatencies = latencies.withLock { $0 }
        let finalErrors = errors.withLock { $0 }
        
        let avgLatency = finalLatencies.isEmpty ? 0 : finalLatencies.reduce(0, +) / Double(finalLatencies.count)
        let maxLatency = finalLatencies.max() ?? 0
        let minLatency = finalLatencies.min() ?? 0
        
        // Calculate throughput (simplified estimation)
        let throughput = calculateThroughput(
            connectionCount: connectionCount,
            durationSeconds: totalDuration,
            successfulConnections: finalLatencies.count
        )
        
        let metrics = WebSocketMetrics(
            connectionCount: connectionCount,
            averageLatencyMs: avgLatency,
            maxLatencyMs: maxLatency,
            minLatencyMs: minLatency,
            allocations: allocations,
            backPressureEvents: backPressureEvents,
            errorCount: finalErrors.count,
            throughputMbps: throughput,
            connectionErrors: finalErrors
        )
        
        logger.info("WebSocket test completed - Connections: \(connectionCount), Avg Latency: \(avgLatency)ms, Errors: \(finalErrors.count)")
        
        return metrics
    }
    
    // MARK: - Latency Measurement (<10ms validation)
    
    private func measureConnectionLatency(
        host: String,
        port: Int,
        connectionIndex: Int,
        durationSeconds: TimeInterval
    ) async throws -> Double {
        let startTime = DispatchTime.now()
        
        // Simple connection latency measurement
        // In real implementation, this would use actual WebSocket client connection
        try await Task.sleep(nanoseconds: UInt64.random(in: 1_000_000...15_000_000)) // 1-15ms simulation
        
        // Record allocation during connection
        allocationTracker.recordAllocation(bytes: 1024) // Typical WebSocket connection overhead
        
        let endTime = DispatchTime.now()
        let latencyMs = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
        
        return latencyMs
    }
    
    // MARK: - Performance Validation
    
    public func validatePerformance(_ metrics: WebSocketMetrics) -> (passed: Bool, failures: [String]) {
        var failures: [String] = []
        
        // Latency validation (<10ms requirement)
        if metrics.averageLatencyMs > thresholds.maxLatencyMs {
            failures.append("Average latency (\(metrics.averageLatencyMs)ms) exceeds threshold (\(thresholds.maxLatencyMs)ms)")
        }
        
        // Memory leak validation (must be 0)
        if metrics.allocations.hasMemoryLeaks {
            failures.append("Memory leaks detected: \(metrics.allocations.remainingAllocations) remaining allocations")
        }
        
        // Error rate validation
        let errorRate = Double(metrics.errorCount) / Double(metrics.connectionCount) * 100
        if errorRate > thresholds.maxErrorRate {
            failures.append("Error rate (\(errorRate)%) exceeds threshold (\(thresholds.maxErrorRate)%)")
        }
        
        // Throughput validation
        if metrics.throughputMbps < thresholds.minThroughputMbps {
            failures.append("Throughput (\(metrics.throughputMbps) Mbps) below threshold (\(thresholds.minThroughputMbps) Mbps)")
        }
        
        // Allocation rate validation
        if metrics.allocations.allocationRate > thresholds.maxAllocationRate {
            failures.append("Allocation rate (\(metrics.allocations.allocationRate)/s) exceeds threshold (\(thresholds.maxAllocationRate)/s)")
        }
        
        let passed = failures.isEmpty
        if passed {
            logger.info("Performance validation passed for \(metrics.connectionCount) connections")
        } else {
            logger.error("Performance validation failed: \(failures.joined(separator: ", "))")
        }
        
        return (passed: passed, failures: failures)
    }
    
    // MARK: - Utility Methods
    
    private func calculateThroughput(
        connectionCount: Int,
        durationSeconds: TimeInterval,
        successfulConnections: Int
    ) -> Double {
        guard durationSeconds > 0 else { return 0 }
        
        // Simplified throughput calculation
        // In real implementation, this would measure actual data transfer
        let connectionsPerSecond = Double(successfulConnections) / durationSeconds
        let estimatedBytesPerConnection = 1024.0 // Typical WebSocket overhead
        let bytesPerSecond = connectionsPerSecond * estimatedBytesPerConnection
        let bitsPerSecond = bytesPerSecond * 8
        let mbps = bitsPerSecond / (1024 * 1024)
        
        return mbps
    }
}

// MARK: - BenchmarkFramework WebSocket Extensions

extension BenchmarkFramework {
    
    public func runWebSocketBenchmark(
        name: String,
        connectionCount: Int,
        testDurationSeconds: TimeInterval = 30.0,
        thresholds: WebSocketPerformanceThresholds = .enterprise
    ) async -> BenchmarkResult {
        logger.info("Starting WebSocket benchmark: \(name) with \(connectionCount) connections")
        
        let webSocketFramework = WebSocketBenchmarkFramework(thresholds: thresholds)
        let startTime = DispatchTime.now()
        
        var status: BenchmarkResult.BenchmarkStatus = .passed
        var metrics: PerformanceMetrics
        
        do {
            let wsMetrics = try await webSocketFramework.testConcurrentConnections(
                connectionCount: connectionCount,
                testDurationSeconds: testDurationSeconds
            )
            
            let validation = webSocketFramework.validatePerformance(wsMetrics)
            
            if !validation.passed {
                status = .failed
                logger.error("WebSocket benchmark failed: \(validation.failures.joined(separator: ", "))")
            }
            
            // Convert WebSocket metrics to standard PerformanceMetrics
            metrics = PerformanceMetrics(
                cpuUsage: 0, // Will be measured separately
                memoryUsageMB: Double(wsMetrics.allocations.totalAllocatedBytes) / (1024 * 1024),
                renderTimeMs: wsMetrics.averageLatencyMs,
                operationName: name
            )
            
        } catch {
            status = .failed
            logger.error("WebSocket benchmark error: \(error.localizedDescription)")
            
            metrics = PerformanceMetrics(
                cpuUsage: 0,
                memoryUsageMB: 0,
                renderTimeMs: 0,
                operationName: name
            )
        }
        
        let endTime = DispatchTime.now()
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
        
        let result = BenchmarkResult(
            testName: name,
            duration: duration,
            metrics: metrics,
            status: status,
            iterations: 1
        )
        
        results.append(result)
        return result
    }
    
    // MARK: - Advanced Dashboard Integration
    
    /// Generate dashboard visualization data from benchmark results
    public func generateDashboardVisualizationData(
        visualizationManager: DashboardVisualizationManager? = nil
    ) -> [String: Any] {
        
        var dashboardData: [String: Any] = [:]
        
        // Performance metrics overview
        let latestMetrics = extractLatestPerformanceMetrics()
        dashboardData["performance_metrics"] = latestMetrics
        
        // Benchmark results summary
        let resultsSummary = generateBenchmarkResultsSummary()
        dashboardData["benchmark_summary"] = resultsSummary
        
        // WebSocket performance data
        if let wsData = generateWebSocketDashboardData() {
            dashboardData["websocket_performance"] = wsData
        }
        
        // Historical trends
        let historicalData = generateHistoricalTrendsData()
        dashboardData["historical_trends"] = historicalData
        
        // Performance comparison
        let comparisonData = generatePerformanceComparisonData()
        dashboardData["performance_comparison"] = comparisonData
        
        return dashboardData
    }
    
    /// Extract latest performance metrics for dashboard
    private func extractLatestPerformanceMetrics() -> [String: Double] {
        guard let latestResult = results.last else {
            return [:]
        }
        
        return [
            "latency": latestResult.metrics.renderTimeMs ?? 0.0,
            "memory_usage": latestResult.metrics.memoryUsageMB,
            "cpu_usage": latestResult.metrics.cpuUsage,
            "duration": latestResult.duration * 1000, // Convert to ms
            "timestamp": latestResult.metrics.timestamp
        ]
    }
    
    /// Generate benchmark results summary
    private func generateBenchmarkResultsSummary() -> [String: Any] {
        let totalBenchmarks = results.count
        let passedBenchmarks = results.filter { $0.status == .passed }.count
        let failedBenchmarks = results.filter { $0.status == .failed }.count
        
        let averageDuration = results.isEmpty ? 0.0 : results.map(\.duration).reduce(0, +) / Double(results.count)
        let averageMemory = results.isEmpty ? 0.0 : results.map(\.metrics.memoryUsageMB).reduce(0, +) / Double(results.count)
        
        return [
            "total_benchmarks": totalBenchmarks,
            "passed_benchmarks": passedBenchmarks,
            "failed_benchmarks": failedBenchmarks,
            "success_rate": totalBenchmarks > 0 ? Double(passedBenchmarks) / Double(totalBenchmarks) * 100 : 0.0,
            "average_duration_ms": averageDuration * 1000,
            "average_memory_mb": averageMemory
        ]
    }
    
    /// Generate WebSocket-specific dashboard data
    private func generateWebSocketDashboardData() -> [String: Any]? {
        // Filter WebSocket-related results
        let wsResults = results.filter { $0.testName.contains("websocket") || $0.testName.contains("WebSocket") }
        
        guard !wsResults.isEmpty else { return nil }
        
        let latencies = wsResults.compactMap { $0.metrics.renderTimeMs }
        let memoryUsages = wsResults.map { $0.metrics.memoryUsageMB }
        
        let averageLatency = latencies.isEmpty ? 0.0 : latencies.reduce(0, +) / Double(latencies.count)
        let maxLatency = latencies.max() ?? 0.0
        let minLatency = latencies.min() ?? 0.0
        
        let averageMemory = memoryUsages.isEmpty ? 0.0 : memoryUsages.reduce(0, +) / Double(memoryUsages.count)
        let maxMemory = memoryUsages.max() ?? 0.0
        
        return [
            "total_websocket_tests": wsResults.count,
            "average_latency_ms": averageLatency,
            "max_latency_ms": maxLatency,
            "min_latency_ms": minLatency,
            "average_memory_mb": averageMemory,
            "max_memory_mb": maxMemory,
            "connection_success_rate": calculateWebSocketSuccessRate(wsResults)
        ]
    }
    
    /// Calculate WebSocket connection success rate
    private func calculateWebSocketSuccessRate(_ wsResults: [BenchmarkResult]) -> Double {
        let successfulTests = wsResults.filter { $0.status == .passed }.count
        return wsResults.isEmpty ? 0.0 : Double(successfulTests) / Double(wsResults.count) * 100
    }
    
    /// Generate historical trends data for dashboard
    private func generateHistoricalTrendsData() -> [[String: Any]] {
        let recentResults = Array(results.suffix(20)) // Last 20 results
        
        return recentResults.enumerated().map { index, result in
            [
                "sequence": index,
                "timestamp": result.metrics.timestamp,
                "latency": result.metrics.renderTimeMs ?? 0.0,
                "memory": result.metrics.memoryUsageMB,
                "cpu": result.metrics.cpuUsage,
                "duration": result.duration * 1000,
                "status": result.status.rawValue,
                "test_name": result.testName
            ]
        }
    }
    
    /// Generate performance comparison data
    private func generatePerformanceComparisonData() -> [String: Any] {
        guard results.count >= 2 else {
            return [:]
        }
        
        let recentResults = Array(results.suffix(10))
        let olderResults = results.count > 20 ? Array(results.suffix(20).prefix(10)) : []
        
        let recentAvgLatency = calculateAverageLatency(recentResults)
        let recentAvgMemory = calculateAverageMemory(recentResults)
        
        let olderAvgLatency = olderResults.isEmpty ? recentAvgLatency : calculateAverageLatency(olderResults)
        let olderAvgMemory = olderResults.isEmpty ? recentAvgMemory : calculateAverageMemory(olderResults)
        
        let latencyImprovement = olderAvgLatency > 0 ? ((olderAvgLatency - recentAvgLatency) / olderAvgLatency) * 100 : 0
        let memoryImprovement = olderAvgMemory > 0 ? ((olderAvgMemory - recentAvgMemory) / olderAvgMemory) * 100 : 0
        
        return [
            "recent_period": [
                "average_latency_ms": recentAvgLatency,
                "average_memory_mb": recentAvgMemory,
                "test_count": recentResults.count
            ],
            "baseline_period": [
                "average_latency_ms": olderAvgLatency,
                "average_memory_mb": olderAvgMemory,
                "test_count": olderResults.count
            ],
            "improvements": [
                "latency_improvement_percent": latencyImprovement,
                "memory_improvement_percent": memoryImprovement,
                "overall_trend": latencyImprovement > 0 && memoryImprovement > 0 ? "improving" : "mixed"
            ]
        ]
    }
    
    private func calculateAverageLatency(_ results: [BenchmarkResult]) -> Double {
        let latencies = results.compactMap { $0.metrics.renderTimeMs }
        return latencies.isEmpty ? 0.0 : latencies.reduce(0, +) / Double(latencies.count)
    }
    
    private func calculateAverageMemory(_ results: [BenchmarkResult]) -> Double {
        let memories = results.map { $0.metrics.memoryUsageMB }
        return memories.isEmpty ? 0.0 : memories.reduce(0, +) / Double(memories.count)
    }
    
    /// Export benchmark data for dashboard consumption
    public func exportForDashboard(format: String = "json") -> String? {
        let dashboardData = generateDashboardVisualizationData()
        
        switch format.lowercased() {
        case "json":
            return exportAsJSON(dashboardData)
        case "csv":
            return exportAsCSV(dashboardData)
        default:
            return exportAsJSON(dashboardData)
        }
    }
    
    private func exportAsJSON(_ data: [String: Any]) -> String? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            logger.error("Failed to export dashboard data as JSON: \(error)")
            return nil
        }
    }
    
    private func exportAsCSV(_ data: [String: Any]) -> String? {
        var csvContent = "Metric,Value\n"
        
        // Flatten the nested dictionary for CSV format
        func flattenDictionary(_ dict: [String: Any], prefix: String = "") {
            for (key, value) in dict {
                let fullKey = prefix.isEmpty ? key : "\(prefix)_\(key)"
                
                if let nestedDict = value as? [String: Any] {
                    flattenDictionary(nestedDict, prefix: fullKey)
                } else if let arrayValue = value as? [Any] {
                    csvContent += "\(fullKey)_count,\(arrayValue.count)\n"
                } else {
                    csvContent += "\(fullKey),\(value)\n"
                }
            }
        }
        
        flattenDictionary(data)
        return csvContent
    }
    
    /// Integration with alerting system (commented out for Phase 3 simplicity)
    /*
    public func checkPerformanceThresholds(alertingSystem: PerformanceAlertingSystem?) async {
        guard let alertingSystem = alertingSystem else { return }
        
        let latestMetrics = extractLatestPerformanceMetrics()
        await alertingSystem.processMetrics(latestMetrics)
    }
    */
    
    /// Generate real-time performance data for visualization
    public func generateRealtimeVisualizationData() -> [String: Any] {
        let latestMetrics = extractLatestPerformanceMetrics()
        let wsData = generateWebSocketDashboardData()
        
        var realtimeData: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "current_metrics": latestMetrics
        ]
        
        if let wsData = wsData {
            realtimeData["websocket_status"] = wsData
        }
        
        // Add performance trends (last 5 results)
        let recentTrends = Array(results.suffix(5)).map { result in
            [
                "timestamp": result.metrics.timestamp,
                "latency": result.metrics.renderTimeMs ?? 0.0,
                "memory": result.metrics.memoryUsageMB,
                "status": result.status.rawValue
            ]
        }
        realtimeData["recent_trends"] = recentTrends
        
        return realtimeData
    }
}
