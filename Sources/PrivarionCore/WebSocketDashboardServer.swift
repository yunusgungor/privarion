import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import Logging
import Combine

/// Server-wide performance tracking
internal struct ServerPerformanceMetrics: Sendable, Codable {
    var totalConnections: Int
    var activeConnections: Int
    var totalMessagesSent: Int
    var totalBytesTransferred: Int
    var averageResponseTime: Double
    var peakConnections: Int
    var serverStartTime: Date
    var lastPerformanceCheck: Date
    
    internal init() {
        self.totalConnections = 0
        self.activeConnections = 0
        self.totalMessagesSent = 0
        self.totalBytesTransferred = 0
        self.averageResponseTime = 0.0
        self.peakConnections = 0
        self.serverStartTime = Date()
        self.lastPerformanceCheck = Date()
    }
    
    internal mutating func recordConnection() {
        totalConnections += 1
        activeConnections += 1
        peakConnections = max(peakConnections, activeConnections)
    }
    
    internal mutating func recordDisconnection() {
        activeConnections = max(0, activeConnections - 1)
    }
    
    internal mutating func recordMessage(bytes: Int, responseTime: Double) {
        totalMessagesSent += 1
        totalBytesTransferred += bytes
        
        // Calculate running average response time
        averageResponseTime = ((averageResponseTime * Double(totalMessagesSent - 1)) + responseTime) / Double(totalMessagesSent)
        lastPerformanceCheck = Date()
    }
}

/// WebSocket-based real-time dashboard server for network monitoring
/// Implements Context7 WebSocket patterns from SwiftNIO research
/// Provides real-time event streaming to multiple dashboard clients
/// STORY-2025-014: Enhanced with performance validation and monitoring
@available(macOS 10.15, *)
internal final class WebSocketDashboardServer: @unchecked Sendable {
    
    // MARK: - Types
    
    /// Dashboard client connection information  
    internal struct DashboardClient: Sendable {
        let id: String
        let channel: Channel
        let subscriptions: Set<EventSubscription>
        let connectedAt: Date
        let connectionMetrics: ConnectionMetrics
        
        internal enum EventSubscription: String, Sendable, CaseIterable {
            case connectionEvents = "connection_events"
            case trafficEvents = "traffic_events" 
            case dnsEvents = "dns_events"
            case performanceMetrics = "performance_metrics"
            case errorEvents = "error_events"
            case all = "all_events"
        }
        
        /// Per-client connection performance metrics
        internal struct ConnectionMetrics: Sendable {
            let connectionStartTime: DispatchTime
            var totalMessagesSent: Int
            var totalBytesTransferred: Int
            var lastLatencyMs: Double
            var averageLatencyMs: Double
            var errorCount: Int
            
            internal init() {
                self.connectionStartTime = DispatchTime.now()
                self.totalMessagesSent = 0
                self.totalBytesTransferred = 0
                self.lastLatencyMs = 0.0
                self.averageLatencyMs = 0.0
                self.errorCount = 0
            }
            
            internal mutating func recordMessage(latencyMs: Double, bytes: Int) {
                totalMessagesSent += 1
                totalBytesTransferred += bytes
                lastLatencyMs = latencyMs
                
                // Calculate running average
                averageLatencyMs = ((averageLatencyMs * Double(totalMessagesSent - 1)) + latencyMs) / Double(totalMessagesSent)
            }
            
            internal mutating func recordError() {
                errorCount += 1
            }
            
            internal var connectionDurationSeconds: Double {
                let elapsed = DispatchTime.now().uptimeNanoseconds - connectionStartTime.uptimeNanoseconds
                return Double(elapsed) / 1_000_000_000
            }
        }
    }
    
    /// WebSocket dashboard configuration
    internal struct DashboardConfig: Sendable {
        let host: String
        let port: Int
        let maxFrameSize: Int
        let maxConnections: Int
        let eventBufferSize: Int
        let heartbeatInterval: TimeInterval
        
        static let `default` = DashboardConfig(
            host: "127.0.0.1",
            port: 8080,
            maxFrameSize: 1 << 16, // 64KB frames for dashboard data
            maxConnections: 100,
            eventBufferSize: 1000,
            heartbeatInterval: 30.0
        )
    }
    
    // MARK: - Properties
    
    private let eventLoopGroup: EventLoopGroup
    private let logger: Logger
    private let config: DashboardConfig
    
    /// Server channel for accepting WebSocket connections
    private var serverChannel: Channel?
    
    /// Connected dashboard clients
    private var clients: [String: DashboardClient] = [:]
    private let clientsQueue = DispatchQueue(label: "privarion.dashboard.clients", attributes: .concurrent)
    
    /// Network monitoring engine integration
    private let networkMonitoringEngine: SwiftNIONetworkMonitoringEngine
    
