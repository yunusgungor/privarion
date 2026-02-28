import XCTest
@testable import PrivarionCore

/// Unit tests for BlocklistManager
final class BlocklistManagerTests: XCTestCase {
    
    var tempDirectory: URL!
    var configManager: SystemExtensionConfigurationManager!
    var blocklistManager: BlocklistManager!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for test configuration
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        
        // Create test configuration manager
        let configPath = tempDirectory.appendingPathComponent("config.json")
        configManager = SystemExtensionConfigurationManager.createTestInstance(configPath: configPath)
        
        // Create default configuration
        let defaultConfig = SystemExtensionConfiguration.defaultConfiguration()
        try? configManager.saveConfiguration(defaultConfig)
        
        // Create blocklist manager
        blocklistManager = BlocklistManager()
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        blocklistManager = nil
        configManager = nil
        tempDirectory = nil
        
        super.tearDown()
    }
    
    // MARK: - Basic Blocking Tests
    
    func testShouldBlockTrackingDomain() {
        // Test that built-in tracking domains are blocked
        XCTAssertTrue(blocklistManager.shouldBlockDomain("google-analytics.com"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("doubleclick.net"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("facebook.com"))
    }
    
    func testShouldAllowNonBlockedDomain() {
        // Test that non-blocked domains are allowed
        XCTAssertFalse(blocklistManager.shouldBlockDomain("apple.com"))
        XCTAssertFalse(blocklistManager.shouldBlockDomain("github.com"))
        XCTAssertFalse(blocklistManager.shouldBlockDomain("example.com"))
    }
    
    func testShouldBlockSubdomain() {
        // Test that subdomains of blocked domains are also blocked
        XCTAssertTrue(blocklistManager.shouldBlockDomain("www.google-analytics.com"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("api.facebook.com"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("sub.doubleclick.net"))
    }
    
    // MARK: - Wildcard Pattern Tests
    
    func testWildcardPatternMatching() {
        // Add wildcard patterns
        blocklistManager.addBlockedDomain("*.analytics.*", category: .tracking)
        blocklistManager.addBlockedDomain("*.telemetry.*", category: .tracking)
        blocklistManager.addBlockedDomain("*.tracking.*", category: .tracking)
        
        // Wait for async operations to complete
        Thread.sleep(forTimeInterval: 0.2)
        
        // Test wildcard matching
        XCTAssertTrue(blocklistManager.shouldBlockDomain("my.analytics.example.com"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("app.telemetry.service.io"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("data.tracking.network.org"))
    }
    
    func testWildcardPatternWithPrefix() {
        // Add pattern with wildcard prefix
        blocklistManager.addBlockedDomain("*.ads.example.com", category: .advertising)
        
        // Wait for async operations to complete
        Thread.sleep(forTimeInterval: 0.2)
        
        // Test matching
        XCTAssertTrue(blocklistManager.shouldBlockDomain("banner.ads.example.com"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("video.ads.example.com"))
        
        // Test non-matching
        XCTAssertFalse(blocklistManager.shouldBlockDomain("ads.example.com"))
        XCTAssertFalse(blocklistManager.shouldBlockDomain("example.com"))
    }
    
    func testWildcardPatternWithSuffix() {
        // Add pattern with wildcard suffix
        blocklistManager.addBlockedDomain("tracker.*", category: .tracking)
        
        // Wait for async operations to complete
        Thread.sleep(forTimeInterval: 0.2)
        
        // Test matching
        XCTAssertTrue(blocklistManager.shouldBlockDomain("tracker.com"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("tracker.net"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("tracker.example.org"))
    }
    
    // MARK: - Add/Remove Tests
    
    func testAddBlockedDomain() {
        // Add a custom blocked domain
        let testDomain = "test-tracking.com"
        XCTAssertFalse(blocklistManager.shouldBlockDomain(testDomain))
        
        blocklistManager.addBlockedDomain(testDomain, category: .tracking)
        
        // Wait for async operation
        Thread.sleep(forTimeInterval: 0.1)
        
        XCTAssertTrue(blocklistManager.shouldBlockDomain(testDomain))
    }
    
    func testRemoveBlockedDomain() {
        // Add and then remove a domain
        let testDomain = "test-ads.com"
        blocklistManager.addBlockedDomain(testDomain, category: .advertising)
        
        // Wait for async operation
        Thread.sleep(forTimeInterval: 0.1)
        
        XCTAssertTrue(blocklistManager.shouldBlockDomain(testDomain))
        
        blocklistManager.removeBlockedDomain(testDomain, category: .advertising)
        
        // Wait for async operation
        Thread.sleep(forTimeInterval: 0.1)
        
        XCTAssertFalse(blocklistManager.shouldBlockDomain(testDomain))
    }
    
    func testAddBlockedIP() {
        // Test IP blocking
        let testIP = "192.168.1.100"
        XCTAssertFalse(blocklistManager.shouldBlockIP(testIP))
        
        blocklistManager.addBlockedIP(testIP)
        
        // Wait for async operation
        Thread.sleep(forTimeInterval: 0.1)
        
        XCTAssertTrue(blocklistManager.shouldBlockIP(testIP))
    }
    
    // MARK: - Whitelist Tests
    
    func testWhitelistedDomain() {
        // Add a domain to blocklist
        let testDomain = "example.com"
        blocklistManager.addBlockedDomain(testDomain, category: .tracking)
        
        // Wait for async operation
        Thread.sleep(forTimeInterval: 0.1)
        
        XCTAssertTrue(blocklistManager.shouldBlockDomain(testDomain))
        
        // Add to whitelist
        blocklistManager.addWhitelistedDomain(testDomain)
        
        // Wait for async operation
        Thread.sleep(forTimeInterval: 0.1)
        
        // Should not be blocked due to whitelist
        XCTAssertFalse(blocklistManager.shouldBlockDomain(testDomain))
    }
    
    // MARK: - Statistics Tests
    
    func testStatistics() {
        // Reset statistics
        blocklistManager.resetStatistics()
        
        // Perform some queries
        _ = blocklistManager.shouldBlockDomain("google-analytics.com")  // blocked
        _ = blocklistManager.shouldBlockDomain("apple.com")             // allowed
        _ = blocklistManager.shouldBlockDomain("doubleclick.net")       // blocked
        
        let stats = blocklistManager.getStatistics()
        
        XCTAssertGreaterThan(stats.totalBlocks, 0)
        XCTAssertGreaterThan(stats.allowedQueries, 0)
        XCTAssertGreaterThan(stats.totalQueries, 0)
    }
    
    // MARK: - Configuration Persistence Tests
    
    func testPersistenceToConfiguration() {
        // This test verifies that blocklist changes are persisted
        // Note: The actual persistence happens asynchronously
        
        let testDomain = "persistent-tracker.com"
        blocklistManager.addBlockedDomain(testDomain, category: .tracking)
        
        // Wait for async persistence
        Thread.sleep(forTimeInterval: 0.5)
        
        // Verify domain is blocked
        XCTAssertTrue(blocklistManager.shouldBlockDomain(testDomain))
        
        // Note: Full persistence testing would require reloading configuration
        // which is tested in SystemExtensionConfigurationManagerTests
    }
    
    // MARK: - Category Tests
    
    func testCategoryBlocking() {
        // Test different categories
        blocklistManager.addBlockedDomain("ad-server.com", category: .advertising)
        blocklistManager.addBlockedDomain("tracker.com", category: .tracking)
        blocklistManager.addBlockedDomain("malware.com", category: .malware)
        
        // Wait for async operation
        Thread.sleep(forTimeInterval: 0.1)
        
        XCTAssertTrue(blocklistManager.shouldBlockDomain("ad-server.com"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("tracker.com"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("malware.com"))
        
        // Check statistics by category
        let stats = blocklistManager.getStatistics()
        XCTAssertGreaterThan(stats.categoryBlocks.count, 0)
    }
    
    // MARK: - Domain Normalization Tests
    
    func testDomainNormalization() {
        // Test that domains are normalized (lowercased, trimmed)
        blocklistManager.addBlockedDomain("  UPPERCASE-DOMAIN.COM  ", category: .tracking)
        
        // Wait for async operation
        Thread.sleep(forTimeInterval: 0.1)
        
        // Should match regardless of case or whitespace
        XCTAssertTrue(blocklistManager.shouldBlockDomain("uppercase-domain.com"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("UPPERCASE-DOMAIN.COM"))
        XCTAssertTrue(blocklistManager.shouldBlockDomain("  uppercase-domain.com  "))
    }
}
