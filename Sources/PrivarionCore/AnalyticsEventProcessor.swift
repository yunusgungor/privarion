import Foundation
import Combine
import Logging

/// Analytics event processor for real-time event processing and filtering
/// Implements event-driven architecture with efficient processing pipelines
public class AnalyticsEventProcessor {
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger = Logger(label: "privarion.analytics.processor")
    
    /// Configuration manager
    private let configManager: ConfigurationManager
    
    /// Analytics configuration
    private var config: NetworkAnalyticsConfig {
        return configManager.getCurrentConfiguration().modules.networkAnalytics
    }
    
    /// Processing state
    private var isProcessing: Bool = false
    
    /// Event processing queue
    private let processingQueue = DispatchQueue(label: "privarion.analytics.processing", qos: .utility)
    
    /// Event filters
    private var eventFilters: [AnalyticsEventFilter] = []
    
    /// Event processors
    private var eventProcessors: [AnalyticsEventType: [EventProcessor]] = [:]
    
    /// Event rate limiter
    private let rateLimiter = EventRateLimiter()
    
    /// Performance metrics
    private var performanceMetrics = ProcessorPerformanceMetrics()
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Publishers
    
    /// Publisher for processed analytics events
    public let eventPublisher = PassthroughSubject<AnalyticsEvent, Never>()
    
    /// Publisher for processing errors
    public let errorPublisher = PassthroughSubject<AnalyticsProcessingError, Never>()
    
    /// Publisher for performance metrics
    public let metricsPublisher = PassthroughSubject<ProcessorPerformanceMetrics, Never>()
    
    // MARK: - Initialization
    
    public init() {
        self.configManager = ConfigurationManager.shared
        setupDefaultFilters()
        setupDefaultProcessors()
        setupLogging()
    }
    
    // MARK: - Public Interface
    
    /// Start event processing
    public func start() {
        guard !isProcessing else {
            logger.warning("Event processor is already running")
            return
        }
        
        isProcessing = true
        rateLimiter.start()
        setupMetricsReporting()
        
        logger.info("Analytics event processor started")
    }
    
    /// Stop event processing
    public func stop() {
        guard isProcessing else {
            logger.warning("Event processor is not running")
            return
        }
        
        isProcessing = false
        rateLimiter.stop()
        cancellables.removeAll()
        
        logger.info("Analytics event processor stopped")
    }
    
    /// Process a raw network event
    public func processNetworkEvent(_ networkEvent: NetworkEvent) {
        guard isProcessing else { return }
        
        processingQueue.async { [weak self] in
            self?.handleNetworkEvent(networkEvent)
        }
    }
    
    /// Add custom event filter
    public func addFilter(_ filter: AnalyticsEventFilter) {
        processingQueue.async(flags: .barrier) { [weak self] in
            self?.eventFilters.append(filter)
            self?.logger.debug("Added event filter", metadata: [
                "filter_type": "\(type(of: filter))"
            ])
        }
    }
    
    /// Add custom event processor
    public func addProcessor(_ processor: EventProcessor, for eventType: AnalyticsEventType) {
        processingQueue.async(flags: .barrier) { [weak self] in
            self?.eventProcessors[eventType, default: []].append(processor)
            self?.logger.debug("Added event processor", metadata: [
                "processor_type": "\(type(of: processor))",
                "event_type": "\(eventType)"
            ])
        }
    }
    
