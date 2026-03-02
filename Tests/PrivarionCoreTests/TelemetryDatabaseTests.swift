import XCTest
@testable import PrivarionCore

/// Unit tests for TelemetryDatabase
/// Requirements: 10.1, 10.10, 20.1
final class TelemetryDatabaseTests: XCTestCase {
    
    var database: TelemetryDatabase!
    
    override func setUp() {
        super.setUp()
        database = TelemetryDatabase()
    }
    
    override func tearDown() {
        database = nil
        super.tearDown()
    }
    
    // MARK: - Endpoint Management Tests
    
    /// Test adding and checking telemetry endpoints
    /// Requirement: 10.1
    func testAddEndpoint() {
        // Add endpoint
        database.addEndpoint("telemetry.example.com")
        
        // Verify endpoint is recognized
        XCTAssertTrue(database.isKnownTelemetryEndpoint("telemetry.example.com"))
    }
    
    /// Test removing telemetry endpoints
    /// Requirement: 10.1
    func testRemoveEndpoint() {
        // Add endpoint
        database.addEndpoint("telemetry.example.com")
        XCTAssertTrue(database.isKnownTelemetryEndpoint("telemetry.example.com"))
        
        // Remove endpoint
        database.removeEndpoint("telemetry.example.com")
        
        // Verify endpoint is no longer recognized
        XCTAssertFalse(database.isKnownTelemetryEndpoint("telemetry.example.com"))
    }
    
    /// Test checking unknown endpoints
    /// Requirement: 10.1
    func testUnknownEndpoint() {
        XCTAssertFalse(database.isKnownTelemetryEndpoint("unknown.example.com"))
    }
    
    /// Test subdomain matching for telemetry endpoints
    /// Requirement: 10.1
    func testSubdomainMatching() {
        // Add parent domain
        database.addEndpoint("telemetry.example.com")
        
        // Verify subdomain is recognized
        XCTAssertTrue(database.isKnownTelemetryEndpoint("api.telemetry.example.com"))
        XCTAssertTrue(database.isKnownTelemetryEndpoint("v2.telemetry.example.com"))
    }
    
    /// Test exact domain matching
    /// Requirement: 10.1
    func testExactDomainMatching() {
        database.addEndpoint("telemetry.example.com")
        
        // Exact match should work
        XCTAssertTrue(database.isKnownTelemetryEndpoint("telemetry.example.com"))
        
        // Parent domain should not match
        XCTAssertFalse(database.isKnownTelemetryEndpoint("example.com"))
    }
    
    /// Test getting all endpoints
    /// Requirement: 10.1
    func testGetAllEndpoints() {
        database.addEndpoint("telemetry1.example.com")
        database.addEndpoint("telemetry2.example.com")
        database.addEndpoint("analytics.example.com")
        
        let endpoints = database.getAllEndpoints()
        XCTAssertEqual(endpoints.count, 3)
        XCTAssertTrue(endpoints.contains("telemetry1.example.com"))
        XCTAssertTrue(endpoints.contains("telemetry2.example.com"))
        XCTAssertTrue(endpoints.contains("analytics.example.com"))
    }
    
    // MARK: - Default Database Tests
    
    /// Test default database initialization
    /// Requirement: 10.1
    func testDefaultDatabase() {
        let defaultDB = TelemetryDatabase.defaultDatabase()
        
        // Verify common telemetry endpoints are included
        XCTAssertTrue(defaultDB.isKnownTelemetryEndpoint("google-analytics.com"))
        XCTAssertTrue(defaultDB.isKnownTelemetryEndpoint("telemetry.microsoft.com"))
        XCTAssertTrue(defaultDB.isKnownTelemetryEndpoint("telemetry.mozilla.org"))
        XCTAssertTrue(defaultDB.isKnownTelemetryEndpoint("mixpanel.com"))
        
        // Verify patterns are included
        let patterns = defaultDB.getAllPatterns()
        XCTAssertFalse(patterns.isEmpty)
    }
    
    // MARK: - Pattern Management Tests
    
