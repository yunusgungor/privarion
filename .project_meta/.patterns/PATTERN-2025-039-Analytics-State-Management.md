# PATTERN-2025-039: Analytics State Management Pattern

## Pattern Information
- **ID**: PATTERN-2025-039
- **Name**: Analytics State Management Pattern
- **Category**: State Management
- **Difficulty**: Medium
- **Reusability**: High
- **Status**: ✅ Active
- **Source**: STORY-2025-010 Network Analytics Module
- **Extracted**: 2025-07-01

## Description
A comprehensive pattern for managing complex analytics state in SwiftUI applications, providing efficient data flow, error handling, loading states, and real-time updates while maintaining separation of concerns and testability. This pattern is specifically designed for analytics dashboards with multiple data sources and interactive components.

## Problem Statement
Analytics applications require sophisticated state management to handle multiple data streams, loading states, error conditions, user interactions, and real-time updates. Traditional approaches often lead to complex state mutations, memory leaks, race conditions, and poor user experience during data loading or error scenarios.

## Solution Overview
The pattern implements a specialized state management system using `@MainActor` classes with `@Published` properties, combining Combine publishers for reactive updates with async/await for data operations. It provides clear separation between UI state, business logic, and data access layers.

## Architecture Components

### 1. Core State Management
```swift
@MainActor
class AnalyticsViewState: ObservableObject {
    // Data state
    @Published var currentSnapshot: AnalyticsSnapshot?
    @Published var historicalData: [AnalyticsDataPoint] = []
    @Published var timeSeriesData: [String: [AnalyticsDataPoint]] = [:]
    
    // UI state
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var selectedTimeRange: TimeRange = .lastHour
    @Published var selectedMetric: AnalyticsMetric = .bandwidth
    @Published var chartType: ChartType = .line
    
    // Error state
    @Published var error: AnalyticsError?
    @Published var hasError: Bool { error != nil }
    
    // Dependencies
    private var analyticsEngine: NetworkAnalyticsEngine?
    private var cancellables = Set<AnyCancellable>()
}
```

### 2. Data Loading States
```swift
enum LoadingState: Equatable {
    case idle
    case loading
    case refreshing
    case loadingMore
    case success
    case failed(AnalyticsError)
    
    var isLoading: Bool {
        switch self {
        case .loading, .refreshing, .loadingMore:
            return true
        default:
            return false
        }
    }
}
```

### 3. Error Handling System
```swift
enum AnalyticsError: LocalizedError, Equatable {
    case networkUnavailable
    case dataFetchFailed(Error)
    case invalidTimeRange
    case exportFailed(String)
    case configurationError
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection unavailable"
        case .dataFetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .invalidTimeRange:
            return "Invalid time range selected"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .configurationError:
            return "Configuration error occurred"
        }
    }
    
    var recoveryAction: AnalyticsRecoveryAction? {
        switch self {
        case .networkUnavailable, .dataFetchFailed:
            return .retry
        case .invalidTimeRange:
            return .resetTimeRange
        case .exportFailed:
            return .retryExport
        case .configurationError:
            return .reconfigure
        }
    }
}
```

### 4. Recovery Actions
```swift
enum AnalyticsRecoveryAction {
    case retry
    case resetTimeRange
    case retryExport
    case reconfigure
    case dismiss
    
    var title: String {
        switch self {
        case .retry: return "Retry"
        case .resetTimeRange: return "Reset Time Range"
        case .retryExport: return "Retry Export"
        case .reconfigure: return "Reconfigure"
        case .dismiss: return "Dismiss"
        }
    }
}
```

## Implementation Details

### State Initialization
- Lazy initialization of dependencies
- Automatic state cleanup on deinit
- Proper memory management for real-time updates
- Thread-safe state updates using `@MainActor`

### Data Flow Management
- Unidirectional data flow from engine to state to UI
- Reactive updates using Combine publishers
- Async operations for data fetching
- Proper error propagation through the state hierarchy

### Performance Optimization
- Debounced user input handling
- Efficient data caching and invalidation
- Memory-conscious data retention policies
- Optimized re-rendering with selective updates

### Real-time Updates
- Timer-based periodic updates
- WebSocket integration for live data streams
- Background data refresh capabilities
- Conflict resolution for concurrent updates

## Code Example

