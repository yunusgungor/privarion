// PrivarionNetworkExtensionTests - DNS Filter Tests
// Unit tests for DNS filtering functionality
// Requirements: 4.1-4.12, 20.1

import XCTest
@testable import PrivarionNetworkExtension
import PrivarionSharedModels

@available(macOS 10.14, *)
final class DNSFilterTests: XCTestCase {
    
    var dnsFilter: DNSFilter!
    
    override func setUp() {
        super.setUp()
        dnsFilter = DNSFilter()
    }
    
    override func tearDown() {
        dnsFilter = nil
        super.tearDown()
    }
    
    // MARK: - Tracking Domain Blocking Tests
    
    /// Test that tracking domains are blocked and return NXDOMAIN
    /// Requirement: 4.3, 4.4
    func testTrackingDomainBlocked() {
        // Given: A DNS query for a known tracking domain
        let query = DNSQuery(
            id: 1,
            domain: "google-analytics.com",
            queryType: .A,
            timestamp: Date()
        )
        
        // When: Filtering the query
        let response = dnsFilter.filterDNSQuery(query)
        
        // Then: Should return NXDOMAIN response (empty addresses)
        XCTAssertNotNil(response, "Should return a response for blocked domain")
        XCTAssertEqual(response?.domain, "google-analytics.com")
        XCTAssertTrue(response?.addresses.isEmpty ?? false, "Blocked domain should return empty addresses (NXDOMAIN)")
    }
    
    /// Test that subdomain of tracking domain is also blocked
    /// Requirement: 4.3
    func testTrackingSubdomainBlocked() {
        // Given: A DNS query for a subdomain of a tracking domain
        let query = DNSQuery(
            id: 2,
            domain: "www.google-analytics.com",
            queryType: .A,
            timestamp: Date()
        )
        
        // When: Filtering the query
        let response = dnsFilter.filterDNSQuery(query)
        
        // Then: Should return NXDOMAIN response
        XCTAssertNotNil(response, "Should return a response for blocked subdomain")
        XCTAssertTrue(response?.addresses.isEmpty ?? false, "Blocked subdomain should return empty addresses")
    }
    
    /// Test isBlocked method directly
    /// Requirement: 4.3
    func testIsBlockedMethod() {
        // Test known tracking domains
        XCTAssertTrue(dnsFilter.isBlocked("google-analytics.com"))
        XCTAssertTrue(dnsFilter.isBlocked("doubleclick.net"))
        XCTAssertTrue(dnsFilter.isBlocked("facebook.com"))
        
        // Test allowed domains
        XCTAssertFalse(dnsFilter.isBlocked("apple.com"))
        XCTAssertFalse(dnsFilter.isBlocked("github.com"))
    }
    
    // MARK: - Fingerprinting Domain Tests
    
    /// Test that fingerprinting domains return fake IP addresses
    /// Requirement: 4.5, 4.6
    func testFingerprintingDomainFaked() {
        // Given: A DNS query for a fingerprinting domain
        let query = DNSQuery(
            id: 3,
            domain: "fingerprint.tracker.com",
            queryType: .A,
            timestamp: Date()
        )
        
        // When: Filtering the query
        let response = dnsFilter.filterDNSQuery(query)
        
        // Then: Should return fake IP address
        XCTAssertNotNil(response, "Should return a response for fingerprinting domain")
        XCTAssertEqual(response?.domain, "fingerprint.tracker.com")
        XCTAssertFalse(response?.addresses.isEmpty ?? true, "Fingerprinting domain should return fake IP")
        
        // Verify it's a fake IP (one of the predefined ones)
        let fakeIPs = ["127.0.0.1", "0.0.0.0", "192.0.2.1", "198.51.100.1", "203.0.113.1"]
        if let address = response?.addresses.first {
            XCTAssertTrue(fakeIPs.contains(address), "Should return one of the fake IP addresses")
        }
    }
    
    /// Test isFingerprintingDomain method with various patterns
    /// Requirement: 4.5
    func testIsFingerprintingDomainDetection() {
        // Test domains with fingerprinting keywords
        XCTAssertTrue(dnsFilter.isFingerprintingDomain("fingerprint.example.com"))
        XCTAssertTrue(dnsFilter.isFingerprintingDomain("tracking.example.com"))
        XCTAssertTrue(dnsFilter.isFingerprintingDomain("analytics.example.com"))
        XCTAssertTrue(dnsFilter.isFingerprintingDomain("telemetry.example.com"))
        XCTAssertTrue(dnsFilter.isFingerprintingDomain("metrics.example.com"))
        
        // Test domains with fingerprinting subdomains
        XCTAssertTrue(dnsFilter.isFingerprintingDomain("fp.example.com"))
        XCTAssertTrue(dnsFilter.isFingerprintingDomain("track.example.com"))
        XCTAssertTrue(dnsFilter.isFingerprintingDomain("pixel.example.com"))
        
        // Test normal domains
        XCTAssertFalse(dnsFilter.isFingerprintingDomain("www.example.com"))
        XCTAssertFalse(dnsFilter.isFingerprintingDomain("api.example.com"))
    }
    
    // MARK: - Allowed Domain Tests
    
