import Foundation
import NIOCore
import NIOHTTP1
import NIOWebSocket
import os.log

/// Enterprise-grade dashboard visualization manager
/// Provides comprehensive chart generation and data export capabilities
public final class DashboardVisualizationManager: @unchecked Sendable {
    
    // MARK: - Visualization Configuration
    
    public struct VisualizationConfig: Sendable {
        let maxDataPoints: Int
        let updateInterval: TimeInterval
        let chartTypes: Set<ChartType>
        let enableHistoricalData: Bool
        let enableExport: Bool
        
        public init(
            maxDataPoints: Int = 1000,
            updateInterval: TimeInterval = 1.0,
            chartTypes: Set<ChartType> = [.line, .bar, .gauge, .heatmap],
            enableHistoricalData: Bool = true,
            enableExport: Bool = true
        ) {
            self.maxDataPoints = maxDataPoints
            self.updateInterval = updateInterval
            self.chartTypes = chartTypes
            self.enableHistoricalData = enableHistoricalData
            self.enableExport = enableExport
        }
    }
    
    public enum ChartType: String, CaseIterable, Sendable {
        case line = "line"
        case bar = "bar"
        case gauge = "gauge"
        case heatmap = "heatmap"
        case histogram = "histogram"
        case scatter = "scatter"
    }
    
    // MARK: - Visualization Data Models
    
    public struct ChartData: Codable, Sendable {
        let type: String
        let title: String
        let labels: [String]
        let datasets: [DataSet]
        let options: ChartOptions
        let timestamp: Date
        
        public init(type: String, title: String, labels: [String], datasets: [DataSet], options: ChartOptions) {
            self.type = type
            self.title = title
            self.labels = labels
            self.datasets = datasets
            self.options = options
            self.timestamp = Date()
        }
    }
    
    public struct DataSet: Codable, Sendable {
        let label: String
        let data: [Double]
        let backgroundColor: String?
        let borderColor: String?
        let borderWidth: Int?
        
        public init(label: String, data: [Double], backgroundColor: String? = nil, borderColor: String? = nil, borderWidth: Int? = 1) {
            self.label = label
            self.data = data
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.borderWidth = borderWidth
        }
    }
    
    public struct ChartOptions: Codable, Sendable {
        let responsive: Bool
        let maintainAspectRatio: Bool
        let animation: AnimationOptions
        let scales: ScaleOptions?
        
        public init(responsive: Bool = true, maintainAspectRatio: Bool = false, animation: AnimationOptions = AnimationOptions(), scales: ScaleOptions? = nil) {
            self.responsive = responsive
            self.maintainAspectRatio = maintainAspectRatio
            self.animation = animation
            self.scales = scales
        }
    }
    
    public struct AnimationOptions: Codable, Sendable {
        let duration: Int
        let easing: String
        
        public init(duration: Int = 1000, easing: String = "easeInOutQuart") {
            self.duration = duration
            self.easing = easing
        }
    }
    
    public struct ScaleOptions: Codable, Sendable {
        let y: AxisOptions?
        let x: AxisOptions?
        
        public init(y: AxisOptions? = nil, x: AxisOptions? = nil) {
            self.y = y
            self.x = x
        }
    }
    
    public struct AxisOptions: Codable, Sendable {
        let beginAtZero: Bool
        let min: Double?
        let max: Double?
        
        public init(beginAtZero: Bool = true, min: Double? = nil, max: Double? = nil) {
            self.beginAtZero = beginAtZero
            self.min = min
            self.max = max
        }
    }
    
    // MARK: - Historical Data Management
    
    public struct HistoricalDataPoint: Codable, Sendable {
        let timestamp: Date
        let metricName: String
        let value: Double
        let metadata: [String: String]
        
        public init(timestamp: Date, metricName: String, value: Double, metadata: [String: String] = [:]) {
            self.timestamp = timestamp
            self.metricName = metricName
            self.value = value
            self.metadata = metadata
        }
    }
    
