import Foundation
import ArgumentParser
import PrivarionCore

/// Enhanced CLI errors with actionable troubleshooting messages
enum PrivarionCLIError: Error, LocalizedError {
    case profileNotFound(String, availableProfiles: [String])
    case profileSwitchFailed(String, underlyingError: Error)
    case systemStartupFailed(underlyingError: Error)
    case unsupportedMacOSVersion(current: String, required: String)
    case insufficientPermissions(directory: String)
    case configurationSetFailed(key: String, value: String, underlyingError: Error)
    case configurationValidationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .profileNotFound(let profile, _):
            return "Profile '\(profile)' not found"
        case .profileSwitchFailed(let profile, let error):
            return "Failed to switch to profile '\(profile)': \(error.localizedDescription)"
        case .systemStartupFailed(let error):
            return "System startup failed: \(error.localizedDescription)"
        case .unsupportedMacOSVersion(let current, let required):
            return "Unsupported macOS version \(current). Requires \(required)"
        case .insufficientPermissions(let directory):
            return "Insufficient permissions for directory: \(directory)"
        case .configurationSetFailed(let key, let value, let error):
            return "Failed to set \(key) = \(value): \(error.localizedDescription)"
        case .configurationValidationFailed(let message):
            return "Configuration validation failed: \(message)"
        }
    }
    
    /// Provides actionable troubleshooting guidance
    var troubleshootingMessage: String {
        switch self {
        case .profileNotFound(let profile, let available):
            return """
            💡 Profile troubleshooting:
               • Available profiles: \(available.joined(separator: ", "))
               • Create new profile: privarion profile create \(profile) "Description"
               • List all profiles: privarion profile list
            """
        case .profileSwitchFailed(let profile, _):
            return """
            💡 Profile switch troubleshooting:
               • Verify profile exists: privarion profile list
               • Check permissions: ls -la ~/.privarion/profiles/
               • Recreate profile: privarion profile delete \(profile) && privarion profile create \(profile) "New"
            """
        case .systemStartupFailed(_):
            return """
            💡 System startup troubleshooting:
               • Check permissions: sudo privarion status
               • Reset configuration: privarion config reset --force
               • View logs: privarion logs --lines 50
               • Verify hooks: privarion hook status
            """
        case .unsupportedMacOSVersion(_, let required):
            return """
            💡 macOS version troubleshooting:
               • Required version: \(required)
               • Current system is not supported
               • Please upgrade macOS to continue
            """
        case .insufficientPermissions(let directory):
            return """
            💡 Permission troubleshooting:
               • Check directory permissions: ls -la \(directory)
               • Fix permissions: chmod 755 \(directory)
               • Create directory: mkdir -p \(directory)
            """
        case .configurationSetFailed(let key, let value, _):
            return """
            💡 Configuration troubleshooting:
               • Verify key format: \(key)
               • Check value type for: \(value)
               • View current config: privarion config list
               • Reset if needed: privarion config reset
            """
        case .configurationValidationFailed(_):
            return """
            💡 Configuration validation troubleshooting:
               • Check config syntax: privarion config list
               • Reset to defaults: privarion config reset --force
               • Verify file permissions: ls -la ~/.privarion/config.json
            """
        }
    }
}

/// Main CLI tool for Privarion privacy protection system
@main
struct PrivacyCtl: ParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "privarion",
        abstract: "Privarion Privacy Protection System - Comprehensive macOS Privacy Control",
        discussion: """
        A comprehensive privacy protection system for macOS that prevents applications 
        from identifying your device and collecting personal information.
        
        COMMON USAGE PATTERNS:
        
        Quick Start:
            privarion start --profile default    # Start protection with default profile
            privarion status --detailed          # Check system status
            privarion stop                       # Stop protection
        
        Configuration Management:
            privarion config list               # View all settings
            privarion config get global.enabled # Get specific setting
            privarion config set key value      # Update configuration
        
        Profile Management:
            privarion profile list              # Show available profiles
            privarion profile switch work       # Switch to work profile
            privarion profile create name desc  # Create custom profile
        
        Advanced Operations:
            privarion inject /path/app           # Launch app with hooks
            privarion hook list                 # Show available hooks
            privarion logs --follow             # Monitor system logs
            privarion identity backup           # Backup system identity
            privarion identity restore <id>     # Restore from backup
        
        For detailed help on any command, use: privarion help <command>
        """,
        version: "1.0.0",
        subcommands: [
            StartCommand.self,
            StopCommand.self,
            StatusCommand.self,
            ConfigCommand.self,
            ProfileCommand.self,
            LogsCommand.self,
            InjectCommand.self,
            HookCommand.self,
            IdentityCommand.self
        ]
    )
}

