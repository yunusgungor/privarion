import XCTest
@testable import PrivarionCore

final class TelemetryPatternMatcherTests: XCTestCase {
    
    var database: TelemetryDatabase!
    var matcher: TelemetryPatternMatcher!
    
    override func setUp() {
        super.setUp()
        // Create database with test patterns
        database = TelemetryDatabase(
            endpoints: [],
            patterns: createTestPatterns()
        )
        matcher = TelemetryPatternMatcher(database: database)
    }
    
    override func tearDown() {
        matcher = nil
        database = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestPatterns() -> [TelemetryPattern] {
        return [
            // Domain patterns
            TelemetryPattern(
                type: .analytics,
                domainPattern: "*.analytics.*",
                pathPattern: nil,
                headerPatterns: [:],
                payloadPattern: nil
            ),
            TelemetryPattern(
                type: .analytics,
                domainPattern: "*.telemetry.*",
                pathPattern: nil,
                headerPatterns: [:],
                payloadPattern: nil
            ),
            TelemetryPattern(
                type: .tracking,
                domainPattern: "*.tracking.*",
                pathPattern: nil,
                headerPatterns: [:],
                payloadPattern: nil
            ),
            
            // Path patterns
            TelemetryPattern(
                type: .analytics,
                domainPattern: "*",
                pathPattern: "/api/analytics",
                headerPatterns: [:],
                payloadPattern: nil
            ),
            TelemetryPattern(
                type: .tracking,
                domainPattern: "*",
                pathPattern: "/track",
                headerPatterns: [:],
                payloadPattern: nil
            ),
            TelemetryPattern(
                type: .tracking,
                domainPattern: "*",
                pathPattern: "/collect",
                headerPatterns: [:],
                payloadPattern: nil
            ),
            
            // Header patterns
            TelemetryPattern(
                type: .analytics,
                domainPattern: "*",
                pathPattern: nil,
                headerPatterns: ["X-Analytics-Id": "*"],
                payloadPattern: nil
            ),
            TelemetryPattern(
                type: .tracking,
                domainPattern: "*",
                pathPattern: nil,
                headerPatterns: ["X-Tracking-Id": "*"],
                payloadPattern: nil
            ),
            
            // Payload patterns
            TelemetryPattern(
                type: .analytics,
                domainPattern: "*",
                pathPattern: nil,
                headerPatterns: [:],
                payloadPattern: "\"event\":\\s*\"track\""
            )
        ]
    }
    
    // MARK: - Domain Pattern Matching Tests (Requirement 10.4)
    
    func testMatchesTelemetryDomain_Analytics() {
        // Test *.analytics.* pattern
        XCTAssertTrue(matcher.matchesTelemetryDomain("google.analytics.com"))
        XCTAssertTrue(matcher.matchesTelemetryDomain("app.analytics.example.com"))
        XCTAssertTrue(matcher.matchesTelemetryDomain("sub.analytics.domain.org"))
    }
    
    func testMatchesTelemetryDomain_Telemetry() {
        // Test *.telemetry.* pattern
        XCTAssertTrue(matcher.matchesTelemetryDomain("app.telemetry.microsoft.com"))
        XCTAssertTrue(matcher.matchesTelemetryDomain("service.telemetry.example.com"))
    }
    
    func testMatchesTelemetryDomain_Tracking() {
        // Test *.tracking.* pattern
        XCTAssertTrue(matcher.matchesTelemetryDomain("ads.tracking.example.com"))
        XCTAssertTrue(matcher.matchesTelemetryDomain("pixel.tracking.domain.com"))
    }
    
    func testMatchesTelemetryDomain_NoMatch() {
        // Test domains that should not match telemetry-specific patterns
        // Note: The test patterns include "*" domain patterns with path/header requirements,
        // so we need to test domains that don't match the specific telemetry patterns
        // (*.analytics.*, *.telemetry.*, *.tracking.*)
        
        // These domains don't contain analytics, telemetry, or tracking in them
        // However, patterns with "*" domain will match any domain, so we check
        // that at least the specific telemetry domain patterns work correctly
        
        // Create a matcher with only specific domain patterns (no wildcards)
        let specificDatabase = TelemetryDatabase(
            endpoints: [],
            patterns: [
                TelemetryPattern(
                    type: .analytics,
                    domainPattern: "*.analytics.*",
                    pathPattern: nil,
                    headerPatterns: [:],
                    payloadPattern: nil
                ),
                TelemetryPattern(
                    type: .analytics,
                    domainPattern: "*.telemetry.*",
                    pathPattern: nil,
                    headerPatterns: [:],
                    payloadPattern: nil
                ),
                TelemetryPattern(
                    type: .tracking,
                    domainPattern: "*.tracking.*",
                    pathPattern: nil,
                    headerPatterns: [:],
                    payloadPattern: nil
                )
            ]
        )
        let specificMatcher = TelemetryPatternMatcher(database: specificDatabase)
        
        XCTAssertFalse(specificMatcher.matchesTelemetryDomain("example.com"))
        XCTAssertFalse(specificMatcher.matchesTelemetryDomain("api.example.com"))
        XCTAssertFalse(specificMatcher.matchesTelemetryDomain("google.com"))
    }
    
    // MARK: - Path Pattern Matching Tests (Requirement 10.5)
    
    func testMatchesTelemetryPath_ApiAnalytics() {
        // Test /api/analytics pattern
        XCTAssertTrue(matcher.matchesTelemetryPath("/api/analytics"))
    }
    
    func testMatchesTelemetryPath_Track() {
        // Test /track pattern
        XCTAssertTrue(matcher.matchesTelemetryPath("/track"))
    }
    
    func testMatchesTelemetryPath_Collect() {
        // Test /collect pattern
        XCTAssertTrue(matcher.matchesTelemetryPath("/collect"))
    }
    
    func testMatchesTelemetryPath_NoMatch() {
        // Test paths that should not match
        XCTAssertFalse(matcher.matchesTelemetryPath("/api/users"))
        XCTAssertFalse(matcher.matchesTelemetryPath("/home"))
        XCTAssertFalse(matcher.matchesTelemetryPath("/data"))
    }
    
    // MARK: - Header Inspection Tests (Requirement 10.6)
    
    func testInspectHeadersForTelemetry_AnalyticsHeader() {
        // Test X-Analytics-* headers
        let headers1 = ["X-Analytics-Id": "12345"]
        XCTAssertTrue(matcher.inspectHeadersForTelemetry(headers1))
        
        let headers2 = ["X-Analytics-Session": "abc-def"]
        XCTAssertTrue(matcher.inspectHeadersForTelemetry(headers2))
        
        let headers3 = ["X-Analytics-User": "user123"]
        XCTAssertTrue(matcher.inspectHeadersForTelemetry(headers3))
    }
    
    func testInspectHeadersForTelemetry_TrackingHeader() {
        // Test X-Tracking-* headers
        let headers1 = ["X-Tracking-Id": "track-123"]
        XCTAssertTrue(matcher.inspectHeadersForTelemetry(headers1))
        
        let headers2 = ["X-Tracking-Session": "session-456"]
        XCTAssertTrue(matcher.inspectHeadersForTelemetry(headers2))
    }
    
    func testInspectHeadersForTelemetry_TelemetryHeader() {
        // Test X-Telemetry-* headers
        let headers = ["X-Telemetry-Version": "1.0"]
        XCTAssertTrue(matcher.inspectHeadersForTelemetry(headers))
    }
    
    func testInspectHeadersForTelemetry_CaseInsensitive() {
        // Test case insensitivity
        let headers1 = ["x-analytics-id": "12345"]
        XCTAssertTrue(matcher.inspectHeadersForTelemetry(headers1))
        
        let headers2 = ["X-TRACKING-ID": "track-123"]
        XCTAssertTrue(matcher.inspectHeadersForTelemetry(headers2))
    }
    
    func testInspectHeadersForTelemetry_NoMatch() {
        // Test headers that should not match
        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer token",
            "User-Agent": "Mozilla/5.0"
        ]
        XCTAssertFalse(matcher.inspectHeadersForTelemetry(headers))
    }
    