    // MARK: - Properties
    
    private let config: VisualizationConfig
    private var historicalData: [String: [HistoricalDataPoint]] = [:]
    private let historicalDataLock = NSLock()
    
    // MARK: - Initialization
    
    public init(config: VisualizationConfig = VisualizationConfig()) {
        self.config = config
    }
    
    // MARK: - Performance Metrics Visualization
    
    /// Generate real-time performance chart data
    public func generatePerformanceChart(
        metrics: [String: Double],
        chartType: ChartType = .line,
        timeRange: TimeInterval = 300 // 5 minutes
    ) -> ChartData {
        
        let currentTime = Date()
        let timeLabels = generateTimeLabels(from: currentTime.addingTimeInterval(-timeRange), to: currentTime, interval: 30)
        
        var datasets: [DataSet] = []
        
        switch chartType {
        case .line:
            for (metricName, _) in metrics {
                let historicalValues = getHistoricalValues(for: metricName, in: timeRange)
                let dataset = DataSet(
                    label: metricName,
                    data: historicalValues,
                    backgroundColor: getColorForMetric(metricName, alpha: 0.2),
                    borderColor: getColorForMetric(metricName),
                    borderWidth: 2
                )
                datasets.append(dataset)
            }
            
        case .gauge:
            for (metricName, value) in metrics {
                let normalizedValue = normalizeValueForGauge(value, metricName: metricName)
                let dataset = DataSet(
                    label: metricName,
                    data: [normalizedValue, 100 - normalizedValue],
                    backgroundColor: getGaugeColors(for: normalizedValue)
                )
                datasets.append(dataset)
            }
            
        case .bar:
            let metricNames = Array(metrics.keys)
            let values = metricNames.map { metrics[$0] ?? 0.0 }
            let dataset = DataSet(
                label: "Current Performance",
                data: values,
                backgroundColor: nil // Simplified - single color will be handled by client
            )
            datasets.append(dataset)
            
        default:
            // Line chart as fallback
            for (metricName, _) in metrics {
                let historicalValues = getHistoricalValues(for: metricName, in: timeRange)
                let dataset = DataSet(
                    label: metricName,
                    data: historicalValues,
                    borderColor: getColorForMetric(metricName)
                )
                datasets.append(dataset)
            }
        }
        
        let options = ChartOptions(
            scales: ScaleOptions(
                y: AxisOptions(beginAtZero: true),
                x: AxisOptions()
            )
        )
        
        return ChartData(
            type: chartType.rawValue,
            title: "Performance Metrics - \(chartType.rawValue.capitalized)",
            labels: chartType == .gauge ? Array(metrics.keys) : timeLabels,
            datasets: datasets,
            options: options
        )
    }
    
    /// Generate load testing results visualization
    public func generateLoadTestChart(
        results: [(connections: Int, latency: Double, errorRate: Double)],
        chartType: ChartType = .line
    ) -> ChartData {
        
        let connectionLabels = results.map { "\($0.connections)" }
        
        let latencyDataset = DataSet(
            label: "Average Latency (ms)",
            data: results.map { $0.latency },
            backgroundColor: "rgba(54, 162, 235, 0.2)",
            borderColor: "rgba(54, 162, 235, 1)",
            borderWidth: 2
        )
        
        let errorRateDataset = DataSet(
            label: "Error Rate (%)",
            data: results.map { $0.errorRate * 100 },
            backgroundColor: "rgba(255, 99, 132, 0.2)",
            borderColor: "rgba(255, 99, 132, 1)",
            borderWidth: 2
        )
        
        let options = ChartOptions(
            scales: ScaleOptions(
                y: AxisOptions(beginAtZero: true)
            )
        )
        
        return ChartData(
            type: chartType.rawValue,
            title: "Load Testing Results",
            labels: connectionLabels,
            datasets: [latencyDataset, errorRateDataset],
            options: options
        )
    }
    