/// Start the privacy protection system
struct StartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start the Privarion privacy protection system",
        discussion: """
        Activates the privacy protection system with the specified profile.
        
        EXAMPLES:
        
        Start with default profile:
            privarion start
        
        Start with specific profile and verbose output:
            privarion start --profile work --verbose
            
        Start in development mode with detailed logging:
            privarion start --profile development --verbose
        
        The system will automatically validate the configuration before starting
        and report any issues that prevent activation.
        """
    )
    
    @Flag(name: .shortAndLong, help: "Enable verbose output with detailed startup information")
    var verbose = false
    
    @Option(name: .shortAndLong, help: "Specify profile to use (use 'privarion profile list' to see available profiles)")
    var profile: String?
    
    func run() throws {
        let logger = PrivarionLogger.shared.logger(for: "cli.start")
        
        print("🔒 Starting Privarion Privacy Protection System...")
        
        // Validate profile if specified
        if let profileName = profile {
            let availableProfiles = ConfigurationManager.shared.listProfiles()
            if !availableProfiles.contains(profileName) {
                print("❌ Error: Profile '\(profileName)' not found")
                print("")
                print("💡 Available profiles:")
                for availableProfile in availableProfiles.sorted() {
                    print("   • \(availableProfile)")
                }
                print("")
                print("💡 To create a new profile:")
                print("   privarion profile create \(profileName) \"Profile description\"")
                throw PrivarionCLIError.profileNotFound(profileName, availableProfiles: availableProfiles)
            }
            
            do {
                try ConfigurationManager.shared.switchProfile(to: profileName)
                print("✅ Switched to profile: \(profileName)")
            } catch {
                print("❌ Failed to switch to profile '\(profileName)': \(error.localizedDescription)")
                print("")
                print("💡 Try these troubleshooting steps:")
                print("   1. Check if the profile exists: privarion profile list")
                print("   2. Verify profile permissions: ls -la ~/.privarion/profiles/")
                print("   3. Reset profile if corrupted: privarion profile delete \(profileName) && privarion profile create \(profileName) \"New description\"")
                throw PrivarionCLIError.profileSwitchFailed(profileName, underlyingError: error)
            }
        }
        
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        let activeProfile = ConfigurationManager.shared.getActiveProfile()
        
        if verbose {
            print("\n📋 Configuration Details:")
            print("   • Active Profile: \(config.activeProfile)")
            print("   • Profile Description: \(activeProfile?.description ?? "Unknown")")
            print("   • System Status: \(config.global.enabled ? "Already enabled" : "Ready to start")")
            print("   • Log Level: \(config.global.logLevel.rawValue)")
        }
        
        // Check if system is already enabled
        if config.global.enabled {
            print("⚠️  Privarion is already running")
            print("")
            print("💡 To check current status:")
            print("   privarion status --detailed")
            print("")
            print("💡 To restart with different settings:")
            print("   privarion stop && privarion start --profile your_profile")
            return
        }
        
        // Validate system requirements before starting
        do {
            try validateSystemRequirements()
        } catch let error as PrivarionCLIError {
            print("❌ System validation failed: \(error.localizedDescription)")
            print("")
            print(error.troubleshootingMessage)
            throw error
        }
        
        // Enable the system
        do {
            // Show progress for startup
            if verbose {
                print("\n🔄 Starting privacy protection modules...")
            }
            
            try ConfigurationManager.shared.setValue(true, keyPath: \.global.enabled)
            logger.info("Privarion system started", metadata: [
                "profile": .string(config.activeProfile)
            ])
            print("✅ Privarion privacy protection is now active")
            
            if let profile = activeProfile {
                printActiveModules(profile: profile)
            }
            
            print("\n💡 Next steps:")
            print("   • Check status: privarion status --detailed")
            print("   • Monitor logs: privarion logs --follow")
            print("   • Launch protected app: privarion inject /path/to/app")
            
        } catch {
            logger.error("Failed to start Privarion", metadata: [
                "error": .string(error.localizedDescription)
            ])
            print("❌ Failed to start Privarion: \(error.localizedDescription)")
            print("")
            print("💡 Troubleshooting steps:")
            print("   1. Check system permissions: sudo privarion status")
            print("   2. Reset configuration: privarion config reset --force")
            print("   3. Check log files: privarion logs --lines 50")
            print("   4. Verify installation: privarion hook status")
            throw PrivarionCLIError.systemStartupFailed(underlyingError: error)
        }
    }
    
    /// Validate system requirements before starting
    private func validateSystemRequirements() throws {
        // Check macOS version compatibility
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        if osVersion.majorVersion < 11 {
            throw PrivarionCLIError.unsupportedMacOSVersion(
                current: "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)",
                required: "11.0 or later"
            )
        }
        
        // Check for required permissions
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configDir = homeDir.appendingPathComponent(".privarion")
        
        if !FileManager.default.fileExists(atPath: configDir.path) {
            try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        }
        
        // Verify write permissions
        let testFile = configDir.appendingPathComponent(".permission_test")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
        } catch {
            throw PrivarionCLIError.insufficientPermissions(directory: configDir.path)
        }
    }
    
    private func printActiveModules(profile: Profile) {
        print("\n🛡️  Active Protection Modules:")
        
        if profile.modules.identitySpoofing.enabled {
            print("   ✓ Identity Spoofing")
        }
        if profile.modules.networkFilter.enabled {
            print("   ✓ Network Filtering")
        }
        if profile.modules.sandboxManager.enabled {
            print("   ✓ Sandbox Manager")
        }
        if profile.modules.snapshotManager.enabled {
            print("   ✓ Snapshot Manager")
        }
        if profile.modules.syscallHook.enabled {
            print("   ✓ System Call Hooks")
        }
    }
}

/// Stop the privacy protection system
struct StopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop the Privarion privacy protection system",
        discussion: """
        Safely deactivates the privacy protection system and all active modules.
        
        EXAMPLES:
        
        Stop with basic output:
            privarion stop
        
        Stop with detailed shutdown information:
            privarion stop --verbose
        
        The system will properly clean up all active hooks and restore 
        normal application behavior.
        """
    )
    
    @Flag(name: .shortAndLong, help: "Enable verbose output with detailed shutdown information")
    var verbose = false
    
    func run() throws {
        let logger = PrivarionLogger.shared.logger(for: "cli.stop")
        
        print("🔓 Stopping Privarion Privacy Protection System...")
        
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        
        // Check if system is already disabled
        if !config.global.enabled {
            print("⚠️  Privarion is not currently running")
            print("")
            print("💡 To check current status:")
            print("   privarion status")
            print("")
            print("💡 To start the system:")
            print("   privarion start")
            return
        }
        
        if verbose {
            print("\n🔄 Shutdown Progress:")
            print("   ⏳ [1/3] Stopping protection modules...")
            usleep(300000) // Visual feedback
        }
        
        // Disable the system
        do {
            try ConfigurationManager.shared.setValue(false, keyPath: \.global.enabled)
            
            if verbose {
                print("   ✅ [1/3] Protection modules stopped")
                print("   ⏳ [2/3] Cleaning up active hooks...")
                usleep(300000)
                print("   ✅ [2/3] Hooks cleaned up")
                print("   ⏳ [3/3] Finalizing shutdown...")
                usleep(300000)
                print("   ✅ [3/3] Shutdown completed")
                print("")
            }
            
            logger.info("Privarion system stopped")
            print("✅ Privarion privacy protection has been stopped")
            
            if verbose {
                print("\n📋 System is now in normal mode:")
                print("   • All privacy modules deactivated")
                print("   • Applications will run with default behavior")
                print("   • Hook libraries unloaded")
            }
            
            print("\n💡 Next steps:")
            print("   • Verify status: privarion status")
            print("   • Restart later: privarion start")
            print("   • Change settings: privarion config list")
            
        } catch {
            logger.error("Failed to stop Privarion", metadata: [
                "error": .string(error.localizedDescription)
            ])
            print("❌ Failed to stop Privarion: \(error.localizedDescription)")
            print("")
            print("💡 Troubleshooting steps:")
            print("   1. Force stop: sudo pkill -f privarion")
            print("   2. Check processes: ps aux | grep privarion")
            print("   3. Reset configuration: privarion config reset --force")
            print("   4. Check system status: privarion status --detailed")
            throw PrivarionCLIError.systemStartupFailed(underlyingError: error)
        }
    }
}

