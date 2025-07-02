import Foundation
import Network
import Combine
import Logging

/// Network analytics engine for advanced traffic analysis and metrics collection
/// Implements PATTERN-2025-022: Real-time Monitoring with Efficient Aggregation
public class NetworkAnalyticsEngine {
    
    // MARK: - Properties
    
    /// Shared singleton instance
    public static let shared = NetworkAnalyticsEngine()
    
    /// Logger instance
    private let logger = Logger(label: "privarion.network.analytics")
    
    /// Configuration manager
    private let configManager: ConfigurationManager
    
    /// Analytics configuration
    private var config: NetworkAnalyticsConfig {
        return configManager.getCurrentConfiguration().modules.networkAnalytics
    }
    
    /// Metrics collector
    private let metricsCollector: MetricsCollector
    
    /// Time series storage
    private let timeSeriesStorage: TimeSeriesStorage
    
    /// Real-time event processor
    private let eventProcessor: AnalyticsEventProcessor
    
    /// Analytics session state
    private var isActive: Bool = false
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Processing queue for analytics operations
    private let analyticsQueue = DispatchQueue(label: "privarion.analytics.processing", qos: .utility)
    
    /// Current analytics session ID
    private var currentSessionId: UUID?
    
    // MARK: - Publishers
    
    /// Publisher for real-time analytics events
    public let analyticsEventPublisher = PassthroughSubject<AnalyticsEvent, Never>()
    
    /// Publisher for aggregated metrics
    public let metricsPublisher = PassthroughSubject<AggregatedMetrics, Never>()
    
    // MARK: - Initialization
    
    private init() {
        self.configManager = ConfigurationManager.shared
        self.metricsCollector = MetricsCollector()
        self.timeSeriesStorage = TimeSeriesStorage()
        self.eventProcessor = AnalyticsEventProcessor()
        
        setupLogging()
        setupEventProcessing()
    }
    
    // MARK: - Public Interface
    
    /// Start analytics collection
    public func startAnalytics() throws {
        logger.info("Starting network analytics engine...")
        
        guard config.enabled else {
            throw AnalyticsError.analyticsDisabled
        }
        
        guard !isActive else {
            logger.warning("Analytics engine is already active")
            return
        }
        
        // Start new analytics session
        currentSessionId = UUID()
        isActive = true
        
        // Initialize components
        try metricsCollector.start()
        try timeSeriesStorage.initialize()
        eventProcessor.start()
        
        // Setup real-time processing if enabled
        if config.realTimeProcessing {
            setupRealTimeProcessing()
        }
        
        logger.info("Network analytics engine started successfully", metadata: [
            "session_id": "\(currentSessionId?.uuidString ?? "unknown")",
            "real_time_processing": "\(config.realTimeProcessing)"
        ])
    }
    
    /// Stop analytics collection
    public func stopAnalytics() {
        logger.info("Stopping network analytics engine...")
        
        guard isActive else {
            logger.warning("Analytics engine is not active")
            return
        }
        
        // Stop components
        metricsCollector.stop()
        eventProcessor.stop()
        
        // Clear subscriptions
        cancellables.removeAll()
        
        // Mark as inactive
        isActive = false
        currentSessionId = nil
        
        logger.info("Network analytics engine stopped")
    }
    
    /// Process a network event for analytics
    public func processNetworkEvent(_ event: NetworkEvent) {
        guard isActive && config.enabled else { return }
        
        analyticsQueue.async { [weak self] in
            self?.handleNetworkEvent(event)
        }
    }
    
    /// Get current analytics metrics
    public func getCurrentMetrics() -> AnalyticsSnapshot {
        return AnalyticsSnapshot(
            sessionId: currentSessionId,
            timestamp: Date(),
            bandwidth: metricsCollector.getBandwidthMetrics(),
            connections: metricsCollector.getConnectionMetrics(),
            dns: metricsCollector.getDNSMetrics(),
            applications: metricsCollector.getApplicationMetrics()
        )
    }
    
    /// Export analytics data
    public func exportAnalytics(format: AnalyticsExportFormat, timeRange: DateInterval? = nil) throws -> Data {
        guard config.export.enabled else {
            throw AnalyticsError.exportDisabled
        }
        
        let data = try timeSeriesStorage.exportData(format: format, timeRange: timeRange)
        
        logger.info("Analytics data exported", metadata: [
            "format": "\(format.rawValue)",
            "data_size": "\(data.count) bytes"
        ])
        
        return data
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        logger.info("Initializing network analytics engine", metadata: [
            "version": "1.0.0",
            "analytics_enabled": "\(config.enabled)",
            "real_time_processing": "\(config.realTimeProcessing)"
        ])
    }
    
