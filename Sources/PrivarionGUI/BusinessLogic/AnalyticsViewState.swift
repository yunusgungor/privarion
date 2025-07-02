import Foundation
import SwiftUI
import Combine
import Logging
import PrivarionCore

/// State management for Analytics view following Clean Architecture pattern
/// Integrates with NetworkAnalyticsEngine for real-time data
@MainActor
final class AnalyticsViewState: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isActive: Bool = false
    @Published var isLoading: Bool = false
    @Published var eventsPerSecond: Double = 0.0
    @Published var totalEvents: Int = 0
    @Published var sessionTime: String = "00:00:00"
    @Published var hasData: Bool = false
    @Published var showSettings: Bool = false
    
    // Chart and visualization properties
    @Published var selectedChart: ChartType = .throughput
    @Published var chartData: [AnalyticsDataPoint] = []
    @Published var currentMetrics: AnalyticsDataPoint?
    @Published var recentEvents: [AnalyticsEventDisplayModel] = []
    
    // Settings properties
    @Published var realTimeProcessing: Bool = true
    @Published var updateInterval: Int = 5
    @Published var retentionDays: Int = 7
    @Published var maxEvents: Int = 1000
    @Published var autoExport: Bool = false
    @Published var exportFormat: String = "json"
    
    // MARK: - Private Properties
    
    private let logger = Logger(label: "AnalyticsViewState")
    private let analyticsEngine = NetworkAnalyticsEngine.shared
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private var sessionStartTime: Date?
    
    // MARK: - Initialization
    
    init() {
        setupAnalyticsSubscription()
        loadSettings()
        logger.info("AnalyticsViewState initialized")
    }
    
    // MARK: - Public Methods
    
    /// Start real-time updates
    func startUpdates() {
        guard updateTimer == nil else { return }
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(updateInterval), repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateData()
            }
        }
        
        // Initial data load
        Task {
            await updateData()
        }
        
        logger.info("Started analytics view updates")
    }
    
    /// Stop real-time updates
    func stopUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
        logger.info("Stopped analytics view updates")
    }
    
    /// Toggle analytics collection
    func toggleAnalytics() async {
        isLoading = true
        
        do {
            if isActive {
                try await stopAnalytics()
            } else {
                try await startAnalytics()
            }
        } catch {
            logger.error("Failed to toggle analytics: \(error)")
            // Handle error through error manager if available
        }
        
        isLoading = false
    }
    
    /// Export analytics data
    func exportAnalytics() async {
        isLoading = true
        
        do {
            let format: AnalyticsExportFormat
            switch exportFormat {
            case "JSON":
                format = .json
            case "CSV":
                format = .csv
            case "JSONL":
                format = .jsonl
            default:
                format = .json
            }
            
            let exportData = try analyticsEngine.exportAnalytics(format: format)
            
            // Save to file using file dialog
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.json, .commaSeparatedText, .plainText]
            savePanel.nameFieldStringValue = "analytics_export_\(Date().timeIntervalSince1970)"
            
            if savePanel.runModal() == .OK {
                if let url = savePanel.url {
                    try exportData.write(to: url)
                    logger.info("Analytics data exported to: \(url.path)")
                }
            }
        } catch {
            logger.error("Failed to export analytics: \(error)")
        }
        
        isLoading = false
    }
    
    /// Refresh analytics data
    func refreshData() async {
        await updateData()
    }
    
    /// Clear recent events
    func clearEvents() {
        recentEvents.removeAll()
        logger.info("Cleared recent events")
    }
    
    /// Save settings
    func saveSettings() async {
        // Save settings to configuration
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        var newConfig = config
        newConfig.modules.networkAnalytics.realTimeProcessing = realTimeProcessing
        newConfig.modules.networkAnalytics.dataRetentionDays = retentionDays
        
        try? ConfigurationManager.shared.updateConfiguration(newConfig)
        
        // Restart timer with new interval if needed
        if updateTimer != nil {
            stopUpdates()
            startUpdates()
        }
        
        logger.info("Analytics settings saved")
    }
    
    // MARK: - Private Methods
    
    private func setupAnalyticsSubscription() {
        // Subscribe to analytics events from the engine
        analyticsEngine.analyticsEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleAnalyticsEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func handleAnalyticsEvent(_ event: AnalyticsEvent) {
        // Convert analytics event to display model
        let displayEvent = AnalyticsEventDisplayModel(
            timestamp: event.timestamp,
            type: event.type.rawValue,
            description: event.metadata["description"] ?? "Network event",
            severity: convertSeverity(event.type)
        )
        
        // Add to recent events (keep only latest)
        recentEvents.insert(displayEvent, at: 0)
        if recentEvents.count > maxEvents {
            recentEvents.removeLast()
        }
        
        // Update counters
        totalEvents += 1
        hasData = true
        
        // Calculate events per second
        updateEventsPerSecond()
    }
    
    private func convertSeverity(_ eventType: AnalyticsEvent.EventType) -> AnalyticsEventDisplayModel.EventSeverity {
        switch eventType {
        case .connection, .dataTransfer:
            return .info
        case .connectionClosed:
            return .warning
        case .dnsQuery:
            return .info
        }
    }
    
    private func startAnalytics() async throws {
        try analyticsEngine.startAnalytics()
        isActive = true
        sessionStartTime = Date()
        
        // Start session time updates
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, self.isActive else {
                    timer.invalidate()
                    return
                }
                self.updateSessionTime()
            }
        }
        
        logger.info("Analytics started successfully")
    }
    
    private func stopAnalytics() async throws {
        analyticsEngine.stopAnalytics()
        isActive = false
        sessionStartTime = nil
        sessionTime = "00:00:00"
        logger.info("Analytics stopped successfully")
    }
    
    private func updateData() async {
        guard isActive else { return }
        
        // Get current analytics snapshot
        let snapshot = analyticsEngine.getCurrentMetrics()
        
        // Convert to data point
        let dataPoint = AnalyticsDataPoint(
            timestamp: Date(),
            throughput: snapshot.bandwidth.currentBytesPerSecond,
            activeConnections: snapshot.connections.activeCount,
            packetsIn: Int(snapshot.bandwidth.totalBytes / 1024), // Approximate packets from bytes
            packetsOut: Int(snapshot.bandwidth.totalBytes / 2048), // Approximate split
            errorCount: 0, // Would need to track errors separately
            latency: snapshot.dns.queriesPerSecond > 0 ? 1.0 / snapshot.dns.queriesPerSecond * 1000 : 0.0 // Approximate latency from DNS response time
        )
        
        // Update chart data
        chartData.append(dataPoint)
        
        // Keep only recent data points (last 5 minutes)
        let cutoffTime = Date().addingTimeInterval(-300) // 5 minutes ago
        chartData.removeAll { $0.timestamp < cutoffTime }
        
        // Update current metrics
        currentMetrics = dataPoint
        hasData = !chartData.isEmpty
    }
    
    private func updateEventsPerSecond() {
        guard let sessionStart = sessionStartTime else {
            eventsPerSecond = 0.0
            return
        }
        
        let sessionDuration = Date().timeIntervalSince(sessionStart)
        guard sessionDuration > 0 else {
            eventsPerSecond = 0.0
            return
        }
        
        eventsPerSecond = Double(totalEvents) / sessionDuration
    }
    
    private func updateSessionTime() {
        guard let sessionStart = sessionStartTime else {
            sessionTime = "00:00:00"
            return
        }
        
        let duration = Date().timeIntervalSince(sessionStart)
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        
        sessionTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func loadSettings() {
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        realTimeProcessing = config.modules.networkAnalytics.realTimeProcessing
        retentionDays = config.modules.networkAnalytics.dataRetentionDays
        
        // Check if analytics is currently active
        // This would typically come from the analytics engine
        isActive = false // Default to inactive
        
        logger.info("Analytics settings loaded")
    }
}

