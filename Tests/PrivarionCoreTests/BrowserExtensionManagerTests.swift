import XCTest
import Foundation
@testable import PrivarionCore

final class BrowserExtensionManagerTests: XCTestCase {
    
    private var manager: BrowserExtensionManager!
    private var userAgentManager: UserAgentSpoofingManager!
    private var canvasManager: CanvasFingerprintMaskingManager!
    private var logger: PrivarionLogger!
    private var testExportDirectory: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        logger = PrivarionLogger.shared
        logger.updateLogLevel(.debug)
        
        userAgentManager = UserAgentSpoofingManager(logger: logger)
        canvasManager = CanvasFingerprintMaskingManager(logger: logger)
        
        testExportDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PrivarionExtensionTests")
        
        manager = BrowserExtensionManager(
            userAgentManager: userAgentManager,
            canvasManager: canvasManager,
            logger: logger,
            exportDirectory: testExportDirectory
        )
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: testExportDirectory)
        manager = nil
        userAgentManager = nil
        canvasManager = nil
        logger = nil
        testExportDirectory = nil
        try super.tearDownWithError()
    }
    
    func testInitialization() {
        XCTAssertNotNil(manager, "BrowserExtensionManager should initialize")
    }
    
    func testGetExtensionStatus() {
        let status = manager.getExtensionStatus()
        
        XCTAssertEqual(status.count, 4)
        XCTAssertNotNil(status[.chrome])
        XCTAssertNotNil(status[.firefox])
        XCTAssertNotNil(status[.safari])
        XCTAssertNotNil(status[.edge])
    }
    
    func testGenerateExtensionChrome() throws {
        try userAgentManager.enableSpoofing(options: .init(profile: .chromeMac, randomize: false))
        try canvasManager.enableMasking(options: .init(level: .moderate))
        
        let extensionURL = try manager.generateExtension(for: .chrome)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extensionURL.path))
        
        let manifestPath = extensionURL.appendingPathComponent("manifest.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestPath.path))
        
        let contentScriptPath = extensionURL.appendingPathComponent("content.js")
        XCTAssertTrue(FileManager.default.fileExists(atPath: contentScriptPath.path))
        
        let backgroundScriptPath = extensionURL.appendingPathComponent("background.js")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backgroundScriptPath.path))
    }
    
    func testGenerateExtensionFirefox() throws {
        try userAgentManager.enableSpoofing(options: .init(profile: .firefoxMac, randomize: false))
        try canvasManager.enableMasking(options: .init(level: .minimal))
        
        let extensionURL = try manager.generateExtension(for: .firefox)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extensionURL.path))
        
        let manifestPath = extensionURL.appendingPathComponent("manifest.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestPath.path))
    }
    
    func testGenerateExtensionSafari() throws {
        try userAgentManager.enableSpoofing(options: .init(profile: .safariMac, randomize: false))
        try canvasManager.enableMasking(options: .init(level: .moderate))
        
        let extensionURL = try manager.generateExtension(for: .safari)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extensionURL.path))
        
        let infoPlistPath = extensionURL.appendingPathComponent("Info.plist")
        XCTAssertTrue(FileManager.default.fileExists(atPath: infoPlistPath.path))
    }
    
    func testGenerateExtensionEdge() throws {
        try userAgentManager.enableSpoofing(options: .init(profile: .edgeWindows, randomize: false))
        
        let extensionURL = try manager.generateExtension(for: .edge)
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: extensionURL.path))
        
        let manifestPath = extensionURL.appendingPathComponent("manifest.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifestPath.path))
    }
    
    func testManifestContent() throws {
        try userAgentManager.enableSpoofing(options: .init(profile: .chromeMac, randomize: false))
        try canvasManager.enableMasking(options: .init(level: .moderate))
        
        let extensionURL = try manager.generateExtension(for: .chrome)
        let manifestPath = extensionURL.appendingPathComponent("manifest.json")
        
        let data = try Data(contentsOf: manifestPath)
        let manifest = try JSONDecoder().decode(BrowserExtensionManager.ExtensionManifest.self, from: data)
        
        XCTAssertEqual(manifest.manifestVersion, 3)
        XCTAssertEqual(manifest.name, "Privarion Browser Protection")
        XCTAssertEqual(manifest.version, "1.0.0")
        XCTAssertFalse(manifest.permissions.isEmpty)
    }
    
    func testContentScriptContainsSpoofing() throws {
        try userAgentManager.enableSpoofing(options: .init(profile: .chromeMac, randomize: false))
        try canvasManager.enableMasking(options: .init(level: .moderate))
        
        let extensionURL = try manager.generateExtension(for: .chrome)
        let contentScriptPath = extensionURL.appendingPathComponent("content.js")
        
        let content = try String(contentsOf: contentScriptPath, encoding: .utf8)
        
        XCTAssertTrue(content.contains("navigator"))
        XCTAssertTrue(content.contains("userAgent"))
        XCTAssertTrue(content.contains("getImageData"))
    }
    
    func testBrowserDisplayNames() {
        XCTAssertEqual(BrowserExtensionManager.Browser.chrome.displayName, "Google Chrome")
        XCTAssertEqual(BrowserExtensionManager.Browser.firefox.displayName, "Mozilla Firefox")
        XCTAssertEqual(BrowserExtensionManager.Browser.safari.displayName, "Safari")
        XCTAssertEqual(BrowserExtensionManager.Browser.edge.displayName, "Microsoft Edge")
    }
    
    func testAllBrowsersSupported() {
        let browsers = BrowserExtensionManager.Browser.allCases
        
        XCTAssertEqual(browsers.count, 4)
        XCTAssertTrue(browsers.contains(.chrome))
        XCTAssertTrue(browsers.contains(.firefox))
        XCTAssertTrue(browsers.contains(.safari))
        XCTAssertTrue(browsers.contains(.edge))
    }
}
