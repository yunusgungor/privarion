import Foundation
import Logging

/// Time series storage for analytics data
/// Implements efficient storage and retrieval of time-stamped analytics events
public class TimeSeriesStorage {
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger = Logger(label: "privarion.analytics.storage")
    
    /// Configuration manager for storage settings
    private let configManager: ConfigurationManager
    
    /// Storage configuration
    private var config: NetworkAnalyticsConfig {
        return configManager.getCurrentConfiguration().modules.networkAnalytics
    }
    
    /// In-memory storage for events
    private var memoryStorage: [TimeSeriesEntry] = []
    
    /// File system storage manager
    private var fileSystemStorage: FileSystemStorageManager?
    
    /// Storage access queue
    private let storageQueue = DispatchQueue(label: "privarion.storage.access", attributes: .concurrent)
    
    /// Storage initialization state
    private var isInitialized: Bool = false
    
    /// Storage file URL for file system backend
    private var storageFileURL: URL?
    
    // MARK: - Initialization
    
    public init() {
        self.configManager = ConfigurationManager.shared
        setupLogging()
    }
    
    // MARK: - Public Interface
    
    /// Initialize storage backend
    public func initialize() throws {
        guard !isInitialized else {
            logger.warning("Time series storage is already initialized")
            return
        }
        
        switch config.storageBackend {
        case .inMemory:
            try initializeInMemoryStorage()
            
        case .fileSystem:
            try initializeFileSystemStorage()
            
        case .hybrid:
            try initializeInMemoryStorage()
            try initializeFileSystemStorage()
        }
        
        isInitialized = true
        
        logger.info("Time series storage initialized", metadata: [
            "backend": "\(config.storageBackend.rawValue)",
            "retention_days": "\(config.dataRetentionDays)",
            "max_events": "\(config.maxEventsInMemory)"
        ])
    }
    
    /// Store an analytics event
    public func store(event: AnalyticsEvent) {
        guard isInitialized else {
            logger.error("Storage not initialized, cannot store event")
            return
        }
        
        storageQueue.async(flags: .barrier) { [weak self] in
            self?.storeEventInternal(event)
        }
    }
    
    /// Query events by time range
    public func query(
        timeRange: DateInterval,
        eventTypes: [AnalyticsEvent.EventType]? = nil,
        applications: [String]? = nil
    ) -> [AnalyticsEvent] {
        return storageQueue.sync {
            return queryEventsInternal(
                timeRange: timeRange,
                eventTypes: eventTypes,
                applications: applications
            )
        }
    }
    
    /// Get aggregated metrics for time range
    public func getAggregatedMetrics(
        timeRange: DateInterval,
        aggregationInterval: TimeInterval
    ) -> [AggregatedTimeSeriesMetrics] {
        return storageQueue.sync {
            return aggregateMetricsInternal(
                timeRange: timeRange,
                aggregationInterval: aggregationInterval
            )
        }
    }
    
    /// Export data in specified format
    public func exportData(
        format: AnalyticsExportFormat,
        timeRange: DateInterval? = nil
    ) throws -> Data {
        let events = storageQueue.sync {
            if let timeRange = timeRange {
                return queryEventsInternal(timeRange: timeRange)
            } else {
                return getAllEventsInternal()
            }
        }
        
        switch format {
        case .json:
            return try exportAsJSON(events: events)
        case .csv:
            return try exportAsCSV(events: events)
        case .jsonl:
            return try exportAsJSONL(events: events)
        }
    }
    
    /// Clean up old data based on retention policy
    public func cleanupOldData() {
        guard isInitialized else { return }
        
        storageQueue.async(flags: .barrier) { [weak self] in
            self?.performDataCleanup()
        }
    }
    