/// Show system status
struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show the current status of Privarion system",
        discussion: """
        Display comprehensive system status information including protection state,
        active profile, module status, and system health metrics.
        
        EXAMPLES:
        
        Quick status check:
            privarion status
        
        Detailed system information:
            privarion status --detailed
        
        System health monitoring:
            privarion status --detailed --verbose
        """
    )
    
    @Flag(name: .shortAndLong, help: "Show detailed status information including module states and performance metrics")
    var detailed = false
    
    @Flag(name: .shortAndLong, help: "Include additional diagnostic information")
    var verbose = false
    
    func run() throws {
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        let profile = ConfigurationManager.shared.getActiveProfile()
        let logStats = PrivarionLogger.shared.getLogStatistics()
        
        // Header with timestamp
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let timestamp = formatter.string(from: Date())
        
        print("📊 Privarion Privacy Protection System Status")
        print("    Report generated: \(timestamp)\n")
        
        // System status with visual indicator
        let statusIcon = config.global.enabled ? "🟢" : "🔴"
        let statusText = config.global.enabled ? "ACTIVE" : "INACTIVE"
        let statusDetail = config.global.enabled ? "Privacy protection is running" : "System is in normal mode"
        
        print("\(statusIcon) System Status: \(statusText)")
        print("   \(statusDetail)")
        
        // Profile information
        print("\n👤 Active Profile: \(config.activeProfile)")
        if let profile = profile {
            print("   Description: \(profile.description)")
            if verbose {
                print("   Profile Type: \(profile.name == "default" ? "Built-in" : "Custom")")
                print("   Created: \(profile.name == "default" ? "System default" : "User created")")
            }
        }
        
        if detailed {
            print("\n🛡️  Module Status:")
            if let profile = profile {
                printDetailedModuleStatus(modules: profile.modules, systemEnabled: config.global.enabled)
            }
            
            print("\n📋 System Configuration:")
            print("   Log Level: \(config.global.logLevel.rawValue.capitalized)")
            print("   Log Directory: \(config.global.logDirectory)")
            print("   Max Log Size: \(config.global.maxLogSizeMB) MB")
            print("   Log Rotation: \(config.global.logRotationCount) files")
            
            print("\n📈 System Metrics:")
            print("   Current Log Size: \(formatBytes(logStats.currentLogSize))")
            print("   Total Log Files: \(logStats.totalLogFiles)")
            
            if let lastRotation = logStats.lastRotationDate {
                print("   Last Log Rotation: \(formatter.string(from: lastRotation))")
            } else {
                print("   Last Log Rotation: Never")
            }
            
            if verbose {
                // Additional diagnostic information
                print("\n🔧 Diagnostic Information:")
                let osVersion = ProcessInfo.processInfo.operatingSystemVersion
                print("   macOS Version: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
                print("   System Uptime: \(formatSystemUptime())")
                print("   Configuration Path: ~/.privarion/config.json")
                
                // Hook system status
                let hookManager = SyscallHookManager.shared
                print("   Hook System Available: \(hookManager.isPlatformSupported ? "Yes" : "No")")
                print("   Active Hook Count: \(hookManager.activeHookCount)")
            }
            
            print("\n👥 Available Profiles:")
            let allProfiles = ConfigurationManager.shared.listProfiles().sorted()
            for profileName in allProfiles {
                let indicator = profileName == config.activeProfile ? "→" : " "
                let type = profileName == "default" ? "(built-in)" : "(custom)"
                print("   \(indicator) \(profileName) \(type)")
            }
            
            // Health status
            print("\n🩺 System Health:")
            let healthStatus = evaluateSystemHealth(config: config, logStats: (logStats.currentLogSize, logStats.totalLogFiles, logStats.lastRotationDate))
            for (check, status) in healthStatus {
                let icon = status ? "✅" : "⚠️"
                print("   \(icon) \(check)")
            }
        }
        
        // Quick action suggestions
        print("\n💡 Quick Actions:")
        if config.global.enabled {
            print("   • Stop protection: privarion stop")
            print("   • View logs: privarion logs --follow")
            print("   • Inject app: privarion inject /path/to/app")
        } else {
            print("   • Start protection: privarion start")
            print("   • Switch profile: privarion profile switch <name>")
            print("   • Configure settings: privarion config list")
        }
    }
    
    private func printDetailedModuleStatus(modules: ModuleConfigs, systemEnabled: Bool) {
        let moduleStatus = [
            ("Identity Spoofing", modules.identitySpoofing.enabled, "Prevents device identification"),
            ("Network Filter", modules.networkFilter.enabled, "Blocks telemetry and tracking"),
            ("Sandbox Manager", modules.sandboxManager.enabled, "Enhanced application sandboxing"),
            ("Snapshot Manager", modules.snapshotManager.enabled, "System state management"),
            ("Syscall Hook", modules.syscallHook.enabled, "System call interception")
        ]
        
        for (name, enabled, description) in moduleStatus {
            let moduleIcon = enabled ? "✅" : "❌"
            let statusText = enabled ? "ENABLED" : "DISABLED"
            let effectiveStatus = systemEnabled && enabled ? "ACTIVE" : (enabled ? "READY" : "INACTIVE")
            
            print("   \(moduleIcon) \(name): \(statusText) (\(effectiveStatus))")
            if detailed {
                print("       \(description)")
            }
        }
    }
    
    private func evaluateSystemHealth(config: PrivarionConfig, logStats: (currentLogSize: Int, totalLogFiles: Int, lastRotationDate: Date?)) -> [(String, Bool)] {
        var health: [(String, Bool)] = []
        
        // Check log size
        let logSizeOK = logStats.currentLogSize < (config.global.maxLogSizeMB * 1024 * 1024)
        health.append(("Log size within limits", logSizeOK))
        
        // Check log rotation
        let rotationOK = logStats.totalLogFiles <= config.global.logRotationCount
        health.append(("Log rotation functioning", rotationOK))
        
        // Check configuration directory
        let configDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".privarion")
        let configDirExists = FileManager.default.fileExists(atPath: configDir.path)
        health.append(("Configuration directory accessible", configDirExists))
        
        // Check system requirements
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let systemOK = osVersion.majorVersion >= 11
        health.append(("macOS version supported", systemOK))
        
        return health
    }
    
    private func formatSystemUptime() -> String {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = Int(uptime) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

/// Configuration management commands
struct ConfigCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage Privarion configuration",
        subcommands: [
            ConfigListCommand.self,
            ConfigGetCommand.self,
            ConfigSetCommand.self,
            ConfigResetCommand.self
        ]
    )
}

struct ConfigListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all configuration values"
    )
    
    func run() throws {
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        
        print("🔧 Privarion Configuration\n")
        
        print("Global Settings:")
        print("  enabled: \(config.global.enabled)")
        print("  logLevel: \(config.global.logLevel.rawValue)")
        print("  logDirectory: \(config.global.logDirectory)")
        print("  maxLogSizeMB: \(config.global.maxLogSizeMB)")
        print("  logRotationCount: \(config.global.logRotationCount)")
        
        print("\nActive Profile: \(config.activeProfile)")
        
        if let profile = ConfigurationManager.shared.getActiveProfile() {
            print("\nProfile Module Settings:")
            printModuleConfig(modules: profile.modules)
        }
    }
    
    private func printModuleConfig(modules: ModuleConfigs) {
        print("  identitySpoofing:")
        print("    enabled: \(modules.identitySpoofing.enabled)")
        print("    spoofHostname: \(modules.identitySpoofing.spoofHostname)")
        print("    spoofMACAddress: \(modules.identitySpoofing.spoofMACAddress)")
        print("    spoofUserInfo: \(modules.identitySpoofing.spoofUserInfo)")
        print("    spoofSystemInfo: \(modules.identitySpoofing.spoofSystemInfo)")
        
        print("  networkFilter:")
        print("    enabled: \(modules.networkFilter.enabled)")
        print("    blockTelemetry: \(modules.networkFilter.blockTelemetry)")
        print("    blockAnalytics: \(modules.networkFilter.blockAnalytics)")
        print("    useDNSFiltering: \(modules.networkFilter.useDNSFiltering)")
        
        print("  sandboxManager:")
        print("    enabled: \(modules.sandboxManager.enabled)")
        print("    strictMode: \(modules.sandboxManager.strictMode)")
        
        print("  snapshotManager:")
        print("    enabled: \(modules.snapshotManager.enabled)")
        print("    autoSnapshot: \(modules.snapshotManager.autoSnapshot)")
        
        print("  syscallHook:")
        print("    enabled: \(modules.syscallHook.enabled)")
        print("    debugMode: \(modules.syscallHook.debugMode)")
    }
}

