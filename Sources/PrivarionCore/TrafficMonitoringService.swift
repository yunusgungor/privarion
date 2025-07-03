import Foundation
import Network
import Combine
import Logging

/// Real-time traffic monitoring service for DNS filtering
/// Implements PATTERN-2025-049: Real-time Network Monitoring Pattern
@available(macOS 10.14, *)
internal class TrafficMonitoringService: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger: Logger
    
    /// Configuration manager
    private let configManager: ConfigurationManager
    
    /// Monitoring configuration
    private var config: NetworkMonitoringConfig {
        return configManager.getCurrentConfiguration().modules.networkFilter.monitoring
    }
    
    /// Real-time event stream
    private let eventStream = PassthroughSubject<TrafficEvent, Never>()
    
    /// Traffic statistics
    private var statistics: TrafficStatistics = TrafficStatistics()
    
    /// Statistics access queue
    private let statsQueue = DispatchQueue(label: "privarion.traffic.stats", attributes: .concurrent)
    
    /// Event buffer for batch processing
    private var eventBuffer: [TrafficEvent] = []
    private let bufferQueue = DispatchQueue(label: "privarion.traffic.buffer", qos: .utility)
    
    /// Timer for periodic statistics updates
    private var statisticsTimer: Timer?
    
    /// Active monitoring state
    private var isMonitoring: Bool = false
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Publishers
    
    /// Publisher for real-time traffic events
    internal var trafficEventPublisher: AnyPublisher<TrafficEvent, Never> {
        return eventStream.eraseToAnyPublisher()
    }
    
    /// Publisher for periodic statistics updates
    private let statisticsSubject = PassthroughSubject<TrafficStatistics, Never>()
    internal var statisticsPublisher: AnyPublisher<TrafficStatistics, Never> {
        return statisticsSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    internal init() {
        self.logger = Logger(label: "privarion.traffic.monitoring")
        self.configManager = ConfigurationManager.shared
        
        setupEventProcessing()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Start traffic monitoring
    internal func startMonitoring() {
        guard config.enabled else {
            logger.warning("Traffic monitoring is disabled in configuration")
            return
        }
        
        guard !isMonitoring else {
            logger.warning("Traffic monitoring is already running")
            return
        }
        
        isMonitoring = true
        
        // Start periodic statistics updates
        startStatisticsTimer()
        
        logger.info("Traffic monitoring started")
    }
    
    /// Stop traffic monitoring
    internal func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        
        // Stop periodic updates
        stopStatisticsTimer()
        
        // Process remaining buffered events
        processBufferedEvents()
        
        logger.info("Traffic monitoring stopped")
    }
    
    /// Record a DNS query event
    /// - Parameters:
    ///   - domain: The queried domain
    ///   - blocked: Whether the query was blocked
    ///   - source: Source application or process
    ///   - latency: Query processing latency
    ///   - reason: Blocking reason if applicable
    internal func recordDNSQuery(
        domain: String,
        blocked: Bool,
        source: TrafficSource? = nil,
        latency: TimeInterval,
        reason: BlockingReason? = nil
    ) {
        guard isMonitoring else { return }
        
        let event = TrafficEvent(
            id: UUID(),
            timestamp: Date(),
            type: .dnsQuery,
            domain: domain,
            blocked: blocked,
            source: source,
            latency: latency,
            reason: reason
        )
        
        // Update statistics
        updateStatistics(with: event)
        
        // Buffer event for batch processing
        bufferEvent(event)
        
        // Emit real-time event if enabled
        if config.logDNSQueries {
            eventStream.send(event)
        }
        
        // Log event if enabled
        if config.logDNSQueries {
            logTrafficEvent(event)
        }
    }
    
    /// Get current traffic statistics
    /// - Returns: Current statistics snapshot
    internal func getCurrentStatistics() -> TrafficStatistics {
        return statsQueue.sync { statistics }
    }
    
    /// Reset traffic statistics
    internal func resetStatistics() {
        statsQueue.async(flags: .barrier) {
            self.statistics = TrafficStatistics()
        }
        
        logger.info("Traffic statistics reset")
    }
    
    /// Get traffic events for a time period
    /// - Parameters:
    ///   - startTime: Start of time period
    ///   - endTime: End of time period
    /// - Returns: Array of traffic events in the time period
    internal func getEvents(from startTime: Date, to endTime: Date) -> [TrafficEvent] {
        return bufferQueue.sync {
            return eventBuffer.filter { event in
                event.timestamp >= startTime && event.timestamp <= endTime
            }
        }
    }
    
    /// Get top blocked domains
    /// - Parameter limit: Maximum number of domains to return
    /// - Returns: Array of domain names sorted by block count
    internal func getTopBlockedDomains(limit: Int = 10) -> [(domain: String, count: Int)] {
        return statsQueue.sync {
            return Array(statistics.blockedDomains.sorted { $0.value > $1.value }.prefix(limit))
                .map { (domain: $0.key, count: $0.value) }
        }
    }
    
    /// Get traffic volume by hour
    /// - Parameter hours: Number of hours to include (default: 24)
    /// - Returns: Array of hourly traffic counts
    internal func getTrafficVolumeByHour(hours: Int = 24) -> [(hour: Int, queries: Int, blocked: Int)] {
        let now = Date()
        let startTime = Calendar.current.date(byAdding: .hour, value: -hours, to: now) ?? now
        
        return bufferQueue.sync {
            var hourlyData: [Int: (queries: Int, blocked: Int)] = [:]
            
            for event in eventBuffer where event.timestamp >= startTime {
                let hour = Calendar.current.component(.hour, from: event.timestamp)
                let current = hourlyData[hour, default: (queries: 0, blocked: 0)]
                
                hourlyData[hour] = (
                    queries: current.queries + 1,
                    blocked: current.blocked + (event.blocked ? 1 : 0)
                )
            }
            
            return hourlyData.sorted { $0.key < $1.key }
                .map { (hour: $0.key, queries: $0.value.queries, blocked: $0.value.blocked) }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupEventProcessing() {
        // Setup real-time event processing pipeline
        trafficEventPublisher
            .buffer(size: 100, prefetch: .keepFull, whenFull: .dropOldest)
            .sink { [weak self] event in
                self?.processBatchedEvents([event])
            }
            .store(in: &cancellables)
    }
    
    private func updateStatistics(with event: TrafficEvent) {
        statsQueue.async(flags: .barrier) {
            self.statistics.totalQueries += 1
            
            if event.blocked {
                self.statistics.blockedQueries += 1
                self.statistics.blockedDomains[event.domain, default: 0] += 1
                
                if let reason = event.reason {
                    self.statistics.blockingReasons[reason, default: 0] += 1
                }
            } else {
                self.statistics.allowedQueries += 1
            }
            
            // Update latency statistics
            self.statistics.totalLatency += event.latency
            self.statistics.averageLatency = self.statistics.totalLatency / Double(self.statistics.totalQueries)
            
            if event.latency > self.statistics.maxLatency {
                self.statistics.maxLatency = event.latency
            }
            
            if self.statistics.minLatency == 0 || event.latency < self.statistics.minLatency {
                self.statistics.minLatency = event.latency
            }
            
            // Update source statistics if available
            if let source = event.source {
                self.statistics.sourceStatistics[source.identifier, default: SourceStatistics()].recordEvent(event)
            }
        }
    }
    
    private func bufferEvent(_ event: TrafficEvent) {
        bufferQueue.async {
            self.eventBuffer.append(event)
            
            // Keep buffer size manageable
            if self.eventBuffer.count > self.config.maxEventsInMemory {
                self.eventBuffer.removeFirst(self.eventBuffer.count - self.config.maxEventsInMemory)
            }
        }
    }
    
    private func processBatchedEvents(_ events: [TrafficEvent]) {
        // Process events in batches for performance
        logger.debug("Processing batch of \(events.count) traffic events")
        
        // Additional batch processing logic could go here
        // e.g., writing to persistent storage, triggering alerts, etc.
    }
    
    private func processBufferedEvents() {
        bufferQueue.async {
            if !self.eventBuffer.isEmpty {
                self.logger.debug("Processing \(self.eventBuffer.count) buffered events")
                // Process any remaining events
                // In a full implementation, this might write to disk or send to analytics
            }
        }
    }
    
    private func startStatisticsTimer() {
        statisticsTimer = Timer.scheduledTimer(withTimeInterval: config.metricsInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let currentStats = self.getCurrentStatistics()
            self.statisticsSubject.send(currentStats)
            
            self.logger.debug("Published statistics update", metadata: [
                "total_queries": "\(currentStats.totalQueries)",
                "blocked_queries": "\(currentStats.blockedQueries)",
                "block_rate": "\(String(format: "%.2f", currentStats.blockRate))%"
            ])
        }
    }
    
    private func stopStatisticsTimer() {
        statisticsTimer?.invalidate()
        statisticsTimer = nil
    }
    
    private func logTrafficEvent(_ event: TrafficEvent) {
        let logLevel: Logger.Level = event.blocked ? .info : .debug
        
        logger.log(level: logLevel, "DNS query event", metadata: [
            "domain": "\(event.domain)",
            "blocked": "\(event.blocked)",
            "latency_ms": "\(String(format: "%.2f", event.latency * 1000))",
            "source": "\(event.source?.identifier ?? "unknown")",
            "reason": "\(event.reason?.rawValue ?? "none")"
        ])
    }
}

// MARK: - Supporting Types

/// Traffic event representing a single network operation
internal struct TrafficEvent: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let type: TrafficEventType
    let domain: String
    let blocked: Bool
    let source: TrafficSource?
    let latency: TimeInterval
    let reason: BlockingReason?
}

/// Type of traffic event
internal enum TrafficEventType: String, Codable, CaseIterable {
    case dnsQuery = "dns_query"
    case httpRequest = "http_request"
    case httpsRequest = "https_request"
    case connectionBlocked = "connection_blocked"
}

/// Source of network traffic
internal struct TrafficSource: Codable {
    let identifier: String // Bundle ID, process name, or IP address
    let type: SourceType
    let processId: Int32?
    let executablePath: String?
}

/// Type of traffic source
internal enum SourceType: String, Codable, CaseIterable {
    case application = "application"
    case system = "system"
    case unknown = "unknown"
}

/// Reason for blocking traffic
internal enum BlockingReason: String, Codable, CaseIterable {
    case applicationRule = "application_rule"
    case domainBlocklist = "domain_blocklist"
    case categoryBlocklist = "category_blocklist"
    case ipBlocklist = "ip_blocklist"
    case malware = "malware"
    case phishing = "phishing"
    case tracking = "tracking"
    case advertising = "advertising"
    case customRule = "custom_rule"
}

/// Traffic statistics for monitoring and reporting
internal struct TrafficStatistics: Codable {
    var totalQueries: Int = 0
    var blockedQueries: Int = 0
    var allowedQueries: Int = 0
    
    var totalLatency: TimeInterval = 0
    var averageLatency: TimeInterval = 0
    var minLatency: TimeInterval = 0
    var maxLatency: TimeInterval = 0
    
    var blockedDomains: [String: Int] = [:]
    var blockingReasons: [BlockingReason: Int] = [:]
    var sourceStatistics: [String: SourceStatistics] = [:]
    
    var blockRate: Double {
        guard totalQueries > 0 else { return 0.0 }
        return Double(blockedQueries) / Double(totalQueries) * 100.0
    }
}

/// Statistics for a specific traffic source
internal struct SourceStatistics: Codable {
    var totalQueries: Int = 0
    var blockedQueries: Int = 0
    var averageLatency: TimeInterval = 0
    var lastActivity: Date = Date()
    
    mutating func recordEvent(_ event: TrafficEvent) {
        totalQueries += 1
        if event.blocked {
            blockedQueries += 1
        }
        
        // Update average latency
        averageLatency = (averageLatency * Double(totalQueries - 1) + event.latency) / Double(totalQueries)
        lastActivity = event.timestamp
    }
    
    var blockRate: Double {
        guard totalQueries > 0 else { return 0.0 }
        return Double(blockedQueries) / Double(totalQueries) * 100.0
    }
}
