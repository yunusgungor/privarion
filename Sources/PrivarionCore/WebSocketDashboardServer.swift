import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
import Logging
import Combine

/// WebSocket-based real-time dashboard server for network monitoring
/// Implements Context7 WebSocket patterns from SwiftNIO research
/// Provides real-time event streaming to multiple dashboard clients
@available(macOS 10.15, *)
internal final class WebSocketDashboardServer: @unchecked Sendable {
    
    // MARK: - Types
    
    /// Dashboard client connection information  
    internal struct DashboardClient: Sendable {
        let id: String
        let channel: Channel
        let subscriptions: Set<EventSubscription>
        let connectedAt: Date
        
        internal enum EventSubscription: String, Sendable, CaseIterable {
            case connectionEvents = "connection_events"
            case trafficEvents = "traffic_events" 
            case dnsEvents = "dns_events"
            case performanceMetrics = "performance_metrics"
            case errorEvents = "error_events"
            case all = "all_events"
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
        
        setupNetworkEventSubscription()
    }
    
    deinit {
        // Safe deinit without capture
        networkEventSubscription?.cancel()
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
                connectedAt: Date()
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

/// Dashboard message types (simplified for compilation)
internal enum DashboardMessage: Sendable, Codable {
    case welcome(clientId: String, serverVersion: String, availableSubscriptions: [String])
    case networkEvent(eventType: DashboardEventType)
    case error(message: String)
    
    internal enum CodingKeys: String, CodingKey {
        case type, clientId, serverVersion, availableSubscriptions, eventType, message
    }
    
    internal enum MessageType: String, Codable {
        case welcome, networkEvent, error
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
        case .error:
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
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
        case .error(let message):
            try container.encode(MessageType.error, forKey: .type)
            try container.encode(message, forKey: .message)
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