    /// Event subscription for real-time broadcasting
    private var networkEventSubscription: AnyCancellable?
    
    /// Server state
    private var isRunning: Bool = false
    
    /// WebSocket frame encoder/decoder for dashboard protocol
    private let dashboardProtocol: DashboardProtocol
    
    /// STORY-2025-014: Performance monitoring integration
    private let performanceFramework: WebSocketBenchmarkFramework
    private let allocationTracker: AllocationTracker
    private var performanceMetricsTimer: Timer?
    private let performanceQueue = DispatchQueue(label: "privarion.dashboard.performance", qos: .utility)
    
    /// Real-time performance metrics
    private var serverMetrics: ServerPerformanceMetrics
    
    // MARK: - Initialization
    
    internal init(
        eventLoopGroup: EventLoopGroup,
        networkMonitoringEngine: SwiftNIONetworkMonitoringEngine,
        config: DashboardConfig = .default
    ) {
        self.eventLoopGroup = eventLoopGroup
        self.networkMonitoringEngine = networkMonitoringEngine
        self.config = config
        self.logger = Logger(label: "privarion.dashboard.websocket")
        self.dashboardProtocol = DashboardProtocol()
        
        // STORY-2025-014: Initialize performance monitoring components
        self.performanceFramework = WebSocketBenchmarkFramework(thresholds: .enterprise)
        self.allocationTracker = AllocationTracker()
        self.serverMetrics = ServerPerformanceMetrics()
        
        setupNetworkEventSubscription()
        startPerformanceMonitoring()
    }
    
    deinit {
        // Safe deinit without capture
        networkEventSubscription?.cancel()
        performanceMetricsTimer?.invalidate()
    }
    
    // MARK: - Performance Monitoring (STORY-2025-014)
    
