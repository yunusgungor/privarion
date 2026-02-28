import XCTest
@testable import PrivarionCore

/// Unit tests for SystemExtensionConfigurationManager
final class SystemExtensionConfigurationManagerTests: XCTestCase {
    
    var tempDirectory: URL!
    var configPath: URL!
    var manager: SystemExtensionConfigurationManager!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for tests
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        
        configPath = tempDirectory.appendingPathComponent("config.json")
        manager = SystemExtensionConfigurationManager.createTestInstance(configPath: configPath)
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        super.tearDown()
    }
    
    // MARK: - Test Loading Valid Configuration
    
    func testLoadValidConfiguration() throws {
        // Create a valid configuration file
        let config = SystemExtensionConfiguration.defaultConfiguration()
        try manager.saveConfiguration(config)
        
        // Load the configuration
        let loadedConfig = try manager.loadConfiguration()
        
        // Verify it matches
        XCTAssertEqual(loadedConfig, config, "Loaded configuration should match saved configuration")
    }
    
    // MARK: - Test Handling Invalid JSON
    
    func testHandleInvalidJSON() throws {
        // Write invalid JSON to file
        let invalidJSON = "{ invalid json }"
        try invalidJSON.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Attempt to load should throw
        XCTAssertThrowsError(try manager.loadConfiguration()) { error in
            guard let configError = error as? ConfigurationManagerError else {
                XCTFail("Expected ConfigurationManagerError, got \(type(of: error))")
                return
            }
            
            if case .parseError = configError {
                // Expected error type
            } else {
                XCTFail("Expected parseError, got \(configError)")
            }
        }
    }
    
    func testHandleInvalidJSONSchema() throws {
        // Write JSON with missing required fields
        let invalidSchema = """
        {
            "version": "1.0.0"
        }
        """
        try invalidSchema.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Attempt to load should throw
        XCTAssertThrowsError(try manager.loadConfiguration()) { error in
            // Should fail during decoding
            XCTAssertTrue(error is ConfigurationManagerError, "Should throw ConfigurationManagerError")
        }
    }
    
    // MARK: - Test Handling Missing Configuration File
    
    func testHandleMissingConfigurationFile() throws {
        // Ensure config file doesn't exist
        XCTAssertFalse(FileManager.default.fileExists(atPath: configPath.path))
        
        // Load should create default configuration
        let config = try manager.loadConfiguration()
        
        // Verify default configuration was created
        XCTAssertEqual(config.version, "1.0.0")
        XCTAssertFalse(config.policies.isEmpty)
        XCTAssertFalse(config.profiles.isEmpty)
        
        // Verify file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath.path))
    }
    
    // MARK: - Test Configuration Reload
    
    func testConfigurationReload() throws {
        // Save initial configuration
        var config = SystemExtensionConfiguration.defaultConfiguration()
        try manager.saveConfiguration(config)
        
        // Load it
        _ = try manager.loadConfiguration()
        
        // Modify the file externally
        config.loggingSettings.level = .debug
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(config)
        try data.write(to: configPath)
        
        // Reload configuration
        try manager.reloadConfiguration()
        
        // Verify the change was picked up
        let reloadedConfig = manager.getCurrentConfiguration()
        XCTAssertEqual(reloadedConfig?.loggingSettings.level, .debug)
    }
    
    func testConfigurationReloadWithInvalidFile() throws {
        // Save valid configuration first
        let config = SystemExtensionConfiguration.defaultConfiguration()
        try manager.saveConfiguration(config)
        
        // Load it
        _ = try manager.loadConfiguration()
        
        // Corrupt the file
        try "invalid".write(to: configPath, atomically: true, encoding: .utf8)
        
        // Reload should fall back to last known good
        try manager.reloadConfiguration()
        
        // Should still have the original configuration
        let currentConfig = manager.getCurrentConfiguration()
        XCTAssertNotNil(currentConfig)
        XCTAssertEqual(currentConfig, config)
    }
    
    // MARK: - Test Backup and Restore
    
    func testBackupCreation() throws {
        // Save initial configuration
        let config = SystemExtensionConfiguration.defaultConfiguration()
        try manager.saveConfiguration(config)
        
        // Modify and save again (should create backup)
        var modifiedConfig = config
        modifiedConfig.loggingSettings.level = .debug
        try manager.saveConfiguration(modifiedConfig)
        
        // Verify backup directory exists
        let backupDir = configPath.deletingLastPathComponent().appendingPathComponent("backups")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupDir.path))
        
        // Verify at least one backup file exists
        let backups = try FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil)
        XCTAssertFalse(backups.isEmpty, "Should have created at least one backup")
    }
    
    func testExportConfiguration() throws {
        // Save configuration
        let config = SystemExtensionConfiguration.defaultConfiguration()
        try manager.saveConfiguration(config)
        
        // Load it
        _ = try manager.loadConfiguration()
        
        // Export configuration
        let exportedData = try manager.exportConfiguration()
        
        // Verify it can be decoded
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exportedConfig = try decoder.decode(SystemExtensionConfiguration.self, from: exportedData)
        
        XCTAssertEqual(exportedConfig, config)
    }
    
    func testImportConfiguration() throws {
        // Create a configuration to import
        let config = SystemExtensionConfiguration(
            version: "1.0.0",
            policies: [
                ProtectionPolicy(
                    identifier: "com.test.app",
                    protectionLevel: .strict
                )
            ],
            profiles: [],
            blocklists: BlocklistConfiguration(),
            networkSettings: NetworkConfiguration(),
            loggingSettings: LoggingConfiguration()
        )
        
        // Encode it
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(config)
        
        // Import it
        try manager.importConfiguration(data)
        
        // Verify it was imported
        let importedConfig = manager.getCurrentConfiguration()
        XCTAssertEqual(importedConfig, config)
        
        // Verify file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath.path))
    }
    
    // MARK: - Test Validation
    
    func testValidationOfInvalidConfiguration() throws {
        // Create configuration with invalid port
        var config = SystemExtensionConfiguration.defaultConfiguration()
        config.networkSettings.dnsProxyPort = 99999 // Invalid port
        
        // Attempt to save should throw validation error
        XCTAssertThrowsError(try manager.saveConfiguration(config)) { error in
            // Should be a validation error (either ConfigurationManagerError or ConfigurationValidationError)
            let isValidationError = (error is ConfigurationManagerError) || (error is ConfigurationValidationError)
            XCTAssertTrue(isValidationError, "Expected validation error, got \(type(of: error))")
        }
    }
    
    func testValidationOfEmptyVersion() throws {
        // Create configuration with empty version
        var config = SystemExtensionConfiguration.defaultConfiguration()
        // Can't directly set version as it's let, so we'll test through JSON
        
        let invalidJSON = """
        {
            "version": "",
            "policies": [],
            "profiles": [],
            "blocklists": {
                "trackingDomains": [],
                "fingerprintingDomains": [],
                "telemetryEndpoints": [],
                "customBlocklist": []
            },
            "networkSettings": {
                "dnsProxyPort": 53,
                "httpProxyPort": 8080,
                "httpsProxyPort": 8443,
                "upstreamDNS": ["8.8.8.8"],
                "enableDoH": false
            },
            "loggingSettings": {
                "level": "info",
                "rotationDays": 7,
                "maxSizeMB": 100,
                "sanitizePII": true
            }
        }
        """
        
        try invalidJSON.write(to: configPath, atomically: true, encoding: .utf8)
        
        // Loading should fail validation
        XCTAssertThrowsError(try manager.loadConfiguration()) { error in
            XCTAssertTrue(error is ConfigurationManagerError)
        }
    }
    
    // MARK: - Test Atomic Write
    
    func testAtomicWrite() throws {
        // Save configuration
        let config = SystemExtensionConfiguration.defaultConfiguration()
        try manager.saveConfiguration(config)
        
        // Verify file exists and is readable
        XCTAssertTrue(FileManager.default.fileExists(atPath: configPath.path))
        
        let loadedConfig = try manager.loadConfiguration()
        XCTAssertEqual(loadedConfig, config)
    }
    
    // MARK: - Test File Permissions
    
    func testFilePermissions() throws {
        // Save configuration
        let config = SystemExtensionConfiguration.defaultConfiguration()
        try manager.saveConfiguration(config)
        
        // Check file permissions
        let attributes = try FileManager.default.attributesOfItem(atPath: configPath.path)
        let permissions = attributes[.posixPermissions] as? NSNumber
        
        // Should be 0o600 (read/write for owner only)
        XCTAssertEqual(permissions?.intValue, 0o600, "File should have 0o600 permissions")
    }
}
