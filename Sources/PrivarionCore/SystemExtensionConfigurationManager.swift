import Foundation
import Logging

/// Configuration manager for system extension
public class SystemExtensionConfigurationManager {
    
    /// Shared instance
    public static let shared = SystemExtensionConfigurationManager()
    
    /// Logger instance
    private let logger = Logger(label: "privarion.sysext.config")
    
    /// Current configuration
    private var currentConfig: SystemExtensionConfiguration?
    
    /// Configuration file path
    private let configPath: URL
    
    /// Backup directory path
    private let backupDirectory: URL
    
    /// Last known good configuration (for fallback)
    private var lastKnownGoodConfig: SystemExtensionConfiguration?
    
    /// Internal initialization with custom path (for testing)
    internal init(customConfigPath: URL? = nil) {
        if let customPath = customConfigPath {
            self.configPath = customPath
            self.backupDirectory = customPath.deletingLastPathComponent()
                .appendingPathComponent("backups")
        } else {
            // Use /Library/Application Support/Privarion/ for system extension
            let appSupportPath = URL(fileURLWithPath: "/Library/Application Support/Privarion")
            self.configPath = appSupportPath.appendingPathComponent("config.json")
            self.backupDirectory = appSupportPath.appendingPathComponent("backups")
        }
        
        // Create directories if they don't exist
        createDirectoriesIfNeeded()
    }
    
    /// Convenience initializer for default behavior
    private convenience init() {
        self.init(customConfigPath: nil)
    }
    
    // MARK: - Public Methods
    
    /// Load configuration from file
    public func loadConfiguration() throws -> SystemExtensionConfiguration {
        // Check if configuration file exists
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            logger.info("Configuration file not found, creating default configuration")
            let defaultConfig = SystemExtensionConfiguration.defaultConfiguration()
            try saveConfiguration(defaultConfig)
            currentConfig = defaultConfig
            lastKnownGoodConfig = defaultConfig
            return defaultConfig
        }
        
        do {
            // Read configuration file
            let data = try Data(contentsOf: configPath)
            
            // Parse JSON
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let config = try decoder.decode(SystemExtensionConfiguration.self, from: data)
            
            // Validate configuration
            try validateConfiguration(config)
            
            // Store as current and last known good
            currentConfig = config
            lastKnownGoodConfig = config
            
            logger.info("Configuration loaded successfully", metadata: [
                "path": .string(configPath.path),
                "version": .string(config.version),
                "policies": .stringConvertible(config.policies.count),
                "profiles": .stringConvertible(config.profiles.count)
            ])
            
            return config
        } catch let error as DecodingError {
            logger.error("Failed to parse configuration", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw ConfigurationManagerError.parseError(error.localizedDescription)
        } catch let error as ConfigurationValidationError {
            logger.error("Configuration validation failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw ConfigurationManagerError.validationFailed(error.localizedDescription)
        } catch {
            logger.error("Failed to load configuration", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw ConfigurationManagerError.loadFailed(error.localizedDescription)
        }
    }
    
    /// Validate configuration
    public func validateConfiguration(_ config: SystemExtensionConfiguration) throws {
        // Validate version format
        guard !config.version.isEmpty else {
            throw ConfigurationValidationError.invalidJSONSchema("Configuration version cannot be empty")
        }
        
        // Validate policies
        for policy in config.policies {
            try validatePolicy(policy)
        }
        
        // Validate hardware profiles
        for profile in config.profiles {
            try profile.validate()
        }
        
        // Validate network settings
        try validateNetworkSettings(config.networkSettings)
        
        // Validate logging settings
        try validateLoggingSettings(config.loggingSettings)
        
        logger.debug("Configuration validation passed")
    }
    
    /// Save configuration to file
    public func saveConfiguration(_ config: SystemExtensionConfiguration) throws {
        // Validate before saving
        try validateConfiguration(config)
        
        // Create backup of existing configuration
        if FileManager.default.fileExists(atPath: configPath.path) {
            try createBackup()
        }
        
        // Encode configuration
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(config)
        
        // Write atomically to temporary file first
        let tempPath = configPath.appendingPathExtension("tmp")
        try data.write(to: tempPath, options: .atomic)
        
        // Move temporary file to final location (replace if exists)
        if FileManager.default.fileExists(atPath: configPath.path) {
            try FileManager.default.removeItem(at: configPath)
        }
        try FileManager.default.moveItem(at: tempPath, to: configPath)
        
        // Set secure file permissions (readable by root only)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: configPath.path
        )
        
        // Update current configuration
        currentConfig = config
        lastKnownGoodConfig = config
        
        logger.info("Configuration saved successfully", metadata: [
            "path": .string(configPath.path)
        ])
    }
    
    /// Reload configuration from file
    public func reloadConfiguration() throws {
        logger.info("Reloading configuration")
        
        do {
            let config = try loadConfiguration()
            currentConfig = config
            logger.info("Configuration reloaded successfully")
        } catch {
            logger.error("Failed to reload configuration, using last known good", metadata: [
                "error": .string(error.localizedDescription)
            ])
            
            // Fall back to last known good configuration
            if let lastGood = lastKnownGoodConfig {
                currentConfig = lastGood
                logger.warning("Reverted to last known good configuration")
            } else {
                throw error
            }
        }
    }
    
    /// Export configuration to data
    public func exportConfiguration() throws -> Data {
        guard let config = currentConfig else {
            throw ConfigurationManagerError.noConfigurationLoaded
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        
        return try encoder.encode(config)
    }
    
    /// Import configuration from data
    public func importConfiguration(_ data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let config = try decoder.decode(SystemExtensionConfiguration.self, from: data)
        
        // Validate imported configuration
        try validateConfiguration(config)
        
        // Save imported configuration
        try saveConfiguration(config)
        
        logger.info("Configuration imported successfully")
    }
    
    /// Get current configuration
    public func getCurrentConfiguration() -> SystemExtensionConfiguration? {
        return currentConfig
    }
    
    // MARK: - Private Methods
    
    /// Create directories if needed
    private func createDirectoriesIfNeeded() {
        let directories = [
            configPath.deletingLastPathComponent(),
            backupDirectory
        ]
        
        for directory in directories {
            do {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o700]
                )
            } catch {
                logger.error("Failed to create directory", metadata: [
                    "path": .string(directory.path),
                    "error": .string(error.localizedDescription)
                ])
            }
        }
    }
    
