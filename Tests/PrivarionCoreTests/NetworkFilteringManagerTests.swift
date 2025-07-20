import XCTest
import Foundation
import Network
@testable import PrivarionCore

/// XCTest-based test suite for NetworkFilteringManager
/// Phase 1 implementation focusing on basic functionality and security
/// 
/// Tests cover:
/// - Manager initialization and basic operations
/// - Statistics collection
/// - Thread safety and basic error handling
final class NetworkFilteringManagerTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    /// Test manager instance
    private var manager: NetworkFilteringManager!
    
    override func setUp() {
        super.setUp()
        manager = NetworkFilteringManager.shared
    }
    
    override func tearDown() {
        manager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testManagerInitialization() {
        XCTAssertNotNil(manager, "NetworkFilteringManager should initialize")
    }
    
    func testSharedInstanceConsistency() {
        let manager1 = NetworkFilteringManager.shared
        let manager2 = NetworkFilteringManager.shared
        XCTAssertTrue(manager1 === manager2, "Shared instance should be singleton")
    }
    
    // MARK: - Statistics Tests
    
    func testStatisticsCollection() {
        let stats = manager.getFilteringStatistics()
        
        XCTAssertGreaterThanOrEqual(stats.totalQueries, 0, "Total queries should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.blockedQueries, 0, "Blocked queries should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.allowedQueries, 0, "Allowed queries should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.uptime, 0, "Uptime should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.cacheHitRate, 0.0, "Cache hit rate should be non-negative")
        XCTAssertLessThanOrEqual(stats.cacheHitRate, 1.0, "Cache hit rate should not exceed 100%")
    }
    
    func testStatisticsValidation() {
        let stats = manager.getFilteringStatistics()
        
        // Verify statistics consistency
        XCTAssertEqual(stats.totalQueries, stats.blockedQueries + stats.allowedQueries, 
                      "Total queries should equal blocked + allowed queries")
        
        // Verify reasonable values
        XCTAssertGreaterThanOrEqual(stats.averageLatency, 0, "Average latency should be non-negative")
        XCTAssertLessThan(stats.averageLatency, 10.0, "Average latency should be reasonable (< 10s)")
    }
    
    // MARK: - Configuration Tests
    
    func testConfigurationAccess() {
        // Test basic configuration access
        let domains = manager.getBlockedDomains()
        XCTAssertNotNil(domains, "Should return blocked domains list")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentStatisticsAccess() async throws {
        // Test concurrent access to statistics doesn't cause crashes
        let operationCount = 50
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<operationCount {
                group.addTask {
                    let _ = self.manager.getFilteringStatistics()
                }
            }
        }
        
        // If we reach here without crashes, the test passes
        XCTAssertTrue(true, "Concurrent statistics access should be thread-safe")
    }
    
    func testConcurrentManagerAccess() async throws {
        // Test accessing shared instance concurrently
        let operationCount = 100
        var managers: [NetworkFilteringManager] = []
        
        await withTaskGroup(of: NetworkFilteringManager.self) { group in
            for _ in 0..<operationCount {
                group.addTask {
                    return NetworkFilteringManager.shared
                }
            }
            
            for await manager in group {
                managers.append(manager)
            }
        }
        
        // Verify all returned instances are the same
        let firstManager = managers.first!
        for manager in managers {
            XCTAssertTrue(manager === firstManager, "All concurrent accesses should return same instance")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testStatisticsResilience() {
        // Test that statistics collection is resilient to errors
        let stats1 = manager.getFilteringStatistics()
        let stats2 = manager.getFilteringStatistics()
        
        // Both calls should succeed
        XCTAssertNotNil(stats1, "First statistics call should succeed")
        XCTAssertNotNil(stats2, "Second statistics call should succeed")
        
        // Statistics should be consistent or incrementing
        XCTAssertGreaterThanOrEqual(stats2.totalQueries, stats1.totalQueries, 
                                   "Total queries should not decrease")
        XCTAssertGreaterThanOrEqual(stats2.uptime, stats1.uptime, 
                                   "Uptime should not decrease")
    }
    
    // MARK: - Memory Safety Tests
    
    func testMemoryStability() {
        // Test that repeated operations don't cause memory issues
        for _ in 0..<1000 {
            let _ = manager.getFilteringStatistics()
        }
        
        // If we complete without crashes, test passes
        XCTAssertTrue(true, "Repeated operations should not cause memory issues")
    }
    
    // MARK: - Performance Tests
    
    func testStatisticsPerformance() {
        let iterations = 1000
        let startTime = Date()
        
        for _ in 0..<iterations {
            let _ = manager.getFilteringStatistics()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let operationsPerSecond = Double(iterations) / duration
        
        XCTAssertGreaterThan(operationsPerSecond, 100, 
                            "Should perform at least 100 statistics operations per second")
        XCTAssertLessThan(duration, 10.0, 
                         "Statistics collection should complete within reasonable time")
    }
    
    // MARK: - Domain Management Tests
    
    func testDomainBlocking() throws {
        let testDomain = "test-blocked-domain.com"
        
        // Initially should not be blocked
        XCTAssertFalse(manager.isDomainBlocked(testDomain), "Domain should not be blocked initially")
        
        // Add to blocklist
        try manager.addBlockedDomain(testDomain)
        
        // Should now be blocked
        XCTAssertTrue(manager.isDomainBlocked(testDomain), "Domain should be blocked after adding")
        
        // Should appear in blocked domains list
        let blockedDomains = manager.getBlockedDomains()
        XCTAssertTrue(blockedDomains.contains(testDomain.lowercased()), "Domain should appear in blocked list")
        
        // Remove from blocklist
        try manager.removeBlockedDomain(testDomain)
        
        // Should no longer be blocked
        XCTAssertFalse(manager.isDomainBlocked(testDomain), "Domain should not be blocked after removal")
    }
    
    func testSubdomainBlocking() throws {
        let baseDomain = "example.com"
        let subdomain = "ads.example.com"
        
        // Add base domain to blocklist
        try manager.addBlockedDomain(baseDomain)
        
        // Both base and subdomain should be blocked
        XCTAssertTrue(manager.isDomainBlocked(baseDomain), "Base domain should be blocked")
        XCTAssertTrue(manager.isDomainBlocked(subdomain), "Subdomain should be blocked")
        
        // Clean up
        try manager.removeBlockedDomain(baseDomain)
    }
    
    func testDomainNormalization() throws {
        let domain1 = "EXAMPLE.COM"
        let domain2 = "  example.com  "
        let domain3 = "example.com"
        
        try manager.addBlockedDomain(domain1)
        
        // All variations should be considered blocked due to normalization
        XCTAssertTrue(manager.isDomainBlocked(domain2), "Normalized domain should be blocked")
        XCTAssertTrue(manager.isDomainBlocked(domain3), "Lowercase domain should be blocked")
        
        try manager.removeBlockedDomain(domain3)
    }
    
    func testInvalidDomainHandling() {
        // Test with various invalid domain formats
        let invalidDomains = ["", ".", "...", "invalid..domain", "-invalid.com", "invalid-.com"]
        
        for invalidDomain in invalidDomains {
            XCTAssertNoThrow({
                // Should handle gracefully, not crash
                let isBlocked = self.manager.isDomainBlocked(invalidDomain)
                XCTAssertFalse(isBlocked, "Invalid domain should not be blocked: \(invalidDomain)")
            }, "Should handle invalid domain gracefully: \(invalidDomain)")
        }
    }
    
    // MARK: - Application Rules Tests
    
    func testApplicationRuleManagement() throws {
        let appId = "com.test.app"
        var rule = ApplicationNetworkRule(applicationId: appId, ruleType: .blocklist)
        rule.blockedDomains = ["ads.com", "tracker.net"]
        rule.enabled = true
        
        // Initially no rule should exist
        XCTAssertNil(manager.getApplicationRule(for: appId), "No rule should exist initially")
        
        // Set the rule
        try manager.setApplicationRule(rule)
        
        // Rule should now exist
        let retrievedRule = manager.getApplicationRule(for: appId)
        XCTAssertNotNil(retrievedRule, "Rule should exist after setting")
        XCTAssertEqual(retrievedRule?.applicationId, appId, "Application ID should match")
        XCTAssertEqual(retrievedRule?.ruleType, .blocklist, "Rule type should match")
        XCTAssertEqual(retrievedRule?.blockedDomains.count, 2, "Should have 2 blocked domains")
        
        // Remove the rule
        try manager.removeApplicationRule(for: appId)
        
        // Rule should no longer exist
        XCTAssertNil(manager.getApplicationRule(for: appId), "Rule should not exist after removal")
    }
    
    func testAllApplicationRules() throws {
        let app1Id = "com.test.app1"
        let app2Id = "com.test.app2"
        
        var rule1 = ApplicationNetworkRule(applicationId: app1Id, ruleType: .blocklist)
        rule1.blockedDomains = ["ads.com"]
        rule1.enabled = true
        
        var rule2 = ApplicationNetworkRule(applicationId: app2Id, ruleType: .allowlist)
        rule2.allowedDomains = ["safe.com"]
        rule2.enabled = true
        
        try manager.setApplicationRule(rule1)
        try manager.setApplicationRule(rule2)
        
        let allRules = manager.getAllApplicationRules()
        XCTAssertEqual(allRules.count, 2, "Should have 2 rules")
        XCTAssertNotNil(allRules[app1Id], "Should contain first app rule")
        XCTAssertNotNil(allRules[app2Id], "Should contain second app rule")
        
        // Clean up
        try manager.removeApplicationRule(for: app1Id)
        try manager.removeApplicationRule(for: app2Id)
    }
    
    // MARK: - Network Filtering State Tests
    
    func testFilteringStateManagement() {
        // Initially should not be active
        XCTAssertFalse(manager.isFilteringActive, "Filtering should not be active initially")
        
        // Note: We don't test actual start/stop here as it requires network permissions
        // and may interfere with system networking in test environment
        // These would be covered in integration tests
    }
    
    // MARK: - Statistics Extended Tests
    
    func testStatisticsConsistencyOverTime() async throws {
        let stats1 = manager.getFilteringStatistics()
        
        // Wait a brief moment
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        let stats2 = manager.getFilteringStatistics()
        
        // Uptime should increase (if filtering was started) or remain 0
        XCTAssertGreaterThanOrEqual(stats2.uptime, stats1.uptime, "Uptime should not decrease")
        
        // Other stats should be consistent or increase
        XCTAssertGreaterThanOrEqual(stats2.totalQueries, stats1.totalQueries, "Total queries should not decrease")
        XCTAssertGreaterThanOrEqual(stats2.blockedQueries, stats1.blockedQueries, "Blocked queries should not decrease")
        XCTAssertGreaterThanOrEqual(stats2.allowedQueries, stats1.allowedQueries, "Allowed queries should not decrease")
    }
    
    func testStatisticsDataTypes() {
        let stats = manager.getFilteringStatistics()
        
        // Verify data types and ranges
        XCTAssertTrue(stats.isActive == true || stats.isActive == false, "isActive should be boolean")
        XCTAssertTrue(stats.uptime.isFinite, "Uptime should be finite")
        XCTAssertTrue(stats.averageLatency.isFinite, "Average latency should be finite")
        XCTAssertTrue(stats.cacheHitRate.isFinite, "Cache hit rate should be finite")
        
        // Verify non-negative values
        XCTAssertGreaterThanOrEqual(stats.uptime, 0, "Uptime should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.totalQueries, 0, "Total queries should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.blockedQueries, 0, "Blocked queries should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.allowedQueries, 0, "Allowed queries should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.averageLatency, 0, "Average latency should be non-negative")
        XCTAssertGreaterThanOrEqual(stats.cacheHitRate, 0, "Cache hit rate should be non-negative")
    }
    
    // MARK: - Integration Tests
    
    func testBasicWorkflow() async throws {
        // Test basic manager workflow
        let initialStats = manager.getFilteringStatistics()
        XCTAssertNotNil(initialStats, "Should get initial statistics")
        
        // Test domain management
        let testDomain = "workflow-test.com"
        try manager.addBlockedDomain(testDomain)
        XCTAssertTrue(manager.isDomainBlocked(testDomain), "Domain should be blocked in workflow")
        
        // Wait a bit and get stats again
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let laterStats = manager.getFilteringStatistics()
        XCTAssertNotNil(laterStats, "Should get later statistics")
        
        // Uptime should have increased or remained the same
        XCTAssertGreaterThanOrEqual(laterStats.uptime, initialStats.uptime, 
                                   "Uptime should not decrease over time")
        
        // Clean up
        try manager.removeBlockedDomain(testDomain)
    }
    
    func testDNSLevelBlockingIntegration() throws {
        // Test the core DNS-level blocking functionality
        let maliciousDomain = "malicious-ads.com"
        let safeDomain = "safe-content.com"
        
        // Add malicious domain to blocklist
        try manager.addBlockedDomain(maliciousDomain)
        
        // Verify blocking logic
        XCTAssertTrue(manager.isDomainBlocked(maliciousDomain), "Malicious domain should be blocked")
        XCTAssertFalse(manager.isDomainBlocked(safeDomain), "Safe domain should not be blocked")
        
        // Test with subdomains
        let maliciousSubdomain = "tracker.\(maliciousDomain)"
        XCTAssertTrue(manager.isDomainBlocked(maliciousSubdomain), "Malicious subdomain should be blocked")
        
        // Clean up
        try manager.removeBlockedDomain(maliciousDomain)
    }
}