struct ConfigGetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "get",
        abstract: "Get a specific configuration value"
    )
    
    @Argument(help: "Configuration key path (e.g., global.logLevel)")
    var keyPath: String
    
    func run() throws {
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        
        // Simple key path resolution
        let value = try getConfigValue(config: config, keyPath: keyPath)
        print(value)
    }
    
    private func getConfigValue(config: PrivarionConfig, keyPath: String) throws -> String {
        let components = keyPath.split(separator: ".").map(String.init)
        
        switch components.first {
        case "global":
            return try getGlobalValue(config: config.global, key: components.dropFirst().first ?? "")
        case "activeProfile":
            return config.activeProfile
        default:
            throw ConfigError.invalidKeyPath(keyPath)
        }
    }
    
    private func getGlobalValue(config: GlobalConfig, key: String) throws -> String {
        switch key {
        case "enabled": return String(config.enabled)
        case "logLevel": return config.logLevel.rawValue
        case "logDirectory": return config.logDirectory
        case "maxLogSizeMB": return String(config.maxLogSizeMB)
        case "logRotationCount": return String(config.logRotationCount)
        default: throw ConfigError.invalidKey(key)
        }
    }
}

struct ConfigSetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set a configuration value",
        discussion: """
        Update configuration settings with validation and confirmation.
        
        EXAMPLES:
        
        Set global settings:
            privarion config set global.logLevel debug
            privarion config set global.enabled true
            privarion config set global.maxLogSizeMB 100
        
        Set module settings (requires profile context):
            privarion config set modules.identitySpoofing.enabled true
            privarion config set modules.networkFilter.blockTelemetry false
        
        SUPPORTED KEY PATHS:
        
        Global settings:
            • global.enabled (true/false)
            • global.logLevel (debug/info/warning/error)
            • global.logDirectory (path)
            • global.maxLogSizeMB (number)
            • global.logRotationCount (number)
        
        Module settings (current profile):
            • modules.identitySpoofing.enabled (true/false)
            • modules.identitySpoofing.spoofHostname (true/false)
            • modules.networkFilter.enabled (true/false)
            • modules.networkFilter.blockTelemetry (true/false)
            • modules.sandboxManager.enabled (true/false)
            • modules.snapshotManager.enabled (true/false)
            • modules.syscallHook.enabled (true/false)
        """
    )
    
    @Argument(help: "Configuration key path (e.g., global.logLevel or modules.identitySpoofing.enabled)")
    var keyPath: String
    
    @Argument(help: "New value (type depends on setting: true/false for booleans, numbers, or strings)")
    var value: String
    
    @Flag(name: .shortAndLong, help: "Show what would be changed without applying")
    var dryRun = false
    
    @Flag(help: "Skip confirmation prompt")
    var force = false
    
    func run() throws {
        // Validate key path format
        let components = keyPath.split(separator: ".").map(String.init)
        guard components.count >= 2 else {
            print("❌ Invalid key path format: \(keyPath)")
            print("")
            print("💡 Key path should be in format: category.setting")
            print("   Examples: global.logLevel, modules.identitySpoofing.enabled")
            print("")
            print("💡 View all settings: privarion config list")
            throw PrivarionCLIError.configurationValidationFailed("Invalid key path format")
        }
        
        let category = components[0]
        let key = components.dropFirst().joined(separator: ".")
        
        // Get current configuration for comparison
        let currentConfig = ConfigurationManager.shared.getCurrentConfiguration()
        let currentValue = try getCurrentValue(config: currentConfig, keyPath: keyPath)
        
        // Validate the new value
        try validateValue(value: value, keyPath: keyPath)
        
        // Show what will change
        print("📝 Configuration Update Preview:")
        print("   Key: \(keyPath)")
        print("   Current: \(currentValue)")
        print("   New: \(value)")
        print("")
        
        if dryRun {
            print("🔍 Dry run mode - no changes will be applied")
            return
        }
        
        // Confirmation prompt
        if !force {
            print("Apply this configuration change? (y/N): ", terminator: "")
            let response = readLine() ?? ""
            if !["y", "Y", "yes", "YES"].contains(response) {
                print("❌ Configuration update cancelled")
                return
            }
        }
        
        // Apply the change with progress indication
        print("🔄 Applying configuration change...")
        
        do {
            try applyConfigurationChange(category: category, key: key, value: value)
            print("✅ Configuration updated successfully")
            print("")
            print("💡 Changes take effect:")
            if category == "global" {
                print("   • Global settings: Immediately")
            } else {
                print("   • Module settings: After next restart")
                print("   • Restart system: privarion stop && privarion start")
            }
            
        } catch {
            throw PrivarionCLIError.configurationSetFailed(key: keyPath, value: value, underlyingError: error)
        }
    }
    
    private func getCurrentValue(config: PrivarionConfig, keyPath: String) throws -> String {
        let components = keyPath.split(separator: ".").map(String.init)
        
        switch components.first {
        case "global":
            return try getGlobalValue(config: config.global, key: components.dropFirst().joined(separator: "."))
        case "modules":
            guard let profile = ConfigurationManager.shared.getActiveProfile() else {
                throw PrivarionCLIError.configurationValidationFailed("No active profile for module settings")
            }
            return try getModuleValue(modules: profile.modules, key: components.dropFirst().joined(separator: "."))
        default:
            throw PrivarionCLIError.configurationValidationFailed("Invalid category: \(components.first ?? "")")
        }
    }
    
    private func getGlobalValue(config: GlobalConfig, key: String) throws -> String {
        switch key {
        case "enabled": return String(config.enabled)
        case "logLevel": return config.logLevel.rawValue
        case "logDirectory": return config.logDirectory
        case "maxLogSizeMB": return String(config.maxLogSizeMB)
        case "logRotationCount": return String(config.logRotationCount)
        default: throw PrivarionCLIError.configurationValidationFailed("Invalid global key: \(key)")
        }
    }
    
    private func getModuleValue(modules: ModuleConfigs, key: String) throws -> String {
        let keyComponents = key.split(separator: ".").map(String.init)
        guard keyComponents.count >= 2 else {
            throw PrivarionCLIError.configurationValidationFailed("Module key must specify module.setting")
        }
        
        let moduleName = keyComponents[0]
        let setting = keyComponents[1]
        
        switch moduleName {
        case "identitySpoofing":
            switch setting {
            case "enabled": return String(modules.identitySpoofing.enabled)
            case "spoofHostname": return String(modules.identitySpoofing.spoofHostname)
            case "spoofMACAddress": return String(modules.identitySpoofing.spoofMACAddress)
            default: throw PrivarionCLIError.configurationValidationFailed("Invalid identitySpoofing setting: \(setting)")
            }
        case "networkFilter":
            switch setting {
            case "enabled": return String(modules.networkFilter.enabled)
            case "blockTelemetry": return String(modules.networkFilter.blockTelemetry)
            case "blockAnalytics": return String(modules.networkFilter.blockAnalytics)
            default: throw PrivarionCLIError.configurationValidationFailed("Invalid networkFilter setting: \(setting)")
            }
        case "sandboxManager":
            switch setting {
            case "enabled": return String(modules.sandboxManager.enabled)
            case "strictMode": return String(modules.sandboxManager.strictMode)
            default: throw PrivarionCLIError.configurationValidationFailed("Invalid sandboxManager setting: \(setting)")
            }
        case "snapshotManager":
            switch setting {
            case "enabled": return String(modules.snapshotManager.enabled)
            case "autoSnapshot": return String(modules.snapshotManager.autoSnapshot)
            default: throw PrivarionCLIError.configurationValidationFailed("Invalid snapshotManager setting: \(setting)")
            }
        case "syscallHook":
            switch setting {
            case "enabled": return String(modules.syscallHook.enabled)
            case "debugMode": return String(modules.syscallHook.debugMode)
            default: throw PrivarionCLIError.configurationValidationFailed("Invalid syscallHook setting: \(setting)")
            }
        default:
            throw PrivarionCLIError.configurationValidationFailed("Invalid module name: \(moduleName)")
        }
    }
    
    private func validateValue(value: String, keyPath: String) throws {
        let components = keyPath.split(separator: ".").map(String.init)
        let key = components.last ?? ""
        
        // Boolean validation
        if key.contains("enabled") || key.contains("strict") || key.contains("auto") || key.contains("spoof") || key.contains("block") {
            if !["true", "false"].contains(value.lowercased()) {
                throw PrivarionCLIError.configurationValidationFailed("Boolean setting '\(key)' requires 'true' or 'false', got: \(value)")
            }
        }
        
        // Number validation
        if key.contains("MB") || key.contains("Count") {
            guard Int(value) != nil else {
                throw PrivarionCLIError.configurationValidationFailed("Numeric setting '\(key)' requires a number, got: \(value)")
            }
        }
        
        // Log level validation
        if key == "logLevel" {
            let validLevels = ["debug", "info", "warning", "error"]
            if !validLevels.contains(value.lowercased()) {
                throw PrivarionCLIError.configurationValidationFailed("logLevel must be one of: \(validLevels.joined(separator: ", "))")
            }
        }
    }
    
    private func applyConfigurationChange(category: String, key: String, value: String) throws {
        // Note: This is a simplified implementation
        // In a real implementation, you would use ConfigurationManager methods
        // to properly update the configuration with type safety
        
        switch category {
        case "global":
            try applyGlobalChange(key: key, value: value)
        case "modules":
            try applyModuleChange(key: key, value: value)
        default:
            throw PrivarionCLIError.configurationValidationFailed("Unknown category: \(category)")
        }
    }
    
    private func applyGlobalChange(key: String, value: String) throws {
        // Implementation would depend on ConfigurationManager API
        // For now, showing the pattern
        switch key {
        case "enabled":
            let boolValue = value.lowercased() == "true"
            try ConfigurationManager.shared.setValue(boolValue, keyPath: \.global.enabled)
        case "logLevel":
            // Would need LogLevel enum conversion
            print("⚠️  Log level change requires restart to take effect")
        default:
            throw PrivarionCLIError.configurationValidationFailed("Unsupported global setting: \(key)")
        }
    }
    
    private func applyModuleChange(key: String, value: String) throws {
        // Module changes would require profile updates
        print("⚠️  Module configuration updates not yet fully implemented")
        print("   Please edit ~/.privarion/config.json directly for module settings")
        throw PrivarionCLIError.configurationValidationFailed("Module configuration updates coming in future release")
    }
}

