import Foundation
import Network
import Logging

/// Connection pool for DNS upstream queries
/// Implements connection reuse and pooling for improved performance
/// Requirements: 4.8, 18.8
@available(macOS 10.14, *)
internal class DNSConnectionPool {
    
    // MARK: - Properties
    
    private let logger: Logger
    private let maxPoolSize: Int
    private let connectionTimeout: TimeInterval
    private let idleTimeout: TimeInterval
    
    /// Pool of available connections
    private var availableConnections: [String: [PooledConnection]] = [:]
    
    /// Active connections currently in use
    private var activeConnections: Set<PooledConnection> = []
    
    /// Queue for thread-safe access
    private let queue = DispatchQueue(label: "privarion.dns.connection.pool", attributes: .concurrent)
    
    /// Timer for cleaning up idle connections
    private var cleanupTimer: Timer?
    
    // MARK: - Initialization
    
    /// Initialize connection pool
    /// - Parameters:
    ///   - maxPoolSize: Maximum number of connections per server (default: 10)
    ///   - connectionTimeout: Timeout for establishing connections (default: 5 seconds)
    ///   - idleTimeout: Time before idle connections are closed (default: 60 seconds)
    internal init(maxPoolSize: Int = 10, connectionTimeout: TimeInterval = 5.0, idleTimeout: TimeInterval = 60.0) {
        self.logger = Logger(label: "privarion.dns.connection.pool")
        self.maxPoolSize = maxPoolSize
        self.connectionTimeout = connectionTimeout
        self.idleTimeout = idleTimeout
        
        // Start cleanup timer
        startCleanupTimer()
        
        logger.info("DNS connection pool initialized (max size: \(maxPoolSize), idle timeout: \(idleTimeout)s)")
    }
    
    deinit {
        cleanupTimer?.invalidate()
        closeAllConnections()
    }
    
    // MARK: - Public Interface
    
    /// Get a connection from the pool or create a new one
    /// - Parameters:
    ///   - host: DNS server host
    ///   - port: DNS server port
    /// - Returns: Pooled connection
    /// - Throws: ConnectionPoolError if unable to get connection
    internal func getConnection(host: String, port: Int) throws -> PooledConnection {
        let key = connectionKey(host: host, port: port)
        
        return try queue.sync(flags: .barrier) {
            // Try to get an available connection
            if var connections = availableConnections[key], !connections.isEmpty {
                let connection = connections.removeFirst()
                availableConnections[key] = connections
                
                // Check if connection is still valid
                if connection.isValid {
                    activeConnections.insert(connection)
                    logger.debug("Reusing connection to \(host):\(port)")
                    return connection
                } else {
                    // Connection is stale, close it
                    connection.close()
                }
            }
            
            // Check if we've reached the pool size limit
            let totalConnections = (availableConnections[key]?.count ?? 0) + 
                                   activeConnections.filter { $0.key == key }.count
            
            if totalConnections >= maxPoolSize {
                throw ConnectionPoolError.poolExhausted(host: host, port: port)
            }
            
            // Create new connection
            let connection = try createConnection(host: host, port: port)
            activeConnections.insert(connection)
            
            logger.debug("Created new connection to \(host):\(port)")
            return connection
        }
    }
    
    /// Return a connection to the pool
    /// - Parameter connection: Connection to return
    internal func returnConnection(_ connection: PooledConnection) {
        queue.async(flags: .barrier) {
            self.activeConnections.remove(connection)
            
            // Only return valid connections to the pool
            if connection.isValid {
                var connections = self.availableConnections[connection.key] ?? []
                connections.append(connection)
                self.availableConnections[connection.key] = connections
                
                self.logger.debug("Returned connection to pool: \(connection.key)")
            } else {
                connection.close()
                self.logger.debug("Closed invalid connection: \(connection.key)")
            }
        }
    }
    
    /// Close a connection and remove it from the pool
    /// - Parameter connection: Connection to close
    internal func closeConnection(_ connection: PooledConnection) {
        queue.async(flags: .barrier) {
            self.activeConnections.remove(connection)
            connection.close()
            self.logger.debug("Closed connection: \(connection.key)")
        }
    }
    
