# PATTERN-2025-040: Clean Architecture GUI Module Pattern

## Pattern Information
- **ID**: PATTERN-2025-040
- **Name**: Clean Architecture GUI Module Pattern
- **Category**: Architecture Design
- **Difficulty**: Advanced
- **Reusability**: High
- **Status**: ✅ Active
- **Source**: STORY-2025-010 Network Analytics Module
- **Extracted**: 2025-07-01

## Description
A comprehensive architectural pattern for implementing GUI modules in SwiftUI applications following Clean Architecture principles. This pattern ensures proper separation of concerns, dependency inversion, testability, and maintainability while providing seamless integration with core business logic and external dependencies.

## Problem Statement
GUI applications often suffer from tight coupling between UI components, business logic, and data access layers, leading to difficult testing, poor maintainability, and code duplication. Traditional MVC or MVVM patterns may not provide sufficient separation for complex applications with multiple modules and varying data sources.

## Solution Overview
The pattern implements a layered architecture with clear boundaries between Presentation, Business Logic, and Data Access layers, using dependency injection and protocol-oriented programming to achieve loose coupling and high testability.

## Architecture Layers

### 1. Presentation Layer
```swift
// SwiftUI Views (Stateless)
struct AnalyticsView: View {
    @StateObject private var viewState = AnalyticsViewState()
    @Environment(\.networkAnalyticsEngine) private var analyticsEngine
    
    var body: some View {
        // UI implementation
    }
}

// View State (UI Logic)
@MainActor
class AnalyticsViewState: ObservableObject {
    @Published var uiState: UIState
    private let interactor: AnalyticsInteractor
    
    func performAction(_ action: AnalyticsAction) {
        interactor.execute(action)
    }
}
```

### 2. Business Logic Layer
```swift
// Interactor (Use Cases)
protocol AnalyticsInteractor {
    func getCurrentSnapshot() async throws -> AnalyticsSnapshot
    func getHistoricalData(timeRange: TimeRange) async throws -> [AnalyticsDataPoint]
    func exportAnalytics(format: AnalyticsExportFormat) async throws -> URL
}

// Implementation
class NetworkAnalyticsInteractor: AnalyticsInteractor {
    private let repository: AnalyticsRepository
    private let exportService: ExportService
    
    init(repository: AnalyticsRepository, exportService: ExportService) {
        self.repository = repository
        self.exportService = exportService
    }
}
```

### 3. Data Access Layer
```swift
// Repository Protocol
protocol AnalyticsRepository {
    func fetchCurrentMetrics() async throws -> MetricsSnapshot
    func fetchHistoricalData(timeRange: TimeRange) async throws -> [DataPoint]
    func saveMetrics(_ metrics: MetricsSnapshot) async throws
}

// Implementation
class NetworkAnalyticsRepository: AnalyticsRepository {
    private let dataSource: NetworkDataSource
    private let cache: AnalyticsCache
    
    init(dataSource: NetworkDataSource, cache: AnalyticsCache) {
        self.dataSource = dataSource
        self.cache = cache
    }
}
```

### 4. Dependency Injection
```swift
// Dependency Container
class AnalyticsDependencyContainer {
    private let coreEngine: NetworkAnalyticsEngine
    
    init(coreEngine: NetworkAnalyticsEngine) {
        self.coreEngine = coreEngine
    }
    
    lazy var repository: AnalyticsRepository = {
        NetworkAnalyticsRepository(
            dataSource: coreEngine,
            cache: AnalyticsCache()
        )
    }()
    
    lazy var interactor: AnalyticsInteractor = {
        NetworkAnalyticsInteractor(
            repository: repository,
            exportService: ExportService()
        )
    }()
}
```

## Implementation Details

### Dependency Inversion
- All layers depend on abstractions (protocols), not concretions
- Dependencies flow inward (UI → Business Logic → Data Access)
- Core business logic has no dependencies on external frameworks
- Easy to swap implementations for testing or different environments

### State Management
- View State handles UI-specific logic and state
- Interactors manage business logic and use cases
- Repositories handle data access and caching
- Clear separation prevents state management issues

### Error Handling
- Domain-specific errors at each layer
- Error transformation between layers
- Comprehensive error recovery strategies
- User-friendly error messages in presentation layer

### Testing Strategy
- Unit tests for each layer independently
- Mock implementations for external dependencies
- Integration tests for full data flow
- UI tests for user interaction scenarios

## Code Example

### Complete Implementation