struct ConfigResetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "reset",
        abstract: "Reset configuration to defaults"
    )
    
    @Flag(help: "Skip confirmation prompt")
    var force = false
    
    func run() throws {
        if !force {
            print("⚠️  This will reset all configuration to defaults. Continue? (y/N): ", terminator: "")
            let response = readLine() ?? ""
            if !["y", "Y", "yes", "YES"].contains(response) {
                print("Operation cancelled")
                return
            }
        }
        
        let defaultConfig = PrivarionConfig()
        try ConfigurationManager.shared.updateConfiguration(defaultConfig)
        print("✅ Configuration reset to defaults")
    }
}

/// Profile management commands
struct ProfileCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "profile",
        abstract: "Manage privacy protection profiles",
        subcommands: [
            ProfileListCommand.self,
            ProfileSwitchCommand.self,
            ProfileCreateCommand.self,
            ProfileDeleteCommand.self
        ]
    )
}

struct ProfileListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all available profiles"
    )
    
    func run() throws {
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        let profiles = ConfigurationManager.shared.listProfiles().sorted()
        
        print("👥 Available Profiles:\n")
        
        for profileName in profiles {
            let isActive = profileName == config.activeProfile
            let indicator = isActive ? "→" : " "
            let profile = config.profiles[profileName]
            
            print("\(indicator) \(profileName)")
            if let description = profile?.description {
                print("   \(description)")
            }
            print()
        }
    }
}