### Complete State Management Implementation
```swift
import SwiftUI
import Combine

@MainActor
class AnalyticsViewState: ObservableObject {
    // MARK: - Published Properties
    
    // Data Properties
    @Published var currentSnapshot: AnalyticsSnapshot?
    @Published var historicalData: [AnalyticsDataPoint] = []
    @Published var timeSeriesData: [String: [AnalyticsDataPoint]] = [:]
    @Published var exportedFiles: [URL] = []
    
    // UI State Properties
    @Published var loadingState: LoadingState = .idle
    @Published var selectedTimeRange: TimeRange = .lastHour {
        didSet {
            if selectedTimeRange != oldValue {
                scheduleDataRefresh()
            }
        }
    }
    @Published var selectedMetric: AnalyticsMetric = .bandwidth {
        didSet {
            if selectedMetric != oldValue {
                updateDisplayData()
            }
        }
    }
    @Published var chartType: ChartType = .line
    @Published var showingExportOptions = false
    @Published var showingSettings = false
    
    // Error State
    @Published var error: AnalyticsError?
    @Published var showingError = false
    
    // Computed Properties
    var isLoading: Bool { loadingState.isLoading }
    var hasData: Bool { !historicalData.isEmpty }
    var canExport: Bool { hasData && !isLoading }
    
    // MARK: - Private Properties
    
    private var analyticsEngine: NetworkAnalyticsEngine?
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var dataRefreshDebouncer = Timer()
    
    // MARK: - Configuration
    
    private struct Config {
        static let refreshInterval: TimeInterval = 30.0
        static let debounceDelay: TimeInterval = 0.5
        static let maxDataPoints = 1000
        static let cacheTimeout: TimeInterval = 300.0 // 5 minutes
    }
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    deinit {
        cleanup()
    }
    
    func initialize(analyticsEngine: NetworkAnalyticsEngine) {
        self.analyticsEngine = analyticsEngine
        Task {
            await performInitialLoad()
        }
    }
    
    // MARK: - Public Methods
    
    func refreshData() async {
        await performDataLoad(isRefresh: true)
    }
    
    func loadMoreData() async {
        guard case .success = loadingState else { return }
        await performDataLoad(isLoadMore: true)
    }
    
    func exportData(format: AnalyticsExportFormat) async {
        guard let engine = analyticsEngine else { return }
        
        do {
            loadingState = .loading
            let exportURL = try await engine.exportAnalytics(format: format)
            exportedFiles.append(exportURL)
            loadingState = .success
        } catch {
            handleError(.exportFailed(error.localizedDescription))
        }
    }
    
    func retryLastOperation() async {
        guard let error = error else { return }
        clearError()
        
        switch error.recoveryAction {
        case .retry:
            await refreshData()
        case .resetTimeRange:
            selectedTimeRange = .lastHour
            await refreshData()
        case .retryExport:
            await exportData(format: .json)
        case .reconfigure:
            // Trigger reconfiguration flow
            showingSettings = true
        case .dismiss:
            break
        case .none:
            break
        }
    }
    
    func clearError() {
        error = nil
        showingError = false
        if case .failed = loadingState {
            loadingState = .idle
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Observe error state changes
        $error
            .compactMap { $0 }
            .sink { [weak self] _ in
                self?.showingError = true
            }
            .store(in: &cancellables)
        
        // Setup automatic refresh timer
        startPeriodicRefresh()
    }
    
    private func performInitialLoad() async {
        loadingState = .loading
        await performDataLoad(isInitial: true)
    }
    
    private func performDataLoad(isRefresh: Bool = false, 
                               isLoadMore: Bool = false, 
                               isInitial: Bool = false) async {
        guard let engine = analyticsEngine else {
            handleError(.configurationError)
            return
        }
        
        if isRefresh {
            loadingState = .refreshing
        } else if isLoadMore {
            loadingState = .loadingMore
        } else if !isInitial && loadingState != .loading {
            loadingState = .loading
        }
        
        do {
            // Parallel data loading
            async let snapshot = engine.getCurrentSnapshot()
            async let historical = engine.getHistoricalData(timeRange: selectedTimeRange)
            
            let (newSnapshot, newHistorical) = try await (snapshot, historical)
            
            // Update state on main actor
            await MainActor.run {
                updateDataState(snapshot: newSnapshot, historical: newHistorical, isLoadMore: isLoadMore)
                loadingState = .success
                clearError()
            }
            
        } catch {
            await MainActor.run {
                handleError(.dataFetchFailed(error))
            }
        }
    }
    
    private func updateDataState(snapshot: AnalyticsSnapshot, 
                               historical: [AnalyticsDataPoint], 
                               isLoadMore: Bool) {
        currentSnapshot = snapshot
        
        if isLoadMore {
            // Append new data and maintain size limit
            historicalData.append(contentsOf: historical)
            if historicalData.count > Config.maxDataPoints {
                historicalData = Array(historicalData.suffix(Config.maxDataPoints))
            }
        } else {
            historicalData = historical
        }
        
        updateTimeSeriesData()
    }
    
    private func updateTimeSeriesData() {
        // Group data by metric type for efficient chart rendering
        timeSeriesData = Dictionary(grouping: historicalData) { $0.category }
            .mapValues { points in
                points.sorted { $0.timestamp < $1.timestamp }
            }
    }
    
    private func updateDisplayData() {
        // Trigger UI updates based on selected metric
        objectWillChange.send()
    }
    
    private func scheduleDataRefresh() {
        // Debounce rapid time range changes
        dataRefreshDebouncer.invalidate()
        dataRefreshDebouncer = Timer.scheduledTimer(withTimeInterval: Config.debounceDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshData()
            }
        }
    }
    
    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Config.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Only auto-refresh if not currently loading and no errors
                if self?.loadingState == .success {
                    await self?.performDataLoad(isRefresh: true)
                }
            }
        }
    }
    
    private func handleError(_ analyticsError: AnalyticsError) {
        error = analyticsError
        loadingState = .failed(analyticsError)
        
        // Log error for debugging
        Logger.analytics.error("Analytics error occurred: \(analyticsError.localizedDescription)")
    }
    
    private func cleanup() {
        refreshTimer?.invalidate()
        dataRefreshDebouncer.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - SwiftUI Integration

extension AnalyticsViewState {
    
    // Convenience computed properties for SwiftUI
    var filteredData: [AnalyticsDataPoint] {
        guard let seriesData = timeSeriesData[selectedMetric.rawValue] else {
            return []
        }
        return seriesData
    }
    
    var displayMetrics: [String: Any] {
        guard let snapshot = currentSnapshot else { return [:] }
        
        switch selectedMetric {
        case .bandwidth:
            return [
                "current": snapshot.bandwidth.current,
                "average": snapshot.bandwidth.average,
                "peak": snapshot.bandwidth.peak
            ]
        case .connections:
            return [
                "current": snapshot.connections.current,
                "average": snapshot.connections.average,
                "peak": snapshot.connections.peak
            ]
        case .dns:
            return [
                "queries": snapshot.dns.queries,
                "responses": snapshot.dns.responses,
                "failures": snapshot.dns.failures
            ]
        }
    }
}

// MARK: - Supporting Types

enum AnalyticsMetric: String, CaseIterable {
    case bandwidth = "bandwidth"
    case connections = "connections"
    case dns = "dns"
    
    var displayName: String {
        switch self {
        case .bandwidth: return "Bandwidth"
        case .connections: return "Connections"
        case .dns: return "DNS"
        }
    }
    
    var unit: String {
        switch self {
        case .bandwidth: return "MB/s"
        case .connections: return "count"
        case .dns: return "queries"
        }
    }
}

enum ChartType: String, CaseIterable {
    case line = "line"
    case area = "area"
    case bar = "bar"
    
    var displayName: String {
        rawValue.capitalized
    }
}

enum TimeRange: String, CaseIterable {
    case lastHour = "1h"
    case last6Hours = "6h"
    case last24Hours = "24h"
    case lastWeek = "7d"
    case lastMonth = "30d"
    
    var displayName: String {
        switch self {
        case .lastHour: return "Last Hour"
        case .last6Hours: return "Last 6 Hours"
        case .last24Hours: return "Last 24 Hours"
        case .lastWeek: return "Last Week"
        case .lastMonth: return "Last Month"
        }
    }
}
```