    /// Test adding patterns
    /// Requirement: 10.2
    func testAddPattern() {
        let pattern = TelemetryPattern(
            type: .analytics,
            domainPattern: "*.analytics.*",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        database.addPattern(pattern)
        
        let patterns = database.getAllPatterns()
        XCTAssertEqual(patterns.count, 1)
        XCTAssertEqual(patterns.first, pattern)
    }
    
    /// Test removing patterns
    /// Requirement: 10.2
    func testRemovePattern() {
        let pattern = TelemetryPattern(
            type: .analytics,
            domainPattern: "*.analytics.*",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        database.addPattern(pattern)
        XCTAssertEqual(database.getAllPatterns().count, 1)
        
        database.removePattern(pattern)
        XCTAssertEqual(database.getAllPatterns().count, 0)
    }
    
    // MARK: - Pattern Matching Tests
    
    /// Test domain pattern matching with wildcards
    /// Requirement: 10.4
    func testDomainPatternMatching() {
        let pattern = TelemetryPattern(
            type: .analytics,
            domainPattern: "*.analytics.*",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        XCTAssertTrue(pattern.matchesDomain("api.analytics.example.com"))
        XCTAssertTrue(pattern.matchesDomain("v2.analytics.google.com"))
        XCTAssertFalse(pattern.matchesDomain("example.com"))
        XCTAssertFalse(pattern.matchesDomain("analytics-api.example.com"))
    }
    
    /// Test path pattern matching
    /// Requirement: 10.5
    func testPathPatternMatching() {
        let pattern = TelemetryPattern(
            type: .tracking,
            domainPattern: "*",
            pathPattern: "/api/analytics",
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        XCTAssertTrue(pattern.matchesPath("/api/analytics"))
        XCTAssertFalse(pattern.matchesPath("/api/data"))
        XCTAssertFalse(pattern.matchesPath("/analytics"))
    }
    
    /// Test path pattern with wildcards
    /// Requirement: 10.5
    func testPathPatternWithWildcards() {
        let pattern = TelemetryPattern(
            type: .tracking,
            domainPattern: "*",
            pathPattern: "/api/*/track",
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        XCTAssertTrue(pattern.matchesPath("/api/v1/track"))
        XCTAssertTrue(pattern.matchesPath("/api/v2/track"))
        XCTAssertFalse(pattern.matchesPath("/api/track"))
    }
    
    /// Test header pattern matching
    /// Requirement: 10.6
    func testHeaderPatternMatching() {
        let pattern = TelemetryPattern(
            type: .analytics,
            domainPattern: "*",
            pathPattern: nil,
            headerPatterns: ["X-Analytics-Id": "*"],
            payloadPattern: nil
        )
        
        XCTAssertTrue(pattern.matchesHeaders(["X-Analytics-Id": "12345"]))
        XCTAssertTrue(pattern.matchesHeaders(["X-Analytics-Id": "abc-def"]))
        XCTAssertFalse(pattern.matchesHeaders(["X-Other-Header": "value"]))
        XCTAssertFalse(pattern.matchesHeaders([:]))
    }
    
    /// Test multiple header pattern matching
    /// Requirement: 10.6
    func testMultipleHeaderPatternMatching() {
        let pattern = TelemetryPattern(
            type: .analytics,
            domainPattern: "*",
            pathPattern: nil,
            headerPatterns: [
                "X-Analytics-Id": "*",
                "X-Tracking-Id": "*"
            ],
            payloadPattern: nil
        )
        
        XCTAssertTrue(pattern.matchesHeaders([
            "X-Analytics-Id": "12345",
            "X-Tracking-Id": "67890"
        ]))
        
        XCTAssertFalse(pattern.matchesHeaders([
            "X-Analytics-Id": "12345"
        ]))
    }
    
    /// Test pattern with no constraints matches everything
    /// Requirement: 10.4
    func testPatternWithNoConstraints() {
        let pattern = TelemetryPattern(
            type: .analytics,
            domainPattern: "*",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        
        XCTAssertTrue(pattern.matchesDomain("any.domain.com"))
        XCTAssertTrue(pattern.matchesPath("/any/path"))
        XCTAssertTrue(pattern.matchesHeaders(["Any": "Header"]))
    }
    
    // MARK: - Persistence Tests
    
    /// Test saving database to file
    /// Requirement: 10.1
    func testSaveToFile() throws {
        database.addEndpoint("telemetry.example.com")
        database.addEndpoint("analytics.example.com")
        
        let pattern = TelemetryPattern(
            type: .analytics,
            domainPattern: "*.analytics.*",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        database.addPattern(pattern)
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-telemetry-db.json")
        
        try database.save(to: tempURL)
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    /// Test loading database from file
    /// Requirement: 10.1
    func testLoadFromFile() throws {
        // Create and save database
        database.addEndpoint("telemetry.example.com")
        database.addEndpoint("analytics.example.com")
        
        let pattern = TelemetryPattern(
            type: .analytics,
            domainPattern: "*.analytics.*",
            pathPattern: nil,
            headerPatterns: [:],
            payloadPattern: nil
        )
        database.addPattern(pattern)
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-telemetry-db.json")
        
        try database.save(to: tempURL)
        
        // Create new database and load
        let newDatabase = TelemetryDatabase()
        try newDatabase.load(from: tempURL)
        
        // Verify endpoints were loaded
        XCTAssertTrue(newDatabase.isKnownTelemetryEndpoint("telemetry.example.com"))
        XCTAssertTrue(newDatabase.isKnownTelemetryEndpoint("analytics.example.com"))
        
        // Verify patterns were loaded
        let patterns = newDatabase.getAllPatterns()
        XCTAssertEqual(patterns.count, 1)
        XCTAssertEqual(patterns.first, pattern)
        
        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }
    
    // MARK: - Thread Safety Tests
    
    /// Test concurrent endpoint additions
    /// Requirement: 10.1
    func testConcurrentEndpointAdditions() {
        let expectation = XCTestExpectation(description: "Concurrent additions complete")
        expectation.expectedFulfillmentCount = 100
        
        for i in 0..<100 {
            DispatchQueue.global().async {
                self.database.addEndpoint("telemetry\(i).example.com")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify all endpoints were added
        let endpoints = database.getAllEndpoints()
        XCTAssertEqual(endpoints.count, 100)
    }
    
    /// Test concurrent reads and writes
    /// Requirement: 10.1
    func testConcurrentReadsAndWrites() {
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 200
        
        // Add some initial endpoints
        for i in 0..<50 {
            database.addEndpoint("telemetry\(i).example.com")
        }
        
        // Concurrent reads
        for i in 0..<100 {
            DispatchQueue.global().async {
                _ = self.database.isKnownTelemetryEndpoint("telemetry\(i % 50).example.com")
                expectation.fulfill()
            }
        }
        
        // Concurrent writes
        for i in 50..<150 {
            DispatchQueue.global().async {
                self.database.addEndpoint("telemetry\(i).example.com")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Verify database is in consistent state
        let endpoints = database.getAllEndpoints()
        XCTAssertGreaterThanOrEqual(endpoints.count, 50)
    }
    
    // MARK: - Remote Loading Tests
    
    /// Test remote loading with no URL configured
    /// Requirement: 10.10
    func testRemoteLoadingWithNoURL() async {
        do {
            try await database.loadFromRemote()
            XCTFail("Should throw error when no remote URL is configured")
        } catch let error as TelemetryDatabaseError {
            XCTAssertEqual(error, .noRemoteSourceConfigured)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    /// Test remote loading with invalid URL
    /// Requirement: 10.10
    func testRemoteLoadingWithInvalidURL() async {
        let invalidURL = URL(string: "https://invalid.example.com/telemetry.json")!
        let database = TelemetryDatabase(remoteSourceURL: invalidURL)
        
        do {
            try await database.loadFromRemote()
            XCTFail("Should throw error when remote URL is invalid")
        } catch {
            // Expected to fail
            XCTAssertTrue(true)
        }
    }
}