```swift
import SwiftUI
import Combine

// MARK: - Domain Models

struct AnalyticsSnapshot {
    let timestamp: Date
    let bandwidth: BandwidthMetrics
    let connections: ConnectionMetrics
    let dns: DNSMetrics
}

struct AnalyticsDataPoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let value: Double
    let category: String
}

// MARK: - Business Logic Layer

protocol AnalyticsInteractor {
    func getCurrentSnapshot() async throws -> AnalyticsSnapshot
    func getHistoricalData(timeRange: TimeRange) async throws -> [AnalyticsDataPoint]
    func exportAnalytics(format: AnalyticsExportFormat) async throws -> URL
    func startRealtimeUpdates() -> AnyPublisher<AnalyticsSnapshot, Error>
}

class NetworkAnalyticsInteractor: AnalyticsInteractor {
    private let repository: AnalyticsRepository
    private let exportService: ExportService
    private let logger: Logger
    
    init(repository: AnalyticsRepository, 
         exportService: ExportService,
         logger: Logger = Logger.analytics) {
        self.repository = repository
        self.exportService = exportService
        self.logger = logger
    }
    
    func getCurrentSnapshot() async throws -> AnalyticsSnapshot {
        logger.debug("Fetching current analytics snapshot")
        
        do {
            let metrics = try await repository.fetchCurrentMetrics()
            let snapshot = mapToAnalyticsSnapshot(metrics)
            
            // Cache the result
            try await repository.saveMetrics(metrics)
            
            logger.debug("Successfully fetched analytics snapshot")
            return snapshot
        } catch {
            logger.error("Failed to fetch analytics snapshot: \(error)")
            throw AnalyticsError.dataFetchFailed(error)
        }
    }
    
    func getHistoricalData(timeRange: TimeRange) async throws -> [AnalyticsDataPoint] {
        logger.debug("Fetching historical data for range: \(timeRange)")
        
        do {
            let dataPoints = try await repository.fetchHistoricalData(timeRange: timeRange)
            let analyticsPoints = dataPoints.map(mapToAnalyticsDataPoint)
            
            logger.debug("Successfully fetched \(analyticsPoints.count) historical data points")
            return analyticsPoints
        } catch {
            logger.error("Failed to fetch historical data: \(error)")
            throw AnalyticsError.dataFetchFailed(error)
        }
    }
    
    func exportAnalytics(format: AnalyticsExportFormat) async throws -> URL {
        logger.debug("Exporting analytics in format: \(format)")
        
        do {
            let snapshot = try await getCurrentSnapshot()
            let historicalData = try await getHistoricalData(timeRange: .last24Hours)
            
            let exportData = AnalyticsExportData(
                snapshot: snapshot,
                historicalData: historicalData,
                exportedAt: Date()
            )
            
            let url = try await exportService.export(exportData, format: format)
            logger.debug("Successfully exported analytics to: \(url)")
            return url
        } catch {
            logger.error("Failed to export analytics: \(error)")
            throw AnalyticsError.exportFailed(error.localizedDescription)
        }
    }
    
    func startRealtimeUpdates() -> AnyPublisher<AnalyticsSnapshot, Error> {
        logger.debug("Starting realtime analytics updates")
        
        return Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .asyncMap { [weak self] _ in
                try await self?.getCurrentSnapshot()
            }
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func mapToAnalyticsSnapshot(_ metrics: MetricsSnapshot) -> AnalyticsSnapshot {
        AnalyticsSnapshot(
            timestamp: metrics.timestamp,
            bandwidth: BandwidthMetrics(
                current: metrics.bandwidthCurrent,
                average: metrics.bandwidthAverage,
                peak: metrics.bandwidthPeak
            ),
            connections: ConnectionMetrics(
                current: metrics.connectionsCurrent,
                average: metrics.connectionsAverage,
                peak: metrics.connectionsPeak
            ),
            dns: DNSMetrics(
                queries: metrics.dnsQueries,
                responses: metrics.dnsResponses,
                failures: metrics.dnsFailures
            )
        )
    }
    
    private func mapToAnalyticsDataPoint(_ dataPoint: DataPoint) -> AnalyticsDataPoint {
        AnalyticsDataPoint(
            timestamp: dataPoint.timestamp,
            value: dataPoint.value,
            category: dataPoint.category
        )
    }
}

// MARK: - Data Access Layer

protocol AnalyticsRepository {
    func fetchCurrentMetrics() async throws -> MetricsSnapshot
    func fetchHistoricalData(timeRange: TimeRange) async throws -> [DataPoint]
    func saveMetrics(_ metrics: MetricsSnapshot) async throws
    func clearCache() async throws
}

class NetworkAnalyticsRepository: AnalyticsRepository {
    private let networkEngine: NetworkAnalyticsEngine
    private let cache: AnalyticsCache
    private let logger: Logger
    
    init(networkEngine: NetworkAnalyticsEngine, 
         cache: AnalyticsCache,
         logger: Logger = Logger.analytics) {
        self.networkEngine = networkEngine
        self.cache = cache
        self.logger = logger
    }
    
    func fetchCurrentMetrics() async throws -> MetricsSnapshot {
        // Try cache first
        if let cachedMetrics = await cache.getCurrentMetrics(),
           cachedMetrics.isValid {
            logger.debug("Returning cached metrics")
            return cachedMetrics
        }
        
        // Fetch from network engine
        logger.debug("Fetching metrics from network engine")
        let snapshot = try await networkEngine.getCurrentSnapshot()
        
        let metrics = MetricsSnapshot(
            timestamp: Date(),
            bandwidthCurrent: snapshot.bandwidth.current,
            bandwidthAverage: snapshot.bandwidth.average,
            bandwidthPeak: snapshot.bandwidth.peak,
            connectionsCurrent: snapshot.connections.current,
            connectionsAverage: snapshot.connections.average,
            connectionsPeak: snapshot.connections.peak,
            dnsQueries: snapshot.dns.queries,
            dnsResponses: snapshot.dns.responses,
            dnsFailures: snapshot.dns.failures
        )
        
        await cache.saveMetrics(metrics)
        return metrics
    }
    
    func fetchHistoricalData(timeRange: TimeRange) async throws -> [DataPoint] {
        logger.debug("Fetching historical data from network engine")
        let analyticsData = try await networkEngine.getHistoricalData(timeRange: timeRange)
        
        return analyticsData.map { point in
            DataPoint(
                timestamp: point.timestamp,
                value: point.value,
                category: point.category
            )
        }
    }
    
    func saveMetrics(_ metrics: MetricsSnapshot) async throws {
        await cache.saveMetrics(metrics)
    }
    
    func clearCache() async throws {
        await cache.clear()
    }
}

// MARK: - Presentation Layer

@MainActor
class AnalyticsViewState: ObservableObject {
    // Published properties for UI
    @Published var currentSnapshot: AnalyticsSnapshot?
    @Published var historicalData: [AnalyticsDataPoint] = []
    @Published var isLoading = false
    @Published var error: AnalyticsError?
    @Published var selectedTimeRange: TimeRange = .lastHour
    
    // Dependencies
    private let interactor: AnalyticsInteractor
    private var cancellables = Set<AnyCancellable>()
    
    init(interactor: AnalyticsInteractor) {
        self.interactor = interactor
        setupRealtimeUpdates()
    }
    
    // MARK: - Public Methods
    
    func loadInitialData() async {
        await performAction(.loadInitialData)
    }
    
    func refreshData() async {
        await performAction(.refreshData)
    }
    
    func changeTimeRange(_ timeRange: TimeRange) async {
        selectedTimeRange = timeRange
        await performAction(.changeTimeRange(timeRange))
    }
    
    func exportData(_ format: AnalyticsExportFormat) async {
        await performAction(.exportData(format))
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Private Methods
    
    private func performAction(_ action: AnalyticsAction) async {
        isLoading = true
        error = nil
        
        do {
            switch action {
            case .loadInitialData, .refreshData:
                async let snapshot = interactor.getCurrentSnapshot()
                async let historical = interactor.getHistoricalData(timeRange: selectedTimeRange)
                
                currentSnapshot = try await snapshot
                historicalData = try await historical
                
            case .changeTimeRange(let timeRange):
                historicalData = try await interactor.getHistoricalData(timeRange: timeRange)
                
            case .exportData(let format):
                _ = try await interactor.exportAnalytics(format: format)
                // Handle export success (e.g., show success message)
            }
        } catch {
            self.error = error as? AnalyticsError ?? .unknown(error)
        }
        
        isLoading = false
    }
    
    private func setupRealtimeUpdates() {
        interactor.startRealtimeUpdates()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.error = error as? AnalyticsError ?? .unknown(error)
                    }
                },
                receiveValue: { snapshot in
                    self.currentSnapshot = snapshot
                }
            )
            .store(in: &cancellables)
    }
}

struct AnalyticsView: View {
    @StateObject private var viewState: AnalyticsViewState
    
    init(interactor: AnalyticsInteractor) {
        _viewState = StateObject(wrappedValue: AnalyticsViewState(interactor: interactor))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Current metrics overview
                    if let snapshot = viewState.currentSnapshot {
                        MetricsOverviewCard(snapshot: snapshot)
                    }
                    
                    // Time range picker
                    TimeRangePicker(selectedRange: .constant(viewState.selectedTimeRange)) { timeRange in
                        Task {
                            await viewState.changeTimeRange(timeRange)
                        }
                    }
                    
                    // Charts section
                    AnalyticsChartSection(data: viewState.historicalData)
                    
                    // Export section
                    ExportSection { format in
                        Task {
                            await viewState.exportData(format)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .refreshable {
                await viewState.refreshData()
            }
            .overlay {
                if viewState.isLoading {
                    ProgressView("Loading...")
                        .scaleEffect(1.2)
                        .background(Color(.systemBackground).opacity(0.8))
                }
            }
            .alert("Error", isPresented: .constant(viewState.error != nil)) {
                Button("Retry") {
                    Task { await viewState.refreshData() }
                }
                Button("Dismiss") {
                    viewState.clearError()
                }
            } message: {
                Text(viewState.error?.localizedDescription ?? "An unknown error occurred")
            }
        }
        .task {
            await viewState.loadInitialData()
        }
    }
}

// MARK: - Dependency Container

class AnalyticsDependencyContainer {
    private let coreEngine: NetworkAnalyticsEngine
    
    init(coreEngine: NetworkAnalyticsEngine) {
        self.coreEngine = coreEngine
    }
    
    // Lazy initialization for better performance
    lazy var cache: AnalyticsCache = {
        AnalyticsCache()
    }()
    
    lazy var exportService: ExportService = {
        FileExportService()
    }()
    
    lazy var repository: AnalyticsRepository = {
        NetworkAnalyticsRepository(
            networkEngine: coreEngine,
            cache: cache
        )
    }()
    
    lazy var interactor: AnalyticsInteractor = {
        NetworkAnalyticsInteractor(
            repository: repository,
            exportService: exportService
        )
    }()
    
    func makeAnalyticsView() -> AnalyticsView {
        AnalyticsView(interactor: interactor)
    }
}

// MARK: - Supporting Types

enum AnalyticsAction {
    case loadInitialData
    case refreshData
    case changeTimeRange(TimeRange)
    case exportData(AnalyticsExportFormat)
}

enum AnalyticsError: LocalizedError {
    case dataFetchFailed(Error)
    case exportFailed(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .dataFetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}
```