    /// Generate client connection heatmap
    public func generateConnectionHeatmap(
        connectionData: [String: Int], // IP -> connection count
        timeWindow: TimeInterval = 3600 // 1 hour
    ) -> ChartData {
        
        let sortedConnections = connectionData.sorted { $0.value > $1.value }
        let labels = sortedConnections.map { $0.key }
        let values = sortedConnections.map { Double($0.value) }
        
        let dataset = DataSet(
            label: "Connections per IP",
            data: values,
            backgroundColor: nil // Simplified - heatmap colors will be handled by client
        )
        
        return ChartData(
            type: ChartType.heatmap.rawValue,
            title: "Client Connection Heatmap",
            labels: labels,
            datasets: [dataset],
            options: ChartOptions()
        )
    }
    
    // MARK: - Historical Data Management
    
    /// Store performance data point for historical analysis
    public func storeDataPoint(_ point: HistoricalDataPoint) {
        guard config.enableHistoricalData else { return }
        
        historicalDataLock.lock()
        defer { historicalDataLock.unlock() }
        
        if historicalData[point.metricName] == nil {
            historicalData[point.metricName] = []
        }
        
        historicalData[point.metricName]?.append(point)
        
        // Limit data points to prevent memory issues
        if let count = historicalData[point.metricName]?.count, count > config.maxDataPoints {
            historicalData[point.metricName]?.removeFirst(count - config.maxDataPoints)
        }
        
        os_log("Stored data point: %{public}@ = %f", log: OSLog.default, type: .debug, point.metricName, point.value)
    }
    
    /// Retrieve historical data for metric in time range
    public func getHistoricalData(
        for metricName: String,
        from startTime: Date,
        to endTime: Date
    ) -> [HistoricalDataPoint] {
        
        historicalDataLock.lock()
        defer { historicalDataLock.unlock() }
        
        return historicalData[metricName]?.filter { point in
            point.timestamp >= startTime && point.timestamp <= endTime
        } ?? []
    }
    
    // MARK: - Export Functionality
    