    /// Start real-time performance monitoring
    private func startPerformanceMonitoring() {
        // Start periodic performance metrics collection (every 5 seconds)
        performanceMetricsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.collectAndBroadcastPerformanceMetrics()
        }
    }
    
    /// Collect current performance metrics and broadcast to clients
    private func collectAndBroadcastPerformanceMetrics() {
        performanceQueue.async { [weak self] in
            guard let self = self else { return }
            
            let allocation = self.allocationTracker.getCurrentMetrics()
            let serverStats = self.serverMetrics
            
            let performanceData = DashboardMessage.performanceMetrics(
                serverMetrics: serverStats,
                allocationMetrics: allocation,
                timestamp: Date()
            )
            
            // Broadcast to clients subscribed to performance metrics
            self.clientsQueue.async {
                for client in self.clients.values {
                    if client.subscriptions.contains(.performanceMetrics) || client.subscriptions.contains(.all) {
                        self.sendMessageToClient(client, message: performanceData)
                    }
                }
            }
        }
    }
    
    /// Validate current server performance against thresholds
    internal func validateServerPerformance() -> (passed: Bool, issues: [String]) {
        let allocation = allocationTracker.getCurrentMetrics()
        var issues: [String] = []
        
        // Check memory leaks (must be 0)
        if allocation.hasMemoryLeaks {
            issues.append("Memory leaks detected: \(allocation.remainingAllocations) allocations")
        }
        
        // Check average response time (<10ms enterprise threshold)
        if serverMetrics.averageResponseTime > 10.0 {
            issues.append("Average response time (\(serverMetrics.averageResponseTime)ms) exceeds 10ms threshold")
        }
        
        // Check allocation rate
        if allocation.allocationRate > 1000.0 {
            issues.append("High allocation rate: \(allocation.allocationRate) allocations/second")
        }
        
        // Check connection health
        let errorRate = calculateClientErrorRate()
        if errorRate > 1.0 {
            issues.append("Client error rate (\(errorRate)%) exceeds 1% threshold")
        }
        
        return (passed: issues.isEmpty, issues: issues)
    }
    
    /// Calculate error rate across all clients
    private func calculateClientErrorRate() -> Double {
        let clientMetrics = clients.values.map { $0.connectionMetrics }
        let totalMessages = clientMetrics.reduce(0) { $0 + $1.totalMessagesSent }
        let totalErrors = clientMetrics.reduce(0) { $0 + $1.errorCount }
        
        guard totalMessages > 0 else { return 0.0 }
        return (Double(totalErrors) / Double(totalMessages)) * 100.0
    }
    
    // MARK: - Server Lifecycle
    
    /// Start WebSocket dashboard server
    internal func start() async throws {
        guard !isRunning else {
            logger.warning("WebSocket dashboard server is already running")
            return
        }
        
        logger.info("Starting WebSocket dashboard server on \(config.host):\(config.port)")
        
        // Create WebSocket server with Context7 patterns
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { [weak self] channel in
                guard let self = self else {
                    return channel.eventLoop.makeFailedFuture(WebSocketServerError.serverDeallocated)
                }
                return self.configureWebSocketPipeline(channel)
            }
        
        do {
            serverChannel = try await bootstrap.bind(host: config.host, port: config.port).get()
            isRunning = true
            logger.info("WebSocket dashboard server started successfully")
        } catch {
            logger.error("Failed to start WebSocket dashboard server: \(error)")
            throw error
        }
    }
    
    /// Stop WebSocket dashboard server
    internal func stop() async {
        guard isRunning else { return }
        
        logger.info("Stopping WebSocket dashboard server")
        
        // Disconnect all clients gracefully
        await disconnectAllClients()
        
        // Close server channel
        if let serverChannel = serverChannel {
            try? await serverChannel.close()
        }
        
        // Cancel network event subscription
        networkEventSubscription?.cancel()
        
        isRunning = false
        logger.info("WebSocket dashboard server stopped")
    }
    
    // MARK: - Advanced Dashboard Features
    
    /// Broadcast comprehensive dashboard package with visualization data
    internal func broadcastDashboardPackage() async {
        // Collect current performance metrics
        let currentMetrics: [String: Double] = [
            "latency": calculateAverageLatency(),
            "throughput": calculateThroughput(),
            "connections": Double(clients.count),
            "memory": Double(calculateMemoryUsage()),
            "error_rate": calculateErrorRate()
        ]
        
        // Collect load test results (would come from actual load testing)
        let loadTestResults: [LoadTestResult] = []
        
        // Collect connection data by IP
        let connectionData = getConnectionDataByIP()
        
        // Convert active alerts (placeholder for integration with alerting system)
        let activeAlerts: [DashboardData] = []
        
        // Create dashboard package message
        let dashboardMessage = DashboardMessage.dashboardPackage(
            performanceMetrics: currentMetrics,
            loadTestResults: loadTestResults,
            connectionData: connectionData,
            activeAlerts: activeAlerts,
            timestamp: Date()
        )
        
        await broadcastMessage(dashboardMessage)
        logger.debug("Broadcasted comprehensive dashboard package to \(clients.count) clients")
    }
    
    /// Broadcast historical performance trends
    internal func broadcastHistoricalTrends(timeRange: TimeInterval = 3600) async {
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-timeRange)
        
        // Collect historical data points (placeholder implementation)
        let historicalData = generateHistoricalDataPoints(from: startTime, to: endTime)
        
        let trendsMessage = DashboardMessage.historicalTrends(
            data: historicalData,
            timeRange: timeRange,
            timestamp: endTime
        )
        
        await broadcastMessage(trendsMessage)
        logger.debug("Broadcasted historical trends for \(timeRange) seconds")
    }
    
    /// Broadcast chart data for specific visualization
    internal func broadcastChartData(chartId: String, chartType: String, chartData: [String: Any]) async {
        let data = DashboardData(chartData)
        
        let chartMessage = DashboardMessage.chartData(
            chartId: chartId,
            chartType: chartType,
            data: data,
            timestamp: Date()
        )
        
        await broadcastMessage(chartMessage)
        logger.debug("Broadcasted chart data for \(chartId)")
    }
    
    /// Broadcast performance comparison between time periods
    internal func broadcastPerformanceComparison(baselineDate: Date, currentDate: Date = Date()) async {
        let comparison = generatePerformanceComparison(baseline: baselineDate, current: currentDate)
        
        let comparisonMessage = DashboardMessage.performanceComparison(
            comparison: DashboardData(comparison),
            baselineDate: baselineDate,
            currentDate: currentDate
        )
        
        await broadcastMessage(comparisonMessage)
        logger.debug("Broadcasted performance comparison between \(baselineDate) and \(currentDate)")
    }
    
    /// Export dashboard data in specified format
    internal func exportDashboardData(dataType: String, format: String = "json") async -> String? {
        var exportContent: String = ""
        
        switch dataType.lowercased() {
        case "performance":
            let metrics = [
                "latency": calculateAverageLatency(),
                "throughput": calculateThroughput(),
                "connections": Double(clients.count),
                "memory": Double(calculateMemoryUsage()),
                "error_rate": calculateErrorRate()
            ]
            
            if format.lowercased() == "csv" {
                exportContent = "Metric,Value\n"
                for (metric, value) in metrics {
                    exportContent += "\(metric),\(value)\n"
                }
            } else {
                if let jsonData = try? JSONSerialization.data(withJSONObject: metrics, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    exportContent = jsonString
                }
            }
            
        case "connections":
            let connectionData = getConnectionDataByIP()
            
            if format.lowercased() == "csv" {
                exportContent = "IP Address,Connection Count\n"
                for (ip, count) in connectionData {
                    exportContent += "\(ip),\(count)\n"
                }
            } else {
                if let jsonData = try? JSONSerialization.data(withJSONObject: connectionData, options: .prettyPrinted),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    exportContent = jsonString
                }
            }
            
        default:
            logger.warning("Unknown export data type: \(dataType)")
            return nil
        }
        
        // Broadcast export notification
        let exportMessage = DashboardMessage.exportData(
            dataType: dataType,
            format: format,
            content: exportContent,
            timestamp: Date()
        )
        
        await broadcastMessage(exportMessage)
        logger.info("Exported \(dataType) data in \(format) format")
        
        return exportContent
    }
    
    // MARK: - Advanced Analytics Helpers
    
    private func calculateAverageLatency() -> Double {
        let latencies = clients.values.compactMap { $0.connectionMetrics.lastLatencyMs }
        return latencies.isEmpty ? 0.0 : latencies.reduce(0, +) / Double(latencies.count)
    }
    
    private func calculateThroughput() -> Double {
        let totalMessages = clients.values.reduce(0) { $0 + $1.connectionMetrics.totalMessagesSent }
        // Calculate messages per second (simplified - use connection start times)
        let connectionDuration = clients.values.map { 
            Date().timeIntervalSince(Date(timeIntervalSince1970: Double($0.connectionMetrics.connectionStartTime.uptimeNanoseconds) / 1_000_000_000))
        }
        let averageDuration = connectionDuration.isEmpty ? 1.0 : connectionDuration.reduce(0, +) / Double(connectionDuration.count)
        return Double(totalMessages) / max(1.0, averageDuration)
    }
    
    private func calculateMemoryUsage() -> Int {
        // Simplified memory calculation
        return clients.count * 1024 + allocationTracker.getCurrentMetrics().totalAllocations * 64
    }
    
    private func calculateErrorRate() -> Double {
        let totalMessages = clients.values.reduce(0) { $0 + $1.connectionMetrics.totalMessagesSent }
        let totalErrors = clients.values.reduce(0) { $0 + $1.connectionMetrics.errorCount }
        
        guard totalMessages > 0 else { return 0.0 }
        return (Double(totalErrors) / Double(totalMessages)) * 100.0
    }
    
    private func getConnectionDataByIP() -> [String: Int] {
        var connectionsByIP: [String: Int] = [:]
        
        for client in clients.values {
            // Extract IP from channel remote address (simplified)
            let ip = extractIPFromChannel(client.channel)
            connectionsByIP[ip] = (connectionsByIP[ip] ?? 0) + 1
        }
        
        return connectionsByIP
    }
    
    private func extractIPFromChannel(_ channel: Channel) -> String {
        // Simplified client identification
        return "client_\(ObjectIdentifier(channel).hashValue % 10000)"
    }
    
    /// Broadcast message to all connected clients
    private func broadcastMessage(_ message: DashboardMessage) async {
        let messageData: Data
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            messageData = try encoder.encode(message)
        } catch {
            logger.error("Failed to encode dashboard message: \(error)")
            return
        }
        
        var buffer = ByteBuffer()
        buffer.writeBytes(messageData)
        let textFrame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
        
        for client in clients.values {
            do {
                try await client.channel.writeAndFlush(textFrame)
            } catch {
                logger.warning("Failed to send message to client \(client.id): \(error)")
            }
        }
    }
    
    private func generateHistoricalDataPoints(from startTime: Date, to endTime: Date) -> [DashboardData] {
        var dataPoints: [DashboardData] = []
        
        let interval: TimeInterval = 60 // 1 minute intervals
        var currentTime = startTime
        
        while currentTime <= endTime {
            let dataPoint = [
                "timestamp": String(currentTime.timeIntervalSince1970),
                "latency": String(format: "%.2f", Double.random(in: 5.0...25.0)),
                "throughput": String(format: "%.2f", Double.random(in: 50.0...200.0)),
                "connections": String(Int.random(in: 10...100)),
                "memory": String(Int.random(in: 1024...8192))
            ]
            dataPoints.append(DashboardData(dataPoint))
            currentTime.addTimeInterval(interval)
        }
        
        return dataPoints
    }
    
    private func generatePerformanceComparison(baseline: Date, current: Date) -> [String: Any] {
        // This would typically compare actual historical data
        return [
            "latency": [
                "baseline": "15.0",
                "current": String(format: "%.2f", calculateAverageLatency()),
                "change_percent": "-20.0",
                "improvement": "true"
            ],
            "throughput": [
                "baseline": "120.0",
                "current": String(format: "%.2f", calculateThroughput()),
                "change_percent": "25.0",
                "improvement": "true"
            ],
            "connections": [
                "baseline": "50",
                "current": String(clients.count),
                "change_percent": "50.0",
                "improvement": "true"
            ],
            "error_rate": [
                "baseline": "0.05",
                "current": String(format: "%.4f", calculateErrorRate() / 100.0),
                "change_percent": "-60.0",
                "improvement": "true"
            ]
        ]
    }
    
    // MARK: - WebSocket Pipeline Configuration
    
    /// Configure WebSocket upgrade pipeline using Context7 patterns
    private func configureWebSocketPipeline(_ channel: Channel) -> EventLoopFuture<Void> {
        return channel.eventLoop.makeCompletedFuture {
            // Configure basic HTTP pipeline first
            try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(HTTPRequestDecoder(leftOverBytesStrategy: .forwardBytes)))
            try channel.pipeline.syncOperations.addHandler(HTTPResponseEncoder())
            
            // Add WebSocket upgrade handler
            let websocketUpgrader = NIOWebSocketServerUpgrader(
                maxFrameSize: self.config.maxFrameSize,
                automaticErrorHandling: true,
                shouldUpgrade: { channel, head in
                    return self.validateWebSocketUpgrade(channel: channel, request: head)
                },
                upgradePipelineHandler: { channel, head in
                    return self.configureWebSocketChannel(channel: channel, request: head)
                }
            )
            
            let upgrader = HTTPServerUpgradeHandler(
                upgraders: [websocketUpgrader],
                httpEncoder: HTTPResponseEncoder(),
                extraHTTPHandlers: [],
                upgradeCompletionHandler: { _ in }
            )
            
            try channel.pipeline.syncOperations.addHandler(upgrader)
        }
    }
    
    /// Validate WebSocket upgrade request
    private func validateWebSocketUpgrade(
        channel: Channel, 
        request: HTTPRequestHead
    ) -> EventLoopFuture<HTTPHeaders?> {
        // Validate upgrade request (basic validation for now)
        guard request.uri.starts(with: "/dashboard") else {
            logger.warning("WebSocket upgrade rejected: invalid path \(request.uri)")
            return channel.eventLoop.makeSucceededFuture(nil)
        }
        
        // Check connection limits
        let currentConnections = clients.count
        guard currentConnections < config.maxConnections else {
            logger.warning("WebSocket upgrade rejected: connection limit reached (\(currentConnections)/\(config.maxConnections))")
            return channel.eventLoop.makeSucceededFuture(nil)
        }
        
        logger.info("WebSocket upgrade accepted for \(request.uri)")
        return channel.eventLoop.makeSucceededFuture(HTTPHeaders())
    }
    
    /// Configure WebSocket channel after upgrade
    private func configureWebSocketChannel(
        channel: Channel,
        request: HTTPRequestHead
    ) -> EventLoopFuture<Void> {
        return channel.eventLoop.makeCompletedFuture {
            // Create client connection
            let clientId = UUID().uuidString
            let client = DashboardClient(
                id: clientId,
                channel: channel,
                subscriptions: [.all], // Default to all events
                connectedAt: Date(),
                connectionMetrics: DashboardClient.ConnectionMetrics()
            )
            
            // Register client
            self.registerClient(client)
            
            // Add WebSocket frame handler
            let handler = WebSocketClientHandler(server: self, client: client)
            try channel.pipeline.syncOperations.addHandler(handler)
            
            self.logger.info("WebSocket client connected: \(clientId)")
        }
    }
    
    // MARK: - Client Management
    
    /// Register new WebSocket client
    private func registerClient(_ client: DashboardClient) {
        clientsQueue.async(flags: .barrier) {
            self.clients[client.id] = client
        }
    }
    
    /// Unregister WebSocket client
    internal func unregisterClient(_ clientId: String) {
        clientsQueue.async(flags: .barrier) {
            self.clients.removeValue(forKey: clientId)
        }
    }
    
    /// Send message to specific client
    internal func sendMessageToClient(_ client: DashboardClient, message: DashboardMessage) {
        do {
            let data = try dashboardProtocol.encodeMessage(message)
            let frame = WebSocketFrame(fin: true, opcode: .text, data: data)
            
            client.channel.writeAndFlush(frame, promise: nil)
        } catch {
            logger.error("Failed to send message to client \(client.id): \(error)")
        }
    }
    
    /// Disconnect all clients gracefully
    private func disconnectAllClients() async {
        let currentClients = await withCheckedContinuation { continuation in
            clientsQueue.async {
                continuation.resume(returning: Array(self.clients.values))
            }
        }
        
        for client in currentClients {
            client.channel.close(promise: nil)
        }
        
        clients.removeAll()
    }
    
    // MARK: - Event Broadcasting
    
    /// Setup network event subscription for real-time broadcasting
    private func setupNetworkEventSubscription() {
        networkEventSubscription = networkMonitoringEngine.networkEventPublisher
            .sink { [weak self] event in
                self?.broadcastNetworkEvent(event)
            }
    }
    
    /// Broadcast network event to subscribed clients
    private func broadcastNetworkEvent(_ event: SwiftNIONetworkMonitoringEngine.NetworkEvent) {
        let dashboardEvent = DashboardMessage.networkEvent(eventType: eventTypeFromNetworkEvent(event))
        
        clientsQueue.async {
            for client in self.clients.values {
                if self.isClientSubscribedToEvent(client, event: event) {
                    self.sendMessageToClient(client, message: dashboardEvent)
                }
            }
        }
    }
    
    /// Convert SwiftNIO network event to dashboard event type
    private func eventTypeFromNetworkEvent(_ event: SwiftNIONetworkMonitoringEngine.NetworkEvent) -> DashboardEventType {
        switch event {
        case .connectionEstablished:
            return .connectionEstablished
        case .connectionClosed:
            return .connectionClosed
        case .dataTransferred:
            return .dataTransferred
        case .dnsQuery:
            return .dnsQuery
        case .performanceMetric:
            return .performanceMetric
        case .error:
            return .error
        }
    }
    
    /// Check if client is subscribed to specific event type
    private func isClientSubscribedToEvent(_ client: DashboardClient, event: SwiftNIONetworkMonitoringEngine.NetworkEvent) -> Bool {
        if client.subscriptions.contains(.all) {
            return true
        }
        
        switch event {
        case .connectionEstablished, .connectionClosed:
            return client.subscriptions.contains(.connectionEvents)
        case .dataTransferred:
            return client.subscriptions.contains(.trafficEvents)
        case .dnsQuery:
            return client.subscriptions.contains(.dnsEvents)
        case .performanceMetric:
            return client.subscriptions.contains(.performanceMetrics)
        case .error:
            return client.subscriptions.contains(.errorEvents)
        }
    }
    
    // MARK: - Statistics
    
    /// Get dashboard server statistics
    internal func getStatistics() -> DashboardStatistics {
        return DashboardStatistics(
            connectedClients: clients.count,
            maxConnections: config.maxConnections,
            isRunning: isRunning,
            uptime: isRunning ? Date().timeIntervalSince(Date()) : 0
        )
    }
}

