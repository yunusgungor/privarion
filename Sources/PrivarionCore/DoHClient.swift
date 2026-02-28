import Foundation
import Logging

/// DNS over HTTPS (DoH) client for secure upstream DNS queries
/// Implements RFC 8484 - DNS Queries over HTTPS (DoH)
/// Requirements: 4.8
@available(macOS 10.15, *)
internal class DoHClient {
    
    // MARK: - Properties
    
    private let logger: Logger
    private let session: URLSession
    private let doHServers: [String]
    private var currentServerIndex = 0
    
    /// Common DoH providers
    internal static let defaultDoHServers = [
        "https://dns.google/dns-query",           // Google Public DNS
        "https://cloudflare-dns.com/dns-query",   // Cloudflare DNS
        "https://dns.quad9.net/dns-query"         // Quad9 DNS
    ]
    
    // MARK: - Initialization
    
    /// Initialize DoH client with custom servers
    /// - Parameters:
    ///   - doHServers: List of DoH server URLs (defaults to public DoH providers)
    ///   - timeout: Request timeout in seconds
    internal init(doHServers: [String] = defaultDoHServers, timeout: TimeInterval = 5.0) {
        self.logger = Logger(label: "privarion.doh.client")
        self.doHServers = doHServers
        
        // Configure URLSession for DoH requests
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "Accept": "application/dns-message",
            "Content-Type": "application/dns-message"
        ]
        
        self.session = URLSession(configuration: configuration)
        
        logger.info("DoH client initialized with \(doHServers.count) servers")
    }
    
    // MARK: - Public Interface
    
    /// Query DNS over HTTPS
    /// - Parameters:
    ///   - domain: Domain name to query
    ///   - queryType: DNS query type (A, AAAA, etc.)
    /// - Returns: DNS response data
    /// - Throws: DoHError if query fails
    internal func query(domain: String, queryType: DNSQueryType = .A) async throws -> Data {
        let dnsQuery = createDNSQuery(domain: domain, queryType: queryType)
        
        // Try each DoH server in sequence until one succeeds
        var lastError: Error?
        
        for attempt in 0..<doHServers.count {
            let serverURL = doHServers[(currentServerIndex + attempt) % doHServers.count]
            
            do {
                let response = try await queryDoHServer(serverURL, dnsQuery: dnsQuery, domain: domain)
                
                // Update current server index on success
                currentServerIndex = (currentServerIndex + attempt) % doHServers.count
                
                return response
            } catch {
                logger.warning("DoH query failed for \(serverURL): \(error)")
                lastError = error
                continue
            }
        }
        
        // All servers failed
        throw lastError ?? DoHError.allServersFailed
    }
    
    /// Query DNS over HTTPS with raw DNS query data
    /// - Parameter dnsQueryData: Raw DNS query packet
    /// - Returns: DNS response data
    /// - Throws: DoHError if query fails
    internal func queryRaw(_ dnsQueryData: Data) async throws -> Data {
        var lastError: Error?
        
        for attempt in 0..<doHServers.count {
            let serverURL = doHServers[(currentServerIndex + attempt) % doHServers.count]
            
            do {
                let response = try await queryDoHServerRaw(serverURL, dnsQuery: dnsQueryData)
                
                // Update current server index on success
                currentServerIndex = (currentServerIndex + attempt) % doHServers.count
                
                return response
            } catch {
                logger.warning("DoH raw query failed for \(serverURL): \(error)")
                lastError = error
                continue
            }
        }
        
        throw lastError ?? DoHError.allServersFailed
    }
    
    // MARK: - Private Methods
    
    private func queryDoHServer(_ serverURL: String, dnsQuery: Data, domain: String) async throws -> Data {
        guard let url = URL(string: serverURL) else {
            throw DoHError.invalidServerURL(serverURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = dnsQuery
        
        logger.debug("Sending DoH query for \(domain) to \(serverURL)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DoHError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DoHError.httpError(httpResponse.statusCode)
        }
        
        guard let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
              contentType.contains("application/dns-message") else {
            throw DoHError.invalidContentType
        }
        
        logger.debug("Received DoH response for \(domain) from \(serverURL)")
        
        return data
    }
    
    private func queryDoHServerRaw(_ serverURL: String, dnsQuery: Data) async throws -> Data {
        guard let url = URL(string: serverURL) else {
            throw DoHError.invalidServerURL(serverURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = dnsQuery
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DoHError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw DoHError.httpError(httpResponse.statusCode)
        }
        
        return data
    }
    
    private func createDNSQuery(domain: String, queryType: DNSQueryType) -> Data {
        var data = Data()
        
        // DNS Header (12 bytes)
        data.append(contentsOf: [0x00, 0x00]) // Transaction ID (will be random)
        data.append(contentsOf: [0x01, 0x00]) // Flags: Standard query
        data.append(contentsOf: [0x00, 0x01]) // Questions: 1
        data.append(contentsOf: [0x00, 0x00]) // Answer RRs: 0
        data.append(contentsOf: [0x00, 0x00]) // Authority RRs: 0
        data.append(contentsOf: [0x00, 0x00]) // Additional RRs: 0
        
        // Question section
        let labels = domain.components(separatedBy: ".")
        for label in labels {
            data.append(UInt8(label.count))
            data.append(contentsOf: label.utf8)
        }
        data.append(0x00) // Null terminator
        
        // Query type
        let typeValue = queryType.rawValue
        data.append(UInt8(typeValue >> 8))
        data.append(UInt8(typeValue & 0xFF))
        
        // Query class (IN = 1)
        data.append(contentsOf: [0x00, 0x01])
        
        return data
    }
}

// MARK: - Supporting Types

/// DNS query types
internal enum DNSQueryType: UInt16 {
    case A = 1      // IPv4 address
    case AAAA = 28  // IPv6 address
    case CNAME = 5  // Canonical name
    case MX = 15    // Mail exchange
    case TXT = 16   // Text record
}

// Extend existing DoHError with additional cases needed for DoHClient
extension DoHError {
    static func invalidServerURL(_ url: String) -> DoHError {
        return .invalidServerURL
    }
    
    static func httpError(_ code: Int) -> DoHError {
        return .serverError(code)
    }
    
    static var invalidContentType: DoHError {
        return .invalidResponse
    }
    
    static var allServersFailed: DoHError {
        return .invalidResponse
    }
    
    static var timeout: DoHError {
        return .queryTimeout
    }
}