    /// Get pool statistics
    /// - Returns: Pool statistics
    internal func getStatistics() -> PoolStatistics {
        return queue.sync {
            let availableCount = availableConnections.values.reduce(0) { $0 + $1.count }
            let activeCount = activeConnections.count
            let totalCount = availableCount + activeCount
            
            return PoolStatistics(
                totalConnections: totalCount,
                availableConnections: availableCount,
                activeConnections: activeCount,
                poolUtilization: totalCount > 0 ? Double(activeCount) / Double(totalCount) : 0.0
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func createConnection(host: String, port: Int) throws -> PooledConnection {
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(integerLiteral: UInt16(port))
        let endpoint = NWEndpoint.hostPort(host: nwHost, port: nwPort)
        
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        let nwConnection = NWConnection(to: endpoint, using: parameters)
        let key = connectionKey(host: host, port: port)
        
        let connection = PooledConnection(
            connection: nwConnection,
            key: key,
            createdAt: Date(),
            idleTimeout: idleTimeout
        )
        
        // Start the connection
        nwConnection.start(queue: .global(qos: .userInitiated))
        
        // Wait for connection to be ready (with timeout)
        let semaphore = DispatchSemaphore(value: 0)
        var connectionReady = false
        var connectionError: Error?
        
        nwConnection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connectionReady = true
                semaphore.signal()
            case .failed(let error):
                connectionError = error
                semaphore.signal()
            case .cancelled:
                connectionError = ConnectionPoolError.connectionCancelled
                semaphore.signal()
            default:
                break
            }
        }
        
        // Wait for connection with timeout
        let timeout = DispatchTime.now() + connectionTimeout
        if semaphore.wait(timeout: timeout) == .timedOut {
            nwConnection.cancel()
            throw ConnectionPoolError.connectionTimeout(host: host, port: port)
        }
        
        if let error = connectionError {
            throw ConnectionPoolError.connectionFailed(host: host, port: port, error: error)
        }
        
        guard connectionReady else {
            throw ConnectionPoolError.connectionFailed(host: host, port: port, error: nil)
        }
        
        return connection
    }
    
    private func connectionKey(host: String, port: Int) -> String {
        return "\(host):\(port)"
    }
    
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.cleanupIdleConnections()
        }
    }
    
    private func cleanupIdleConnections() {
        queue.async(flags: .barrier) {
            let now = Date()
            var closedCount = 0
            
            for (key, connections) in self.availableConnections {
                let validConnections = connections.filter { connection in
                    if connection.isIdle(at: now) {
                        connection.close()
                        closedCount += 1
                        return false
                    }
                    return true
                }
                
                if validConnections.isEmpty {
                    self.availableConnections.removeValue(forKey: key)
                } else {
                    self.availableConnections[key] = validConnections
                }
            }
            
            if closedCount > 0 {
                self.logger.info("Cleaned up \(closedCount) idle connections")
            }
        }
    }
    
    private func closeAllConnections() {
        queue.sync(flags: .barrier) {
            for connections in availableConnections.values {
                connections.forEach { $0.close() }
            }
            availableConnections.removeAll()
            
            activeConnections.forEach { $0.close() }
            activeConnections.removeAll()
        }
    }
}

// MARK: - Supporting Types

/// Pooled DNS connection wrapper
@available(macOS 10.14, *)
internal class PooledConnection: Hashable {
    let connection: NWConnection
    let key: String
    let createdAt: Date
    private let idleTimeout: TimeInterval
    private var lastUsedAt: Date
    
    internal init(connection: NWConnection, key: String, createdAt: Date, idleTimeout: TimeInterval) {
        self.connection = connection
        self.key = key
        self.createdAt = createdAt
        self.idleTimeout = idleTimeout
        self.lastUsedAt = createdAt
    }
    
    /// Check if connection is still valid
    internal var isValid: Bool {
        switch connection.state {
        case .ready:
            return true
        default:
            return false
        }
    }
    
    /// Check if connection has been idle too long
    internal func isIdle(at date: Date) -> Bool {
        return date.timeIntervalSince(lastUsedAt) > idleTimeout
    }
    
    /// Update last used timestamp
    internal func markUsed() {
        lastUsedAt = Date()
    }
    
    /// Close the connection
    internal func close() {
        connection.cancel()
    }
    
    // Hashable conformance
    static func == (lhs: PooledConnection, rhs: PooledConnection) -> Bool {
        return lhs.connection === rhs.connection
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(connection))
    }
}

/// Pool statistics
internal struct PoolStatistics {
    let totalConnections: Int
    let availableConnections: Int
    let activeConnections: Int
    let poolUtilization: Double
}

/// Connection pool errors
internal enum ConnectionPoolError: Error, LocalizedError {
    case poolExhausted(host: String, port: Int)
    case connectionTimeout(host: String, port: Int)
    case connectionFailed(host: String, port: Int, error: Error?)
    case connectionCancelled
    
    var errorDescription: String? {
        switch self {
        case .poolExhausted(let host, let port):
            return "Connection pool exhausted for \(host):\(port)"
        case .connectionTimeout(let host, let port):
            return "Connection timeout to \(host):\(port)"
        case .connectionFailed(let host, let port, let error):
            if let error = error {
                return "Connection failed to \(host):\(port): \(error.localizedDescription)"
            }
            return "Connection failed to \(host):\(port)"
        case .connectionCancelled:
            return "Connection was cancelled"
        }
    }
}
