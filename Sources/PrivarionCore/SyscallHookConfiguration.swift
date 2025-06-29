import Foundation
import Logging

/// Configuration model for syscall hook settings
public struct SyscallHookConfiguration: Codable {
    
    /// Hook rules for different system calls
    public var hooks: HookRules
    
    /// Global hook settings
    public var settings: HookSettings
    
    /// Fake data definitions for system calls
    public var fakeData: FakeDataDefinitions
    
    public init() {
        self.hooks = HookRules()
        self.settings = HookSettings()
        self.fakeData = FakeDataDefinitions()
    }
}

// MARK: - Hook Rules

public struct HookRules: Codable {
    /// Enable/disable uname() hook
    public var uname: Bool = false
    
    /// Enable/disable gethostname() hook  
    public var gethostname: Bool = false
    
    /// Enable/disable getuid() hook
    public var getuid: Bool = false
    
    /// Enable/disable getgid() hook
    public var getgid: Bool = false
    
    /// Application-specific hook rules
    public var applicationRules: [String: ApplicationHookRules] = [:]
    
    public init() {}
}

public struct ApplicationHookRules: Codable {
    /// Bundle identifier of the target application
    public var bundleId: String
    
    /// Hook rules specific to this application
    public var hooks: HookRules
    
    /// Whether to inherit global rules
    public var inheritGlobalRules: Bool = true
    
    public init(bundleId: String, hooks: HookRules = HookRules(), inheritGlobalRules: Bool = true) {
        self.bundleId = bundleId
        self.hooks = hooks
        self.inheritGlobalRules = inheritGlobalRules
    }
}

// MARK: - Hook Settings

public struct HookSettings: Codable {
    /// Enable audit logging for hook calls
    public var auditLogging: Bool = true
    
    /// Log level for hook operations
    public var logLevel: String = "info"
    
    /// Maximum number of hook calls to log
    public var maxLogEntries: Int = 1000
    
    /// Enable security validation
    public var securityValidation: Bool = true
    
    /// Require code signing for target applications
    public var requireCodeSigning: Bool = true
    
    /// Check System Integrity Protection status
    public var checkSIP: Bool = true
    
    public init() {}
}

// MARK: - Fake Data Definitions

public struct FakeDataDefinitions: Codable {
    /// Fake system information for uname()
    public var systemInfo: FakeSystemInfo = FakeSystemInfo()
    
    /// Fake hostname for gethostname()
    public var hostname: String = "anonymous-mac"
    
    /// Fake user ID for getuid()
    public var userId: UInt32 = 1001
    
    /// Fake group ID for getgid()
    public var groupId: UInt32 = 1001
    
    /// Fake user name for user-related calls
    public var username: String = "user"
    
    public init() {}
}

public struct FakeSystemInfo: Codable {
    /// System name (e.g., "Darwin")
    public var sysname: String = "Darwin"
    
    /// Node name (hostname)
    public var nodename: String = "anonymous-mac"
    
    /// Release version
    public var release: String = "21.0.0"
    
    /// Version string
    public var version: String = "Darwin Kernel Version 21.0.0"
    
    /// Machine type
    public var machine: String = "x86_64"
    
    public init() {}
}

// MARK: - Hook Configuration Manager

/// Manages syscall hook configuration
public final class SyscallHookConfigurationManager {
    
    // MARK: - Properties
    
    private let configurationManager: ConfigurationManager
    private let logger: Logger
    private var cachedConfig: SyscallHookConfiguration?
    
    // MARK: - Initialization
    
    public init(configurationManager: ConfigurationManager) {
        self.configurationManager = configurationManager
        self.logger = Logger(label: "com.privarion.syscall-hook-config")
    }
    
    // MARK: - Public Interface
    
    /// Load syscall hook configuration
    public func loadConfiguration() throws -> SyscallHookConfiguration {
        if let cached = cachedConfig {
            return cached
        }
        
        logger.debug("Loading syscall hook configuration")
        
        // Get current configuration from manager
        let currentConfig = configurationManager.getCurrentConfiguration()
        
        // Check if syscall hook config exists and try to decode from it
        let basicConfig = currentConfig.modules.syscallHook
        
        // For now, create a mapping from basic config to enhanced config
        var enhancedConfig = SyscallHookConfiguration()
        enhancedConfig.hooks.uname = basicConfig.enabled
        enhancedConfig.hooks.gethostname = basicConfig.enabled 
        enhancedConfig.hooks.getuid = basicConfig.enabled
        enhancedConfig.hooks.getgid = basicConfig.enabled
        enhancedConfig.settings.auditLogging = basicConfig.debugMode
        
        cachedConfig = enhancedConfig
        logger.info("Loaded syscall hook configuration")
        return enhancedConfig
    }
    
