import XCTest
import Foundation
@testable import PrivarionCore

final class CanvasFingerprintMaskingManagerTests: XCTestCase {
    
    private var manager: CanvasFingerprintMaskingManager!
    private var logger: PrivarionLogger!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        logger = PrivarionLogger.shared
        logger.updateLogLevel(.debug)
        
        manager = CanvasFingerprintMaskingManager(logger: logger)
    }
    
    override func tearDownWithError() throws {
        try manager.disableMasking()
        manager = nil
        logger = nil
        try super.tearDownWithError()
    }
    
    func testInitialization() {
        XCTAssertNotNil(manager, "CanvasFingerprintMaskingManager should initialize")
    }
    
    func testEnableMasking() throws {
        let options = CanvasFingerprintMaskingManager.MaskingOptions(
            level: .moderate,
            randomizeNoise: true,
            blockReadback: true
        )
        
        try manager.enableMasking(options: options)
        
        XCTAssertTrue(manager.isEnabled())
        XCTAssertEqual(manager.getCurrentLevel(), .moderate)
    }
    
    func testDisableMasking() throws {
        let options = CanvasFingerprintMaskingManager.MaskingOptions(
            level: .moderate,
            randomizeNoise: true,
            blockReadback: true
        )
        
        try manager.enableMasking(options: options)
        try manager.disableMasking()
        
        XCTAssertFalse(manager.isEnabled())
        XCTAssertEqual(manager.getCurrentLevel(), .off)
    }
    
    func testMaskingLevels() throws {
        let levels = CanvasFingerprintMaskingManager.MaskingLevel.allCases
        
        XCTAssertEqual(levels.count, 4)
        XCTAssertTrue(levels.contains(.off))
        XCTAssertTrue(levels.contains(.minimal))
        XCTAssertTrue(levels.contains(.moderate))
        XCTAssertTrue(levels.contains(.aggressive))
    }
    
    func testLevelNoiseFactors() {
        XCTAssertEqual(CanvasFingerprintMaskingManager.MaskingLevel.off.noiseFactor, 0.0)
        XCTAssertEqual(CanvasFingerprintMaskingManager.MaskingLevel.minimal.noiseFactor, 0.01)
        XCTAssertEqual(CanvasFingerprintMaskingManager.MaskingLevel.moderate.noiseFactor, 0.05)
        XCTAssertEqual(CanvasFingerprintMaskingManager.MaskingLevel.aggressive.noiseFactor, 0.15)
    }
    
    func testGenerateMaskingScriptOff() {
        let script = manager.generateMaskingScript()
        XCTAssertEqual(script, "")
    }
    
    func testGenerateMaskingScriptModerate() throws {
        let options = CanvasFingerprintMaskingManager.MaskingOptions(
            level: .moderate,
            randomizeNoise: true,
            blockReadback: true
        )
        
        try manager.enableMasking(options: options)
        
        let script = manager.generateMaskingScript()
        
        XCTAssertFalse(script.isEmpty)
        XCTAssertTrue(script.contains("getImageData"))
        XCTAssertTrue(script.contains("toDataURL"))
        XCTAssertTrue(script.contains("toBlob"))
    }
    
    func testGenerateMaskingScriptMinimal() throws {
        let options = CanvasFingerprintMaskingManager.MaskingOptions(
            level: .minimal,
            randomizeNoise: true,
            blockReadback: true
        )
        
        try manager.enableMasking(options: options)
        
        let script = manager.generateMaskingScript()
        
        XCTAssertFalse(script.isEmpty)
        XCTAssertTrue(script.contains("NOISE_FACTOR"))
        XCTAssertTrue(script.contains("0.01"))
    }
    
    func testGenerateMaskingScriptAggressive() throws {
        let options = CanvasFingerprintMaskingManager.MaskingOptions(
            level: .aggressive,
            randomizeNoise: true,
            blockReadback: true
        )
        
        try manager.enableMasking(options: options)
        
        let script = manager.generateMaskingScript()
        
        XCTAssertFalse(script.isEmpty)
        XCTAssertTrue(script.contains("0.15"))
    }
    
    func testMaskingNotEnabledThrowsOnDisable() {
        XCTAssertFalse(manager.isEnabled())
        
        XCTAssertNoThrow(try manager.disableMasking())
    }
    
    func testLevelDisplayNames() {
        XCTAssertEqual(CanvasFingerprintMaskingManager.MaskingLevel.off.displayName, "Off")
        XCTAssertEqual(CanvasFingerprintMaskingManager.MaskingLevel.minimal.displayName, "Minimal")
        XCTAssertEqual(CanvasFingerprintMaskingManager.MaskingLevel.moderate.displayName, "Moderate")
        XCTAssertEqual(CanvasFingerprintMaskingManager.MaskingLevel.aggressive.displayName, "Aggressive")
    }
}
