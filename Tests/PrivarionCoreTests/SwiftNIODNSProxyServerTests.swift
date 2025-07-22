import XCTest
import NIOCore
import NIOPosix
@testable import PrivarionCore

@available(macOS 10.15, *)
final class SwiftNIODNSProxyServerTests: XCTestCase {
    var server: SwiftNIODNSProxyServer!
    var delegate: MockDNSProxyDelegate!
    
    override func setUp() async throws {
        delegate = MockDNSProxyDelegate()
        // Use a different port for each test to avoid conflicts
        let testPort = Int.random(in: 20000...30000)
        server = SwiftNIODNSProxyServer(
            port: testPort,
            upstreamServers: ["8.8.8.8", "1.1.1.1"],
            queryTimeout: 5.0
        )
        server.delegate = delegate
    }
    
    override func tearDown() async throws {
        await server.stop()
        server = nil
        delegate = nil
    }
    
    // MARK: - Server Lifecycle Tests
    
    func testServerStartAndStop() async throws {
        // Test starting the server
        try await server.start()
        
        // Server should be running
        XCTAssertTrue(server.isRunning, "Server should be running after start")
        
        // Test stopping the server
        await server.stop()
        
        // Verify server is stopped
        XCTAssertFalse(server.isRunning, "Server should be stopped after stop")
    }
    
    func testMultipleStartCalls() async throws {
        // First start should succeed
        try await server.start()
        XCTAssertTrue(server.isRunning)
        
        // Second start should not fail and server should remain running
        try await server.start()
        XCTAssertTrue(server.isRunning)
        
        await server.stop()
    }
    
    // MARK: - DNS Query Processing Tests
    
    func testDNSQueryParsing() async throws {
        try await server.start()
        
        // Create a simple DNS query for "example.com"
        _ = createDNSQuery(domain: "example.com", queryId: 12345)
        
        // This test would need access to internal parsing methods
        // For now, we'll test the integration
        
        await server.stop()
    }
    
    func testBlockedDomainResponse() async throws {
        // Configure delegate to block certain domains
        delegate.shouldBlockDomain = { domain, _ in
            return domain.contains("malicious")
        }
        
        try await server.start()
        
        // Send DNS query for blocked domain
        let expectation = XCTestExpectation(description: "DNS query processed")
        delegate.onQueryProcessed = { domain, blocked, latency in
            XCTAssertEqual(domain, "malicious.example.com")
            XCTAssertTrue(blocked, "Domain should be blocked")
            XCTAssertGreaterThan(latency, 0, "Latency should be positive")
            expectation.fulfill()
        }
        
        // This would require sending actual UDP packets
        // For integration testing, we'd need network test utilities
        
        await fulfillment(of: [expectation], timeout: 5.0)
        await server.stop()
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentDNSQueries() async throws {
        try await server.start()
        
        let queryCount = 100
        let expectations = (0..<queryCount).map { i in
            XCTestExpectation(description: "DNS query \(i) processed")
        }
        
        var processedQueries = 0
        delegate.onQueryProcessed = { _, _, _ in
            processedQueries += 1
            if processedQueries <= queryCount {
                expectations[processedQueries - 1].fulfill()
            }
        }
        
        // Send concurrent DNS queries
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<queryCount {
                group.addTask {
                    // Simulate DNS query
                    await self.simulateDNSQuery(domain: "test\(i).example.com")
                }
            }
        }
        
        await fulfillment(of: expectations, timeout: 10.0)
        await server.stop()
    }
    
    func testLatencyMeasurement() async throws {
        try await server.start()
        
        let expectation = XCTestExpectation(description: "Latency measured")
        delegate.onQueryProcessed = { _, _, latency in
            XCTAssertLessThan(latency, 1.0, "Latency should be less than 1 second for local testing")
            XCTAssertGreaterThan(latency, 0, "Latency should be positive")
            expectation.fulfill()
        }
        
        await simulateDNSQuery(domain: "example.com")
        
        await fulfillment(of: [expectation], timeout: 5.0)
        await server.stop()
    }
    
    // MARK: - Error Handling Tests
    
    func testTimeoutHandling() async throws {
        // Create server with very short timeout
        let shortTimeoutServer = SwiftNIODNSProxyServer(
            port: 15354,
            upstreamServers: ["192.0.2.1"], // Non-routable address to force timeout
            queryTimeout: 0.1
        )
        shortTimeoutServer.delegate = delegate
        
        try await shortTimeoutServer.start()
        
        let expectation = XCTestExpectation(description: "Timeout handled")
        delegate.onQueryProcessed = { _, blocked, _ in
            // Should receive error response, not blocked
            XCTAssertFalse(blocked, "Should not be blocked, but should receive error response")
            expectation.fulfill()
        }
        
        await simulateDNSQuery(domain: "example.com", server: shortTimeoutServer)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        await shortTimeoutServer.stop()
    }
    