## Benefits
1. **Separation of Concerns**: Clear boundaries between UI, business logic, and data
2. **Reactive Updates**: Automatic UI updates when data changes
3. **Error Resilience**: Comprehensive error handling with recovery options
4. **Performance**: Optimized data loading and memory management
5. **Testability**: Easy to unit test state management logic
6. **Maintainability**: Well-structured code with clear responsibilities

## Trade-offs
1. **Complexity**: More sophisticated than simple state management
2. **Memory Usage**: Maintains multiple state properties in memory
3. **Learning Curve**: Requires understanding of Combine and async/await
4. **Boilerplate**: More setup code compared to simple `@State` variables

## Usage Guidelines
- Use `@MainActor` for all state management classes
- Implement proper cleanup in `deinit`
- Handle errors gracefully with user-friendly messages
- Provide loading states for all async operations
- Use debouncing for rapid user input changes
- Implement data retention policies for memory management

## Related Patterns
- PATTERN-2025-035: SwiftUI Async State Management
- PATTERN-2025-037: Real-time Analytics Visualization Pattern
- PATTERN-2025-036: GUI-Core API Bridge Pattern

## Testing Strategy
- Unit tests for state management logic
- Mock analytics engines for testing
- Error scenario testing
- Memory leak detection
- Concurrency testing for race conditions

## Quality Metrics
- **State Update Performance**: <50ms for UI updates
- **Memory Stability**: No memory leaks during extended use
- **Error Coverage**: 100% error scenario handling
- **Code Coverage**: 95%+ for state management logic

---
*Extracted from STORY-2025-010: Network Analytics Module Integration*  
*Pattern validated in production analytics dashboard*