## Benefits
1. **Separation of Concerns**: Clear boundaries between UI, business logic, and data
2. **Testability**: Each layer can be independently tested with mocks
3. **Maintainability**: Changes in one layer don't affect others
4. **Flexibility**: Easy to swap implementations or add new features
5. **Reusability**: Business logic can be reused across different UI frameworks
6. **Scalability**: Architecture supports complex applications with multiple modules

## Trade-offs
1. **Initial Complexity**: More setup and boilerplate code
2. **Learning Curve**: Requires understanding of Clean Architecture principles
3. **Over-engineering**: May be excessive for simple applications
4. **Performance**: Additional abstraction layers may introduce minor overhead

## Usage Guidelines
- Use protocols for all dependencies between layers
- Keep views stateless and delegate logic to view state objects
- Implement proper dependency injection
- Write comprehensive unit tests for each layer
- Use interactors for all business logic operations
- Implement proper error handling at each layer boundary

## Integration Points
- Environment injection for SwiftUI views
- Protocol-based dependency injection
- Combine publishers for reactive data flow
- Async/await for asynchronous operations

## Related Patterns
- PATTERN-2025-035: SwiftUI Async State Management
- PATTERN-2025-036: GUI-Core API Bridge Pattern
- PATTERN-2025-039: Analytics State Management Pattern

## Testing Strategy
- Unit tests for interactors with mocked repositories
- Repository tests with mocked data sources
- View state tests with mocked interactors
- Integration tests for complete data flow
- UI tests for user interaction scenarios

## Quality Metrics
- **Test Coverage**: 95%+ for business logic
- **Dependency Analysis**: Zero circular dependencies
- **Code Quality**: High cohesion, low coupling
- **Performance**: Fast dependency resolution

---
*Extracted from STORY-2025-010: Network Analytics Module Integration*  
*Pattern validated with Clean Architecture principles and SwiftUI best practices*