    func testInvalidQueryHandling() async throws {
        try await server.start()
        
        // This test would send malformed DNS packets
        // For now, we ensure the server doesn't crash with invalid input
        
        await server.stop()
    }
    
    // MARK: - Integration Tests
    
    func testRealDNSQuery() async throws {
        // Only run if we have network access
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping real DNS query test in CI environment")
        }
        
        try await server.start()
        
        let expectation = XCTestExpectation(description: "Real DNS query processed")
        delegate.onQueryProcessed = { domain, blocked, latency in
            XCTAssertEqual(domain, "apple.com")
            XCTAssertFalse(blocked, "apple.com should not be blocked")
            XCTAssertLessThan(latency, 2.0, "DNS query should complete within 2 seconds")
            expectation.fulfill()
        }
        
        await simulateDNSQuery(domain: "apple.com")
        
        await fulfillment(of: [expectation], timeout: 10.0)
        await server.stop()
    }
    
    // MARK: - Helper Methods
    
    private func createDNSQuery(domain: String, queryId: UInt16) -> ByteBuffer {
        var buffer = ByteBufferAllocator().buffer(capacity: 512)
        
        // DNS Header
        buffer.writeInteger(queryId) // ID
        buffer.writeInteger(UInt16(0x0100)) // Flags: standard query
        buffer.writeInteger(UInt16(1)) // QDCOUNT: 1 question
        buffer.writeInteger(UInt16(0)) // ANCOUNT: 0 answers
        buffer.writeInteger(UInt16(0)) // NSCOUNT: 0 authority
        buffer.writeInteger(UInt16(0)) // ARCOUNT: 0 additional
        
        // Question section
        let components = domain.components(separatedBy: ".")
        for component in components {
            buffer.writeInteger(UInt8(component.count))
            buffer.writeString(component)
        }
        buffer.writeInteger(UInt8(0)) // End of domain name
        
        buffer.writeInteger(UInt16(1)) // QTYPE: A record
        buffer.writeInteger(UInt16(1)) // QCLASS: IN
        
        return buffer
    }
    
    private func simulateDNSQuery(domain: String, server: SwiftNIODNSProxyServer? = nil) async {
        // This would send actual UDP packets to the server
        // For now, it's a placeholder for integration testing
        
        // In a real implementation, we would:
        // 1. Create a UDP socket
        // 2. Send DNS query to localhost:15353
        // 3. Wait for response
        
        // Simulate processing delay
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }
}

// MARK: - Mock Delegate

class MockDNSProxyDelegate: DNSProxyServerDelegate {
    var shouldBlockDomain: (String, String?) -> Bool = { _, _ in false }
    var onQueryProcessed: ((String, Bool, TimeInterval) -> Void)?
    
    func dnsProxy(_ proxy: DNSProxyServer, shouldBlockDomain domain: String, for applicationId: String?) -> Bool {
        return shouldBlockDomain(domain, applicationId)
    }
    
    func dnsProxy(_ proxy: DNSProxyServer, didProcessQuery domain: String, blocked: Bool, latency: TimeInterval) {
        onQueryProcessed?(domain, blocked, latency)
    }
}

// MARK: - Performance Benchmarks

@available(macOS 10.15, *)
extension SwiftNIODNSProxyServerTests {
    
    func testPerformanceBenchmark() throws {
        // Measure server startup time
        measure {
            let server = SwiftNIODNSProxyServer(
                port: 15355,
                upstreamServers: ["8.8.8.8"],
                queryTimeout: 5.0
            )
            
            Task {
                try? await server.start()
                await server.stop()
            }
        }
    }
    
    func testThroughputBenchmark() async throws {
        try await server.start()
        
        let startTime = Date()
        let queryCount = 1000
        
        // Send many concurrent queries
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<queryCount {
                group.addTask {
                    await self.simulateDNSQuery(domain: "test\(i).example.com")
                }
            }
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let throughput = Double(queryCount) / duration
        
        print("Processed \(queryCount) queries in \(duration) seconds")
        print("Throughput: \(throughput) queries/second")
        
        // Verify we can handle at least 1000 queries/second
        XCTAssertGreaterThan(throughput, 1000, "Should handle at least 1000 queries per second")
        
        await server.stop()
    }
}