    /// Create backup of current configuration
    private func createBackup() throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupPath = backupDirectory.appendingPathComponent("config-\(timestamp).json")
        
        try FileManager.default.copyItem(at: configPath, to: backupPath)
        
        logger.info("Configuration backup created", metadata: [
            "backup": .string(backupPath.path)
        ])
        
        // Clean up old backups (keep last 10)
        try cleanupOldBackups()
    }
    
    /// Clean up old backup files
    private func cleanupOldBackups() throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )
        
        // Sort by creation date (newest first)
        let sortedBackups = try contents.sorted { url1, url2 in
            let date1 = try url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            let date2 = try url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
            return date1 > date2
        }
        
        // Remove backups beyond the 10 most recent
        for backup in sortedBackups.dropFirst(10) {
            try FileManager.default.removeItem(at: backup)
            logger.debug("Removed old backup", metadata: [
                "backup": .string(backup.path)
            ])
        }
    }
    
    /// Validate policy
    private func validatePolicy(_ policy: ProtectionPolicy) throws {
        // Validate identifier is not empty
        guard !policy.identifier.isEmpty else {
            throw ConfigurationValidationError.inconsistentPolicyRules("Policy identifier cannot be empty")
        }
        
        // Validate network filtering rules
        if policy.networkFiltering.action == .allow {
            // If action is allow, blocked domains should be empty or allowlist should be specified
            if !policy.networkFiltering.blockedDomains.isEmpty &&
               policy.networkFiltering.allowedDomains.isEmpty {
                throw ConfigurationValidationError.inconsistentPolicyRules(
                    "Policy '\(policy.identifier)': Cannot have blocked domains with 'allow' action without allowlist"
                )
            }
        }
        
        // Validate VM isolation requirement
        if policy.requiresVMIsolation && policy.hardwareSpoofing != .full {
            logger.warning("Policy requires VM isolation but hardware spoofing is not set to 'full'", metadata: [
                "policy": .string(policy.identifier)
            ])
        }
    }
    
    /// Validate network settings
    private func validateNetworkSettings(_ settings: NetworkConfiguration) throws {
        // Validate port numbers
        let ports = [settings.dnsProxyPort, settings.httpProxyPort, settings.httpsProxyPort]
        for port in ports {
            guard port > 0 && port <= 65535 else {
                throw ConfigurationValidationError.invalidJSONSchema("Invalid port number: \(port)")
            }
        }
        
        // Validate upstream DNS servers
        guard !settings.upstreamDNS.isEmpty else {
            throw ConfigurationValidationError.invalidJSONSchema("At least one upstream DNS server must be specified")
        }
    }
    
    /// Validate logging settings
    private func validateLoggingSettings(_ settings: LoggingConfiguration) throws {
        // Validate rotation days
        guard settings.rotationDays > 0 else {
            throw ConfigurationValidationError.invalidJSONSchema("Log rotation days must be positive")
        }
        
        // Validate max size
        guard settings.maxSizeMB > 0 else {
            throw ConfigurationValidationError.invalidJSONSchema("Maximum log size must be positive")
        }
    }
    
    /// Create test instance with custom configuration path (for testing)
    public static func createTestInstance(configPath: URL) -> SystemExtensionConfigurationManager {
        return SystemExtensionConfigurationManager(customConfigPath: configPath)
    }
}

// MARK: - Configuration Manager Errors

/// Configuration manager errors
public enum ConfigurationManagerError: Error, LocalizedError {
    case loadFailed(String)
    case parseError(String)
    case validationFailed(String)
    case saveFailed(String)
    case noConfigurationLoaded
    case backupFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Failed to load configuration: \(message)"
        case .parseError(let message):
            return "Failed to parse configuration: \(message)"
        case .validationFailed(let message):
            return "Configuration validation failed: \(message)"
        case .saveFailed(let message):
            return "Failed to save configuration: \(message)"
        case .noConfigurationLoaded:
            return "No configuration loaded"
        case .backupFailed(let message):
            return "Failed to create backup: \(message)"
        }
    }
}
