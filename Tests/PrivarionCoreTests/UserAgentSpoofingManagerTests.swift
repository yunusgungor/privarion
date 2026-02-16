import XCTest
import Foundation
@testable import PrivarionCore

final class UserAgentSpoofingManagerTests: XCTestCase {
    
    private var manager: UserAgentSpoofingManager!
    private var logger: PrivarionLogger!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        logger = PrivarionLogger.shared
        logger.updateLogLevel(.debug)
        
        manager = UserAgentSpoofingManager(logger: logger)
    }
    
    override func tearDownWithError() throws {
        try manager.disableSpoofing()
        manager = nil
        logger = nil
        try super.tearDownWithError()
    }
    
    func testInitialization() {
        XCTAssertNotNil(manager, "UserAgentSpoofingManager should initialize")
    }
    
    func testEnableSpoofingWithProfile() throws {
        let options = UserAgentSpoofingManager.SpoofingOptions(
            profile: .chromeMac,
            randomize: false,
            persistSession: false
        )
        
        try manager.enableSpoofing(options: options)
        
        let currentUA = try XCTUnwrap(manager.getCurrentUserAgent())
        XCTAssertFalse(currentUA.isEmpty)
        XCTAssertTrue(currentUA.contains("Chrome"))
        XCTAssertTrue(currentUA.contains("Mac"))
    }
    
    func testEnableSpoofingWithRandomProfile() throws {
        let options = UserAgentSpoofingManager.SpoofingOptions(
            profile: .random,
            randomize: true,
            persistSession: false
        )
        
        try manager.enableSpoofing(options: options)
        
        let currentUA = try XCTUnwrap(manager.getCurrentUserAgent())
        XCTAssertFalse(currentUA.isEmpty)
        XCTAssertTrue(manager.validateUserAgent(currentUA))
    }
    
    func testCustomUserAgent() throws {
        let customUA = "Mozilla/5.0 (Macintosh; TestBrowser/1.0) Chrome/100.0.0.0 Safari/537.36"
        
        let options = UserAgentSpoofingManager.SpoofingOptions(
            profile: .chromeMac,
            customUserAgent: customUA,
            randomize: false,
            persistSession: false
        )
        
        try manager.enableSpoofing(options: options)
        
        let currentUA = try XCTUnwrap(manager.getCurrentUserAgent())
        XCTAssertEqual(currentUA, customUA)
    }
    
    func testInvalidCustomUserAgent() {
        let invalidUA = "InvalidString"
        
        let options = UserAgentSpoofingManager.SpoofingOptions(
            profile: .chromeMac,
            customUserAgent: invalidUA,
            randomize: false,
            persistSession: false
        )
        
        XCTAssertThrowsError(try manager.enableSpoofing(options: options)) { error in
            XCTAssertTrue(error is UserAgentSpoofingManager.SpoofingError)
        }
    }
    
    func testDisableSpoofing() throws {
        let options = UserAgentSpoofingManager.SpoofingOptions(
            profile: .chromeMac,
            randomize: false,
            persistSession: false
        )
        
        try manager.enableSpoofing(options: options)
        try manager.disableSpoofing()
        
        let currentUA = manager.getCurrentUserAgent()
        XCTAssertNil(currentUA)
    }
    
    func testValidateUserAgent() {
        XCTAssertTrue(manager.validateUserAgent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"))
        XCTAssertTrue(manager.validateUserAgent("Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"))
        XCTAssertFalse(manager.validateUserAgent("InvalidUA"))
        XCTAssertFalse(manager.validateUserAgent(""))
    }
    
    func testParseUserAgent() {
        let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        
        let parsed = manager.parseUserAgent(ua)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.browser, "Chrome")
        XCTAssertTrue(parsed?.platform.contains("10") == true)
        XCTAssertEqual(parsed?.version, "120")
    }
    
    func testParseFirefoxUserAgent() {
        let ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
        
        let parsed = manager.parseUserAgent(ua)
        
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.browser, "Firefox")
        XCTAssertEqual(parsed?.platform, "Windows")
    }
    
    func testGetAvailableProfiles() {
        let profiles = manager.getAvailableProfiles()
        
        XCTAssertFalse(profiles.isEmpty)
        XCTAssertTrue(profiles.contains(.chromeMac))
        XCTAssertTrue(profiles.contains(.safariMac))
        XCTAssertTrue(profiles.contains(.random))
    }
    
    func testGenerateRandomUserAgent() throws {
        let ua = try manager.generateRandomUserAgent()
        
        XCTAssertFalse(ua.isEmpty)
        XCTAssertTrue(manager.validateUserAgent(ua))
    }
    
    func testGenerateSpoofingScript() throws {
        let options = UserAgentSpoofingManager.SpoofingOptions(
            profile: .chromeMac,
            randomize: false,
            persistSession: false
        )
        
        try manager.enableSpoofing(options: options)
        
        let script = manager.generateSpoofingScript()
        
        XCTAssertFalse(script.isEmpty)
        XCTAssertTrue(script.contains("navigator"))
        XCTAssertTrue(script.contains("userAgent"))
    }
    
    func testMultipleProfileGeneration() throws {
        var generatedUAs = Set<String>()
        
        for _ in 0..<10 {
            let ua = try manager.generateRandomUserAgent()
            generatedUAs.insert(ua)
        }
        
        XCTAssertGreaterThan(generatedUAs.count, 1, "Should generate different User-Agents")
    }
}