    /// Export chart data to JSON
    public func exportChartData(_ chartData: ChartData) -> Data? {
        guard config.enableExport else { return nil }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(chartData)
        } catch {
            os_log("Failed to export chart data: %{public}@", log: OSLog.default, type: .error, error.localizedDescription)
            return nil
        }
    }
    
    /// Export historical data to CSV format
    public func exportHistoricalDataCSV(
        for metricName: String,
        timeRange: TimeInterval = 3600
    ) -> String? {
        guard config.enableExport else { return nil }
        
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-timeRange)
        let data = getHistoricalData(for: metricName, from: startTime, to: endTime)
        
        var csv = "Timestamp,Metric,Value,Metadata\n"
        
        for point in data {
            let metadataJson = (try? JSONSerialization.data(withJSONObject: point.metadata))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            
            csv += "\(ISO8601DateFormatter().string(from: point.timestamp)),\(point.metricName),\(point.value),\"\(metadataJson)\"\n"
        }
        
        return csv
    }
    
    // MARK: - Helper Methods
    
    private func generateTimeLabels(from startTime: Date, to endTime: Date, interval: TimeInterval) -> [String] {
        var labels: [String] = []
        var currentTime = startTime
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        
        while currentTime <= endTime {
            labels.append(formatter.string(from: currentTime))
            currentTime.addTimeInterval(interval)
        }
        
        return labels
    }
    
    private func getHistoricalValues(for metricName: String, in timeRange: TimeInterval) -> [Double] {
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-timeRange)
        let points = getHistoricalData(for: metricName, from: startTime, to: endTime)
        
        // Group by time intervals and average values
        let interval: TimeInterval = 30 // 30 second intervals
        var values: [Double] = []
        var currentTime = startTime
        
        while currentTime <= endTime {
            let intervalEnd = currentTime.addingTimeInterval(interval)
            let intervalPoints = points.filter { $0.timestamp >= currentTime && $0.timestamp < intervalEnd }
            
            let averageValue = intervalPoints.isEmpty ? 0.0 : intervalPoints.map(\.value).reduce(0, +) / Double(intervalPoints.count)
            values.append(averageValue)
            
            currentTime = intervalEnd
        }
        
        return values
    }
    
    private func getColorForMetric(_ metricName: String, alpha: Double = 1.0) -> String {
        let colors = [
            "latency": "rgba(255, 99, 132, \(alpha))",
            "throughput": "rgba(54, 162, 235, \(alpha))",
            "memory": "rgba(255, 205, 86, \(alpha))",
            "cpu": "rgba(75, 192, 192, \(alpha))",
            "connections": "rgba(153, 102, 255, \(alpha))",
            "errors": "rgba(255, 159, 64, \(alpha))"
        ]
        
        let key = metricName.lowercased()
        for (metric, color) in colors {
            if key.contains(metric) {
                return color
            }
        }
        
        return "rgba(128, 128, 128, \(alpha))" // Default gray
    }
    
    private func getColorForValue(_ value: Double) -> String {
        // Color based on performance (green = good, yellow = warning, red = bad)
        if value <= 50 {
            return "rgba(75, 192, 192, 0.8)" // Green
        } else if value <= 100 {
            return "rgba(255, 205, 86, 0.8)" // Yellow
        } else {
            return "rgba(255, 99, 132, 0.8)" // Red
        }
    }
    
    private func getGaugeColors(for value: Double) -> String {
        if value <= 60 {
            return "rgba(75, 192, 192, 0.8)" // Green
        } else if value <= 80 {
            return "rgba(255, 205, 86, 0.8)" // Yellow
        } else {
            return "rgba(255, 99, 132, 0.8)" // Red
        }
    }
    
    private func getHeatmapColor(for value: Double, max: Double) -> String {
        let intensity = value / max
        let red = Int(255 * intensity)
        let alpha = 0.3 + (0.7 * intensity)
        return "rgba(\(red), 100, 100, \(alpha))"
    }
    
    private func normalizeValueForGauge(_ value: Double, metricName: String) -> Double {
        // Normalize different metrics to 0-100 scale for gauge display
        switch metricName.lowercased() {
        case let name where name.contains("latency"):
            // Latency: 0-100ms -> 0-100
            return min(100, value)
        case let name where name.contains("memory"):
            // Memory: 0-100% -> 0-100
            return min(100, value)
        case let name where name.contains("cpu"):
            // CPU: 0-100% -> 0-100
            return min(100, value)
        case let name where name.contains("error"):
            // Error rate: 0-1 -> 0-100
            return min(100, value * 100)
        default:
            return min(100, value)
        }
    }
}

// MARK: - Dashboard Integration Extensions

extension DashboardVisualizationManager {
    
    /// Generate comprehensive dashboard data package
    public func generateDashboardPackage(
        performanceMetrics: [String: Double],
        loadTestResults: [(connections: Int, latency: Double, errorRate: Double)] = [],
        connectionData: [String: Int] = [:]
    ) -> [String: ChartData] {
        
        var charts: [String: ChartData] = [:]
        
        // Performance line chart
        charts["performance_line"] = generatePerformanceChart(
            metrics: performanceMetrics,
            chartType: .line
        )
        
        // Performance gauge chart
        charts["performance_gauge"] = generatePerformanceChart(
            metrics: performanceMetrics,
            chartType: .gauge
        )
        
        // Load test results if available
        if !loadTestResults.isEmpty {
            charts["load_test"] = generateLoadTestChart(results: loadTestResults)
        }
        
        // Connection heatmap if available
        if !connectionData.isEmpty {
            charts["connection_heatmap"] = generateConnectionHeatmap(connectionData: connectionData)
        }
        
        os_log("Generated dashboard package with %d charts", log: OSLog.default, type: .info, charts.count)
        return charts
    }
}
