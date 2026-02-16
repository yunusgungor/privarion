import Foundation
import NIOCore
import NIOPosix
import Logging

/// High-performance DNS proxy server using SwiftNIO for modern async networking
/// Implements Context7 research findings and PATTERN-2025-067, 068, 070
@available(macOS 10.15, *)
internal class SwiftNIODNSProxyServer {
    // MARK: - Configuration
    private let configuration: NetworkFilterConfig
    private let logger: Logger
    private let dnsPort: Int
    private let upstreamServers: [String]
    private let queryTimeout: Double
    
    // MARK: - SwiftNIO Components (PATTERN-2025-068: EventLoop Group Management)
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private var serverChannel: Channel?
    private var _isRunning = false
    
    // MARK: - Business Logic Components
    private let ruleEngine: ApplicationNetworkRuleEngine
    private let blocklistManager: BlocklistManager
    private let trafficMonitor: TrafficMonitoringService
    
    // MARK: - Async Channel Management (PATTERN-2025-067: SwiftNIO Async Channel Pattern)
    private var asyncChannel: NIOAsyncChannel<AddressedEnvelope<ByteBuffer>, AddressedEnvelope<ByteBuffer>>?
    
    weak var delegate: DNSProxyServerDelegate?
    
    // Public getter for isRunning
    internal var isRunning: Bool {
        return _isRunning
    }
    
    // MARK: - Initialization
    internal init(port: Int, upstreamServers: [String], queryTimeout: Double) {
        self.configuration = ConfigurationManager.shared.getCurrentConfiguration().modules.networkFilter
        self.logger = Logger(label: "privarion.swiftnio.dns.proxy")
        self.dnsPort = port
        self.upstreamServers = upstreamServers
        self.queryTimeout = queryTimeout
        self.ruleEngine = ApplicationNetworkRuleEngine()
        self.blocklistManager = BlocklistManager()
        self.trafficMonitor = TrafficMonitoringService()
        
        // PATTERN-2025-068: Optimal CPU utilization with core count detection
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        logger.info("SwiftNIO DNS Proxy Server initialized with \(System.coreCount) threads")
    }
    
    deinit {
        let eventLoopGroup = self.eventLoopGroup
        Task.detached {
            do {
                try await eventLoopGroup.shutdownGracefully()
            } catch {
                // Log but don't throw from deinit
            }
        }
    }
    
    // MARK: - Server Lifecycle
    
    /// Start the high-performance SwiftNIO DNS proxy server
    internal func start() async throws {
        guard !_isRunning else {
            logger.warning("SwiftNIO DNS proxy server is already running")
            return
        }
        
        // PATTERN-2025-070: Channel Pipeline Configuration Pattern
        let serverBootstrap = DatagramBootstrap(group: eventLoopGroup)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                // Configure the channel pipeline for DNS processing
                return channel.eventLoop.makeCompletedFuture {
                    // PATTERN-2025-067: Wrap channel with NIOAsyncChannel for async I/O
                    let _ = try NIOAsyncChannel<AddressedEnvelope<ByteBuffer>, AddressedEnvelope<ByteBuffer>>(
                        wrappingChannelSynchronously: channel
                    )
                    return ()
                }
            }
        
        // Bind to DNS port
        let boundChannel = try await serverBootstrap.bind(host: "0.0.0.0", port: dnsPort) { channel in
            return channel.eventLoop.makeCompletedFuture {
                let asyncChannel = try NIOAsyncChannel<AddressedEnvelope<ByteBuffer>, AddressedEnvelope<ByteBuffer>>(
                    wrappingChannelSynchronously: channel
                )
                return asyncChannel
            }
        }
        
        self.serverChannel = boundChannel.channel
        self.asyncChannel = boundChannel
        self._isRunning = true
        
        // Start traffic monitoring
        trafficMonitor.startMonitoring()
        
        logger.info("SwiftNIO DNS proxy server started on port \(dnsPort) with async I/O")
        