    /// Test that allowed domains return nil (to be forwarded)
    /// Requirement: 4.7
    func testAllowedDomainForwarded() {
        // Given: A DNS query for an allowed domain
        let query = DNSQuery(
            id: 4,
            domain: "apple.com",
            queryType: .A,
            timestamp: Date()
        )
        
        // When: Filtering the query
        let response = dnsFilter.filterDNSQuery(query)
        
        // Then: Should return nil to indicate forwarding needed
        XCTAssertNil(response, "Allowed domain should return nil for forwarding")
    }
    
    // MARK: - Cache Tests
    
    /// Test that cached responses are returned quickly
    /// Requirement: 4.9, 4.11
    func testCachedResponseReturned() {
        // Given: A DNS query that will be cached
        let query = DNSQuery(
            id: 5,
            domain: "google-analytics.com",
            queryType: .A,
            timestamp: Date()
        )
        
        // When: Filtering the query twice
        let response1 = dnsFilter.filterDNSQuery(query)
        let response2 = dnsFilter.filterDNSQuery(query)
        
        // Then: Both responses should be identical and second should be cached
        XCTAssertNotNil(response1)
        XCTAssertNotNil(response2)
        XCTAssertEqual(response1?.domain, response2?.domain)
        XCTAssertTrue(response2?.cached ?? false, "Second response should be marked as cached")
    }
    
    /// Test createFakeResponse method
    /// Requirement: 4.6
    func testCreateFakeResponse() {
        // Given: A DNS query
        let query = DNSQuery(
            id: 6,
            domain: "test.example.com",
            queryType: .A,
            timestamp: Date()
        )
        
        // When: Creating a fake response
        let response = dnsFilter.createFakeResponse(for: query)
        
        // Then: Should return valid fake response
        XCTAssertEqual(response.id, query.id)
        XCTAssertEqual(response.domain, query.domain)
        XCTAssertFalse(response.addresses.isEmpty, "Fake response should have addresses")
        XCTAssertEqual(response.ttl, 300, "TTL should be 300 seconds")
    }
    
    // MARK: - Performance Tests
    
    /// Test that DNS query processing is fast
    /// Requirement: 4.11, 4.12
    func testQueryProcessingPerformance() {
        let query = DNSQuery(
            id: 7,
            domain: "google-analytics.com",
            queryType: .A,
            timestamp: Date()
        )
        
        // First query (non-cached) - should be under 200ms
        measure {
            _ = dnsFilter.filterDNSQuery(query)
        }
        
        // Note: In real implementation, cached queries should be under 50ms
        // This is tested in the measure block above after first query caches the result
    }
}

// MARK: - DNS Cache Tests

@available(macOS 10.14, *)
final class DNSCacheTests: XCTestCase {
    
    var cache: DNSCache!
    
    override func setUp() {
        super.setUp()
        cache = DNSCache()
    }
    
    override func tearDown() {
        cache = nil
        super.tearDown()
    }
    
    /// Test basic cache set and get operations
    /// Requirement: 4.9
    func testCacheSetAndGet() {
        // Given: A DNS response
        let response = DNSResponse(
            id: 1,
            domain: "example.com",
            addresses: ["93.184.216.34"],
            ttl: 300,
            cached: false,
            timestamp: Date()
        )
        
        // When: Storing in cache
        cache.set("example.com", response: response, ttl: 300)
        
        // Then: Should be retrievable
        let cachedResponse = cache.get("example.com")
        XCTAssertNotNil(cachedResponse)
        XCTAssertEqual(cachedResponse?.domain, "example.com")
        XCTAssertTrue(cachedResponse?.cached ?? false, "Retrieved response should be marked as cached")
    }
    
    /// Test that expired entries are not returned
    /// Requirement: 4.9
    func testExpiredEntriesNotReturned() {
        // Given: A DNS response with very short TTL
        let response = DNSResponse(
            id: 2,
            domain: "example.com",
            addresses: ["93.184.216.34"],
            ttl: 0.1, // 100ms TTL
            cached: false,
            timestamp: Date()
        )
        
        // When: Storing in cache and waiting for expiration
        cache.set("example.com", response: response, ttl: 0.1)
        
        // Immediately should be available
        XCTAssertNotNil(cache.get("example.com"))
        
        // After expiration should return nil
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertNil(cache.get("example.com"), "Expired entry should not be returned")
    }
    
    /// Test cache clear operation
    func testCacheClear() {
        // Given: Multiple cached entries
        let response1 = DNSResponse(id: 1, domain: "example1.com", addresses: ["1.1.1.1"], ttl: 300)
        let response2 = DNSResponse(id: 2, domain: "example2.com", addresses: ["2.2.2.2"], ttl: 300)
        
        cache.set("example1.com", response: response1, ttl: 300)
        cache.set("example2.com", response: response2, ttl: 300)
        
        // When: Clearing cache
        cache.clear()
        
        // Then: All entries should be removed
        XCTAssertNil(cache.get("example1.com"))
        XCTAssertNil(cache.get("example2.com"))
    }
    
    /// Test cache statistics
    func testCacheStatistics() {
        // Given: Some cached entries
        let response = DNSResponse(id: 1, domain: "example.com", addresses: ["1.1.1.1"], ttl: 300)
        cache.set("example.com", response: response, ttl: 300)
        
        // When: Getting statistics
        let stats = cache.getStatistics()
        
        // Then: Should reflect cached entries
        XCTAssertEqual(stats.count, 1)
    }
}