    /// Get storage statistics
    public func getStorageStats() -> StorageStatistics {
        return storageQueue.sync {
            return StorageStatistics(
                totalEvents: memoryStorage.count,
                memoryUsageBytes: estimateMemoryUsage(),
                oldestEventTimestamp: memoryStorage.first?.event.timestamp,
                newestEventTimestamp: memoryStorage.last?.event.timestamp,
                storageBackend: config.storageBackend
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        logger.info("Initializing time series storage", metadata: [
            "version": "1.0.0"
        ])
    }
    
    private func initializeInMemoryStorage() throws {
        memoryStorage.removeAll()
        memoryStorage.reserveCapacity(config.maxEventsInMemory)
        
        logger.debug("In-memory storage initialized", metadata: [
            "capacity": "\(config.maxEventsInMemory)"
        ])
    }
    
    private func initializeFileSystemStorage() throws {
        // Create storage directory
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let storageDirectory = homeDirectory
            .appendingPathComponent(".privarion")
            .appendingPathComponent("analytics")
        
        try FileManager.default.createDirectory(
            at: storageDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        
        // Initialize file system storage manager
        let fileURL = storageDirectory.appendingPathComponent("analytics_data.json")
        self.storageFileURL = fileURL
        self.fileSystemStorage = FileSystemStorageManager(fileURL: fileURL)
        
        // Load existing data if available
        try loadExistingData()
        
        logger.debug("File system storage initialized", metadata: [
            "storage_path": "\(storageFileURL?.path ?? "unknown")"
        ])
    }
    
    private func loadExistingData() throws {
        guard let fileURL = storageFileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        
        let data = try Data(contentsOf: fileURL)
        let entries = try JSONDecoder().decode([TimeSeriesEntry].self, from: data)
        
        // Filter out old data based on retention policy
        let retentionDate = Date().addingTimeInterval(-TimeInterval(config.dataRetentionDays * 24 * 3600))
        memoryStorage = entries.filter { $0.event.timestamp >= retentionDate }
        
        logger.info("Loaded existing analytics data", metadata: [
            "total_entries": "\(entries.count)",
            "retained_entries": "\(memoryStorage.count)"
        ])
    }
    
    private func storeEventInternal(_ event: AnalyticsEvent) {
        let entry = TimeSeriesEntry(
            id: UUID(),
            event: event,
            storedAt: Date()
        )
        
        // Add to memory storage
        memoryStorage.append(entry)
        
        // Maintain memory limits
        if memoryStorage.count > config.maxEventsInMemory {
            memoryStorage.removeFirst(memoryStorage.count - config.maxEventsInMemory)
        }
        
        // Persist to file system if enabled
        if config.storageBackend == .fileSystem || config.storageBackend == .hybrid {
            persistToFileSystem()
        }
        
        logger.debug("Analytics event stored", metadata: [
            "event_id": "\(event.id)",
            "event_type": "\(event.type)",
            "storage_size": "\(memoryStorage.count)"
        ])
    }
    
    private func queryEventsInternal(
        timeRange: DateInterval,
        eventTypes: [AnalyticsEvent.EventType]? = nil,
        applications: [String]? = nil
    ) -> [AnalyticsEvent] {
        var results = memoryStorage.filter { entry in
            timeRange.contains(entry.event.timestamp)
        }
        
        if let eventTypes = eventTypes {
            results = results.filter { entry in
                eventTypes.contains(entry.event.type)
            }
        }
        
        if let applications = applications {
            results = results.filter { entry in
                guard let eventApp = entry.event.application else { return false }
                return applications.contains(eventApp)
            }
        }
        
        return results.map { $0.event }
    }
    
    private func getAllEventsInternal() -> [AnalyticsEvent] {
        return memoryStorage.map { $0.event }
    }
    
    private func aggregateMetricsInternal(
        timeRange: DateInterval,
        aggregationInterval: TimeInterval
    ) -> [AggregatedTimeSeriesMetrics] {
        let events = queryEventsInternal(timeRange: timeRange)
        var aggregatedMetrics: [AggregatedTimeSeriesMetrics] = []
        
        // Create time buckets
        var currentTime = timeRange.start
        while currentTime < timeRange.end {
            let bucketEnd = min(currentTime.addingTimeInterval(aggregationInterval), timeRange.end)
            let bucketInterval = DateInterval(start: currentTime, end: bucketEnd)
            
            let bucketEvents = events.filter { bucketInterval.contains($0.timestamp) }
            _ = calculateMetricsForEvents(bucketEvents) // Calculate but don't use directly
            
            aggregatedMetrics.append(AggregatedTimeSeriesMetrics(
                timestamp: currentTime,
                interval: aggregationInterval,
                eventCount: bucketEvents.count,
                totalDataSize: bucketEvents.reduce(0) { $0 + $1.dataSize },
                uniqueApplications: Set(bucketEvents.compactMap { $0.application }).count,
                dnsQueryCount: bucketEvents.filter { $0.type == .dnsQuery }.count,
                connectionCount: bucketEvents.filter { $0.type == .connection }.count
            ))
            
            currentTime = bucketEnd
        }
        
        return aggregatedMetrics
    }
    
    private func calculateMetricsForEvents(_ events: [AnalyticsEvent]) -> AnalyticsMetrics {
        return AnalyticsMetrics(
            eventCount: events.count,
            totalDataSize: events.reduce(0) { $0 + $1.dataSize },
            averageDataSize: events.isEmpty ? 0 : Double(events.reduce(0) { $0 + $1.dataSize }) / Double(events.count),
            uniqueApplications: Set(events.compactMap { $0.application }).count,
            eventTypeDistribution: Dictionary(grouping: events, by: { $0.type })
                .mapValues { $0.count }
        )
    }
    
    private func persistToFileSystem() {
        guard let fileURL = storageFileURL else { return }
        
        do {
            let data = try JSONEncoder().encode(memoryStorage)
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to persist analytics data", metadata: [
                "error": "\(error)"
            ])
        }
    }
    
    private func performDataCleanup() {
        let retentionDate = Date().addingTimeInterval(-TimeInterval(config.dataRetentionDays * 24 * 3600))
        let initialCount = memoryStorage.count
        
        memoryStorage = memoryStorage.filter { $0.event.timestamp >= retentionDate }
        
        let removedCount = initialCount - memoryStorage.count
        
        if removedCount > 0 {
            logger.info("Data cleanup completed", metadata: [
                "removed_events": "\(removedCount)",
                "remaining_events": "\(memoryStorage.count)"
            ])
            
            // Persist updated data
            if config.storageBackend == .fileSystem || config.storageBackend == .hybrid {
                persistToFileSystem()
            }
        }
    }
    
    private func estimateMemoryUsage() -> Int {
        // Rough estimate: each event ~1KB in memory
        return memoryStorage.count * 1024
    }
    
    private func exportAsJSON(events: [AnalyticsEvent]) throws -> Data {
        return try JSONEncoder().encode(events)
    }
    
    private func exportAsCSV(events: [AnalyticsEvent]) throws -> Data {
        var csvContent = "timestamp,type,source_address,destination_address,data_size,application\n"
        
        for event in events {
            let row = [
                ISO8601DateFormatter().string(from: event.timestamp),
                "\(event.type)",
                event.source.address,
                event.destination.address,
                "\(event.dataSize)",
                event.application ?? ""
            ].joined(separator: ",")
            csvContent += row + "\n"
        }
        
        return csvContent.data(using: .utf8) ?? Data()
    }
    
    private func exportAsJSONL(events: [AnalyticsEvent]) throws -> Data {
        let encoder = JSONEncoder()
        var jsonlContent = ""
        
        for event in events {
            let eventData = try encoder.encode(event)
            if let eventString = String(data: eventData, encoding: .utf8) {
                jsonlContent += eventString + "\n"
            }
        }
        
        return jsonlContent.data(using: .utf8) ?? Data()
    }
}

// MARK: - Supporting Types

/// Time series entry for internal storage
private struct TimeSeriesEntry: Codable {
    let id: UUID
    let event: AnalyticsEvent
    let storedAt: Date
}

/// Aggregated time series metrics
public struct AggregatedTimeSeriesMetrics {
    public let timestamp: Date
    public let interval: TimeInterval
    public let eventCount: Int
    public let totalDataSize: UInt64
    public let uniqueApplications: Int
    public let dnsQueryCount: Int
    public let connectionCount: Int
}

/// Analytics metrics calculation result
public struct AnalyticsMetrics {
    public let eventCount: Int
    public let totalDataSize: UInt64
    public let averageDataSize: Double
    public let uniqueApplications: Int
    public let eventTypeDistribution: [AnalyticsEvent.EventType: Int]
}

/// Storage statistics
public struct StorageStatistics {
    public let totalEvents: Int
    public let memoryUsageBytes: Int
    public let oldestEventTimestamp: Date?
    public let newestEventTimestamp: Date?
    public let storageBackend: AnalyticsStorageBackend
}

/// File system storage manager
private class FileSystemStorageManager {
    private let fileURL: URL
    
    init(fileURL: URL) {
        self.fileURL = fileURL
    }
    
    func save(_ entries: [TimeSeriesEntry]) throws {
        let data = try JSONEncoder().encode(entries)
        try data.write(to: fileURL)
    }
    
    func load() throws -> [TimeSeriesEntry] {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([TimeSeriesEntry].self, from: data)
    }
}