    /// Get current performance metrics
    public func getCurrentPerformanceMetrics() -> ProcessorPerformanceMetrics {
        return processingQueue.sync {
            return performanceMetrics
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        logger.info("Initializing analytics event processor", metadata: [
            "version": "1.0.0",
            "real_time_processing": "\(config.realTimeProcessing)"
        ])
    }
    
    private func setupDefaultFilters() {
        // Add default filters
        eventFilters = [
            DataSizeFilter(minSize: 0, maxSize: 1_000_000_000), // 1GB max
            ApplicationFilter(allowedApplications: nil), // Allow all by default
            RateLimitFilter(maxEventsPerSecond: 1000)
        ]
    }
    
    private func setupDefaultProcessors() {
        // Setup default processors for each event type
        eventProcessors[.connection] = [ConnectionEventProcessor()]
        eventProcessors[.dnsQuery] = [DNSEventProcessor()]
        eventProcessors[.dataTransfer] = [DataTransferEventProcessor()]
        eventProcessors[.connectionClosed] = [ConnectionClosedEventProcessor()]
    }
    
    private func setupMetricsReporting() {
        Timer.publish(every: 60.0, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                self?.reportPerformanceMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func handleNetworkEvent(_ networkEvent: NetworkEvent) {
        let startTime = Date()
        
        do {
            // Convert to analytics event
            let analyticsEvent = try createAnalyticsEvent(from: networkEvent)
            
            // Apply filters
            if try applyFilters(to: analyticsEvent) {
                // Process with specific processors
                let processedEvent = try processEvent(analyticsEvent)
                
                // Apply rate limiting
                if rateLimiter.shouldAllow(event: processedEvent) {
                    // Publish processed event
                    eventPublisher.send(processedEvent)
                    
                    // Update performance metrics
                    updatePerformanceMetrics(
                        processingTime: Date().timeIntervalSince(startTime),
                        eventType: processedEvent.type,
                        success: true
                    )
                } else {
                    // Event was rate limited
                    updatePerformanceMetrics(
                        processingTime: Date().timeIntervalSince(startTime),
                        eventType: analyticsEvent.type,
                        rateLimited: true
                    )
                }
            } else {
                // Event was filtered out
                updatePerformanceMetrics(
                    processingTime: Date().timeIntervalSince(startTime),
                    eventType: analyticsEvent.type,
                    filtered: true
                )
            }
            
        } catch {
            // Processing error
            let processingError = AnalyticsProcessingError(
                networkEvent: networkEvent,
                error: error,
                timestamp: Date()
            )
            
            errorPublisher.send(processingError)
            
            updatePerformanceMetrics(
                processingTime: Date().timeIntervalSince(startTime),
                eventType: .dataTransfer, // Default
                error: error
            )
            
            logger.error("Failed to process network event", metadata: [
                "error": "\(error)",
                "event_type": "\(networkEvent.type)"
            ])
        }
    }
    
    private func createAnalyticsEvent(from networkEvent: NetworkEvent) throws -> AnalyticsEvent {
        return AnalyticsEvent(
            id: UUID(),
            timestamp: Date(),
            sessionId: nil, // Will be set by analytics engine
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
    
    private func applyFilters(to event: AnalyticsEvent) throws -> Bool {
        for filter in eventFilters {
            if !filter.shouldAllow(event: event) {
                return false
            }
        }
        return true
    }
    
    private func processEvent(_ event: AnalyticsEvent) throws -> AnalyticsEvent {
        var processedEvent = event
        
        // Convert AnalyticsEvent.EventType to AnalyticsEventType
        let eventType = mapAnalyticsEventType(event.type)
        
        // Apply type-specific processors
        if let processors = eventProcessors[eventType] {
            for processor in processors {
                processedEvent = try processor.process(event: processedEvent)
            }
        }
        
        return processedEvent
    }
    
    private func mapAnalyticsEventType(_ eventType: AnalyticsEvent.EventType) -> AnalyticsEventType {
        switch eventType {
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
    
    private func updatePerformanceMetrics(
        processingTime: TimeInterval,
        eventType: AnalyticsEvent.EventType,
        success: Bool = false,
        filtered: Bool = false,
        rateLimited: Bool = false,
        error: Error? = nil
    ) {
        performanceMetrics.totalEvents += 1
        performanceMetrics.totalProcessingTime += processingTime
        performanceMetrics.averageProcessingTime = performanceMetrics.totalProcessingTime / Double(performanceMetrics.totalEvents)
        
        if success {
            performanceMetrics.successfulEvents += 1
        } else if filtered {
            performanceMetrics.filteredEvents += 1
        } else if rateLimited {
            performanceMetrics.rateLimitedEvents += 1
        } else if error != nil {
            performanceMetrics.errorEvents += 1
        }
        
        // Update peak processing time
        if processingTime > performanceMetrics.peakProcessingTime {
            performanceMetrics.peakProcessingTime = processingTime
        }
        
        // Update event type metrics
        performanceMetrics.eventTypeMetrics[eventType, default: EventTypeMetrics()].update(
            processingTime: processingTime,
            success: success,
            error: error != nil
        )
    }
    
    private func reportPerformanceMetrics() {
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.metricsPublisher.send(self.performanceMetrics)
            
            self.logger.debug("Performance metrics reported", metadata: [
                "total_events": "\(self.performanceMetrics.totalEvents)",
                "success_rate": "\(self.performanceMetrics.successRate)",
                "average_processing_time": "\(self.performanceMetrics.averageProcessingTime)ms"
            ])
        }
    }
}

// MARK: - Supporting Types

/// Analytics event type
public enum AnalyticsEventType {
    case connection
    case dnsQuery
    case dataTransfer
    case connectionClosed
}

/// Event filter protocol
public protocol AnalyticsEventFilter {
    func shouldAllow(event: AnalyticsEvent) -> Bool
}

/// Event processor protocol
public protocol EventProcessor {
    func process(event: AnalyticsEvent) throws -> AnalyticsEvent
}

/// Analytics processing error
public struct AnalyticsProcessingError {
    public let networkEvent: NetworkEvent
    public let error: Error
    public let timestamp: Date
}

/// Processor performance metrics
public struct ProcessorPerformanceMetrics {
    public var totalEvents: UInt64 = 0
    public var successfulEvents: UInt64 = 0
    public var errorEvents: UInt64 = 0
    public var filteredEvents: UInt64 = 0
    public var rateLimitedEvents: UInt64 = 0
    public var totalProcessingTime: TimeInterval = 0
    public var averageProcessingTime: TimeInterval = 0
    public var peakProcessingTime: TimeInterval = 0
    public var eventTypeMetrics: [AnalyticsEvent.EventType: EventTypeMetrics] = [:]
    
    public var successRate: Double {
        guard totalEvents > 0 else { return 0 }
        return Double(successfulEvents) / Double(totalEvents) * 100
    }
}

/// Event type specific metrics
public struct EventTypeMetrics {
    public var count: UInt64 = 0
    public var successCount: UInt64 = 0
    public var errorCount: UInt64 = 0
    public var totalProcessingTime: TimeInterval = 0
    public var averageProcessingTime: TimeInterval = 0
    
    mutating func update(processingTime: TimeInterval, success: Bool, error: Bool) {
        count += 1
        totalProcessingTime += processingTime
        averageProcessingTime = totalProcessingTime / Double(count)
        
        if success {
            successCount += 1
        } else if error {
            errorCount += 1
        }
    }
}

// MARK: - Default Filter Implementations

/// Data size filter
private class DataSizeFilter: AnalyticsEventFilter {
    private let minSize: UInt64
    private let maxSize: UInt64
    
    init(minSize: UInt64, maxSize: UInt64) {
        self.minSize = minSize
        self.maxSize = maxSize
    }
    
    func shouldAllow(event: AnalyticsEvent) -> Bool {
        return event.dataSize >= minSize && event.dataSize <= maxSize
    }
}

/// Application filter
private class ApplicationFilter: AnalyticsEventFilter {
    private let allowedApplications: Set<String>?
    
    init(allowedApplications: Set<String>?) {
        self.allowedApplications = allowedApplications
    }
    
    func shouldAllow(event: AnalyticsEvent) -> Bool {
        guard let allowedApps = allowedApplications else { return true }
        guard let eventApp = event.application else { return false }
        return allowedApps.contains(eventApp)
    }
}

/// Rate limit filter
private class RateLimitFilter: AnalyticsEventFilter {
    private let maxEventsPerSecond: Int
    private var eventTimes: [Date] = []
    private let lock = NSLock()
    
    init(maxEventsPerSecond: Int) {
        self.maxEventsPerSecond = maxEventsPerSecond
    }
    
    func shouldAllow(event: AnalyticsEvent) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let oneSecondAgo = now.addingTimeInterval(-1.0)
        
        // Remove old entries
        eventTimes = eventTimes.filter { $0 >= oneSecondAgo }
        
        // Check if we're under the limit
        if eventTimes.count < maxEventsPerSecond {
            eventTimes.append(now)
            return true
        }
        
        return false
    }
}

// MARK: - Default Processor Implementations

/// Connection event processor
private class ConnectionEventProcessor: EventProcessor {
    func process(event: AnalyticsEvent) throws -> AnalyticsEvent {
        // Add connection-specific processing logic here
        return event
    }
}

/// DNS event processor
private class DNSEventProcessor: EventProcessor {
    func process(event: AnalyticsEvent) throws -> AnalyticsEvent {
        // Add DNS-specific processing logic here
        return event
    }
}

/// Data transfer event processor
private class DataTransferEventProcessor: EventProcessor {
    func process(event: AnalyticsEvent) throws -> AnalyticsEvent {
        // Add data transfer-specific processing logic here
        return event
    }
}

/// Connection closed event processor
private class ConnectionClosedEventProcessor: EventProcessor {
    func process(event: AnalyticsEvent) throws -> AnalyticsEvent {
        // Add connection closed-specific processing logic here
        return event
    }
}

/// Event rate limiter
private class EventRateLimiter {
    private var isRunning = false
    
    func start() {
        isRunning = true
    }
    
    func stop() {
        isRunning = false
    }
    
    func shouldAllow(event: AnalyticsEvent) -> Bool {
        return isRunning
    }
}