        // Start processing DNS requests asynchronously
        Task {
            await processDNSRequests()
        }
    }
    
    /// Stop the DNS proxy server gracefully
    internal func stop() async {
        await shutdown()
    }
    
    private func shutdown() async {
        guard isRunning else { return }
        
        logger.info("Shutting down SwiftNIO DNS proxy server...")
        
        // Stop traffic monitoring
        trafficMonitor.stopMonitoring()
        
        // Close the server channel
        if let serverChannel = self.serverChannel {
            do {
                try await serverChannel.close()
            } catch {
                logger.warning("Failed to close server channel: \(error.localizedDescription)")
            }
        }
        
        // Shutdown event loop group
        do {
            try await eventLoopGroup.shutdownGracefully()
        } catch {
            logger.warning("Failed to shutdown event loop group: \(error.localizedDescription)")
        }
        
        _isRunning = false
        asyncChannel = nil
        serverChannel = nil
        
        logger.info("SwiftNIO DNS proxy server shutdown completed")
    }
    
    // MARK: - High-Performance DNS Request Processing
    
    private func processDNSRequests() async {
        guard let asyncChannel = self.asyncChannel else {
            logger.error("Async channel not available for DNS request processing")
            return
        }
        
        do {
            // PATTERN-2025-067: Modern async/await pattern with AsyncSequence
            try await asyncChannel.executeThenClose { inbound, outbound in
                for try await request in inbound {
                    let startTime = Date()
                    
                    // Process DNS request asynchronously without blocking the event loop
                    Task {
                        await self.handleDNSRequest(request, outbound: outbound, startTime: startTime)
                    }
                }
            }
        } catch {
            logger.error("Error in DNS request processing: \(error)")
        }
    }
    
    private func handleDNSRequest(
        _ request: AddressedEnvelope<ByteBuffer>,
        outbound: NIOAsyncChannelOutboundWriter<AddressedEnvelope<ByteBuffer>>,
        startTime: Date
    ) async {
        let clientAddress = request.remoteAddress
        var requestBuffer = request.data
        
        // Parse DNS query
        guard let dnsQuery = parseDNSQuery(from: &requestBuffer) else {
            logger.warning("Failed to parse DNS query from \(clientAddress)")
            return
        }
        
        logger.debug("Processing DNS query for domain: \(dnsQuery.domain) from \(clientAddress)")
        
        // Check if domain should be blocked
        let applicationId = extractApplicationId(from: clientAddress)
        let shouldBlock = shouldBlockDomain(dnsQuery.domain, for: applicationId)
        
        if shouldBlock {
            // Send blocked response
            await sendBlockedResponse(for: dnsQuery, to: clientAddress, via: outbound, startTime: startTime)
            logger.info("Blocked DNS query for domain: \(dnsQuery.domain)")
            return
        }
        
        // Forward to upstream DNS server
        await forwardDNSQuery(dnsQuery, requestBuffer: requestBuffer, to: clientAddress, via: outbound, startTime: startTime)
    }
    
    private func sendBlockedResponse(
        for query: DNSQuery,
        to clientAddress: SocketAddress,
        via outbound: NIOAsyncChannelOutboundWriter<AddressedEnvelope<ByteBuffer>>,
        startTime: Date
    ) async {
        // Create DNS response with NXDOMAIN (domain not found)
        let response = createDNSErrorResponse(for: query.id, errorCode: 3) // NXDOMAIN
        
        do {
            let envelope = AddressedEnvelope(remoteAddress: clientAddress, data: response)
            try await outbound.write(envelope)
            
            let latency = Date().timeIntervalSince(startTime)
            // Report metrics (delegate integration will be improved in later iteration)
            logger.info("Blocked query for \(query.domain), latency: \(latency)ms")
            
            logger.debug("Sent blocked response for \(query.domain) to \(clientAddress), latency: \(String(format: "%.3f", latency * 1000))ms")
        } catch {
            logger.error("Failed to send blocked DNS response: \(error)")
        }
    }
    
    private func forwardDNSQuery(
        _ query: DNSQuery,
        requestBuffer: ByteBuffer,
        to clientAddress: SocketAddress,
        via outbound: NIOAsyncChannelOutboundWriter<AddressedEnvelope<ByteBuffer>>,
        startTime: Date
    ) async {
        let upstreamServer = upstreamServers.first ?? "8.8.8.8"
        
        do {
            // Create upstream connection using SwiftNIO
            let upstreamChannel = try await DatagramBootstrap(group: eventLoopGroup)
                .connect(host: upstreamServer, port: 53) { channel in
                    return channel.eventLoop.makeCompletedFuture {
                        return try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
                    }
                }
            
            // Send query to upstream server and receive response
            try await upstreamChannel.executeThenClose { upstreamInbound, upstreamOutbound in
                // Send query
                try await upstreamOutbound.write(requestBuffer)
                
                // Wait for response with timeout
                let timeoutTask = Task<ByteBuffer, Error> {
                    try await Task.sleep(nanoseconds: UInt64(queryTimeout * 1_000_000_000))
                    throw DNSProxyError.timeout
                }
                
                let responseTask = Task<ByteBuffer, Error> {
                    for try await response in upstreamInbound {
                        return response
                    }
                    throw DNSProxyError.noResponse
                }
                
                do {
                    let response = try await withThrowingTaskGroup(of: ByteBuffer.self) { group in
                        group.addTask { try await responseTask.value }
                        group.addTask { try await timeoutTask.value }
                        
                        let result = try await group.next()!
                        group.cancelAll()
                        return result
                    }
                    
                    // Forward response to client
                    let envelope = AddressedEnvelope(remoteAddress: clientAddress, data: response)
                    try await outbound.write(envelope)
                    
                    let latency = Date().timeIntervalSince(startTime)
                    logger.info("Forwarded query for \(query.domain), latency: \(latency)ms")
                    
                    logger.debug("Forwarded DNS response for \(query.domain) to \(clientAddress), latency: \(String(format: "%.3f", latency * 1000))ms")
                    
                } catch {
                    logger.error("Failed to forward DNS query for \(query.domain): \(error)")
                    // Send server failure response
                    let errorResponse = createDNSErrorResponse(for: query.id, errorCode: 2) // SERVFAIL
                    let envelope = AddressedEnvelope(remoteAddress: clientAddress, data: errorResponse)
                    do {
                        try await outbound.write(envelope)
                    } catch {
                        logger.warning("Failed to send error response: \(error.localizedDescription)")
                    }
                }
            }
            
        } catch {
            logger.error("Failed to create upstream connection for \(query.domain): \(error)")
            // Send server failure response
            let errorResponse = createDNSErrorResponse(for: query.id, errorCode: 2) // SERVFAIL
            let envelope = AddressedEnvelope(remoteAddress: clientAddress, data: errorResponse)
            do {
                try await outbound.write(envelope)
            } catch {
                logger.warning("Failed to send error response: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - DNS Protocol Helpers
    
    private func parseDNSQuery(from buffer: inout ByteBuffer) -> DNSQuery? {
        guard buffer.readableBytes >= 12 else { return nil } // Minimum DNS header size
        
        let originalReaderIndex = buffer.readerIndex
        
        // Read DNS header
        guard let id = buffer.readInteger(as: UInt16.self) else {
            buffer.moveReaderIndex(to: originalReaderIndex)
            return nil
        }
        
        // Skip flags, QDCOUNT, ANCOUNT, NSCOUNT, ARCOUNT
        buffer.moveReaderIndex(forwardBy: 10)
        
        // Parse domain name from question section
        guard let domain = readDomainName(from: &buffer) else {
            buffer.moveReaderIndex(to: originalReaderIndex)
            return nil
        }
        
        return DNSQuery(id: id, domain: domain)
    }
    
    private func readDomainName(from buffer: inout ByteBuffer) -> String? {
        var components: [String] = []
        
        while let labelLength = buffer.readInteger(as: UInt8.self) {
            if labelLength == 0 {
                break // End of domain name
            }
            
            if labelLength > 63 {
                return nil // Invalid label length
            }
            
            guard let labelData = buffer.readSlice(length: Int(labelLength)),
                  let label = labelData.getString(at: 0, length: labelData.readableBytes) else {
                return nil
            }
            
            components.append(label)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ".")
    }
    
    private func createDNSErrorResponse(for queryId: UInt16, errorCode: UInt8) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: 12)
        
        // DNS Header
        buffer.writeInteger(queryId) // ID
        buffer.writeInteger(UInt16(0x8000 | UInt16(errorCode))) // Flags with error code
        buffer.writeInteger(UInt16(0)) // QDCOUNT
        buffer.writeInteger(UInt16(0)) // ANCOUNT
        buffer.writeInteger(UInt16(0)) // NSCOUNT
        buffer.writeInteger(UInt16(0)) // ARCOUNT
        
        return buffer
    }
    
    private func extractApplicationId(from address: SocketAddress) -> String? {
        // Implementation to extract application ID from connection metadata
        // This would integrate with system-level process tracking
        return nil
    }
    
    private func shouldBlockDomain(_ domain: String, for applicationId: String?) -> Bool {
        // Use the correct BlocklistManager method
        return blocklistManager.shouldBlockDomain(domain)
    }
}

// MARK: - Supporting Types and Errors

internal enum DNSProxyError: Error {
    case timeout
    case noResponse
    case invalidQuery
    case upstreamConnectionFailed
}

// MARK: - Legacy Compatibility

extension SwiftNIODNSProxyServer {
    /// Legacy compatibility method to start server synchronously
    internal func startLegacy() throws {
        Task {
            try await start()
        }
    }
    
    /// Legacy compatibility method to stop server synchronously
    internal func stopLegacy() {
        Task {
            await stop()
        }
    }
}