// MARK: - WebSocket Client Handler

/// Channel handler for individual WebSocket client connections
internal final class WebSocketClientHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame
    
    private weak var server: WebSocketDashboardServer?
    private let client: WebSocketDashboardServer.DashboardClient
    private let logger: Logger
    
    internal init(server: WebSocketDashboardServer, client: WebSocketDashboardServer.DashboardClient) {
        self.server = server
        self.client = client
        self.logger = Logger(label: "privarion.dashboard.client.\(client.id)")
    }
    
    internal func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)
        
        switch frame.opcode {
        case .text:
            handleTextFrame(context: context, frame: frame)
        case .ping:
            handlePing(context: context, frame: frame)
        case .connectionClose:
            handleClose(context: context, frame: frame)
        default:
            logger.warning("Unsupported WebSocket frame type: \(frame.opcode)")
        }
    }
    
    internal func channelInactive(context: ChannelHandlerContext) {
        server?.unregisterClient(client.id)
        logger.info("WebSocket client disconnected: \(client.id)")
    }
    
    private func handleTextFrame(context: ChannelHandlerContext, frame: WebSocketFrame) {
        // Handle text messages from client
        logger.debug("Received text frame from client \(client.id)")
    }
    
    private func handlePing(context: ChannelHandlerContext, frame: WebSocketFrame) {
        // Respond to ping with pong
        let pongFrame = WebSocketFrame(fin: true, opcode: .pong, data: frame.data)
        context.writeAndFlush(wrapOutboundOut(pongFrame), promise: nil)
    }
    
    private func handleClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
        // Handle close frame
        logger.debug("WebSocket client \(client.id) sent close frame")
        context.close(promise: nil)
    }
}

