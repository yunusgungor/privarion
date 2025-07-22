import Foundation
import Network
import Combine
import Logging

/// Network monitoring engine for real-time network status and connection tracking
/// Implements PATTERN-2025-049: Real-time Network Monitoring Pattern
@available(macOS 10.14, *)
internal class NetworkMonitoringEngine: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// Logger instance
    private let logger: Logger
    
    /// Network path monitor
    private let pathMonitor: NWPathMonitor
    
    /// Monitoring queue
    private let monitoringQueue: DispatchQueue
    
    /// Network status publisher
    private let networkStatusSubject = CurrentValueSubject<NetworkStatus, Never>(.unknown)
    
    /// Active connections tracking
    private var activeConnections: [String: ConnectionInfo] = [:]
    private let connectionsQueue = DispatchQueue(label: "privarion.network.connections", attributes: .concurrent)
    
    /// Monitoring state
    private var isMonitoring: Bool = false
    
    /// Configuration
    private let config: NetworkMonitoringConfig
    
    /// Statistics collection
    private var networkStatistics: NetworkStatistics = NetworkStatistics()
    
    /// DNS query statistics for integration with NetworkFilteringManager
    var totalQueries: Int = 0
    var blockedQueries: Int = 0
    var allowedQueries: Int = 0
    var averageLatency: TimeInterval = 0.0
    var uptime: TimeInterval = 0.0
    
    // MARK: - Initialization
    
    internal init(config: NetworkMonitoringConfig) {
        self.logger = Logger(label: "privarion.network.monitoring")
        self.pathMonitor = NWPathMonitor()
        self.monitoringQueue = DispatchQueue(label: "privarion.network.monitor", qos: .utility)
        self.config = config
        
        setupNetworkMonitoring()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Interface
    
    /// Publisher for network status changes
    internal var networkStatusPublisher: AnyPublisher<NetworkStatus, Never> {
        return networkStatusSubject.eraseToAnyPublisher()
    }
    
    /// Start network monitoring
    internal func start() {
        guard !isMonitoring else {
            logger.warning("Network monitoring is already active")
            return
        }
        
        logger.info("Starting network monitoring engine")
        pathMonitor.start(queue: monitoringQueue)
        isMonitoring = true
        
        // Initialize statistics
        networkStatistics.startTime = Date()
        updateNetworkStatus()
    }
    
    /// Stop network monitoring
    internal func stop() {
        guard isMonitoring else { return }
        
        logger.info("Stopping network monitoring engine")
        pathMonitor.cancel()
        isMonitoring = false
        
        connectionsQueue.async(flags: .barrier) {
            self.activeConnections.removeAll()
        }
    }
    
    /// Record DNS query for statistics (compatibility with NetworkFilteringManager)
    internal func recordDNSQuery(domain: String, blocked: Bool, latency: TimeInterval) {
        totalQueries += 1
        if blocked {
            blockedQueries += 1
        }
        
        // Update network statistics
        monitoringQueue.async {
            // Simple latency tracking (for compatibility)
            self.networkStatistics.uptime = Date().timeIntervalSince(self.networkStatistics.startTime)
        }
    }
    
    /// STORY-2025-014: WebSocket Dashboard Performance Integration
    /// Start real-time performance monitoring for WebSocket dashboard
    internal func startWebSocketPerformanceMonitoring() async throws -> WebSocketMetrics {
        logger.info("Starting WebSocket dashboard performance monitoring")
        
        let benchmarkFramework = WebSocketBenchmarkFramework(thresholds: .enterprise)
        
        do {
            // Test concurrent connections with real-time monitoring
            let metrics = try await benchmarkFramework.testConcurrentConnections(
                connectionCount: 50, // Start with 50 connections for real-time testing
                host: "127.0.0.1",
                port: 8080,
                testDurationSeconds: 10.0
            )
            
            let validation = benchmarkFramework.validatePerformance(metrics)
            
            if validation.passed {
                logger.info("WebSocket performance validation passed")
            } else {
                logger.warning("WebSocket performance validation failed: \(validation.failures.joined(separator: ", "))")
            }
            
            return metrics
        } catch {
            logger.error("WebSocket performance monitoring failed: \(error)")
            throw error
        }
    }
    
    /// Continuous WebSocket load testing for dashboard validation
    internal func runContinuousWebSocketLoadTest(
        maxConnections: Int = 100,
        testDurationMinutes: Double = 5.0
    ) async throws -> [WebSocketMetrics] {
        logger.info("Starting continuous WebSocket load test with \(maxConnections) max connections")
        
        var results: [WebSocketMetrics] = []
        let benchmarkFramework = WebSocketBenchmarkFramework(thresholds: .enterprise)
        
        // Progressive load testing: 10, 25, 50, 75, 100 connections
        let connectionLevels = [10, 25, 50, 75, min(maxConnections, 100)]
        
        for connectionCount in connectionLevels {
            logger.info("Testing \(connectionCount) concurrent connections")
            
            let metrics = try await benchmarkFramework.testConcurrentConnections(
                connectionCount: connectionCount,
                host: "127.0.0.1",
                port: 8080,
                testDurationSeconds: testDurationMinutes * 60.0 / Double(connectionLevels.count)
            )
            
            results.append(metrics)
            
            // Validate performance at each level
            let validation = benchmarkFramework.validatePerformance(metrics)
            if !validation.passed {
                logger.warning("Performance validation failed at \(connectionCount) connections: \(validation.failures)")
                // Continue testing but log the failures
            }
            
            // Brief pause between test levels
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }
        
        logger.info("Continuous WebSocket load test completed with \(results.count) test levels")
        return results
    }
    
    /// Get current network status
    internal func getCurrentNetworkStatus() -> NetworkStatus {
        return networkStatusSubject.value
    }
    
    /// Register a new connection for monitoring
    internal func registerConnection(_ connection: NWConnection, forProcess processId: Int32) {
        let connectionId = generateConnectionId(connection)
        let connectionInfo = ConnectionInfo(
            id: connectionId,
            connection: connection,
            processId: processId,
            startTime: Date(),
            localEndpoint: connection.currentPath?.localEndpoint,
            remoteEndpoint: connection.currentPath?.remoteEndpoint
        )
        
        connectionsQueue.async(flags: .barrier) {
            self.activeConnections[connectionId] = connectionInfo
        }
        
        logger.debug("Registered connection", metadata: [
            "connectionId": "\(connectionId)",
            "processId": "\(processId)"
        ])
        
        // Update statistics
        updateConnectionStatistics()
    }
    
    /// Unregister a connection
    internal func unregisterConnection(_ connection: NWConnection) {
        let connectionId = generateConnectionId(connection)
        
        connectionsQueue.async(flags: .barrier) {
            self.activeConnections.removeValue(forKey: connectionId)
        }
        
        logger.debug("Unregistered connection", metadata: ["connectionId": "\(connectionId)"])
        updateConnectionStatistics()
    }
    
    /// Get active connections count
    internal func getActiveConnectionsCount() -> Int {
        return connectionsQueue.sync {
            return activeConnections.count
        }
    }
    
    /// Get network monitoring statistics
    internal func getNetworkStatistics() -> NetworkStatistics {
        let currentStats = networkStatistics
        currentStats.activeConnections = getActiveConnectionsCount()
        currentStats.uptime = Date().timeIntervalSince(currentStats.startTime)
        return currentStats
    }
    
    /// Check if network is available for DNS resolution
    internal func isNetworkAvailable() -> Bool {
        let currentStatus = getCurrentNetworkStatus()
        return currentStatus == .connected || currentStatus == .connectedViaWiFi || currentStatus == .connectedViaEthernet
    }
    
    /// Get preferred network interface type
    internal func getPreferredNetworkInterface() -> NWInterface.InterfaceType? {
        let currentPath = pathMonitor.currentPath
        
        // Prefer ethernet over WiFi, WiFi over cellular
        if currentPath.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else if currentPath.usesInterfaceType(.wifi) {
            return .wifi
        } else if currentPath.usesInterfaceType(.cellular) {
            return .cellular
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            self.logger.debug("Network path updated", metadata: [
                "status": "\(path.status)",
                "isExpensive": "\(path.isExpensive)",
                "interfaces": "\(path.availableInterfaces.count)"
            ])
            
            self.updateNetworkStatus(from: path)
        }
    }
    
    private func updateNetworkStatus(from path: NWPath? = nil) {
        let currentPath = path ?? pathMonitor.currentPath
        let newStatus = determineNetworkStatus(from: currentPath)
        
        if newStatus != networkStatusSubject.value {
            networkStatusSubject.send(newStatus)
            logger.info("Network status changed", metadata: ["status": "\(newStatus)"])
        }
    }
    
    private func determineNetworkStatus(from path: NWPath?) -> NetworkStatus {
        guard let path = path else { return .unknown }
        
        switch path.status {
        case .satisfied:
            if path.usesInterfaceType(.wiredEthernet) {
                return .connectedViaEthernet
            } else if path.usesInterfaceType(.wifi) {
                return .connectedViaWiFi
            } else if path.usesInterfaceType(.cellular) {
                return .connectedViaCellular
            } else {
                return .connected
            }
        case .unsatisfied:
            return .disconnected
        case .requiresConnection:
            return .requiresConnection
        @unknown default:
            return .unknown
        }
    }
    
    private func generateConnectionId(_ connection: NWConnection) -> String {
        return "\(ObjectIdentifier(connection).hashValue)"
    }
    
    private func updateConnectionStatistics() {
        let connectionCount = getActiveConnectionsCount()
        networkStatistics.activeConnections = connectionCount
        networkStatistics.peakConnections = max(networkStatistics.peakConnections, connectionCount)
    }
}

// MARK: - Supporting Types

/// Network status enumeration
internal enum NetworkStatus: String, CaseIterable, Sendable {
    case unknown = "unknown"
    case connected = "connected"
    case connectedViaWiFi = "wifi"
    case connectedViaEthernet = "ethernet"
    case connectedViaCellular = "cellular"
    case disconnected = "disconnected"
    case requiresConnection = "requires_connection"
}

/// Connection information for tracking
internal struct ConnectionInfo: Sendable {
    let id: String
    let connection: NWConnection
    let processId: Int32
    let startTime: Date
    let localEndpoint: NWEndpoint?
    let remoteEndpoint: NWEndpoint?
}

/// Network monitoring statistics
internal class NetworkStatistics: @unchecked Sendable {
    var startTime: Date = Date()
    var uptime: TimeInterval = 0
    var activeConnections: Int = 0
    var peakConnections: Int = 0
    var totalConnections: Int = 0
    var networkChanges: Int = 0
    
    init() {}
}
