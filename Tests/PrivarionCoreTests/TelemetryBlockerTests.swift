// TelemetryBlocker Unit Tests
// Requirements: 10.2-10.3, 10.9, 20.1

import XCTest
@testable import PrivarionCore
@testable import PrivarionSharedModels

final class TelemetryBlockerTests: XCTestCase {
    
    var telemetryBlocker: TelemetryBlocker!
    var database: TelemetryDatabase!
    var patternMatcher: TelemetryPatternMatcher!
    
    override func setUp() {
        super.setUp()
        database = TelemetryDatabase.defaultDatabase()
        patternMatcher = TelemetryPatternMatcher(database: database)
        telemetryBlocker = TelemetryBlocker(
            telemetryDatabase: database,
            patternMatcher: patternMatcher
        )
    }
    
    override func tearDown() {
        telemetryBlocker = nil
        patternMatcher = nil
        database = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithDefaultDatabase() {
        // Test convenience initializer
        let blocker = TelemetryBlocker()
        
        // Should be able to block known telemetry domains
        let request = createNetworkRequest(domain: "google-analytics.com")
        XCTAssertTrue(blocker.shouldBlock(request))
    }
    
    func testInitializationWithCustomPatterns() {
        let customPattern = TelemetryPattern(
            type: .analytics,
            domainPattern: "custom-analytics.com",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        let blocker = TelemetryBlocker(
            telemetryDatabase: database,
            patternMatcher: patternMatcher,
            userDefinedPatterns: [customPattern]
        )
        
        let request = createNetworkRequest(domain: "custom-analytics.com")
        XCTAssertTrue(blocker.shouldBlock(request))
    }
    
    // MARK: - Known Endpoint Blocking Tests
    
    func testShouldBlockKnownTelemetryEndpoint() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "google-analytics.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request))
    }
    
    func testShouldBlockMicrosoftTelemetry() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "telemetry.microsoft.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request))
    }
    
