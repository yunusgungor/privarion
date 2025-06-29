import Foundation
import XCTest
import Logging
@testable import PrivarionCore

final class ConfigurationTests: XCTestCase {
    
    var tempDirectory: URL!
    var configManager: ConfigurationManager!
    
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
    
    func testDefaultConfigurationCreation() {
        let config = PrivarionConfig()
        
        XCTAssertEqual(config.version, "1.0.0")
        XCTAssertEqual(config.activeProfile, "default")
        XCTAssertTrue(config.global.enabled)
        XCTAssertEqual(config.global.logLevel, .info)
        XCTAssertEqual(config.profiles.count, 3)
        XCTAssertNotNil(config.profiles["default"])
        XCTAssertNotNil(config.profiles["paranoid"])
        XCTAssertNotNil(config.profiles["balanced"])
    }
    
    func testProfileCreation() {
        // Test default profile
        let defaultProfile = Profile.defaultProfile()
        XCTAssertEqual(defaultProfile.name, "default")
        XCTAssertTrue(defaultProfile.modules.networkFilter.enabled)
        XCTAssertTrue(defaultProfile.modules.networkFilter.blockTelemetry)
        XCTAssertFalse(defaultProfile.modules.identitySpoofing.enabled)
        
        // Test paranoid profile
        let paranoidProfile = Profile.paranoidProfile()
        XCTAssertEqual(paranoidProfile.name, "paranoid")
        XCTAssertTrue(paranoidProfile.modules.identitySpoofing.enabled)
        XCTAssertTrue(paranoidProfile.modules.networkFilter.enabled)
        XCTAssertTrue(paranoidProfile.modules.sandboxManager.enabled)
        
        // Test balanced profile
        let balancedProfile = Profile.balancedProfile()
        XCTAssertEqual(balancedProfile.name, "balanced")
        XCTAssertTrue(balancedProfile.modules.identitySpoofing.enabled)
        XCTAssertTrue(balancedProfile.modules.identitySpoofing.spoofHostname)
        XCTAssertFalse(balancedProfile.modules.identitySpoofing.spoofMACAddress)
    }
    
    func testConfigurationSerialization() throws {
        let config = PrivarionConfig()
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        XCTAssertGreaterThan(data.count, 0)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(PrivarionConfig.self, from: data)
        
        XCTAssertEqual(config.version, decodedConfig.version)
        XCTAssertEqual(config.activeProfile, decodedConfig.activeProfile)
        XCTAssertEqual(config.global.logLevel, decodedConfig.global.logLevel)
    }
    
    func testLogLevelConversion() {
        XCTAssertEqual(LogLevel.debug.swiftLogLevel, Logger.Level.debug)
        XCTAssertEqual(LogLevel.info.swiftLogLevel, Logger.Level.info)
        XCTAssertEqual(LogLevel.warning.swiftLogLevel, Logger.Level.warning)
        XCTAssertEqual(LogLevel.error.swiftLogLevel, Logger.Level.error)
    }
}

final class ConfigurationManagerTests: XCTestCase {
    
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
    
    func testConfigurationManagerInitialization() {
        // ConfigurationManager should create default configuration
        let manager = ConfigurationManager.shared
        let config = manager.getCurrentConfiguration()
        
        XCTAssertEqual(config.version, "1.0.0")
        XCTAssertEqual(config.activeProfile, "default")
        
        // Check if configuration file was created
        let configPath = tempDirectory.appendingPathComponent(".privarion/config.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath.path))
    }
    
    func testProfileSwitching() throws {
        let manager = ConfigurationManager.shared
        
        // Switch to paranoid profile
        try manager.switchProfile(to: "paranoid")
        let config = manager.getCurrentConfiguration()
        XCTAssertEqual(config.activeProfile, "paranoid")
        
        let activeProfile = manager.getActiveProfile()
        XCTAssertNotNil(activeProfile)
        XCTAssertEqual(activeProfile?.name, "paranoid")
        
        // Test switching to non-existent profile
        XCTAssertThrowsError(try manager.switchProfile(to: "nonexistent")) { error in
            if case ConfigurationError.profileNotFound(let profile) = error {
                XCTAssertEqual(profile, "nonexistent")
            } else {
                XCTFail("Expected profileNotFound error")
            }
        }
    }
    
    func testProfileCreationAndDeletion() throws {
        let manager = ConfigurationManager.shared
        
        // Create custom profile
        let customProfile = Profile(
            name: "custom",
            description: "Custom test profile",
            modules: ModuleConfigs()
        )
        
        try manager.createProfile(customProfile)
        let profiles = manager.listProfiles()
        XCTAssertTrue(profiles.contains("custom"))
        
        // Delete custom profile
        try manager.deleteProfile("custom")
        let updatedProfiles = manager.listProfiles()
        XCTAssertFalse(updatedProfiles.contains("custom"))
        
        // Test deleting built-in profile
        XCTAssertThrowsError(try manager.deleteProfile("default")) { error in
            if case ConfigurationError.cannotDeleteBuiltinProfile(let profile) = error {
                XCTAssertEqual(profile, "default")
            } else {
                XCTFail("Expected cannotDeleteBuiltinProfile error")
            }
        }
    }
    
    func testConfigurationValueUpdate() throws {
        let manager = ConfigurationManager.shared
        
        // Test setting boolean value
        try manager.setValue(false, keyPath: \.global.enabled)
        let config = manager.getCurrentConfiguration()
        XCTAssertFalse(config.global.enabled)
        
        // Test setting enum value
        try manager.setValue(.debug, keyPath: \.global.logLevel)
        let updatedConfig = manager.getCurrentConfiguration()
        XCTAssertEqual(updatedConfig.global.logLevel, .debug)
    }
    
    func testConfigurationPersistence() throws {
        let manager = ConfigurationManager.shared
        
        // Modify configuration
        try manager.setValue(.warning, keyPath: \.global.logLevel)
        try manager.setValue(20, keyPath: \.global.maxLogSizeMB)
        
        // Verify changes are persisted by checking file contents
        let configPath = tempDirectory.appendingPathComponent(".privarion/config.json")
        let data = try Data(contentsOf: configPath)
        let loadedConfig = try JSONDecoder().decode(PrivarionConfig.self, from: data)
        
        XCTAssertEqual(loadedConfig.global.logLevel, .warning)
        XCTAssertEqual(loadedConfig.global.maxLogSizeMB, 20)
    }
    
    func testConfigurationValidation() throws {
        let manager = ConfigurationManager.shared
        
        // Create invalid configuration
        var invalidConfig = PrivarionConfig()
        invalidConfig.activeProfile = "nonexistent"
        
        // Should throw validation error
        XCTAssertThrowsError(try manager.updateConfiguration(invalidConfig)) { error in
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
