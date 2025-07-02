import Foundation
import Logging
import ArgumentParser

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
    public var networkAnalytics: NetworkAnalyticsConfig
    public var sandboxManager: SandboxManagerConfig
    public var snapshotManager: SnapshotManagerConfig
    public var syscallHook: SyscallHookConfig
    
    public init() {
        self.identitySpoofing = IdentitySpoofingConfig()
        self.networkFilter = NetworkFilterConfig()
        self.networkAnalytics = NetworkAnalyticsConfig()
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
    
    /// DNS proxy settings
    public var dnsProxy: DNSProxyConfig
    
    /// Blocked domains list
    public var blockedDomains: [String]
    
    /// Per-application network rules
    public var applicationRules: [String: ApplicationNetworkRule]
    
    /// Traffic monitoring settings
    public var monitoring: NetworkMonitoringConfig
    
    public init() {
        self.enabled = false
        self.blockTelemetry = false
        self.blockAnalytics = false
        self.useDNSFiltering = false
        self.dnsProxy = DNSProxyConfig()
        self.blockedDomains = []
        self.applicationRules = [:]
        self.monitoring = NetworkMonitoringConfig()
    }
}

/// DNS proxy configuration
public struct DNSProxyConfig: Codable {
    /// DNS proxy server port
    public var proxyPort: Int
    
    /// Upstream DNS servers
    public var upstreamServers: [String]
    
    /// DNS response cache TTL in seconds
    public var cacheTTL: Int
    
    /// Maximum number of cached responses
    public var maxCacheSize: Int
    
    /// DNS query timeout in seconds
    public var queryTimeout: Double
    
    public init() {
        self.proxyPort = 5353
        self.upstreamServers = ["8.8.8.8", "8.8.4.4", "1.1.1.1"]
        self.cacheTTL = 300 // 5 minutes
        self.maxCacheSize = 1000
        self.queryTimeout = 5.0
    }
}

/// Per-application network rule
public struct ApplicationNetworkRule: Codable {
    /// Application identifier (bundle ID or process name)
    public var applicationId: String
    
    /// Rule type
    public var ruleType: NetworkRuleType
    
    /// Blocked domains for this application
    public var blockedDomains: [String]
    
    /// Allowed domains for this application (if rule type is allowlist)
    public var allowedDomains: [String]
    
    /// Rule priority (higher number = higher priority)
    public var priority: Int
    
    /// Rule enabled status
    public var enabled: Bool
    
    public init(applicationId: String, ruleType: NetworkRuleType = .blocklist) {
        self.applicationId = applicationId
        self.ruleType = ruleType
        self.blockedDomains = []
        self.allowedDomains = []
        self.priority = 0
        self.enabled = true
    }
}

/// Network rule type
public enum NetworkRuleType: String, Codable, CaseIterable {
    case blocklist = "blocklist"
    case allowlist = "allowlist"
    case monitor = "monitor"
}

/// Network monitoring configuration  
public struct NetworkMonitoringConfig: Codable {
    /// Enable real-time traffic monitoring
    public var enabled: Bool
    
    /// Log all DNS queries
    public var logDNSQueries: Bool
    
    /// Log blocked requests
    public var logBlockedRequests: Bool
    
    /// Collect performance metrics
    public var collectMetrics: Bool
    
    /// Metrics collection interval in seconds
    public var metricsInterval: Double
    
    /// Maximum monitoring events to store in memory
    public var maxEventsInMemory: Int
    
    public init() {
        self.enabled = true
        self.logDNSQueries = true
        self.logBlockedRequests = true
        self.collectMetrics = true
        self.metricsInterval = 60.0
        self.maxEventsInMemory = 1000
    }
}

/// Network analytics configuration
public struct NetworkAnalyticsConfig: Codable {
    /// Enable network analytics collection
    public var enabled: Bool
    
    /// Enable real-time analytics processing
    public var realTimeProcessing: Bool
    
    /// Analytics data retention period in days
    public var dataRetentionDays: Int
    
    /// Time series aggregation intervals in seconds
    public var aggregationIntervals: [TimeInterval]
    
    /// Maximum analytics events to store in memory
    public var maxEventsInMemory: Int
    
    /// Enable bandwidth analytics
    public var bandwidthAnalytics: Bool
    
    /// Enable connection analytics
    public var connectionAnalytics: Bool
    
    /// Enable DNS analytics
    public var dnsAnalytics: Bool
    
    /// Enable application-level analytics
    public var applicationAnalytics: Bool
    
    /// Storage backend for time series data
    public var storageBackend: AnalyticsStorageBackend
    
    /// Export configuration for analytics data
    public var export: AnalyticsExportConfig
    
    public init() {
        self.enabled = false
        self.realTimeProcessing = true
        self.dataRetentionDays = 30
        self.aggregationIntervals = [60.0, 300.0, 3600.0, 86400.0] // 1min, 5min, 1hour, 1day
        self.maxEventsInMemory = 5000
        self.bandwidthAnalytics = true
        self.connectionAnalytics = true
        self.dnsAnalytics = true
        self.applicationAnalytics = true
        self.storageBackend = .inMemory
        self.export = AnalyticsExportConfig()
    }
}

/// Analytics storage backend options
public enum AnalyticsStorageBackend: String, Codable, CaseIterable {
    case inMemory = "in_memory"
    case fileSystem = "file_system"
    case hybrid = "hybrid"
}

/// Analytics export configuration
public struct AnalyticsExportConfig: Codable {
    /// Enable automatic export
    public var enabled: Bool
    
    /// Export format
    public var format: AnalyticsExportFormat
    
    /// Export interval in seconds
    public var intervalSeconds: TimeInterval
    
    /// Export directory path
    public var exportPath: String
    
    /// Maximum export file size in MB
    public var maxFileSizeMB: Int
    
    public init() {
        self.enabled = false
        self.format = .json
        self.intervalSeconds = 3600.0 // 1 hour
        self.exportPath = "~/.privarion/analytics"
        self.maxFileSizeMB = 50
    }
}

/// Analytics export format
public enum AnalyticsExportFormat: String, Codable, CaseIterable {
    case json = "json"
    case csv = "csv"
    case jsonl = "jsonl"
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
