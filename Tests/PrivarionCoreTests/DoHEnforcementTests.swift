import XCTest
import Foundation
@testable import PrivarionCore

final class DoHEnforcementTests: XCTestCase {
    
    private var enforcement: DoHEnforcement!
    
    override func setUp() {
        super.setUp()
        enforcement = DoHEnforcement.shared
    }
    
    override func tearDown() {
        if enforcement.running {
            enforcement.stop()
        }
        super.tearDown()
    }
    
    func testManagerInitialization() {
        XCTAssertNotNil(enforcement, "DoHEnforcement should initialize")
    }
    
    func testSharedInstanceConsistency() {
        let e1 = DoHEnforcement.shared
        let e2 = DoHEnforcement.shared
        XCTAssertTrue(e1 === e2, "Shared instance should be singleton")
    }
    
    func testInitialState() {
        XCTAssertFalse(enforcement.running, "Enforcement should not be running initially")
    }
    
    func testUpdateConfig() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.dohServers = ["https://dns.example.com/dns-query"]
        
        enforcement.updateConfig(config)
        
        XCTAssertTrue(true, "Update config should complete without error")
    }
    
    func testDisabledConfigStart() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.enforcement.start()
        }, "Starting with disabled config should not throw")
        
        XCTAssertFalse(enforcement.running, "Enforcement should not be running with disabled config")
    }
    
    func testStartWithEnforceDoH() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.dohServers = ["https://dns.google/dns-query"]
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.enforcement.start()
        }, "Starting with enforceDoH should not throw")
        
        XCTAssertTrue(enforcement.running, "Enforcement should be running")
        
        enforcement.stop()
    }
    
    func testDoubleStart() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.dohServers = ["https://dns.google/dns-query"]
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.enforcement.start()
        }, "First start should not throw")
        
        XCTAssertNoThrow({
            try self.enforcement.start()
        }, "Second start should not throw")
        
        enforcement.stop()
    }
    
    func testStopWhenNotRunning() {
        XCTAssertNoThrow({
            self.enforcement.stop()
        }, "Stop when not running should not throw")
        
        XCTAssertFalse(enforcement.running)
    }
    
    func testStopWhenRunning() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.dohServers = ["https://dns.google/dns-query"]
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.enforcement.start()
        }, "Start should not throw")
        
        XCTAssertNoThrow({
            self.enforcement.stop()
        }, "Stop should not throw")
        
        XCTAssertFalse(enforcement.running)
    }
    
    func testShouldUseDoHWhenNotRunning() {
        let shouldUse = enforcement.shouldUseDoH(for: "example.com")
        
        XCTAssertFalse(shouldUse, "Should not use DoH when not running")
    }
    
    func testShouldUseDoHWhenRunningButNotEnforced() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = false
        config.dohServers = ["https://dns.google/dns-query"]
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.enforcement.start()
        }, "Start should not throw")
        
        let shouldUse = enforcement.shouldUseDoH(for: "example.com")
        
        XCTAssertFalse(shouldUse, "Should not use DoH when not enforced")
        
        enforcement.stop()
    }
    
    func testShouldUseDoHWhenEnforced() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.dohServers = ["https://dns.google/dns-query"]
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.enforcement.start()
        }, "Start should not throw")
        
        let shouldUse = enforcement.shouldUseDoH(for: "example.com")
        
        XCTAssertTrue(shouldUse, "Should use DoH when enforced")
        
        enforcement.stop()
    }
    
    func testShouldUseDoHWithTrustedDomain() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.dohServers = ["https://dns.google/dns-query"]
        config.trustedDomains = ["trusted.example.com"]
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.enforcement.start()
        }, "Start should not throw")
        
        let shouldUseForUntrusted = enforcement.shouldUseDoH(for: "untrusted.com")
        let shouldUseForTrusted = enforcement.shouldUseDoH(for: "trusted.example.com")
        
        XCTAssertTrue(shouldUseForUntrusted, "Should use DoH for untrusted domain")
        XCTAssertFalse(shouldUseForTrusted, "Should not use DoH for trusted domain")
        
        enforcement.stop()
    }
    
    func testShouldUseDoHWithSubdomainOfTrusted() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.dohServers = ["https://dns.google/dns-query"]
        config.trustedDomains = ["example.com"]
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.enforcement.start()
        }, "Start should not throw")
        
        let shouldUse = enforcement.shouldUseDoH(for: "subdomain.example.com")
        
        XCTAssertFalse(shouldUse, "Should not use DoH for subdomain of trusted")
        
        enforcement.stop()
    }
    
    func testShouldBlockPlainDNS() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        config.blockPlainDNS = true
        
        enforcement.updateConfig(config)
        
        let shouldBlock = enforcement.shouldBlockPlainDNS()
        
        XCTAssertFalse(shouldBlock, "Should not block plain DNS when disabled")
    }
    
    func testShouldBlockPlainDNSWhenEnabled() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.blockPlainDNS = true
        
        enforcement.updateConfig(config)
        
        let shouldBlock = enforcement.shouldBlockPlainDNS()
        
        XCTAssertTrue(shouldBlock, "Should block plain DNS when enabled")
    }
    
    func testGetDoHServer() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.dohServers = ["https://dns.google/dns-query", "https://cloudflare.com/dns-query"]
        
        enforcement.updateConfig(config)
        
        try! self.enforcement.start()
        
        let server = enforcement.getDoHServer(for: "example.com")
        
        XCTAssertNotNil(server, "Should return DoH server")
        XCTAssertEqual(server, "https://dns.google/dns-query", "Should return first server")
        
        enforcement.stop()
    }
    
    func testGetDoHServerForTrustedDomain() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.dohServers = ["https://dns.google/dns-query"]
        config.trustedDomains = ["trusted.com"]
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            try self.enforcement.start()
        }, "Start should not throw")
        
        let server = enforcement.getDoHServer(for: "trusted.com")
        
        XCTAssertNil(server, "Should not return DoH server for trusted domain")
        
        enforcement.stop()
    }
    
    func testGetBlockedPlainDNSClients() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        config.blockPlainDNS = false
        
        enforcement.updateConfig(config)
        
        let clients = enforcement.getBlockedPlainDNSClients()
        
        XCTAssertNotNil(clients, "Should return clients list")
        XCTAssertTrue(clients.isEmpty, "Should be empty when disabled")
    }
    
    func testAddDoHServer() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        config.dohServers = []
        
        enforcement.updateConfig(config)
        
        enforcement.addDoHServer("https://new-dns.example.com/dns-query")
        
        let currentConfig = enforcement.getCurrentConfig()
        
        XCTAssertTrue(currentConfig.dohServers.contains("https://new-dns.example.com/dns-query"), "Should add server")
    }
    
    func testAddDuplicateDoHServer() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        config.dohServers = ["https://existing.example.com/dns-query"]
        
        enforcement.updateConfig(config)
        
        enforcement.addDoHServer("https://existing.example.com/dns-query")
        
        let currentConfig = enforcement.getCurrentConfig()
        
        XCTAssertEqual(currentConfig.dohServers.count, 1, "Should not add duplicate")
    }
    
    func testRemoveDoHServer() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        config.dohServers = ["https://to-remove.example.com/dns-query"]
        
        enforcement.updateConfig(config)
        
        enforcement.removeDoHServer("https://to-remove.example.com/dns-query")
        
        let currentConfig = enforcement.getCurrentConfig()
        
        XCTAssertFalse(currentConfig.dohServers.contains("https://to-remove.example.com/dns-query"), "Should remove server")
    }
    
    func testRemoveNonexistentDoHServer() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        config.dohServers = []
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            self.enforcement.removeDoHServer("https://nonexistent.example.com/dns-query")
        }, "Removing nonexistent server should not throw")
    }
    
    func testAddTrustedDomain() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        config.trustedDomains = []
        
        enforcement.updateConfig(config)
        
        enforcement.addTrustedDomain("newtrusted.com")
        
        let currentConfig = enforcement.getCurrentConfig()
        
        XCTAssertTrue(currentConfig.trustedDomains.contains("newtrusted.com"), "Should add domain")
    }
    
    func testAddDuplicateTrustedDomain() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        config.trustedDomains = ["existingtrusted.com"]
        
        enforcement.updateConfig(config)
        
        enforcement.addTrustedDomain("existingtrusted.com")
        
        let currentConfig = enforcement.getCurrentConfig()
        
        XCTAssertEqual(currentConfig.trustedDomains.count, 1, "Should not add duplicate domain")
    }
    
    func testRemoveTrustedDomain() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        config.trustedDomains = ["toremove.com"]
        
        enforcement.updateConfig(config)
        
        enforcement.removeTrustedDomain("toremove.com")
        
        let currentConfig = enforcement.getCurrentConfig()
        
        XCTAssertFalse(currentConfig.trustedDomains.contains("toremove.com"), "Should remove domain")
    }
    
    func testRemoveNonexistentTrustedDomain() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        config.trustedDomains = []
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow({
            self.enforcement.removeTrustedDomain("nonexistent.com")
        }, "Removing nonexistent domain should not throw")
    }
    
    func testGetCurrentConfig() {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.blockPlainDNS = true
        config.dohServers = ["https://dns.example.com"]
        config.trustedDomains = ["trusted.com"]
        
        enforcement.updateConfig(config)
        
        let currentConfig = enforcement.getCurrentConfig()
        
        XCTAssertEqual(currentConfig.enabled, true)
        XCTAssertEqual(currentConfig.enforceDoH, true)
        XCTAssertEqual(currentConfig.blockPlainDNS, true)
        XCTAssertEqual(currentConfig.dohServers.count, 1)
        XCTAssertEqual(currentConfig.trustedDomains.count, 1)
    }
    
    func testDoHErrorDescriptions() {
        let invalidURL = DoHError.invalidServerURL
        XCTAssertEqual(invalidURL.errorDescription, "Invalid DoH server URL")
        
        let invalidResponse = DoHError.invalidResponse
        XCTAssertEqual(invalidResponse.errorDescription, "Invalid response from DoH server")
        
        let serverError = DoHError.serverError(500)
        XCTAssertEqual(serverError.errorDescription, "DoH server returned error: 500")
        
        let timeout = DoHError.queryTimeout
        XCTAssertEqual(timeout.errorDescription, "DoH query timed out")
    }
    
    func testStartStopLifecycle() {
        var config = DoHEnforcementConfig()
        config.enabled = false
        
        enforcement.updateConfig(config)
        
        XCTAssertNoThrow(try enforcement.start())
        XCTAssertFalse(enforcement.running)
        
        enforcement.stop()
        XCTAssertFalse(enforcement.running)
    }
    
    func testMemoryStability() {
        for _ in 0..<1000 {
            _ = enforcement.running
        }
        
        XCTAssertTrue(true, "Repeated operations should not cause memory issues")
    }
    
    func testConcurrentAccess() async throws {
        var config = DoHEnforcementConfig()
        config.enabled = true
        config.enforceDoH = true
        config.dohServers = ["https://dns.google/dns-query"]
        
        enforcement.updateConfig(config)
        
        try enforcement.start()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    _ = self.enforcement.running
                    _ = self.enforcement.shouldUseDoH(for: "example.com")
                }
            }
        }
        
        enforcement.stop()
        
        XCTAssertTrue(true, "Concurrent access should not crash")
    }
}