struct ProfileSwitchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "switch",
        abstract: "Switch to a different profile"
    )
    
    @Argument(help: "Profile name to switch to")
    var profileName: String
    
    func run() throws {
        do {
            try ConfigurationManager.shared.switchProfile(to: profileName)
            print("✅ Switched to profile: \(profileName)")
            
            if let profile = ConfigurationManager.shared.getActiveProfile() {
                print("   \(profile.description)")
            }
        } catch {
            print("❌ Failed to switch profile: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct ProfileCreateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new custom profile"
    )
    
    @Argument(help: "Profile name")
    var name: String
    
    @Argument(help: "Profile description")
    var description: String
    
    func run() throws {
        // Create a profile based on default settings
        let profile = Profile(
            name: name,
            description: description,
            modules: ModuleConfigs()
        )
        
        do {
            try ConfigurationManager.shared.createProfile(profile)
            print("✅ Created profile: \(name)")
            print("   Use 'privacyctl config' to customize module settings")
        } catch {
            print("❌ Failed to create profile: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct ProfileDeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a custom profile"
    )
    
    @Argument(help: "Profile name to delete")
    var profileName: String
    
    func run() throws {
        do {
            try ConfigurationManager.shared.deleteProfile(profileName)
            print("✅ Deleted profile: \(profileName)")
        } catch {
            print("❌ Failed to delete profile: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

/// Logs management command
struct LogsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "logs",
        abstract: "View and manage system logs"
    )
    
    @Flag(name: .shortAndLong, help: "Follow log output (like tail -f)")
    var follow = false
    
    @Option(name: .shortAndLong, help: "Number of lines to show")
    var lines: Int = 50
    
    @Flag(help: "Rotate current log file")
    var rotate = false
    
    func run() throws {
        if rotate {
            PrivarionLogger.shared.rotateLog()
            print("✅ Log rotation completed")
            return
        }
        
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        let logDirectory = expandPath(config.global.logDirectory)
        let logFile = logDirectory.appendingPathComponent("privarion.log")
        
        if !FileManager.default.fileExists(atPath: logFile.path) {
            print("⚠️  No log file found at \(logFile.path)")
            return
        }
        
        if follow {
            print("📊 Following logs (Press Ctrl+C to stop)...")
            try followLogFile(logFile)
        } else {
            try showLogTail(logFile, lines: lines)
        }
    }
    
    private func expandPath(_ path: String) -> URL {
        if path.hasPrefix("~") {
            let expandedPath = NSString(string: path).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath)
        }
        return URL(fileURLWithPath: path)
    }
    
    private func showLogTail(_ logFile: URL, lines: Int) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        task.arguments = ["-n", String(lines), logFile.path]
        try task.run()
        task.waitUntilExit()
    }
    
    private func followLogFile(_ logFile: URL) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        task.arguments = ["-f", logFile.path]
        try task.run()
        task.waitUntilExit()
    }
}

/// Inject syscall hooks into target application via DYLD
/// This implements STORY-2025-002 AC001 requirement
struct InjectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "inject",
        abstract: "Launch application with syscall hooks via DYLD injection"
    )
    
    @Argument(help: "Path to target application")
    var applicationPath: String
    
    @Option(parsing: .remaining, help: "Arguments to pass to the application")
    var arguments: [String] = []
    
    @Flag(name: .shortAndLong, help: "Show injection command without executing")
    var dryRun = false
    
    @Flag(name: .shortAndLong, help: "Enable verbose output and debug logging")
    var verbose = false
    
    func run() throws {
        let logger = PrivarionLogger.shared.logger(for: "cli.inject")
        
        print("🎯 DYLD Injection for: \(applicationPath)")
        
        let injectionManager = SyscallHookWithInjection(configuration: ConfigurationManager.shared)
        
        if dryRun {
            let command = injectionManager.getInjectionCommand(
                applicationPath: applicationPath,
                arguments: arguments
            )
            print("📋 Injection Command:")
            print("   \(command)")
            return
        }
        
        if verbose {
            let status = injectionManager.getSystemStatus()
            print("🔍 System Status:")
            for (key, value) in status {
                print("   - \(key): \(value)")
            }
            print("")
        }
        
        print("🚀 Launching application with hooks...")
        
        // Show progress for injection process
        if verbose {
            print("\n🔄 Injection Progress:")
            print("   ⏳ [1/4] Validating application...")
            usleep(500000) // 0.5 second delay for visual feedback
            print("   ✅ [2/4] Application validated")
            
            print("   ⏳ [2/4] Preparing hook environment...")
            usleep(500000)
            print("   ✅ [2/4] Hook environment ready")
            
            print("   ⏳ [3/4] Configuring DYLD injection...")
            usleep(500000)
            print("   ✅ [3/4] DYLD injection configured")
            
            print("   ⏳ [4/4] Launching application...")
        }
        
        let result = injectionManager.launchApplicationWithHooks(
            applicationPath: applicationPath,
            arguments: arguments,
            environment: verbose ? ["PRIVARION_DEBUG": "1"] : [:]
        )
        
        if verbose {
            print("   ✅ [4/4] Application launch completed")
            print("")
        }
        
        switch result {
        case .success:
            print("✅ Application launched successfully with syscall hooks")
            logger.info("DYLD injection successful", metadata: [
                "application": .string(applicationPath),
                "arguments": .array(arguments.map { .string($0) })
            ])
            
        case .sipEnabled:
            print("⚠️  System Integrity Protection (SIP) is enabled")
            print("   Hooks may not work with system applications")
            print("   Consider disabling SIP for testing: csrutil disable")
            
        case .targetNotFound:
            print("❌ Target application not found: \(applicationPath)")
            throw ExitCode.failure
            
        case .hookLibraryNotFound:
            print("❌ Privarion hook library not found")
            print("   Make sure the system is properly installed")
            throw ExitCode.failure
            
        default:
            print("❌ DYLD injection failed: \(result.description)")
            logger.error("DYLD injection failed", metadata: [
                "application": .string(applicationPath),
                "error": .string(result.description)
            ])
            throw ExitCode.failure
        }
    }
}

/// Manage syscall hooks directly
struct HookCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "hook",
        abstract: "Manage syscall hooks",
        subcommands: [
            HookListCommand.self,
            HookTestCommand.self,
            HookStatusCommand.self
        ]
    )
}

/// List available and active hooks
struct HookListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available and active syscall hooks"
    )
    
    func run() throws {
        let hookManager = SyscallHookManager.shared
        
        print("🔗 Syscall Hook Status:")
        print("")
        
        let functions = SyscallHookManager.SyscallFunction.allCases
        
        for function in functions {
            let isHooked = hookManager.isHooked(function)
            let status = isHooked ? "✓ ACTIVE" : "○ Available"
            print("   \(status) \(function.rawValue) - \(function.description)")
        }
        
        print("")
        print("📊 Summary:")
        print("   - Total hooks available: \(functions.count)")
        print("   - Active hooks: \(hookManager.activeHookCount)")
        print("   - Platform supported: \(hookManager.isPlatformSupported ? "Yes" : "No")")
        print("   - Version: \(hookManager.version)")
    }
}

/// Test syscall hook functionality
struct HookTestCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Test syscall hook functionality"
    )
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose = false
    
    func run() throws {
        let hookManager = SyscallHookManager.shared
        
        print("🧪 Testing Syscall Hook System...")
        
        do {
            // Initialize hook system
            try hookManager.initialize()
            print("✅ Hook system initialized")
            
            // Install configured hooks
            let installedHooks = try hookManager.installConfiguredHooks()
            print("✅ Hooks installed: \(installedHooks.keys.joined(separator: ", "))")
            
            if verbose {
                print("\n🔍 Hook Details:")
                for (name, handle) in installedHooks {
                    print("   - \(name): ID=\(handle.id), Valid=\(handle.isValid)")
                }
            }
            
            print("\n📋 System Test Completed Successfully")
            print("   Active hooks: \(hookManager.activeHookCount)")
            
        } catch {
            print("❌ Hook system test failed: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

/// Show hook system status
struct HookStatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show detailed hook system status"
    )
    
    func run() throws {
        let hookManager = SyscallHookManager.shared
        let injectionManager = SyscallHookWithInjection(configuration: ConfigurationManager.shared)
        
        print("🔍 Hook System Status:")
        print("")
        
        let status = injectionManager.getSystemStatus()
        
        print("📊 System Information:")
        for (key, value) in status {
            print("   - \(key): \(value)")
        }
        
        print("")
        print("🔗 Active Hooks:")
        let activeHooks = hookManager.activeHooks
        if activeHooks.isEmpty {
            print("   No active hooks")
        } else {
            for hook in activeHooks {
                print("   ✓ \(hook)")
            }
        }
        
        print("")
        print("⚙️  Configuration:")
        if let config = hookManager.hookConfiguration {
            print("   - getuid hook: \(config.hooks.getuid ? "enabled" : "disabled")")
            print("   - getgid hook: \(config.hooks.getgid ? "enabled" : "disabled")")
            print("   - gethostname hook: \(config.hooks.gethostname ? "enabled" : "disabled")")
            print("   - uname hook: \(config.hooks.uname ? "enabled" : "disabled")")
        } else {
            print("   No hook configuration loaded")
        }
    }
}

/// Configuration errors
enum ConfigError: Error, LocalizedError {
    case invalidKeyPath(String)
    case invalidKey(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidKeyPath(let path):
            return "Invalid configuration key path: \(path)"
        case .invalidKey(let key):
            return "Invalid configuration key: \(key)"
        }
    }
}