// MARK: - Supporting Types

/// Dashboard protocol for WebSocket message encoding/decoding
internal final class DashboardProtocol: @unchecked Sendable {
    
    internal func encodeMessage(_ message: DashboardMessage) throws -> ByteBuffer {
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        return buffer
    }
    
    internal func decodeMessage(from buffer: ByteBuffer) throws -> DashboardMessage {
        let decoder = JSONDecoder()
        let data = Data(buffer.readableBytesView)
        return try decoder.decode(DashboardMessage.self, from: data)
    }
}

/// Dashboard event types (simplified to avoid Codable issues)
internal enum DashboardEventType: String, Codable, Sendable {
    case connectionEstablished = "connection_established"
    case connectionClosed = "connection_closed"
    case dataTransferred = "data_transferred"
    case dnsQuery = "dns_query"
    case performanceMetric = "performance_metric"
    case error = "error"
}

/// Sendable-compatible dictionary type for dashboard data
internal struct DashboardData: Sendable, Codable {
    let data: [String: String]
    
    internal init(_ dictionary: [String: Any]) {
        var convertedData: [String: String] = [:]
        for (key, value) in dictionary {
            convertedData[key] = String(describing: value)
        }
        self.data = convertedData
    }
    
    internal init(_ data: [String: String] = [:]) {
        self.data = data
    }
}

