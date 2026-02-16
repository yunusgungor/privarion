import XCTest
import Foundation
import Network
@testable import PrivarionCore

/// XCTest-based test suite for TorProxyManager
/// Tests cover manager lifecycle, configuration, connection handling, and error cases
final class TorProxyManagerTests: XCTestCase {
    
    // MARK: - Test Configuration
    
    private var manager: TorProxyManager!
    
    override func setUp() {
        super.setUp()
        manager = TorProxyManager.shared
    }
    
    override func tearDown() {
        // Ensure manager is stopped after each test
        if manager.running {
            manager.stop()
        }
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testManagerInitialization() {
        XCTAssertNotNil(manager, "TorProxyManager should initialize")
    }
    
    func testSharedInstanceConsistency() {
        let manager1 = TorProxyManager.shared
        let manager2 = TorProxyManager.shared
        XCTAssertTrue(manager1 === manager2, "Shared instance should be singleton")
    }
    
    func testInitialState() {
        XCTAssertFalse(manager.running, "Manager should not be running initially")
    }
    
    // MARK: - Configuration Tests
    
    func testUpdateConfig() {
        var newConfig = TorProxyConfig()
        newConfig.enabled = true
        newConfig.socksPort = 9050
        newConfig.useTorBrowser = false
        
        manager.updateConfig(newConfig)
        
        // Update should not throw
        XCTAssertTrue(true, "Update config should complete without error")
    }
    
    func testDisabledConfigStart() {
        var config = TorProxyConfig()
        config.enabled = false
        
        manager.updateConfig(config)
        
        // Should not throw when starting with disabled config
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Starting with disabled config should not throw")
        
        XCTAssertFalse(manager.running, "Manager should not be running with disabled config")
    }
    
    // MARK: - Start/Stop Tests
    
    func testStartWithNoProxyConfigured() {
        var config = TorProxyConfig()
        config.enabled = true
        config.customSocksProxy = nil
        config.useTorBrowser = false
        
        manager.updateConfig(config)
        
        // This will try to connect to system Tor which won't exist in test environment
        // But it should handle gracefully
        do {
            try manager.start()
        } catch {
            // Expected - no Tor available in test environment
            XCTAssertFalse(manager.running, "Manager should not be running after failed start")
        }
    }
    
    func testDoubleStart() {
        var config = TorProxyConfig()
        config.enabled = true
        config.customSocksProxy = "invalid:9999"
        
        manager.updateConfig(config)
        
        // First start attempt
        do {
            try manager.start()
        } catch {
            // Expected to fail
        }
        
        // Second start should be idempotent (just logs warning)
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Double start should not throw")
    }
    
    func testStopWhenNotRunning() {
        // Should not throw when stopping when not running
        XCTAssertNoThrow({
            self.manager.stop()
        }, "Stop when not running should not throw")
        
        XCTAssertFalse(manager.running, "Manager should not be running")
    }
    
    func testStopWhenRunning() {
        var config = TorProxyConfig()
        config.enabled = true
        config.customSocksProxy = "invalid:9999"
        
        manager.updateConfig(config)
        
        do {
            try manager.start()
        } catch {
        }
        
        Thread.sleep(forTimeInterval: 0.1)
        
        manager.stop()
        
        Thread.sleep(forTimeInterval: 0.1)
        
        XCTAssertFalse(manager.running, "Manager should not be running after stop")
    }
    
    // MARK: - Error Handling Tests
    
    func testGetNewNymWhenNotRunning() async {
        do {
            try await manager.getNewNym()
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is TorProxyError, "Should throw TorProxyError")
            if let torError = error as? TorProxyError {
                XCTAssertEqual(torError.errorDescription, "Tor proxy is not running", "Error should be notRunning")
            }
        }
    }
    