    func testShouldBlockMozillaTelemetry() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "telemetry.mozilla.org")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request))
    }
    
    func testShouldNotBlockNonTelemetryDomain() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "apple.com")
        XCTAssertFalse(telemetryBlocker.shouldBlock(request))
    }
    
    func testShouldNotBlockRequestWithoutDomain() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: nil)
        XCTAssertFalse(telemetryBlocker.shouldBlock(request))
    }
    
    // MARK: - Pattern Matching Tests
    
    func testShouldBlockAnalyticsDomainPattern() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "my-app.analytics.example.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request))
    }
    
    func testShouldBlockTrackingDomainPattern() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "tracking.example.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request))
    }
    
    func testShouldBlockTelemetryDomainPattern() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "app.telemetry.example.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request))
    }
    
    func testShouldBlockWithTelemetryPath() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "example.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request, path: "/track"))
    }
    
    func testShouldBlockWithAnalyticsPath() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "example.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request, path: "/api/analytics"))
    }
    
    func testShouldBlockWithCollectPath() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "example.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request, path: "/collect"))
    }
    
    func testShouldBlockWithTelemetryHeaders() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "example.com")
        let headers = ["X-Analytics-Id": "12345"]
        XCTAssertTrue(telemetryBlocker.shouldBlock(request, headers: headers))
    }
    
    func testShouldBlockWithTrackingHeaders() {
        // Requirement: 10.2-10.3
        let request = createNetworkRequest(domain: "example.com")
        let headers = ["X-Tracking-Id": "abc123"]
        XCTAssertTrue(telemetryBlocker.shouldBlock(request, headers: headers))
    }
    
    // MARK: - Pattern Detection Tests
    
    func testDetectTelemetryPatternInPayload() {
        // Requirement: 10.2
        let payload = """
        {
            "event": "page_view",
            "analytics": {
                "user_id": "12345",
                "session_id": "abc"
            }
        }
        """.data(using: .utf8)!
        
        let pattern = telemetryBlocker.detectTelemetryPattern(in: payload)
        XCTAssertNotNil(pattern)
    }
    
    func testDetectTelemetryPatternWithFullContext() {
        // Requirement: 10.2
        let pattern = telemetryBlocker.detectTelemetryPattern(
            domain: "google-analytics.com",
            path: "/collect",
            headers: ["X-Analytics-Id": "test"],
            payload: nil
        )
        
        XCTAssertNotNil(pattern)
        XCTAssertEqual(pattern?.type, .analytics)
    }
    
    func testDetectNoTelemetryPatternInCleanPayload() {
        // Requirement: 10.2
        let payload = """
        {
            "message": "Hello, world!",
            "data": "Some content"
        }
        """.data(using: .utf8)!
        
        let pattern = telemetryBlocker.detectTelemetryPattern(in: payload)
        XCTAssertNil(pattern)
    }
    
    // MARK: - User-Defined Patterns Tests
    
    func testAddUserDefinedPattern() {
        // Requirement: 10.9
        let customPattern = TelemetryPattern(
            type: .tracking,
            domainPattern: "my-custom-tracker.com",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        telemetryBlocker.addUserDefinedPattern(customPattern)
        
        let patterns = telemetryBlocker.getUserDefinedPatterns()
        XCTAssertEqual(patterns.count, 1)
        XCTAssertEqual(patterns.first?.domainPattern, "my-custom-tracker.com")
    }
    
    func testRemoveUserDefinedPattern() {
        // Requirement: 10.9
        let customPattern = TelemetryPattern(
            type: .tracking,
            domainPattern: "my-custom-tracker.com",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        telemetryBlocker.addUserDefinedPattern(customPattern)
        XCTAssertEqual(telemetryBlocker.getUserDefinedPatterns().count, 1)
        
        telemetryBlocker.removeUserDefinedPattern(customPattern)
        XCTAssertEqual(telemetryBlocker.getUserDefinedPatterns().count, 0)
    }
    
    func testClearUserDefinedPatterns() {
        // Requirement: 10.9
        let pattern1 = TelemetryPattern(
            type: .tracking,
            domainPattern: "tracker1.com",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        let pattern2 = TelemetryPattern(
            type: .analytics,
            domainPattern: "analytics2.com",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        telemetryBlocker.addUserDefinedPattern(pattern1)
        telemetryBlocker.addUserDefinedPattern(pattern2)
        XCTAssertEqual(telemetryBlocker.getUserDefinedPatterns().count, 2)
        
        telemetryBlocker.clearUserDefinedPatterns()
        XCTAssertEqual(telemetryBlocker.getUserDefinedPatterns().count, 0)
    }
    
    func testShouldBlockWithUserDefinedPattern() {
        // Requirement: 10.9
        let customPattern = TelemetryPattern(
            type: .tracking,
            domainPattern: "my-custom-tracker.com",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        telemetryBlocker.addUserDefinedPattern(customPattern)
        
        let request = createNetworkRequest(domain: "my-custom-tracker.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request))
    }
    
    func testUserDefinedPatternWithPath() {
        // Requirement: 10.9
        let customPattern = TelemetryPattern(
            type: .analytics,
            domainPattern: "example.com",
            pathPattern: "/custom/analytics",
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        telemetryBlocker.addUserDefinedPattern(customPattern)
        
        let request = createNetworkRequest(domain: "example.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request, path: "/custom/analytics"))
        XCTAssertFalse(telemetryBlocker.shouldBlock(request, path: "/other/path"))
    }
    
    func testUserDefinedPatternWithHeaders() {
        // Requirement: 10.9
        let customPattern = TelemetryPattern(
            type: .tracking,
            domainPattern: "example.com",
            pathPattern: nil,
            headerPatterns: ["X-Custom-Tracker": "*"],
            payloadPattern: nil
        )
        
        telemetryBlocker.addUserDefinedPattern(customPattern)
        
        let request = createNetworkRequest(domain: "example.com")
        XCTAssertTrue(telemetryBlocker.shouldBlock(request, headers: ["X-Custom-Tracker": "value"]))
        XCTAssertFalse(telemetryBlocker.shouldBlock(request, headers: ["Other-Header": "value"]))
    }
    
    // MARK: - Convenience Methods Tests
    
    func testGetBlockingReason() {
        let request = createNetworkRequest(domain: "google-analytics.com")
        let reason = telemetryBlocker.getBlockingReason(request)
        
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.contains("google-analytics.com"))
    }
    
    func testGetBlockingReasonForNonBlockedRequest() {
        let request = createNetworkRequest(domain: "apple.com")
        let reason = telemetryBlocker.getBlockingReason(request)
        
        XCTAssertNil(reason)
    }
    
    func testGetTelemetryType() {
        let request = createNetworkRequest(domain: "google-analytics.com")
        let type = telemetryBlocker.getTelemetryType(request)
        
        XCTAssertNotNil(type)
        XCTAssertEqual(type, .analytics)
    }
    
    func testGetTelemetryTypeForNonTelemetryRequest() {
        let request = createNetworkRequest(domain: "apple.com")
        let type = telemetryBlocker.getTelemetryType(request)
        
        XCTAssertNil(type)
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() {
        // Test thread-safe access to user-defined patterns
        let expectation = self.expectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        for i in 0..<100 {
            queue.async {
                let pattern = TelemetryPattern(
                    type: .tracking,
                    domainPattern: "tracker\(i).com",
                    pathPattern: nil,
                    headerPatterns: [:],
                    payloadPattern: nil
                )
                
                self.telemetryBlocker.addUserDefinedPattern(pattern)
                _ = self.telemetryBlocker.getUserDefinedPatterns()
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
        
        // Should have 100 patterns added
        XCTAssertEqual(telemetryBlocker.getUserDefinedPatterns().count, 100)
    }
    
    func testConcurrentBlockingChecks() {
        // Test thread-safe blocking checks
        let expectation = self.expectation(description: "Concurrent blocking checks")
        expectation.expectedFulfillmentCount = 100
        
        let queue = DispatchQueue(label: "test.concurrent.checks", attributes: .concurrent)
        
        for i in 0..<100 {
            queue.async {
                let domain = i % 2 == 0 ? "google-analytics.com" : "apple.com"
                let request = self.createNetworkRequest(domain: domain)
                _ = self.telemetryBlocker.shouldBlock(request)
                
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
    }
    
    // MARK: - Helper Methods
    
    private func createNetworkRequest(domain: String?) -> NetworkRequest {
        return NetworkRequest(
            id: UUID(),
            timestamp: Date(),
            processID: 1234,
            sourceIP: "192.168.1.100",
            sourcePort: 54321,
            destinationIP: "93.184.216.34",
            destinationPort: 443,
            protocol: .tcp,
            domain: domain
        )
    }
}