// MARK: - Extensions

extension AnalyticsViewState {
    /// Get mock data for preview/testing
    static func mockData() -> AnalyticsViewState {
        let state = AnalyticsViewState()
        state.isActive = true
        state.eventsPerSecond = 12.5
        state.totalEvents = 1847
        state.sessionTime = "01:23:45"
        state.hasData = true
        
        // Mock chart data
        let now = Date()
        state.chartData = (0..<30).map { i in
            AnalyticsDataPoint(
                timestamp: now.addingTimeInterval(TimeInterval(-i * 10)),
                throughput: Double.random(in: 0...100),
                activeConnections: Int.random(in: 5...50),
                packetsIn: Int.random(in: 100...1000),
                packetsOut: Int.random(in: 80...800),
                errorCount: Int.random(in: 0...5),
                latency: Double.random(in: 1...50)
            )
        }.reversed()
        
        // Mock current metrics
        state.currentMetrics = state.chartData.last
        
        // Mock recent events
        state.recentEvents = [
            AnalyticsEventDisplayModel(
                timestamp: now,
                type: "ConnectionEstablished",
                description: "New connection from 192.168.1.100",
                severity: .info
            ),
            AnalyticsEventDisplayModel(
                timestamp: now.addingTimeInterval(-30),
                type: "DataTransfer",
                description: "High throughput detected",
                severity: .warning
            ),
            AnalyticsEventDisplayModel(
                timestamp: now.addingTimeInterval(-60),
                type: "SecurityAlert",
                description: "Suspicious activity detected",
                severity: .critical
            )
        ]
        
        return state
    }
}
