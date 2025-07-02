import Foundation
import Combine
import Logging

/// Metrics collector for network analytics
/// Implements efficient data aggregation following PATTERN-2025-022
public class MetricsCollector {
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger = Logger(label: "privarion.analytics.metrics")
    
    /// Current bandwidth metrics
    private var bandwidthMetrics = BandwidthMetrics()
    
    /// Current connection metrics
    private var connectionMetrics = ConnectionMetrics()
    
    /// Current DNS metrics
    private var dnsMetrics = DNSMetrics()
    
    /// Current application metrics
    private var applicationMetrics = ApplicationMetrics()
    
    /// Metrics collection state
    private var isCollecting: Bool = false
    
    /// Metrics access queue
    private let metricsQueue = DispatchQueue(label: "privarion.metrics.access", attributes: .concurrent)
    
    /// Aggregation timer
    private var aggregationTimer: Timer?
    
    // MARK: - Public Interface
    
    /// Start metrics collection
    public func start() throws {
        guard !isCollecting else {
            logger.warning("Metrics collection is already active")
            return
        }
        
        isCollecting = true
        resetMetrics()
        startAggregationTimer()
        
        logger.info("Metrics collection started")
    }
    
    /// Stop metrics collection
    public func stop() {
        guard isCollecting else {
            logger.warning("Metrics collection is not active")
            return
        }
        
        isCollecting = false
        stopAggregationTimer()
        
        logger.info("Metrics collection stopped")
    }
    
    /// Update metrics with analytics event
    public func update(with event: AnalyticsEvent) {
        guard isCollecting else { return }
        
        metricsQueue.async(flags: .barrier) { [weak self] in
            self?.updateMetrics(with: event)
        }
    }
    
    /// Get current bandwidth metrics
    public func getBandwidthMetrics() -> BandwidthMetrics {
        return metricsQueue.sync {
            return bandwidthMetrics
        }
    }
    
    /// Get current connection metrics
    public func getConnectionMetrics() -> ConnectionMetrics {
        return metricsQueue.sync {
            return connectionMetrics
        }
    }
    
    /// Get current DNS metrics
    public func getDNSMetrics() -> DNSMetrics {
        return metricsQueue.sync {
            return dnsMetrics
        }
    }
    
    /// Get current application metrics
    public func getApplicationMetrics() -> ApplicationMetrics {
        return metricsQueue.sync {
            return applicationMetrics
        }
    }
    