    private func setupEventProcessing() {
        // Setup event processing pipeline
        eventProcessor.eventPublisher
            .receive(on: analyticsQueue)
            .sink { [weak self] event in
                self?.handleProcessedEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func setupRealTimeProcessing() {
        // Setup real-time metrics aggregation
        Timer.publish(every: 60.0, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performRealTimeAggregation()
            }
            .store(in: &cancellables)
        
        logger.debug("Real-time processing enabled with 60-second intervals")
    }
    
    private func handleNetworkEvent(_ event: NetworkEvent) {
        do {
            // Create analytics event
            let analyticsEvent = try createAnalyticsEvent(from: event)
            
            // Store in time series
            timeSeriesStorage.store(event: analyticsEvent)
            
            // Update metrics
            metricsCollector.update(with: analyticsEvent)
            
            // Publish for real-time consumption
            if config.realTimeProcessing {
                analyticsEventPublisher.send(analyticsEvent)
            }
            
        } catch {
            logger.error("Failed to process network event", metadata: [
                "error": "\(error)",
                "event_type": "\(event.type)"
            ])
        }
    }
    
    private func handleProcessedEvent(_ event: AnalyticsEvent) {
        // Additional processing for complex analytics
        logger.debug("Processed analytics event", metadata: [
            "event_id": "\(event.id)",
            "event_type": "\(event.type)"
        ])
    }
    
    private func performRealTimeAggregation() {
        analyticsQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let aggregated = try self.metricsCollector.aggregateMetrics()
                self.metricsPublisher.send(aggregated)
                
                self.logger.debug("Real-time metrics aggregated", metadata: [
                    "bandwidth_mbps": "\(aggregated.bandwidth.totalMbps)",
                    "active_connections": "\(aggregated.connections.activeCount)"
                ])
                
            } catch {
                self.logger.error("Failed to aggregate real-time metrics", metadata: [
                    "error": "\(error)"
                ])
            }
        }
    }
    
    private func createAnalyticsEvent(from networkEvent: NetworkEvent) throws -> AnalyticsEvent {
        return AnalyticsEvent(
            id: UUID(),
            timestamp: Date(),
            sessionId: currentSessionId,
            type: mapNetworkEventType(networkEvent.type),
            source: networkEvent.source,
            destination: networkEvent.destination,
            protocol: networkEvent.`protocol`,
            dataSize: networkEvent.dataSize,
            duration: networkEvent.duration,
            application: networkEvent.application,
            metadata: networkEvent.metadata
        )
    }
    
    private func mapNetworkEventType(_ networkType: NetworkEvent.EventType) -> AnalyticsEvent.EventType {
        switch networkType {
        case .connection:
            return .connection
        case .dnsQuery:
            return .dnsQuery
        case .dataTransfer:
            return .dataTransfer
        case .connectionClosed:
            return .connectionClosed
        }
    }
}

// MARK: - Supporting Types

/// Analytics error cases
public enum AnalyticsError: Error, LocalizedError {
    case analyticsDisabled
    case exportDisabled
    case storageError(String)
    case configurationError(String)
    case processingError(String)
    
    public var errorDescription: String? {
        switch self {
        case .analyticsDisabled:
            return "Network analytics is disabled in configuration"
        case .exportDisabled:
            return "Analytics export is disabled in configuration"
        case .storageError(let message):
            return "Analytics storage error: \(message)"
        case .configurationError(let message):
            return "Analytics configuration error: \(message)"
        case .processingError(let message):
            return "Analytics processing error: \(message)"
        }
    }
}

/// Network event structure for analytics input
public struct NetworkEvent {
    public let type: EventType
    public let source: NetworkEndpoint
    public let destination: NetworkEndpoint
    public let `protocol`: NetworkProtocol
    public let dataSize: UInt64
    public let duration: TimeInterval?
    public let application: String?
    public let metadata: [String: String] // Changed from [String: Any] to make it compatible
    
    public enum EventType {
        case connection
        case dnsQuery
        case dataTransfer
        case connectionClosed
    }
}

/// Network endpoint information
public struct NetworkEndpoint: Codable {
    public let address: String
    public let port: UInt16?
    public let hostname: String?
}

/// Network protocol information
public enum NetworkProtocol: String, Codable {
    case tcp = "tcp"
    case udp = "udp"
    case icmp = "icmp"
    case other = "other"
}

/// Analytics event structure for internal processing
public struct AnalyticsEvent: Codable {
    public let id: UUID
    public let timestamp: Date
    public let sessionId: UUID?
    public let type: EventType
    public let source: NetworkEndpoint
    public let destination: NetworkEndpoint
    public let `protocol`: NetworkProtocol
    public let dataSize: UInt64
    public let duration: TimeInterval?
    public let application: String?
    public let metadata: [String: String] // Changed from [String: Any] to make it Codable
    
    public enum EventType: String, Codable {
        case connection
        case dnsQuery
        case dataTransfer
        case connectionClosed
    }
}

/// Analytics snapshot for current metrics
public struct AnalyticsSnapshot: Codable {
    public let sessionId: UUID?
    public let timestamp: Date
    public let bandwidth: BandwidthMetrics
    public let connections: ConnectionMetrics
    public let dns: DNSMetrics
    public let applications: ApplicationMetrics
}

/// Aggregated metrics structure
public struct AggregatedMetrics {
    public let timestamp: Date
    public let interval: TimeInterval
    public let bandwidth: BandwidthMetrics
    public let connections: ConnectionMetrics
    public let dns: DNSMetrics
    public let applications: ApplicationMetrics
}