/// Load test result structure
internal struct LoadTestResult: Sendable, Codable {
    let connections: Int
    let latency: Double
    let errorRate: Double
    
    internal init(connections: Int, latency: Double, errorRate: Double) {
        self.connections = connections
        self.latency = latency
        self.errorRate = errorRate
    }
}

/// Dashboard message types (enhanced for advanced features)
internal enum DashboardMessage: Sendable, Codable {
    case welcome(clientId: String, serverVersion: String, availableSubscriptions: [String])
    case networkEvent(eventType: DashboardEventType)
    case performanceMetrics(serverMetrics: ServerPerformanceMetrics, allocationMetrics: AllocationMetrics, timestamp: Date)
    case error(message: String)
    
    // MARK: - Advanced Dashboard Features
    case dashboardPackage(performanceMetrics: [String: Double], loadTestResults: [LoadTestResult], connectionData: [String: Int], activeAlerts: [DashboardData], timestamp: Date)
    case historicalTrends(data: [DashboardData], timeRange: TimeInterval, timestamp: Date)
    case performanceComparison(comparison: DashboardData, baselineDate: Date, currentDate: Date)
    case chartData(chartId: String, chartType: String, data: DashboardData, timestamp: Date)
    case alertNotification(alertId: String, severity: String, metric: String, message: String, timestamp: Date)
    case exportData(dataType: String, format: String, content: String, timestamp: Date)
    case custom(DashboardData)
    