    func testInspectHeadersForTelemetry_EmptyHeaders() {
        // Test empty headers
        XCTAssertFalse(matcher.inspectHeadersForTelemetry([:]))
    }
    
    // MARK: - Payload Inspection Tests (Requirement 10.7)
    
    func testInspectPayloadForTelemetry_JSONWithEventTrack() {
        // Test JSON with event: "track"
        let json = """
        {
            "event": "track",
            "properties": {
                "page": "home"
            }
        }
        """
        let payload = json.data(using: .utf8)!
        XCTAssertTrue(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_JSONWithAnalyticsKey() {
        // Test JSON with analytics key
        let json = """
        {
            "analytics": {
                "user_id": "12345",
                "session_id": "abc-def"
            }
        }
        """
        let payload = json.data(using: .utf8)!
        XCTAssertTrue(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_JSONWithTrackingKey() {
        // Test JSON with tracking key
        let json = """
        {
            "tracking": {
                "event": "page_view",
                "timestamp": 1234567890
            }
        }
        """
        let payload = json.data(using: .utf8)!
        XCTAssertTrue(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_JSONWithTelemetryKey() {
        // Test JSON with telemetry key
        let json = """
        {
            "telemetry": {
                "version": "1.0",
                "data": {}
            }
        }
        """
        let payload = json.data(using: .utf8)!
        XCTAssertTrue(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_JSONWithMetricsKey() {
        // Test JSON with metrics key
        let json = """
        {
            "metrics": {
                "cpu": 50,
                "memory": 1024
            }
        }
        """
        let payload = json.data(using: .utf8)!
        XCTAssertTrue(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_JSONWithUserIdKey() {
        // Test JSON with user_id key
        let json = """
        {
            "user_id": "12345",
            "action": "click"
        }
        """
        let payload = json.data(using: .utf8)!
        XCTAssertTrue(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_JSONWithSessionIdKey() {
        // Test JSON with session_id key
        let json = """
        {
            "session_id": "abc-def-ghi",
            "timestamp": 1234567890
        }
        """
        let payload = json.data(using: .utf8)!
        XCTAssertTrue(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_JSONWithGoogleAnalytics() {
        // Test JSON with Google Analytics identifiers
        let json = """
        {
            "ga": "UA-12345-1",
            "gtm": "GTM-XXXX"
        }
        """
        let payload = json.data(using: .utf8)!
        XCTAssertTrue(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_NestedJSON() {
        // Test nested JSON with telemetry keys
        let json = """
        {
            "data": {
                "user": {
                    "analytics": {
                        "id": "12345"
                    }
                }
            }
        }
        """
        let payload = json.data(using: .utf8)!
        XCTAssertTrue(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_StringWithTelemetryKeywords() {
        // Test non-JSON string with telemetry keywords
        let string = "tracking_id=12345&event=page_view"
        let payload = string.data(using: .utf8)!
        XCTAssertTrue(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_NoMatch() {
        // Test payload that should not match
        let json = """
        {
            "username": "john",
            "email": "john@example.com"
        }
        """
        let payload = json.data(using: .utf8)!
        XCTAssertFalse(matcher.inspectPayloadForTelemetry(payload))
    }
    
    func testInspectPayloadForTelemetry_EmptyPayload() {
        // Test empty payload
        let payload = Data()
        XCTAssertFalse(matcher.inspectPayloadForTelemetry(payload))
    }
    
    // MARK: - Combined Matching Tests
    
    func testMatchRequest_DomainOnly() {
        // Test matching with domain only
        let pattern = matcher.matchRequest(domain: "google.analytics.com")
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.type, .analytics)
    }
    
    func testMatchRequest_DomainAndPath() {
        // Test matching with domain and path
        let pattern = matcher.matchRequest(
            domain: "example.com",
            path: "/api/analytics"
        )
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.type, .analytics)
    }
    
    func testMatchRequest_DomainAndHeaders() {
        // Test matching with domain and headers
        let pattern = matcher.matchRequest(
            domain: "example.com",
            headers: ["X-Analytics-Id": "12345"]
        )
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.type, .analytics)
    }
    
    func testMatchRequest_AllComponents() {
        // Test matching with all components
        let json = """
        {
            "event": "track",
            "user_id": "12345"
        }
        """
        let payload = json.data(using: .utf8)!
        
        let pattern = matcher.matchRequest(
            domain: "google.analytics.com",
            path: "/collect",
            headers: ["X-Analytics-Id": "12345"],
            payload: payload
        )
        XCTAssertNotNil(pattern)
    }
    
    func testMatchRequest_NoMatch() {
        // Test request that should not match
        let pattern = matcher.matchRequest(
            domain: "example.com",
            path: "/api/users"
        )
        XCTAssertNil(pattern)
    }
    
    // MARK: - Multiple Pattern Matching Tests
    
    func testGetAllMatchingPatterns_MultipleDomainMatches() {
        // Test getting all matching patterns for a domain
        let patterns = matcher.getAllMatchingPatterns(domain: "google.analytics.com")
        XCTAssertFalse(patterns.isEmpty)
        XCTAssertTrue(patterns.contains { $0.domainPattern == "*.analytics.*" })
    }
    
    func testGetAllMatchingPatterns_MultiplePathMatches() {
        // Test getting all matching patterns for a path
        let patterns = matcher.getAllMatchingPatterns(
            domain: "example.com",
            path: "/track"
        )
        XCTAssertFalse(patterns.isEmpty)
        XCTAssertTrue(patterns.contains { $0.pathPattern == "/track" })
    }
    
    func testGetAllMatchingPatterns_NoMatches() {
        // Test getting patterns when nothing matches
        let patterns = matcher.getAllMatchingPatterns(
            domain: "example.com",
            path: "/api/users"
        )
        XCTAssertTrue(patterns.isEmpty)
    }
    
    // MARK: - Convenience Method Tests
    
    func testShouldBlockRequest_True() {
        // Test that telemetry request should be blocked
        XCTAssertTrue(matcher.shouldBlockRequest(domain: "google.analytics.com"))
        XCTAssertTrue(matcher.shouldBlockRequest(domain: "example.com", path: "/track"))
        XCTAssertTrue(matcher.shouldBlockRequest(
            domain: "example.com",
            headers: ["X-Tracking-Id": "12345"]
        ))
    }
    
    func testShouldBlockRequest_False() {
        // Test that non-telemetry request should not be blocked
        XCTAssertFalse(matcher.shouldBlockRequest(domain: "example.com"))
        XCTAssertFalse(matcher.shouldBlockRequest(domain: "example.com", path: "/api/users"))
    }
    
    func testGetTelemetryType_Analytics() {
        // Test getting telemetry type for analytics request
        let type = matcher.getTelemetryType(domain: "google.analytics.com")
        XCTAssertEqual(type, .analytics)
    }
    
    func testGetTelemetryType_Tracking() {
        // Test getting telemetry type for tracking request
        let type = matcher.getTelemetryType(domain: "ads.tracking.example.com")
        XCTAssertEqual(type, .tracking)
    }
    
    func testGetTelemetryType_NoMatch() {
        // Test getting telemetry type when no match
        let type = matcher.getTelemetryType(domain: "example.com")
        XCTAssertNil(type)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() {
        // Test thread-safe concurrent access
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        for i in 0..<10 {
            queue.async {
                let domain = i % 2 == 0 ? "google.analytics.com" : "example.com"
                _ = self.matcher.matchesTelemetryDomain(domain)
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Edge Case Tests
    
    func testMatchRequest_EmptyDomain() {
        // Test with empty domain
        let pattern = matcher.matchRequest(domain: "")
        XCTAssertNil(pattern)
    }
    
    func testMatchRequest_EmptyPath() {
        // Test with empty path
        let pattern = matcher.matchRequest(domain: "example.com", path: "")
        XCTAssertNil(pattern)
    }
    
    func testMatchRequest_NilOptionalParameters() {
        // Test with nil optional parameters
        let pattern = matcher.matchRequest(
            domain: "google.analytics.com",
            path: nil,
            headers: nil,
            payload: nil
        )
        XCTAssertNotNil(pattern)
    }
    
    func testInspectPayloadForTelemetry_InvalidUTF8() {
        // Test with invalid UTF-8 data
        let invalidData = Data([0xFF, 0xFE, 0xFD])
        XCTAssertFalse(matcher.inspectPayloadForTelemetry(invalidData))
    }
    
    func testInspectPayloadForTelemetry_InvalidJSON() {
        // Test with invalid JSON
        let invalidJSON = "{invalid json}".data(using: .utf8)!
        // Should still check for string patterns
        XCTAssertFalse(matcher.inspectPayloadForTelemetry(invalidJSON))
    }
}
