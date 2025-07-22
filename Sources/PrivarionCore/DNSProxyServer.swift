import Foundation
import Network
import Logging

/// DNS proxy server for intercepting and filtering DNS requests
@available(macOS 10.14, *)
internal class DNSProxyServer: DNSProxyServerProtocol {
    private let configuration: NetworkFilterConfig
    private let logger: Logger
    private var listener: NWListener?
    private var isRunning = false
    private let queue = DispatchQueue(label: "dns.proxy.server", qos: .userInitiated)
    
    // DNS server settings
    private let dnsPort: NWEndpoint.Port
    private let upstreamServers: [String]
    private let queryTimeout: Double
    
    // Application network rule engine
    private let ruleEngine: ApplicationNetworkRuleEngine
    
    // Advanced blocklist manager
    private let blocklistManager: BlocklistManager
    
    // Real-time traffic monitoring service
    private let trafficMonitor: TrafficMonitoringService
    
    weak var delegate: DNSProxyServerDelegate?
    
    internal init(port: Int, upstreamServers: [String], queryTimeout: Double) {
        self.configuration = ConfigurationManager.shared.getCurrentConfiguration().modules.networkFilter
        self.logger = Logger(label: "privarion.dns.proxy")
        self.dnsPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        self.upstreamServers = upstreamServers
        self.queryTimeout = queryTimeout
        self.ruleEngine = ApplicationNetworkRuleEngine()
        self.blocklistManager = BlocklistManager()
        self.trafficMonitor = TrafficMonitoringService()
    }
    
    /// Start the DNS proxy server
    internal func start() throws {
        guard !isRunning else {
            logger.warning("DNS proxy server is already running")
            return
        }
        
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        listener = try NWListener(using: parameters, on: dnsPort)
        
        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        
        listener?.stateUpdateHandler = { [weak self] state in
            self?.handleListenerStateChange(state)
        }
        
        listener?.start(queue: queue)
        isRunning = true
        
        // Start traffic monitoring
        trafficMonitor.startMonitoring()
        
        logger.info("DNS proxy server started on port \(dnsPort)")
    }
    
    /// Stop the DNS proxy server
    internal func stop() {
        guard isRunning else { return }
        
        // Stop traffic monitoring
        trafficMonitor.stopMonitoring()
        
        listener?.cancel()
        listener = nil
        isRunning = false
        
        logger.info("DNS proxy server stopped")
    }
    
    /// Check if the server is currently running
    internal var running: Bool {
        return isRunning
    }
    
    /// Get access to the application network rule engine
    internal var applicationRuleEngine: ApplicationNetworkRuleEngine {
        return ruleEngine
    }
    
    /// Get access to the blocklist manager
    internal var blocklist: BlocklistManager {
        return blocklistManager
    }
    
    /// Get access to the traffic monitoring service
    internal var monitoring: TrafficMonitoringService {
        return trafficMonitor
    }
    