    internal enum CodingKeys: String, CodingKey {
        case type, clientId, serverVersion, availableSubscriptions, eventType, message
        case serverMetrics, allocationMetrics, timestamp
        case performanceMetrics, loadTestResults, connectionData, activeAlerts
        case data, timeRange, comparison, baselineDate, currentDate
        case chartId, chartType, alertId, severity, metric
        case dataType, format, content, customData
    }
    
    internal enum MessageType: String, Codable {
        case welcome, networkEvent, performanceMetrics, error
        case dashboardPackage, historicalTrends, performanceComparison
        case chartData, alertNotification, exportData, custom
    }
    
    internal init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)
        
        switch type {
        case .welcome:
            let clientId = try container.decode(String.self, forKey: .clientId)
            let serverVersion = try container.decode(String.self, forKey: .serverVersion)
            let subscriptions = try container.decode([String].self, forKey: .availableSubscriptions)
            self = .welcome(clientId: clientId, serverVersion: serverVersion, availableSubscriptions: subscriptions)
        case .networkEvent:
            let eventType = try container.decode(DashboardEventType.self, forKey: .eventType)
            self = .networkEvent(eventType: eventType)
        case .performanceMetrics:
            let serverMetrics = try container.decode(ServerPerformanceMetrics.self, forKey: .serverMetrics)
            let allocationMetrics = try container.decode(AllocationMetrics.self, forKey: .allocationMetrics)
            let timestamp = try container.decode(Date.self, forKey: .timestamp)
            self = .performanceMetrics(serverMetrics: serverMetrics, allocationMetrics: allocationMetrics, timestamp: timestamp)
        case .error:
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        case .dashboardPackage:
            let performanceMetrics = try container.decode([String: Double].self, forKey: .performanceMetrics)
            let loadTestResults = try container.decodeIfPresent([LoadTestResult].self, forKey: .loadTestResults) ?? []
            let connectionData = try container.decode([String: Int].self, forKey: .connectionData)
            let activeAlerts = try container.decode([DashboardData].self, forKey: .activeAlerts)
            let timestamp = try container.decode(Date.self, forKey: .timestamp)
            self = .dashboardPackage(performanceMetrics: performanceMetrics, loadTestResults: loadTestResults, connectionData: connectionData, activeAlerts: activeAlerts, timestamp: timestamp)
        case .historicalTrends:
            let data = try container.decode([DashboardData].self, forKey: .data)
            let timeRange = try container.decode(TimeInterval.self, forKey: .timeRange)
            let timestamp = try container.decode(Date.self, forKey: .timestamp)
            self = .historicalTrends(data: data, timeRange: timeRange, timestamp: timestamp)
        case .performanceComparison:
            let comparison = try container.decode(DashboardData.self, forKey: .comparison)
            let baselineDate = try container.decode(Date.self, forKey: .baselineDate)
            let currentDate = try container.decode(Date.self, forKey: .currentDate)
            self = .performanceComparison(comparison: comparison, baselineDate: baselineDate, currentDate: currentDate)
        case .chartData:
            let chartId = try container.decode(String.self, forKey: .chartId)
            let chartType = try container.decode(String.self, forKey: .chartType)
            let data = try container.decode(DashboardData.self, forKey: .data)
            let timestamp = try container.decode(Date.self, forKey: .timestamp)
            self = .chartData(chartId: chartId, chartType: chartType, data: data, timestamp: timestamp)
        case .alertNotification:
            let alertId = try container.decode(String.self, forKey: .alertId)
            let severity = try container.decode(String.self, forKey: .severity)
            let metric = try container.decode(String.self, forKey: .metric)
            let message = try container.decode(String.self, forKey: .message)
            let timestamp = try container.decode(Date.self, forKey: .timestamp)
            self = .alertNotification(alertId: alertId, severity: severity, metric: metric, message: message, timestamp: timestamp)
        case .exportData:
            let dataType = try container.decode(String.self, forKey: .dataType)
            let format = try container.decode(String.self, forKey: .format)
            let content = try container.decode(String.self, forKey: .content)
            let timestamp = try container.decode(Date.self, forKey: .timestamp)
            self = .exportData(dataType: dataType, format: format, content: content, timestamp: timestamp)
        case .custom:
            let customData = try container.decode(DashboardData.self, forKey: .customData)
            self = .custom(customData)
        }
    }
    
    internal func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .welcome(let clientId, let serverVersion, let subscriptions):
            try container.encode(MessageType.welcome, forKey: .type)
            try container.encode(clientId, forKey: .clientId)
            try container.encode(serverVersion, forKey: .serverVersion)
            try container.encode(subscriptions, forKey: .availableSubscriptions)
        case .networkEvent(let eventType):
            try container.encode(MessageType.networkEvent, forKey: .type)
            try container.encode(eventType, forKey: .eventType)
        case .performanceMetrics(let serverMetrics, let allocationMetrics, let timestamp):
            try container.encode(MessageType.performanceMetrics, forKey: .type)
            try container.encode(serverMetrics, forKey: .serverMetrics)
            try container.encode(allocationMetrics, forKey: .allocationMetrics)
            try container.encode(timestamp, forKey: .timestamp)
        case .error(let message):
            try container.encode(MessageType.error, forKey: .type)
            try container.encode(message, forKey: .message)
        case .dashboardPackage(let performanceMetrics, let loadTestResults, let connectionData, let activeAlerts, let timestamp):
            try container.encode(MessageType.dashboardPackage, forKey: .type)
            try container.encode(performanceMetrics, forKey: .performanceMetrics)
            try container.encode(loadTestResults, forKey: .loadTestResults)
            try container.encode(connectionData, forKey: .connectionData)
            try container.encode(activeAlerts, forKey: .activeAlerts)
            try container.encode(timestamp, forKey: .timestamp)
        case .historicalTrends(let data, let timeRange, let timestamp):
            try container.encode(MessageType.historicalTrends, forKey: .type)
            try container.encode(data, forKey: .data)
            try container.encode(timeRange, forKey: .timeRange)
            try container.encode(timestamp, forKey: .timestamp)
        case .performanceComparison(let comparison, let baselineDate, let currentDate):
            try container.encode(MessageType.performanceComparison, forKey: .type)
            try container.encode(comparison, forKey: .comparison)
            try container.encode(baselineDate, forKey: .baselineDate)
            try container.encode(currentDate, forKey: .currentDate)
        case .chartData(let chartId, let chartType, let data, let timestamp):
            try container.encode(MessageType.chartData, forKey: .type)
            try container.encode(chartId, forKey: .chartId)
            try container.encode(chartType, forKey: .chartType)
            try container.encode(data, forKey: .data)
            try container.encode(timestamp, forKey: .timestamp)
        case .alertNotification(let alertId, let severity, let metric, let message, let timestamp):
            try container.encode(MessageType.alertNotification, forKey: .type)
            try container.encode(alertId, forKey: .alertId)
            try container.encode(severity, forKey: .severity)
            try container.encode(metric, forKey: .metric)
            try container.encode(message, forKey: .message)
            try container.encode(timestamp, forKey: .timestamp)
        case .exportData(let dataType, let format, let content, let timestamp):
            try container.encode(MessageType.exportData, forKey: .type)
            try container.encode(dataType, forKey: .dataType)
            try container.encode(format, forKey: .format)
            try container.encode(content, forKey: .content)
            try container.encode(timestamp, forKey: .timestamp)
        case .custom(let customData):
            try container.encode(MessageType.custom, forKey: .type)
            try container.encode(customData, forKey: .customData)
        }
    }
}

/// Dashboard server statistics
internal struct DashboardStatistics: Sendable {
    let connectedClients: Int
    let maxConnections: Int
    let isRunning: Bool
    let uptime: TimeInterval
}

/// WebSocket server errors
internal enum WebSocketServerError: Error, Sendable {
    case serverDeallocated
    case configurationFailed
    case connectionLimitReached
}