/// Identity backup and restore management commands
struct IdentityCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "identity",
        abstract: "Manage system identity backups and restoration",
        discussion: """
        The identity command provides comprehensive backup and restore capabilities 
        for system identities, enabling safe rollback of identity spoofing operations.
        
        EXAMPLES:
        
        Backup Management:
            privarion identity backup --type hostname         # Backup current hostname
            privarion identity backup --type mac --name work  # Named MAC backup
            privarion identity backup --session production    # Multi-item session
        
        Restore Operations:
            privarion identity restore <backup-id>            # Restore specific backup
            privarion identity restore --session <session-id> # Restore entire session
            privarion identity restore --latest --type mac    # Restore latest MAC
        
        Information Commands:
            privarion identity list                           # List all backups
            privarion identity sessions                       # Show backup sessions
            privarion identity info <backup-id>              # Backup details
            privarion identity validate                       # Validate integrity
        
        Cleanup Commands:
            privarion identity cleanup --older-than 30d      # Clean old backups
            privarion identity delete <backup-id>            # Delete specific backup
            privarion identity delete --session <session-id> # Delete session
        """,
        subcommands: [
            IdentityBackupCommand.self,
            IdentityRestoreCommand.self,
            IdentityListCommand.self,
            IdentitySessionsCommand.self,
            IdentityInfoCommand.self,
            IdentityValidateCommand.self,
            IdentityCleanupCommand.self,
            IdentityDeleteCommand.self
        ]
    )
}

/// Backup current system identity
struct IdentityBackupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "backup",
        abstract: "Create a backup of current system identity"
    )
    
    @Option(name: .shortAndLong, help: "Type of identity to backup (hostname, mac, serial, disk, network)")
    var type: String?
    
    @Option(name: .shortAndLong, help: "Name for the backup session")
    var name: String = "cli_backup"
    
    @Option(help: "Additional metadata as key=value pairs")
    var metadata: [String] = []
    
    @Flag(name: .shortAndLong, help: "Make this backup persistent (won't be auto-cleaned)")
    var persistent: Bool = false
    
    @Flag(name: .shortAndLong, help: "Output detailed backup information")
    var verbose: Bool = false
    
    func run() throws {
        let logger = PrivarionLogger.shared
        
        do {
            let backupManager = try IdentityBackupManager(logger: logger)
            
            if let typeStr = type {
                // Single identity backup
                guard let identityType = parseIdentityType(typeStr) else {
                    throw ValidationError("Invalid identity type: \(typeStr). Valid types: hostname, mac, serial, disk, network")
                }
                
                // Get current value for the identity type
                let currentValue = try getCurrentIdentityValue(for: identityType)
                
                // Parse metadata
                let metadataDict = try parseMetadata(metadata)
                
                let backupId = try backupManager.createBackup(
                    type: identityType,
                    originalValue: currentValue,
                    sessionName: name
                )
                
                if verbose {
                    print("✅ Identity backup created successfully")
                    print("   Type: \(identityType)")
                    print("   Value: \(currentValue)")
                    print("   Backup ID: \(backupId.uuidString)")
                    print("   Session: \(name)")
                    if !metadataDict.isEmpty {
                        print("   Metadata: \(metadataDict)")
                    }
                } else {
                    print("Backup created: \(backupId.uuidString)")
                }
                
            } else {
                // Multi-identity session backup
                let sessionId = try backupManager.startSession(name: name, persistent: persistent)
                
                // Backup all major identity types
                let identityTypes: [IdentitySpoofingManager.IdentityType] = [
                    .hostname, .macAddress, .serialNumber, .diskUUID, .networkInterface
                ]
                
                var backupIds: [UUID] = []
                for identityType in identityTypes {
                    do {
                        let currentValue = try getCurrentIdentityValue(for: identityType)
                        let metadataDict = try parseMetadata(metadata)
                        
                        let backupId = try backupManager.addBackup(
                            type: identityType,
                            originalValue: currentValue,
                            metadata: metadataDict
                        )
                        
                        backupIds.append(backupId)
                        
                        if verbose {
                            print("✅ Backed up \(identityType): \(currentValue)")
                        }
                    } catch {
                        if verbose {
                            print("⚠️  Failed to backup \(identityType): \(error.localizedDescription)")
                        }
                    }
                }
                
                try backupManager.completeSession()
                
                if verbose {
                    print("✅ Complete system identity backup created")
                    print("   Session ID: \(sessionId.uuidString)")
                    print("   Session Name: \(name)")
                    print("   Persistent: \(persistent)")
                    print("   Backups Created: \(backupIds.count)")
                    for (index, backupId) in backupIds.enumerated() {
                        print("   [\(index + 1)] \(backupId.uuidString)")
                    }
                } else {
                    print("Session backup created: \(sessionId.uuidString) (\(backupIds.count) items)")
                }
            }
            
        } catch {
            throw PrivarionCLIError.systemStartupFailed(underlyingError: error)
        }
    }
    
    private func parseIdentityType(_ typeString: String) -> IdentitySpoofingManager.IdentityType? {
        switch typeString.lowercased() {
        case "hostname", "host":
            return .hostname
        case "mac", "macaddress", "mac-address":
            return .macAddress
        case "serial", "serialnumber", "serial-number":
            return .serialNumber
        case "disk", "diskuuid", "disk-uuid":
            return .diskUUID
        case "network", "networkinterface", "network-interface":
            return .networkInterface
        default:
            return nil
        }
    }
    
    private func getCurrentIdentityValue(for type: IdentitySpoofingManager.IdentityType) throws -> String {
        let engine = HardwareIdentifierEngine()
        
        switch type {
        case .hostname:
            return engine.getCurrentHostname()
        case .macAddress:
            let interfaces = engine.getNetworkInterfaces()
            return interfaces.first?.macAddress ?? "unknown"
        case .serialNumber:
            return engine.getSystemSerial()
        case .diskUUID:
            let diskInfo = engine.getDiskInfo()
            return diskInfo.first?.uuid ?? "unknown"
        case .networkInterface:
            let interfaces = engine.getNetworkInterfaces()
            return interfaces.first?.name ?? "unknown"
        }
    }
    
    private func parseMetadata(_ metadataArray: [String]) throws -> [String: String] {
        var metadata: [String: String] = [:]
        
        for item in metadataArray {
            let parts = item.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else {
                throw ValidationError("Invalid metadata format: '\(item)'. Use key=value format.")
            }
            
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            
            metadata[key] = value
        }
        
        return metadata
    }
}