    // MARK: - Private Methods
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { [weak self] data, _, isComplete, error in
            if let error = error {
                self?.logger.error("DNS connection error: \(error)")
                return
            }
            
            if let data = data, !data.isEmpty {
                self?.processDNSRequest(data, connection: connection)
            }
            
            if isComplete {
                connection.cancel()
            }
        }
    }
    
    private func handleListenerStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            logger.info("DNS proxy server is ready")
        case .failed(let error):
            logger.error("DNS proxy server failed: \(error)")
            isRunning = false
        case .cancelled:
            logger.info("DNS proxy server cancelled")
            isRunning = false
        default:
            break
        }
    }
    
    private func processDNSRequest(_ data: Data, connection: NWConnection) {
        let startTime = Date()
        
        guard let dnsQuery = parseDNSQuery(data) else {
            logger.warning("Failed to parse DNS query")
            return
        }
        
        logger.debug("DNS query for: \(dnsQuery.domain)")
        
        var blockingReason: BlockingReason?
        var blocked = false
        
        // Check per-application rules first
        let shouldBlockByAppRule = ruleEngine.shouldBlockQuery(domain: dnsQuery.domain, from: connection)
        
        if shouldBlockByAppRule {
            blocked = true
            blockingReason = .applicationRule
            logger.info("Blocking DNS query for: \(dnsQuery.domain) due to application rule")
            sendBlockedResponse(dnsQuery, connection: connection)
        }
        
        // Check advanced blocklist (domains, categories, IPs) if not already blocked
        if !blocked {
            let shouldBlockByBlocklist = blocklistManager.shouldBlockDomain(dnsQuery.domain)
            
            if shouldBlockByBlocklist {
                blocked = true
                blockingReason = .domainBlocklist // This could be more specific based on blocklist type
                logger.info("Blocking DNS query for: \(dnsQuery.domain) due to blocklist rule")
                sendBlockedResponse(dnsQuery, connection: connection)
            }
        }
        
        // Check general domain blocking via delegate (legacy support) if not already blocked
        if !blocked {
            let shouldBlockByDelegate = delegate?.dnsProxy(self, shouldBlockDomain: dnsQuery.domain, for: nil as String?) ?? false
            
            if shouldBlockByDelegate {
                blocked = true
                blockingReason = .customRule
                logger.info("Blocking DNS query for: \(dnsQuery.domain) due to delegate rule")
                sendBlockedResponse(dnsQuery, connection: connection)
            }
        }
        
        // Calculate latency and record traffic event
        let latency = Date().timeIntervalSince(startTime)
        
        // Record traffic monitoring event
        trafficMonitor.recordDNSQuery(
            domain: dnsQuery.domain,
            blocked: blocked,
            source: nil, // TODO: Extract source from connection
            latency: latency,
            reason: blockingReason
        )
        
        // Notify delegate
        delegate?.dnsProxy(self, didProcessQuery: dnsQuery.domain, blocked: blocked, latency: latency)
        
        // Forward to upstream DNS server if not blocked
        if !blocked {
            forwardDNSQuery(data, originalConnection: connection, domain: dnsQuery.domain, startTime: startTime)
        }
    }
    
    private func parseDNSQuery(_ data: Data) -> DNSQuery? {
        // Simplified DNS parsing - in production would use more robust parsing
        guard data.count >= 12 else { return nil }
        
        let questionStart = 12
        var offset = questionStart
        var domain = ""
        
        // Parse domain name from DNS query
        while offset < data.count {
            let length = Int(data[offset])
            if length == 0 { break }
            
            offset += 1
            if offset + length > data.count { return nil }
            
            let label = String(data: data[offset..<offset + length], encoding: .utf8) ?? ""
            domain += domain.isEmpty ? label : ".\(label)"
            offset += length
        }
        
        return DNSQuery(id: UInt16(data[0]) << 8 | UInt16(data[1]), domain: domain)
    }
    
    private func sendBlockedResponse(_ query: DNSQuery, connection: NWConnection) {
        // Create DNS response indicating domain is blocked (NXDOMAIN)
        var response = Data()
        
        // DNS Header (12 bytes)
        response.append(UInt16(query.id).bigEndianData) // Transaction ID
        response.append(Data([0x81, 0x83])) // Flags: Response, NXDOMAIN
        response.append(Data([0x00, 0x01])) // Questions: 1
        response.append(Data([0x00, 0x00])) // Answer RRs: 0
        response.append(Data([0x00, 0x00])) // Authority RRs: 0
        response.append(Data([0x00, 0x00])) // Additional RRs: 0
        
        // Question section (copy from original query)
        response.append(encodeDomainName(query.domain))
        response.append(Data([0x00, 0x01])) // Type A
        response.append(Data([0x00, 0x01])) // Class IN
        
        connection.send(content: response, completion: .contentProcessed { error in
            if let error = error {
                self.logger.error("Failed to send DNS response: \(error)")
            }
        })
    }
    
    private func forwardDNSQuery(_ data: Data, originalConnection: NWConnection, domain: String, startTime: Date) {
        let upstreamServer = upstreamServers.first ?? "8.8.8.8"
        let host = NWEndpoint.Host(upstreamServer)
        let port = NWEndpoint.Port(integerLiteral: 53)
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        
        let connection = NWConnection(to: endpoint, using: .udp)
        
        connection.start(queue: queue)
        
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.logger.error("Failed to forward DNS query: \(error)")
                return
            }
            
            // Receive response from upstream DNS server
            connection.receive(minimumIncompleteLength: 1, maximumLength: 512) { responseData, _, _, error in
                defer { connection.cancel() }
                
                if let error = error {
                    self?.logger.error("Failed to receive DNS response: \(error)")
                    return
                }
                
                if let responseData = responseData {
                    // Forward response back to original client
                    originalConnection.send(content: responseData, completion: .contentProcessed { _ in })
                    
                    // Report latency to delegate
                    let latency = Date().timeIntervalSince(startTime)
                    self?.delegate?.dnsProxy(self!, didProcessQuery: domain, blocked: false, latency: latency)
                }
            }
        })
    }
    
    private func encodeDomainName(_ domain: String) -> Data {
        var data = Data()
        let components = domain.components(separatedBy: ".")
        
        for component in components {
            let componentData = component.data(using: .utf8) ?? Data()
            data.append(UInt8(componentData.count))
            data.append(componentData)
        }
        
        data.append(0) // Null terminator
        return data
    }
}

// MARK: - Supporting Types

internal struct DNSQuery {
    let id: UInt16
    let domain: String
}

/// DNS Proxy Server Delegate
internal protocol DNSProxyServerDelegate: AnyObject {
    func dnsProxy(_ proxy: DNSProxyServer, shouldBlockDomain domain: String, for applicationId: String?) -> Bool
    func dnsProxy(_ proxy: DNSProxyServer, didProcessQuery domain: String, blocked: Bool, latency: TimeInterval)
}

private extension UInt16 {
    var bigEndianData: Data {
        var value = self.bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}
