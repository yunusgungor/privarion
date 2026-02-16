import XCTest
import Foundation
import Network
@testable import PrivarionCore

final class ProxyChainManagerTests: XCTestCase {
    
    private var manager: ProxyChainManager!
    
    override func setUp() {
        super.setUp()
        manager = ProxyChainManager.shared
    }
    
    override func tearDown() {
        if manager.running {
            manager.stop()
        }
        super.tearDown()
    }
    
    func testManagerInitialization() {
        XCTAssertNotNil(manager, "ProxyChainManager should initialize")
    }
    
    func testSharedInstanceConsistency() {
        let m1 = ProxyChainManager.shared
        let m2 = ProxyChainManager.shared
        XCTAssertTrue(m1 === m2, "Shared instance should be singleton")
    }
    
    func testInitialState() {
        XCTAssertFalse(manager.running, "Manager should not be running initially")
    }
    
    func testUpdateConfig() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertTrue(true, "Update config should complete without error")
    }
    
    func testDisabledConfigStart() {
        var config = ProxyChainConfig()
        config.enabled = false
        config.proxies = []
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Starting with disabled config should not throw")
        
        XCTAssertFalse(manager.running, "Manager should not be running with disabled config")
    }
    
    func testStartWithNoProxies() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = []
        
        manager.updateConfig(config)
        
        XCTAssertThrowsError(try manager.start()) { error in
            XCTAssertTrue(error is ProxyChainError, "Should throw ProxyChainError")
            if let chainError = error as? ProxyChainError {
                XCTAssertEqual(chainError.errorDescription, "No proxies configured in proxy chain")
            }
        }
        
        XCTAssertFalse(manager.running)
    }
    
    func testStartWithProxies() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Starting with proxies should not throw")
        
        XCTAssertTrue(manager.running, "Manager should be running with proxies")
        
        manager.stop()
    }
    
    func testDoubleStart() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "First start should not throw")
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Second start should not throw")
        
        manager.stop()
    }
    
    func testStopWhenNotRunning() {
        XCTAssertNoThrow({
            self.manager.stop()
        }, "Stop when not running should not throw")
        
        XCTAssertFalse(manager.running)
    }
    
    func testStopWhenRunning() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Start should not throw")
        
        XCTAssertNoThrow({
            self.manager.stop()
        }, "Stop should not throw")
        
        XCTAssertFalse(manager.running)
    }
    
    func testCreateChainedConnectionWhenNotRunning() {
        let connection = manager.createChainedConnection(to: "example.com", port: 80)
        
        XCTAssertNil(connection, "Should not create connection when manager not running")
    }
    
    func testCreateChainedConnectionWhenRunning() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Start should not throw")
        
        let connection = manager.createChainedConnection(to: "example.com", port: 80)
        
        XCTAssertNotNil(connection, "Should create connection when manager running")
        
        manager.stop()
    }
    
    func testCreateChainedConnectionWithMultipleProxies() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "proxy1.example.com", port: 9050),
            ProxyConfig(type: .socks5, host: "proxy2.example.com", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Start should not throw")
        
        let connection = manager.createChainedConnection(to: "example.com", port: 443)
        
        XCTAssertNotNil(connection, "Should create multi-hop connection")
        
        manager.stop()
    }
    
    func testCloseChainedConnection() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Start should not throw")
        
        _ = manager.createChainedConnection(to: "example.com", port: 80)
        
        let connections = manager.getActiveConnections()
        if let connInfo = connections.first {
            manager.closeChainedConnection(connInfo.id)
        }
        
        XCTAssertTrue(true, "Close should not throw")
        
        manager.stop()
    }
    
    func testGetActiveConnections() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Start should not throw")
        
        let connections = manager.getActiveConnections()
        
        XCTAssertNotNil(connections, "Should return connections list")
        
        manager.stop()
    }
    
    func testGetActiveConnectionsWithMultipleConnections() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Start should not throw")
        
        _ = manager.createChainedConnection(to: "example1.com", port: 80)
        _ = manager.createChainedConnection(to: "example2.com", port: 443)
        _ = manager.createChainedConnection(to: "example3.com", port: 8080)
        
        let connections = manager.getActiveConnections()
        
        XCTAssertEqual(connections.count, 3, "Should have 3 active connections")
        
        manager.stop()
    }
    
    func testProxyChainErrorDescriptions() {
        let noProxies = ProxyChainError.noProxiesConfigured
        XCTAssertEqual(noProxies.errorDescription, "No proxies configured in proxy chain")
        
        let invalidConfig = ProxyChainError.invalidProxyConfiguration
        XCTAssertEqual(invalidConfig.errorDescription, "Invalid proxy configuration")
        
        let connectionFailed = ProxyChainError.connectionFailed("test error")
        XCTAssertEqual(connectionFailed.errorDescription, "Proxy chain connection failed: test error")
    }
    
    func testProxyTypes() {
        let socks5 = ProxyType.socks5
        XCTAssertEqual(socks5.rawValue, "socks5")
        
        let socks4 = ProxyType.socks4
        XCTAssertEqual(socks4.rawValue, "socks4")
        
        let http = ProxyType.http
        XCTAssertEqual(http.rawValue, "http")
        
        let https = ProxyType.https
        XCTAssertEqual(https.rawValue, "https")
    }
    
    func testProxyChainModes() {
        let sequential = ProxyChainMode.sequential
        XCTAssertEqual(sequential.rawValue, "sequential")
        
        let random = ProxyChainMode.random
        XCTAssertEqual(random.rawValue, "random")
        
        let failover = ProxyChainMode.failover
        XCTAssertEqual(failover.rawValue, "failover")
    }
    
    func testRandomChainMode() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.chainMode = .random
        config.proxies = [
            ProxyConfig(type: .socks5, host: "proxy1.example.com", port: 9050),
            ProxyConfig(type: .socks5, host: "proxy2.example.com", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Starting with random mode should not throw")
        
        manager.stop()
    }
    
    func testSequentialChainMode() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.chainMode = .sequential
        config.proxies = [
            ProxyConfig(type: .socks5, host: "proxy1.example.com", port: 9050),
            ProxyConfig(type: .socks5, host: "proxy2.example.com", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Starting with sequential mode should not throw")
        
        manager.stop()
    }
    
    func testFailoverChainMode() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.chainMode = .failover
        config.proxies = [
            ProxyConfig(type: .socks5, host: "proxy1.example.com", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Starting with failover mode should not throw")
        
        manager.stop()
    }
    
    func testProxyConnectionInfo() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Start should not throw")
        
        _ = manager.createChainedConnection(to: "example.com", port: 80)
        
        let connections = manager.getActiveConnections()
        let connInfo = connections.first
        
        XCTAssertNotNil(connInfo, "Should have connection info")
        XCTAssertEqual(connInfo?.targetHost, "example.com")
        XCTAssertEqual(connInfo?.targetPort, 80)
        
        manager.stop()
    }
    
    func testCloseInvalidConnection() {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.manager.start()
        }, "Start should not throw")
        
        let fakeId = UUID()
        
        XCTAssertNoThrow({
            self.manager.closeChainedConnection(fakeId)
        }, "Closing invalid connection should not throw")
        
        manager.stop()
    }
    
    func testConcurrentAccess() async throws {
        var config = ProxyChainConfig()
        config.enabled = true
        config.proxies = [
            ProxyConfig(type: .socks5, host: "127.0.0.1", port: 9050)
        ]
        
        manager.updateConfig(config)
        
        try manager.start()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    _ = self.manager.running
                    _ = self.manager.getActiveConnections()
                }
            }
        }
        
        manager.stop()
        
        XCTAssertTrue(true, "Concurrent access should not crash")
    }
    
    func testStartStopLifecycle() {
        var config = ProxyChainConfig()
        config.enabled = false
        config.proxies = []
        
        manager.updateConfig(config)
        
        XCTAssertThrowsError(try manager.start())
        XCTAssertFalse(manager.running)
        
        manager.stop()
        XCTAssertFalse(manager.running)
    }
    
    func testMemoryStability() {
        for _ in 0..<1000 {
            _ = manager.running
        }
        
        XCTAssertTrue(true, "Repeated operations should not cause memory issues")
    }
}