    /// Aggregate all current metrics
    public func aggregateMetrics() throws -> AggregatedMetrics {
        return metricsQueue.sync {
            return AggregatedMetrics(
                timestamp: Date(),
                interval: 60.0, // 1 minute default
                bandwidth: bandwidthMetrics,
                connections: connectionMetrics,
                dns: dnsMetrics,
                applications: applicationMetrics
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func resetMetrics() {
        metricsQueue.async(flags: .barrier) { [weak self] in
            self?.bandwidthMetrics = BandwidthMetrics()
            self?.connectionMetrics = ConnectionMetrics()
            self?.dnsMetrics = DNSMetrics()
            self?.applicationMetrics = ApplicationMetrics()
        }
    }
    
    private func updateMetrics(with event: AnalyticsEvent) {
        _ = event.timestamp // Acknowledge timestamp without using it
        
        // Update bandwidth metrics
        updateBandwidthMetrics(with: event)
        
        // Update connection metrics
        updateConnectionMetrics(with: event)
        
        // Update DNS metrics
        if event.type == .dnsQuery {
            updateDNSMetrics(with: event)
        }
        
        // Update application metrics
        if let application = event.application {
            updateApplicationMetrics(with: event, application: application)
        }
        
        logger.debug("Metrics updated", metadata: [
            "event_type": "\(event.type)",
            "data_size": "\(event.dataSize)",
            "application": "\(event.application ?? "unknown")"
        ])
    }
    
    private func updateBandwidthMetrics(with event: AnalyticsEvent) {
        bandwidthMetrics.totalBytes += event.dataSize
        bandwidthMetrics.lastUpdated = event.timestamp
        
        // Calculate current throughput (bytes per second)
        let timeInterval = event.timestamp.timeIntervalSince(bandwidthMetrics.windowStart)
        if timeInterval > 0 {
            bandwidthMetrics.currentBytesPerSecond = Double(bandwidthMetrics.totalBytes) / timeInterval
            bandwidthMetrics.totalMbps = (bandwidthMetrics.currentBytesPerSecond * 8) / 1_000_000 // Convert to Mbps
        }
        
        // Update peak metrics
        if bandwidthMetrics.currentBytesPerSecond > bandwidthMetrics.peakBytesPerSecond {
            bandwidthMetrics.peakBytesPerSecond = bandwidthMetrics.currentBytesPerSecond
            bandwidthMetrics.peakMbps = bandwidthMetrics.totalMbps
        }
    }
    
    private func updateConnectionMetrics(with event: AnalyticsEvent) {
        switch event.type {
        case .connection:
            connectionMetrics.totalConnections += 1
            connectionMetrics.activeCount += 1
            connectionMetrics.lastUpdated = event.timestamp
            
        case .connectionClosed:
            connectionMetrics.activeCount = max(0, connectionMetrics.activeCount - 1)
            connectionMetrics.lastUpdated = event.timestamp
            
        default:
            break
        }
        
        // Update peak active connections
        if connectionMetrics.activeCount > connectionMetrics.peakActiveConnections {
            connectionMetrics.peakActiveConnections = connectionMetrics.activeCount
        }
    }
    
    private func updateDNSMetrics(with event: AnalyticsEvent) {
        dnsMetrics.totalQueries += 1
        dnsMetrics.lastUpdated = event.timestamp
        
        // Track query by domain
        if let hostname = event.destination.hostname {
            dnsMetrics.queriesByDomain[hostname, default: 0] += 1
        }
        
        // Calculate queries per second
        let timeInterval = event.timestamp.timeIntervalSince(dnsMetrics.windowStart)
        if timeInterval > 0 {
            dnsMetrics.queriesPerSecond = Double(dnsMetrics.totalQueries) / timeInterval
        }
    }
    
    private func updateApplicationMetrics(with event: AnalyticsEvent, application: String) {
        var appMetric = applicationMetrics.applicationData[application] ?? ApplicationMetric(name: application)
        
        appMetric.totalBytes += event.dataSize
        appMetric.eventCount += 1
        appMetric.lastActivity = event.timestamp
        
        // Update connection count for this app
        if event.type == .connection {
            appMetric.connectionCount += 1
        }
        
        applicationMetrics.applicationData[application] = appMetric
        applicationMetrics.lastUpdated = event.timestamp
    }
    
    private func startAggregationTimer() {
        aggregationTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.performPeriodicAggregation()
        }
    }
    
    private func stopAggregationTimer() {
        aggregationTimer?.invalidate()
        aggregationTimer = nil
    }
    
    private func performPeriodicAggregation() {
        metricsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Reset time-based metrics for next window
            let now = Date()
            
            self.bandwidthMetrics.windowStart = now
            self.dnsMetrics.windowStart = now
            
            self.logger.debug("Periodic metrics aggregation completed")
        }
    }
}

// MARK: - Metrics Structures

/// Bandwidth usage metrics
public struct BandwidthMetrics: Codable {
    public var totalBytes: UInt64 = 0
    public var currentBytesPerSecond: Double = 0
    public var peakBytesPerSecond: Double = 0
    public var totalMbps: Double = 0
    public var peakMbps: Double = 0
    public var windowStart: Date = Date()
    public var lastUpdated: Date = Date()
}

/// Connection metrics
public struct ConnectionMetrics: Codable {
    public var totalConnections: UInt64 = 0
    public var activeCount: Int = 0
    public var peakActiveConnections: Int = 0
    public var lastUpdated: Date = Date()
}

/// DNS query metrics
public struct DNSMetrics: Codable {
    public var totalQueries: UInt64 = 0
    public var queriesPerSecond: Double = 0
    public var queriesByDomain: [String: UInt64] = [:]
    public var windowStart: Date = Date()
    public var lastUpdated: Date = Date()
}

/// Application-specific metrics
public struct ApplicationMetrics: Codable {
    public var applicationData: [String: ApplicationMetric] = [:]
    public var lastUpdated: Date = Date()
}

/// Individual application metric
public struct ApplicationMetric: Codable {
    public let name: String
    public var totalBytes: UInt64 = 0
    public var eventCount: UInt64 = 0
    public var connectionCount: UInt64 = 0
    public var lastActivity: Date = Date()
    
    public init(name: String) {
        self.name = name
    }
}