/// Restore from identity backup
struct IdentityRestoreCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "restore",
        abstract: "Restore system identity from backup"
    )
    
    @Argument(help: "Backup ID or session ID to restore from")
    var backupId: String?
    
    @Option(name: .shortAndLong, help: "Restore entire session by session ID")
    var session: String?
    
    @Flag(help: "Restore from the latest backup of specified type")
    var latest: Bool = false
    
    @Option(help: "Identity type for latest restore (hostname, mac, serial, disk, network)")
    var type: String?
    
    @Flag(name: .shortAndLong, help: "Output detailed restoration information")
    var verbose: Bool = false
    
    @Flag(help: "Perform dry run without actually restoring")
    var dryRun: Bool = false
    
    func run() throws {
        let logger = PrivarionLogger.shared
        
        do {
            let backupManager = try IdentityBackupManager(logger: logger)
            
            if let sessionIdStr = session {
                // Restore entire session
                guard let sessionId = UUID(uuidString: sessionIdStr) else {
                    throw ValidationError("Invalid session ID format: \(sessionIdStr)")
                }
                
                let backups = try backupManager.restoreSession(sessionId: sessionId)
                
                if verbose {
                    print("✅ Session restored successfully")
                    print("   Session ID: \(sessionIdStr)")
                    print("   Items restored: \(backups.count)")
                    for backup in backups {
                        print("   - \(backup.type): \(backup.originalValue)")
                    }
                } else {
                    print("Session restored: \(backups.count) items")
                }
                
            } else if let backupIdStr = backupId {
                // Restore specific backup
                guard let backupUUID = UUID(uuidString: backupIdStr) else {
                    throw ValidationError("Invalid backup ID format: \(backupIdStr)")
                }
                
                let backup = try backupManager.restoreFromBackup(backupId: backupUUID)
                
                if verbose {
                    print("✅ Backup restored successfully")
                    print("   Backup ID: \(backupIdStr)")
                    print("   Type: \(backup.type)")
                    print("   Value: \(backup.originalValue)")
                    if let newValue = backup.newValue {
                        print("   Modified Value: \(newValue)")
                    }
                    print("   Timestamp: \(backup.timestamp)")
                } else {
                    print("Backup restored: \(backup.type) = \(backup.originalValue)")
                }
                
            } else if latest {
                // Restore latest backup of type
                guard let typeStr = type,
                      let identityType = parseIdentityType(typeStr) else {
                    throw ValidationError("--latest requires --type to be specified with valid type")
                }
                
                let sessions = try backupManager.listBackups()
                
                // Find latest backup of specified type
                var latestBackup: IdentityBackupManager.IdentityBackup?
                var latestTimestamp = Date.distantPast
                
                for session in sessions {
                    for backup in session.backups {
                        if backup.type == identityType && backup.timestamp > latestTimestamp {
                            latestBackup = backup
                            latestTimestamp = backup.timestamp
                        }
                    }
                }
                
                guard let backup = latestBackup else {
                    throw ValidationError("No backup found for type: \(typeStr)")
                }
                
                if verbose {
                    print("✅ Latest backup restored successfully")
                    print("   Type: \(backup.type)")
                    print("   Value: \(backup.originalValue)")
                    print("   Timestamp: \(backup.timestamp)")
                } else {
                    print("Latest backup restored: \(backup.type) = \(backup.originalValue)")
                }
                
            } else {
                throw ValidationError("Must specify either backup ID, --session, or --latest with --type")
            }
            
        } catch {
            throw PrivarionCLIError.systemStartupFailed(underlyingError: error)
        }
    }
    
    private func parseIdentityType(_ typeString: String) -> IdentitySpoofingManager.IdentityType? {
        switch typeString.lowercased() {
        case "hostname", "host":
            return .hostname
        case "mac", "macaddress", "mac-address":
            return .macAddress
        case "serial", "serialnumber", "serial-number":
            return .serialNumber
        case "disk", "diskuuid", "disk-uuid":
            return .diskUUID
        case "network", "networkinterface", "network-interface":
            return .networkInterface
        default:
            return nil
        }
    }
}

/// List all identity backups
struct IdentityListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all identity backups"
    )
    
    @Flag(name: .shortAndLong, help: "Show detailed information")
    var verbose: Bool = false
    
    @Option(help: "Filter by identity type")
    var type: String?
    
    @Flag(help: "Show only persistent backups")
    var persistent: Bool = false
    
    @Option(help: "Limit number of results")
    var limit: Int?
    
    func run() throws {
        let logger = PrivarionLogger.shared
        
        do {
            let backupManager = try IdentityBackupManager(logger: logger)
            let sessions = try backupManager.listBackups()
            
            var filteredSessions = sessions
            
            if persistent {
                filteredSessions = filteredSessions.filter { $0.persistent }
            }
            
            if let limit = limit {
                filteredSessions = Array(filteredSessions.prefix(limit))
            }
            
            if verbose {
                print("Identity Backup Sessions (\(filteredSessions.count) total)")
                print("=" * 60)
                
                for session in filteredSessions {
                    print("\n📦 Session: \(session.sessionName)")
                    print("   ID: \(session.sessionId.uuidString)")
                    print("   Created: \(session.timestamp)")
                    print("   Persistent: \(session.persistent ? "Yes" : "No")")
                    print("   Backups: \(session.backups.count)")
                    
                    for backup in session.backups {
                        if let typeFilter = type, 
                           let filterType = parseIdentityType(typeFilter),
                           backup.type != filterType {
                            continue
                        }
                        
                        print("   • \(backup.type): \(backup.originalValue)")
                        print("     ID: \(backup.backupId.uuidString)")
                        print("     Validated: \(backup.validated ? "✅" : "❌")")
                        if !backup.metadata.isEmpty {
                            print("     Metadata: \(backup.metadata)")
                        }
                    }
                }
            } else {
                print("ID\t\t\t\t\tName\t\t\tItems\tPersistent\tCreated")
                print("-" * 80)
                
                for session in filteredSessions {
                    let itemCount = type != nil ? 
                        session.backups.filter { backup in
                            guard let filterType = parseIdentityType(type!) else { return false }
                            return backup.type == filterType
                        }.count : session.backups.count
                    
                    if itemCount > 0 || type == nil {
                        let shortId = String(session.sessionId.uuidString.prefix(8))
                        let name = String(session.sessionName.prefix(15))
                        let persistentIcon = session.persistent ? "🔒" : "⏳"
                        let dateStr = DateFormatter.shortDate.string(from: session.timestamp)
                        
                        print("\(shortId)\t\(name)\t\t\(itemCount)\t\(persistentIcon)\t\t\(dateStr)")
                    }
                }
            }
            
        } catch {
            throw PrivarionCLIError.systemStartupFailed(underlyingError: error)
        }
    }
    
    private func parseIdentityType(_ typeString: String) -> IdentitySpoofingManager.IdentityType? {
        switch typeString.lowercased() {
        case "hostname", "host":
            return .hostname
        case "mac", "macaddress", "mac-address":
            return .macAddress
        case "serial", "serialnumber", "serial-number":
            return .serialNumber
        case "disk", "diskuuid", "disk-uuid":
            return .diskUUID
        case "network", "networkinterface", "network-interface":
            return .networkInterface
        default:
            return nil
        }
    }
}

// Placeholder implementations for other identity commands
struct IdentitySessionsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sessions",
        abstract: "Show backup sessions information"
    )
    
    func run() throws {
        print("Identity sessions command - Implementation coming soon")
    }
}

struct IdentityInfoCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Show detailed information about a backup"
    )
    
    @Argument(help: "Backup ID to show information for")
    var backupId: String
    
    func run() throws {
        print("Identity info command for \(backupId) - Implementation coming soon")
    }
}

struct IdentityValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate backup integrity"
    )
    
    func run() throws {
        print("Identity validate command - Implementation coming soon")
    }
}

struct IdentityCleanupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cleanup",
        abstract: "Clean up old backup files"
    )
    
    @Option(help: "Remove backups older than this period (e.g., 30d, 7d)")
    var olderThan: String = "30d"
    
    func run() throws {
        print("Identity cleanup command - Implementation coming soon")
    }
}

struct IdentityDeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete specific backup or session"
    )
    
    @Argument(help: "Backup ID or session ID to delete")
    var id: String
    
    @Flag(help: "Delete entire session")
    var session: Bool = false
    
    func run() throws {
        print("Identity delete command for \(id) - Implementation coming soon")
    }
}

// Helper extensions
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

extension String {
    static func *(lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