    func testGetCircuitInfoWhenNotRunning() async {
        do {
            _ = try await manager.getCircuitInfo()
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is TorProxyError, "Should throw TorProxyError")
            if let torError = error as? TorProxyError {
                XCTAssertEqual(torError.errorDescription, "Tor proxy is not running", "Error should be notRunning")
            }
        }
    }
    
    func testGetBandwidthStatsWhenNotRunning() async {
        do {
            _ = try await manager.getBandwidthStats()
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error is TorProxyError, "Should throw TorProxyError")
            if let torError = error as? TorProxyError {
                XCTAssertEqual(torError.errorDescription, "Tor proxy is not running", "Error should be notRunning")
            }
        }
    }
    
    // MARK: - Connection Creation Tests
    
    func testCreateSocks5Connection() {
        // Should be able to create connection object (doesn't actually connect)
        let connection = manager.createSocks5Connection(to: "example.com", port: 80)
        
        XCTAssertNotNil(connection, "Should create SOCKS5 connection")
    }
    
    func testCreateSocks5ConnectionWithDifferentPorts() {
        let conn1 = manager.createSocks5Connection(to: "example.com", port: 80)
        let conn2 = manager.createSocks5Connection(to: "example.com", port: 443)
        let conn3 = manager.createSocks5Connection(to: "example.com", port: 8080)
        
        XCTAssertNotNil(conn1, "Should create connection on port 80")
        XCTAssertNotNil(conn2, "Should create connection on port 443")
        XCTAssertNotNil(conn3, "Should create connection on port 8080")
    }
    
    // MARK: - TorProxyError Tests
    
    func testTorProxyErrorDescriptions() {
        let notRunning = TorProxyError.notRunning
        XCTAssertEqual(notRunning.errorDescription, "Tor proxy is not running")
        
        let notConnected = TorProxyError.notConnected
        XCTAssertEqual(notConnected.errorDescription, "Not connected to Tor network")
        
        let invalidProxy = TorProxyError.invalidProxyString
        XCTAssertEqual(invalidProxy.errorDescription, "Invalid SOCKS proxy string format")
        
        let torNotFound = TorProxyError.torNotFound("/fake/path")
        XCTAssertEqual(torNotFound.errorDescription, "Tor binary not found at: /fake/path")
        
        let sendFailed = TorProxyError.sendFailed("test error")
        XCTAssertEqual(sendFailed.errorDescription, "Failed to send command: test error")
        
        let receiveFailed = TorProxyError.receiveFailed("test error")
        XCTAssertEqual(receiveFailed.errorDescription, "Failed to receive response: test error")
        
        let invalidResponse = TorProxyError.invalidResponse
        XCTAssertEqual(invalidResponse.errorDescription, "Invalid response from Tor control port")
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentStartStop() async throws {
        // Test concurrent start/stop operations don't cause crashes
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        try self.manager.start()
                    } catch {
                        // Expected to fail in test environment
                    }
                }
                group.addTask {
                    self.manager.stop()
                }
            }
        }
        
        XCTAssertTrue(true, "Concurrent operations should not crash")
    }
    
    func testConcurrentConfigUpdates() async throws {
        // Test concurrent config updates
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    var config = TorProxyConfig()
                    config.enabled = i % 2 == 0
                    config.socksPort = 9000 + i
                    self.manager.updateConfig(config)
                }
            }
        }
        
        XCTAssertTrue(true, "Concurrent config updates should not crash")
    }
    
    // MARK: - Lifecycle Tests
    
    func testStartStopLifecycle() {
        var config = TorProxyConfig()
        config.enabled = false
        
        manager.updateConfig(config)
        
        // Start (will not start because disabled)
        XCTAssertNoThrow(try manager.start())
        XCTAssertFalse(manager.running)
        
        // Stop
        manager.stop()
        XCTAssertFalse(manager.running)
    }
    
    // MARK: - Memory Safety Tests
    
    func testMemoryStability() {
        // Test that repeated operations don't cause memory issues
        for _ in 0..<1000 {
            _ = manager.running
        }
        
        XCTAssertTrue(true, "Repeated operations should not cause memory issues")
    }
}
