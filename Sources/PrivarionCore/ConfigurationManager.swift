import Foundation
import Logging

/// Configuration manager for Privarion system
public class ConfigurationManager {
    
    /// Shared instance
    public static let shared = ConfigurationManager()
    
    /// Logger instance
    private let logger = Logger(label: "privarion.config")
    
    /// Current configuration
    private var config: PrivarionConfig
    
    /// Configuration file path
    private let configPath: URL
    
    /// File system monitor for configuration changes
    private var fileMonitor: FileMonitor?
    
    /// Check if running in test environment
    private static var isTestEnvironment: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
               ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
               ProcessInfo.processInfo.arguments.contains { $0.contains("xctest") }
    }
    
    /// Internal initialization with custom path (for testing)
    internal init(customConfigPath: URL? = nil) {
        if let customPath = customConfigPath {
            // Use provided path (for testing)
            self.configPath = customPath
            let privarionDirectory = customPath.deletingLastPathComponent()
            
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(
                at: privarionDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } else {
            // Setup configuration directory using current HOME
            let homeDirectory: URL
            if let homeEnv = ProcessInfo.processInfo.environment["HOME"] {
                homeDirectory = URL(fileURLWithPath: homeEnv)
            } else {
                homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            }
            let privarionDirectory = homeDirectory.appendingPathComponent(".privarion")
            
            // Create directory if it doesn't exist
            try? FileManager.default.createDirectory(
                at: privarionDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            
            self.configPath = privarionDirectory.appendingPathComponent("config.json")
        }
        
        // Load or create configuration
        if FileManager.default.fileExists(atPath: configPath.path) {
            do {
                self.config = try Self.loadConfiguration(from: configPath)
                logger.info("Configuration loaded successfully", metadata: [
                    "path": .string(configPath.path),
                    "version": .string(config.version)
                ])
            } catch {
                logger.error("Failed to load configuration, using defaults", metadata: [
                    "error": .string(error.localizedDescription),
                    "path": .string(configPath.path)
                ])
                self.config = PrivarionConfig()
                try? saveConfiguration()
            }
        } else {
            logger.info("Creating new configuration file")
            self.config = PrivarionConfig()
            try? saveConfiguration()
        }
        
        // Start monitoring configuration file changes (skip in test environment)
        if !Self.isTestEnvironment {
            startFileMonitoring()
        }
    }
    
    /// Convenience initializer for default behavior
    private convenience init() {
        self.init(customConfigPath: nil)
    }
    
    deinit {
        fileMonitor?.stop()
    }
    
    /// Get current configuration
    public func getCurrentConfiguration() -> PrivarionConfig {
        return config
    }
    
    /// Get secure hook library path from configuration
    public var hookLibraryPath: String? {
        return config.global.hookLibraryPath
    }
    
    /// Update configuration
    public func updateConfiguration(_ newConfig: PrivarionConfig) throws {
        // Validate configuration
        try validateConfiguration(newConfig)
        
        self.config = newConfig
        try saveConfiguration()
        
        logger.info("Configuration updated successfully")
    }
    
    /// Get specific configuration value
    public func getValue<T>(keyPath: KeyPath<PrivarionConfig, T>) -> T {
        return config[keyPath: keyPath]
    }
    
    /// Set specific configuration value
    public func setValue<T>(_ value: T, keyPath: WritableKeyPath<PrivarionConfig, T>) throws {
        config[keyPath: keyPath] = value
        try saveConfiguration()
        
        logger.debug("Configuration value updated", metadata: [
            "keyPath": .string(String(describing: keyPath))
        ])
    }
    
    /// Get active profile
    public func getActiveProfile() -> Profile? {
        return config.profiles[config.activeProfile]
    }
    
    /// Switch to different profile
    public func switchProfile(to profileName: String) throws {
        guard config.profiles[profileName] != nil else {
            throw ConfigurationError.profileNotFound(profileName)
        }
        
        config.activeProfile = profileName
        try saveConfiguration()
        
        logger.info("Switched to profile", metadata: [
            "profile": .string(profileName)
        ])
    }
    
    /// Create new profile
    public func createProfile(_ profile: Profile) throws {
        config.profiles[profile.name] = profile
        try saveConfiguration()
        
        logger.info("Created new profile", metadata: [
            "profile": .string(profile.name)
        ])
    }
    
    /// Delete profile
    public func deleteProfile(_ profileName: String) throws {
        guard profileName != "default" && profileName != "paranoid" && profileName != "balanced" else {
            throw ConfigurationError.cannotDeleteBuiltinProfile(profileName)
        }
        
        guard config.profiles[profileName] != nil else {
            throw ConfigurationError.profileNotFound(profileName)
        }
        
        // Switch to default if deleting active profile
        if config.activeProfile == profileName {
            config.activeProfile = "default"
        }
        
        config.profiles.removeValue(forKey: profileName)
        try saveConfiguration()
        
        logger.info("Deleted profile", metadata: [
            "profile": .string(profileName)
        ])
    }
    
    /// List all profiles
    public func listProfiles() -> [String] {
        return Array(config.profiles.keys)
    }
    
    /// Create test instance with custom configuration path (for testing)
    public static func createTestInstance(configPath: URL) -> ConfigurationManager {
        return ConfigurationManager(customConfigPath: configPath)
    }
    
    // MARK: - Private Methods
    
    /// Load configuration from file
    private static func loadConfiguration(from url: URL) throws -> PrivarionConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PrivarionConfig.self, from: data)
    }
    
    /// Save configuration to file
    private func saveConfiguration() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(config)
        try data.write(to: configPath, options: [.atomic])
        
        // Set secure file permissions
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: configPath.path
        )
    }
    
    /// Validate configuration
    private func validateConfiguration(_ config: PrivarionConfig) throws {
        // Validate version
        guard !config.version.isEmpty else {
            throw ConfigurationError.invalidVersion
        }
        
        // Validate log level
        guard LogLevel.allCases.contains(config.global.logLevel) else {
            throw ConfigurationError.invalidLogLevel
        }
        
        // Validate active profile exists
        guard config.profiles[config.activeProfile] != nil else {
            throw ConfigurationError.profileNotFound(config.activeProfile)
        }
        
        // Validate log settings
        guard config.global.maxLogSizeMB > 0 && config.global.logRotationCount > 0 else {
            throw ConfigurationError.invalidLogSettings
        }
    }
    
    /// Start monitoring configuration file for external changes
    private func startFileMonitoring() {
        fileMonitor = FileMonitor(url: configPath) { [weak self] in
            self?.handleConfigurationFileChange()
        }
        fileMonitor?.start()
    }
    
    /// Handle configuration file changes
    private func handleConfigurationFileChange() {
        do {
            let newConfig = try Self.loadConfiguration(from: configPath)
            self.config = newConfig
            logger.info("Configuration reloaded due to external changes")
        } catch {
            logger.error("Failed to reload configuration after external changes", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }
}

/// Configuration errors
public enum ConfigurationError: Error, LocalizedError {
    case invalidVersion
    case invalidLogLevel
    case invalidLogSettings
    case profileNotFound(String)
    case cannotDeleteBuiltinProfile(String)
    case configurationFileCorrupted
    
    public var errorDescription: String? {
        switch self {
        case .invalidVersion:
            return "Invalid configuration version"
        case .invalidLogLevel:
            return "Invalid log level specified"
        case .invalidLogSettings:
            return "Invalid log settings (size or rotation count)"
        case .profileNotFound(let profile):
            return "Profile '\(profile)' not found"
        case .cannotDeleteBuiltinProfile(let profile):
            return "Cannot delete built-in profile '\(profile)'"
        case .configurationFileCorrupted:
            return "Configuration file is corrupted or invalid"
        }
    }
}

/// Simple file monitor for configuration changes
private class FileMonitor {
    private let url: URL
    private let callback: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "privarion.config.monitor")
    
    init(url: URL, callback: @escaping () -> Void) {
        self.url = url
        self.callback = callback
    }
    
    func start() {
        let fd = open(url.path, O_EVTONLY)
        guard fd != -1 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: .write,
            queue: queue
        )
        
        source?.setEventHandler { [weak self] in
            self?.callback()
        }
        
        source?.setCancelHandler {
            close(fd)
        }
        
        source?.resume()
    }
    
    func stop() {
        source?.cancel()
        source = nil
    }
}
