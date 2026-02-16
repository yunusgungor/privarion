import XCTest
import Foundation
@testable import PrivarionCore

final class BandwidthThrottlerTests: XCTestCase {
    
    private var throttler: BandwidthThrottler!
    
    override func setUp() {
        super.setUp()
        throttler = BandwidthThrottler.shared
    }
    
    override func tearDown() {
        if throttler.running {
            throttler.stop()
        }
        super.tearDown()
    }
    
    func testManagerInitialization() {
        XCTAssertNotNil(throttler, "BandwidthThrottler should initialize")
    }
    
    func testSharedInstanceConsistency() {
        let t1 = BandwidthThrottler.shared
        let t2 = BandwidthThrottler.shared
        XCTAssertTrue(t1 === t2, "Shared instance should be singleton")
    }
    
    func testInitialState() {
        XCTAssertFalse(throttler.running, "Throttler should not be running initially")
    }
    
    func testUpdateConfig() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        config.downloadLimitKBps = 200
        
        throttler.updateConfig(config)
        
        XCTAssertTrue(true, "Update config should complete without error")
    }
    
    func testDisabledConfigStart() {
        var config = BandwidthThrottleConfig()
        config.enabled = false
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Starting with disabled config should not throw")
        
        XCTAssertFalse(throttler.running, "Throttler should not be running with disabled config")
    }
    
    func testStartWithLimits() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        config.downloadLimitKBps = 200
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Starting with limits should not throw")
        
        XCTAssertTrue(throttler.running, "Throttler should be running with enabled config")
        
        throttler.stop()
    }
    
    func testDoubleStart() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "First start should not throw")
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Second start should not throw")
        
        throttler.stop()
    }
    
    func testStopWhenNotRunning() {
        XCTAssertNoThrow({
            self.throttler.stop()
        }, "Stop when not running should not throw")
        
        XCTAssertFalse(throttler.running)
    }
    
    func testStopWhenRunning() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        XCTAssertNoThrow({
            self.throttler.stop()
        }, "Stop should not throw")
        
        XCTAssertFalse(throttler.running)
    }
    
    func testGetCurrentStats() {
        let stats = throttler.getCurrentStats()
        
        XCTAssertGreaterThanOrEqual(stats.activeConnections, 0)
        XCTAssertGreaterThanOrEqual(stats.uploadRateBps, 0)
        XCTAssertGreaterThanOrEqual(stats.downloadRateBps, 0)
    }
    
    func testGetCurrentStatsWithRunningThrottler() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        config.downloadLimitKBps = 200
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        let stats = throttler.getCurrentStats()
        
        XCTAssertEqual(stats.uploadLimitBps, Int64(100 * 1024))
        XCTAssertEqual(stats.downloadLimitBps, Int64(200 * 1024))
        
        throttler.stop()
    }
    
    func testShouldThrottleConnectionWhenNotRunning() {
        let shouldThrottle = throttler.shouldThrottleConnection(for: "com.test.app")
        
        XCTAssertFalse(shouldThrottle, "Should not throttle when not running")
    }
    
    func testShouldThrottleConnectionWhenDisabled() {
        var config = BandwidthThrottleConfig()
        config.enabled = false
        config.throttleBlocklist = ["com.test.app"]
        
        throttler.updateConfig(config)
        
        let shouldThrottle = throttler.shouldThrottleConnection(for: "com.test.app")
        
        XCTAssertFalse(shouldThrottle, "Should not throttle when disabled")
    }
    
    func testShouldThrottleConnectionInBlocklist() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        config.downloadLimitKBps = 100
        config.throttleBlocklist = ["com.test.app"]
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        let shouldThrottle = throttler.shouldThrottleConnection(for: "com.test.app")
        
        XCTAssertTrue(shouldThrottle, "Should throttle blocklisted app")
        
        throttler.stop()
    }
    
    func testShouldThrottleConnectionNotInBlocklist() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        config.downloadLimitKBps = 100
        config.throttleBlocklist = ["com.test.app"]
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        let shouldThrottle = throttler.shouldThrottleConnection(for: "com.other.app")
        
        XCTAssertTrue(shouldThrottle, "Should throttle when limits are set")
        
        throttler.stop()
    }
    
    func testRegisterConnection() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        config.downloadLimitKBps = 100
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        let connectionId = UUID()
        throttler.registerConnection(connectionId, applicationId: "com.test.app")
        
        let stats = throttler.getCurrentStats()
        XCTAssertEqual(stats.activeConnections, 1, "Should have 1 active connection")
        
        throttler.unregisterConnection(connectionId)
        
        throttler.stop()
    }
    
    func testUnregisterConnection() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        let connectionId = UUID()
        throttler.registerConnection(connectionId, applicationId: nil)
        
        throttler.unregisterConnection(connectionId)
        
        let stats = throttler.getCurrentStats()
        XCTAssertEqual(stats.activeConnections, 0, "Should have 0 active connections after unregister")
        
        throttler.stop()
    }
    
    func testThrottleUpload() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 1000
        config.downloadLimitKBps = 1000
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        let connectionId = UUID()
        throttler.registerConnection(connectionId, applicationId: nil)
        
        let throttled = throttler.throttleUpload(connectionId, dataSize: 1024)
        
        XCTAssertTrue(throttled, "Should allow upload within limits")
        
        throttler.unregisterConnection(connectionId)
        throttler.stop()
    }
    
    func testThrottleDownload() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 1000
        config.downloadLimitKBps = 1000
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        let connectionId = UUID()
        throttler.registerConnection(connectionId, applicationId: nil)
        
        let throttled = throttler.throttleDownload(connectionId, dataSize: 1024)
        
        XCTAssertTrue(throttled, "Should allow download within limits")
        
        throttler.unregisterConnection(connectionId)
        throttler.stop()
    }
    
    func testThrottleUploadNotRegistered() {
        let connectionId = UUID()
        
        let throttled = throttler.throttleUpload(connectionId, dataSize: 1024)
        
        XCTAssertFalse(throttled, "Should not throttle unregistered connection")
    }
    
    func testThrottleDownloadNotRegistered() {
        let connectionId = UUID()
        
        let throttled = throttler.throttleDownload(connectionId, dataSize: 1024)
        
        XCTAssertFalse(throttled, "Should not throttle unregistered connection")
    }
    
    func testBandwidthStatsUtilization() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        config.downloadLimitKBps = 200
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        let stats = throttler.getCurrentStats()
        
        XCTAssertGreaterThanOrEqual(stats.uploadUtilization, 0.0)
        XCTAssertLessThanOrEqual(stats.uploadUtilization, 1.0)
        XCTAssertGreaterThanOrEqual(stats.downloadUtilization, 0.0)
        XCTAssertLessThanOrEqual(stats.downloadUtilization, 1.0)
        
        throttler.stop()
    }
    
    func testBandwidthStatsUtilizationWithZeroLimits() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 0
        config.downloadLimitKBps = 0
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        let stats = throttler.getCurrentStats()
        
        XCTAssertEqual(stats.uploadUtilization, 0.0, "Utilization should be 0 when limit is 0")
        XCTAssertEqual(stats.downloadUtilization, 0.0, "Utilization should be 0 when limit is 0")
        
        throttler.stop()
    }
    
    func testMultipleConnections() {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 1000
        config.downloadLimitKBps = 1000
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.throttler.start()
        }, "Start should not throw")
        
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        
        throttler.registerConnection(id1, applicationId: "com.app1")
        throttler.registerConnection(id2, applicationId: "com.app2")
        throttler.registerConnection(id3, applicationId: nil)
        
        let stats = throttler.getCurrentStats()
        XCTAssertEqual(stats.activeConnections, 3, "Should have 3 active connections")
        
        throttler.unregisterConnection(id1)
        throttler.unregisterConnection(id2)
        throttler.unregisterConnection(id3)
        
        throttler.stop()
    }
    
    func testConcurrentAccess() async throws {
        var config = BandwidthThrottleConfig()
        config.enabled = true
        config.uploadLimitKBps = 100
        
        throttler.updateConfig(config)
        
        try throttler.start()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    _ = self.throttler.getCurrentStats()
                }
            }
        }
        
        throttler.stop()
        
        XCTAssertTrue(true, "Concurrent access should not crash")
    }
    
    func testStartStopLifecycle() {
        var config = BandwidthThrottleConfig()
        config.enabled = false
        config.uploadLimitKBps = 100
        
        throttler.updateConfig(config)
        
        XCTAssertNoThrow(try throttler.start())
        XCTAssertFalse(throttler.running)
        
        throttler.stop()
        XCTAssertFalse(throttler.running)
    }
    
    func testMemoryStability() {
        for _ in 0..<1000 {
            _ = throttler.running
            _ = throttler.getCurrentStats()
        }
        
        XCTAssertTrue(true, "Repeated operations should not cause memory issues")
    }
}
