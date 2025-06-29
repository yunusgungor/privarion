import Foundation
import XCTest
import Logging
@testable import PrivarionCore


final class ConfigurationManagerTests: XCTestCase {
    
    var tempDirectory: URL!
    var configManager: ConfigurationManager!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create test-specific configuration manager
        let configPath = tempDirectory.appendingPathComponent(".privarion/config.json")
        configManager = ConfigurationManager.createTestInstance(configPath: configPath)
    }
    
    override func tearDown() {
        super.tearDown()
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        configManager = nil
    }
    
    func testConfigurationManagerInitialization() {
        // ConfigurationManager should create default configuration
        let config = configManager.getCurrentConfiguration()
        
        XCTAssertEqual(config.version, "1.0.0")
        XCTAssertEqual(config.activeProfile, "default")
        
        // Check if configuration file was created
        let configPath = tempDirectory.appendingPathComponent(".privarion/config.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath.path))
    }
    
    func testProfileSwitching() throws {
        // Switch to paranoid profile
        try configManager.switchProfile(to: "paranoid")
        let config = configManager.getCurrentConfiguration()
        XCTAssertEqual(config.activeProfile, "paranoid")
        
        let activeProfile = configManager.getActiveProfile()
        XCTAssertNotNil(activeProfile)
        XCTAssertEqual(activeProfile?.name, "paranoid")
        
        // Test switching to non-existent profile
        XCTAssertThrowsError(try configManager.switchProfile(to: "nonexistent")) { error in
            if case ConfigurationError.profileNotFound(let profile) = error {
                XCTAssertEqual(profile, "nonexistent")
            } else {
                XCTFail("Expected profileNotFound error")
            }
        }
    }
    
    func testProfileCreationAndDeletion() throws {
        // Create custom profile
        let customProfile = Profile(
            name: "custom",
            description: "Custom test profile",
            modules: ModuleConfigs()
        )
        
        try configManager.createProfile(customProfile)
        let profiles = configManager.listProfiles()
        XCTAssertTrue(profiles.contains("custom"))
        
        // Delete custom profile
        try configManager.deleteProfile("custom")
        let updatedProfiles = configManager.listProfiles()
        XCTAssertFalse(updatedProfiles.contains("custom"))
        
        // Test deleting built-in profile
        XCTAssertThrowsError(try configManager.deleteProfile("default")) { error in
            if case ConfigurationError.cannotDeleteBuiltinProfile(let profile) = error {
                XCTAssertEqual(profile, "default")
            } else {
                XCTFail("Expected cannotDeleteBuiltinProfile error")
            }
        }
    }
    
    func testConfigurationValueUpdate() throws {
        // Test setting boolean value
        try configManager.setValue(false, keyPath: \.global.enabled)
        let config = configManager.getCurrentConfiguration()
        XCTAssertFalse(config.global.enabled)
        
        // Test setting enum value
        try configManager.setValue(LogLevel.debug, keyPath: \.global.logLevel)
        let updatedConfig = configManager.getCurrentConfiguration()
        XCTAssertEqual(updatedConfig.global.logLevel, LogLevel.debug)
    }
    
    func testConfigurationPersistence() throws {
        // Modify configuration
        try configManager.setValue(LogLevel.warning, keyPath: \.global.logLevel)
        try configManager.setValue(20, keyPath: \.global.maxLogSizeMB)
        
        // Create new manager instance with same path
        let configPath = tempDirectory.appendingPathComponent(".privarion/config.json")
        let newManager = ConfigurationManager.createTestInstance(configPath: configPath)
        
        // Verify configuration was persisted
        let config = newManager.getCurrentConfiguration()
        XCTAssertEqual(config.global.logLevel, LogLevel.warning)
        XCTAssertEqual(config.global.maxLogSizeMB, 20)
    }
    
    func testConfigurationValidation() throws {
        // Create invalid configuration
        var invalidConfig = PrivarionConfig()
        invalidConfig.activeProfile = "nonexistent"
        
        // Should throw validation error
        XCTAssertThrowsError(try configManager.updateConfiguration(invalidConfig)) { error in
            if case ConfigurationError.profileNotFound(let profile) = error {
                XCTAssertEqual(profile, "nonexistent")
            } else {
                XCTFail("Expected profileNotFound error")
            }
        }
    }
}

final class LoggerTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Override home directory for testing
        setenv("HOME", tempDirectory.path, 1)
    }
    
    override func tearDown() {
        super.tearDown()
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        // Reset environment
        unsetenv("HOME")
    }
    
    func testLoggerInitialization() {
        let logger = PrivarionLogger.shared
        XCTAssertNotNil(logger)
        
        // Test component logger creation
        let componentLogger = logger.logger(for: "test")
        XCTAssertEqual(componentLogger.label, "privarion.test")
    }
    
    func testLogStatistics() {
        let logger = PrivarionLogger.shared
        let stats = logger.getLogStatistics()
        
        XCTAssertGreaterThanOrEqual(stats.currentLogSize, 0)
        XCTAssertGreaterThanOrEqual(stats.totalLogFiles, 0)
    }
    
    func testLogLevelUpdate() {
        let logger = PrivarionLogger.shared
        
        // Test log level update
        logger.updateLogLevel(.debug)
        logger.updateLogLevel(.error)
        
        // Verify no crashes occur
        XCTAssertTrue(true)
    }
    
    func testLogRotation() {
        let logger = PrivarionLogger.shared
        
        // Test manual log rotation
        logger.rotateLog()
        
        // Verify no crashes occur
        XCTAssertTrue(true)
    }
}