    /// Save syscall hook configuration
    public func saveConfiguration(_ hookConfig: SyscallHookConfiguration) throws {
        logger.debug("Saving syscall hook configuration")
        
        // Map enhanced config back to basic config
        var config = configurationManager.getCurrentConfiguration()
        
        // For now, use simple mapping
        config.modules.syscallHook.enabled = hookConfig.hooks.uname || hookConfig.hooks.gethostname || hookConfig.hooks.getuid || hookConfig.hooks.getgid
        config.modules.syscallHook.debugMode = hookConfig.settings.auditLogging
        
        try configurationManager.updateConfiguration(config)
        cachedConfig = hookConfig
        
        logger.info("Saved syscall hook configuration")
    }
    
    /// Update hook rules
    public func updateHookRules(_ rules: HookRules) throws {
        var config = try loadConfiguration()
        config.hooks = rules
        try saveConfiguration(config)
    }
    
    /// Update hook settings
    public func updateHookSettings(_ settings: HookSettings) throws {
        var config = try loadConfiguration()
        config.settings = settings
        try saveConfiguration(config)
    }
    
    /// Update fake data definitions
    public func updateFakeData(_ fakeData: FakeDataDefinitions) throws {
        var config = try loadConfiguration()
        config.fakeData = fakeData
        try saveConfiguration(config)
    }
    
    /// Add application-specific hook rules
    public func addApplicationRules(bundleId: String, rules: ApplicationHookRules) throws {
        var config = try loadConfiguration()
        config.hooks.applicationRules[bundleId] = rules
        try saveConfiguration(config)
    }
    
    /// Remove application-specific hook rules
    public func removeApplicationRules(bundleId: String) throws {
        var config = try loadConfiguration()
        config.hooks.applicationRules.removeValue(forKey: bundleId)
        try saveConfiguration(config)
    }
    
    /// Get effective hook rules for a specific application
    public func getEffectiveRules(for bundleId: String?) throws -> HookRules {
        let config = try loadConfiguration()
        
        guard let bundleId = bundleId,
              let appRules = config.hooks.applicationRules[bundleId] else {
            return config.hooks
        }
        
        if !appRules.inheritGlobalRules {
            return appRules.hooks
        }
        
        // Merge global and application-specific rules
        var effectiveRules = config.hooks
        
        // Application-specific rules override global rules
        if appRules.hooks.uname != config.hooks.uname {
            effectiveRules.uname = appRules.hooks.uname
        }
        if appRules.hooks.gethostname != config.hooks.gethostname {
            effectiveRules.gethostname = appRules.hooks.gethostname
        }
        if appRules.hooks.getuid != config.hooks.getuid {
            effectiveRules.getuid = appRules.hooks.getuid
        }
        if appRules.hooks.getgid != config.hooks.getgid {
            effectiveRules.getgid = appRules.hooks.getgid
        }
        
        return effectiveRules
    }
    
    /// Validate configuration
    public func validateConfiguration(_ config: SyscallHookConfiguration) throws {
        logger.debug("Validating syscall hook configuration")
        
        // Validate log level
        let validLogLevels = ["trace", "debug", "info", "notice", "warning", "error", "critical"]
        if !validLogLevels.contains(config.settings.logLevel) {
            throw ConfigurationError.invalidLogLevel
        }
        
        // Validate max log entries
        if config.settings.maxLogEntries < 100 || config.settings.maxLogEntries > 100000 {
            throw ConfigurationError.invalidLogSettings
        }
        
        // Validate fake data
        if config.fakeData.hostname.isEmpty {
            throw ConfigurationError.configurationFileCorrupted
        }
        
        if config.fakeData.username.isEmpty {
            throw ConfigurationError.configurationFileCorrupted
        }
        
        if config.fakeData.systemInfo.sysname.isEmpty {
            throw ConfigurationError.configurationFileCorrupted
        }
        
        logger.debug("Configuration validation passed")
    }
    
    /// Clear cached configuration
    public func clearCache() {
        cachedConfig = nil
        logger.debug("Cleared configuration cache")
    }
    
    /// Get current configuration without loading from disk
    public var currentConfiguration: SyscallHookConfiguration? {
        return cachedConfig
    }
}
