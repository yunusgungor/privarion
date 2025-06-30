import Foundation
import Logging

/// Core configuration management for Privarion privacy protection system
public struct PrivarionConfig: Codable {
    /// Version of the configuration schema
    public let version: String
    
    /// Global system settings
    public var global: GlobalConfig
    
    /// Module-specific configurations
    public var modules: ModuleConfigs
    
    /// Active profile identifier
    public var activeProfile: String
    
    /// User-defined profiles
    public var profiles: [String: Profile]
    
    public init() {
        self.version = "1.0.0"
        self.global = GlobalConfig()
        self.modules = ModuleConfigs()
        self.activeProfile = "default"
        self.profiles = [
            "default": Profile.defaultProfile(),
            "paranoid": Profile.paranoidProfile(),
            "balanced": Profile.balancedProfile()
        ]
    }
}

/// Global system configuration
public struct GlobalConfig: Codable {
    /// Enable/disable entire system
    public var enabled: Bool
    
    /// Log level for the system
    public var logLevel: LogLevel
    
    /// Directory for storing logs
    public var logDirectory: String
    
    /// Maximum log file size in MB
    public var maxLogSizeMB: Int
    
    /// Number of log files to keep
    public var logRotationCount: Int
    
    /// Secure path to hook library (prevents hardcoded paths)
    public var hookLibraryPath: String?
    
    public init() {
        self.enabled = true
        self.logLevel = .info
        self.logDirectory = "~/.privarion/logs"
        self.maxLogSizeMB = 10
        self.logRotationCount = 5
        self.hookLibraryPath = nil
    }
}

/// Module-specific configurations
public struct ModuleConfigs: Codable {
    public var identitySpoofing: IdentitySpoofingConfig
    public var networkFilter: NetworkFilterConfig
    public var sandboxManager: SandboxManagerConfig
    public var snapshotManager: SnapshotManagerConfig
    public var syscallHook: SyscallHookConfig
    
    public init() {
        self.identitySpoofing = IdentitySpoofingConfig()
        self.networkFilter = NetworkFilterConfig()
        self.sandboxManager = SandboxManagerConfig()
        self.snapshotManager = SnapshotManagerConfig()
        self.syscallHook = SyscallHookConfig()
    }
}

/// Identity spoofing module configuration
public struct IdentitySpoofingConfig: Codable {
    public var enabled: Bool
    public var spoofHostname: Bool
    public var spoofMACAddress: Bool
    public var spoofUserInfo: Bool
    public var spoofSystemInfo: Bool
    
    public init() {
        self.enabled = false
        self.spoofHostname = false
        self.spoofMACAddress = false
        self.spoofUserInfo = false
        self.spoofSystemInfo = false
    }
}

/// Network filter module configuration
public struct NetworkFilterConfig: Codable {
    public var enabled: Bool
    public var blockTelemetry: Bool
    public var blockAnalytics: Bool
    public var useDNSFiltering: Bool
    
    public init() {
        self.enabled = false
        self.blockTelemetry = false
        self.blockAnalytics = false
        self.useDNSFiltering = false
    }
}

/// Sandbox manager configuration
public struct SandboxManagerConfig: Codable {
    public var enabled: Bool
    public var strictMode: Bool
    
    public init() {
        self.enabled = false
        self.strictMode = false
    }
}

/// Snapshot manager configuration
public struct SnapshotManagerConfig: Codable {
    public var enabled: Bool
    public var autoSnapshot: Bool
    
    public init() {
        self.enabled = false
        self.autoSnapshot = false
    }
}

/// Syscall hook configuration
public struct SyscallHookConfig: Codable {
    public var enabled: Bool
    public var debugMode: Bool
    
    public init() {
        self.enabled = false
        self.debugMode = false
    }
}

/// Log level enumeration
public enum LogLevel: String, Codable, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    /// Convert to swift-log Logger.Level
    public var swiftLogLevel: Logger.Level {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }
}

/// Profile definition for different security postures
public struct Profile: Codable {
    public let name: String
    public let description: String
    public var modules: ModuleConfigs
    
    public init(name: String, description: String, modules: ModuleConfigs) {
        self.name = name
        self.description = description
        self.modules = modules
    }
    
    /// Default profile with minimal protection
    public static func defaultProfile() -> Profile {
        var modules = ModuleConfigs()
        modules.networkFilter.enabled = true
        modules.networkFilter.blockTelemetry = true
        
        return Profile(
            name: "default",
            description: "Basic privacy protection with minimal system impact",
            modules: modules
        )
    }
    
    /// Paranoid profile with maximum protection
    public static func paranoidProfile() -> Profile {
        var modules = ModuleConfigs()
        
        // Enable all modules
        modules.identitySpoofing.enabled = true
        modules.identitySpoofing.spoofHostname = true
        modules.identitySpoofing.spoofMACAddress = true
        modules.identitySpoofing.spoofUserInfo = true
        modules.identitySpoofing.spoofSystemInfo = true
        
        modules.networkFilter.enabled = true
        modules.networkFilter.blockTelemetry = true
        modules.networkFilter.blockAnalytics = true
        modules.networkFilter.useDNSFiltering = true
        
        modules.sandboxManager.enabled = true
        modules.sandboxManager.strictMode = true
        
        modules.snapshotManager.enabled = true
        modules.snapshotManager.autoSnapshot = true
        
        modules.syscallHook.enabled = true
        
        return Profile(
            name: "paranoid",
            description: "Maximum privacy protection with comprehensive spoofing",
            modules: modules
        )
    }
    
    /// Balanced profile with moderate protection
    public static func balancedProfile() -> Profile {
        var modules = ModuleConfigs()
        
        modules.identitySpoofing.enabled = true
        modules.identitySpoofing.spoofHostname = true
        modules.identitySpoofing.spoofSystemInfo = true
        
        modules.networkFilter.enabled = true
        modules.networkFilter.blockTelemetry = true
        modules.networkFilter.blockAnalytics = true
        
        modules.syscallHook.enabled = true
        
        return Profile(
            name: "balanced",
            description: "Balanced privacy protection with good performance",
            modules: modules
        )
    }
}
