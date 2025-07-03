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
    
    // MARK: - Integration Tests
    
    func testBasicWorkflow() async throws {
        // Test basic manager workflow
        let initialStats = manager.getFilteringStatistics()
        XCTAssertNotNil(initialStats, "Should get initial statistics")
        
        // Wait a bit and get stats again
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let laterStats = manager.getFilteringStatistics()
        XCTAssertNotNil(laterStats, "Should get later statistics")
        
        // Uptime should have increased
        XCTAssertGreaterThanOrEqual(laterStats.uptime, initialStats.uptime, 
                                   "Uptime should increase over time")
    }
}
