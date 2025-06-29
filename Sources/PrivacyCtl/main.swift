import Foundation
import ArgumentParser
import PrivarionCore

/// Main CLI tool for Privarion privacy protection system
@main
struct PrivacyCtl: ParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "privacyctl",
        abstract: "Privarion Privacy Protection System Control Tool",
        discussion: """
        A comprehensive privacy protection system for macOS that prevents applications 
        from identifying your device and collecting personal information.
        
        Use 'privacyctl help <command>' for detailed information about specific commands.
        """,
        version: "1.0.0",
        subcommands: [
            StartCommand.self,
            StopCommand.self,
            StatusCommand.self,
            ConfigCommand.self,
            ProfileCommand.self,
            LogsCommand.self
        ]
    )
}

/// Start the privacy protection system
struct StartCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start the Privarion privacy protection system"
    )
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose = false
    
    @Option(name: .shortAndLong, help: "Specify profile to use")
    var profile: String?
    
    func run() throws {
        let logger = PrivarionLogger.shared.logger(for: "cli.start")
        
        print("🔒 Starting Privarion Privacy Protection System...")
        
        // Switch profile if specified
        if let profileName = profile {
            do {
                try ConfigurationManager.shared.switchProfile(to: profileName)
                print("✅ Switched to profile: \(profileName)")
            } catch {
                print("❌ Failed to switch profile: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
        
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        let activeProfile = ConfigurationManager.shared.getActiveProfile()
        
        if verbose {
            print("📋 Configuration:")
            print("   - Active Profile: \(config.activeProfile)")
            print("   - Profile Description: \(activeProfile?.description ?? "Unknown")")
            print("   - System Enabled: \(config.global.enabled)")
        }
        
        // Check if system is already enabled
        if config.global.enabled {
            print("⚠️  Privarion is already running")
            return
        }
        
        // Enable the system
        do {
            try ConfigurationManager.shared.setValue(true, keyPath: \.global.enabled)
            logger.info("Privarion system started", metadata: [
                "profile": .string(config.activeProfile)
            ])
            print("✅ Privarion privacy protection is now active")
            
            if let profile = activeProfile {
                printActiveModules(profile: profile)
            }
            
        } catch {
            logger.error("Failed to start Privarion", metadata: [
                "error": .string(error.localizedDescription)
            ])
            print("❌ Failed to start Privarion: \(error.localizedDescription)")
            throw ExitCode.failure
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
        abstract: "Stop the Privarion privacy protection system"
    )
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose = false
    
    func run() throws {
        let logger = PrivarionLogger.shared.logger(for: "cli.stop")
        
        print("🔓 Stopping Privarion Privacy Protection System...")
        
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        
        // Check if system is already disabled
        if !config.global.enabled {
            print("⚠️  Privarion is not currently running")
            return
        }
        
        // Disable the system
        do {
            try ConfigurationManager.shared.setValue(false, keyPath: \.global.enabled)
            logger.info("Privarion system stopped")
            print("✅ Privarion privacy protection has been stopped")
            
            if verbose {
                print("📋 All protection modules have been deactivated")
            }
            
        } catch {
            logger.error("Failed to stop Privarion", metadata: [
                "error": .string(error.localizedDescription)
            ])
            print("❌ Failed to stop Privarion: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

/// Show system status
struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show the current status of Privarion system"
    )
    
    @Flag(name: .shortAndLong, help: "Show detailed status information")
    var detailed = false
    
    func run() throws {
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        let profile = ConfigurationManager.shared.getActiveProfile()
        let logStats = PrivarionLogger.shared.getLogStatistics()
        
        print("📊 Privarion Privacy Protection System Status\n")
        
        // System status
        let statusIcon = config.global.enabled ? "🟢" : "🔴"
        let statusText = config.global.enabled ? "ACTIVE" : "INACTIVE"
        print("\(statusIcon) System Status: \(statusText)")
        
        // Profile information
        print("👤 Active Profile: \(config.activeProfile)")
        if let profile = profile {
            print("   Description: \(profile.description)")
        }
        
        if detailed {
            print("\n🛡️  Module Status:")
            if let profile = profile {
                printModuleStatus(modules: profile.modules)
            }
            
            print("\n📋 System Configuration:")
            print("   Log Level: \(config.global.logLevel.rawValue)")
            print("   Log Directory: \(config.global.logDirectory)")
            print("   Current Log Size: \(formatBytes(logStats.currentLogSize))")
            print("   Total Log Files: \(logStats.totalLogFiles)")
            
            if let lastRotation = logStats.lastRotationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                print("   Last Log Rotation: \(formatter.string(from: lastRotation))")
            }
            
            print("\n👥 Available Profiles:")
            for profileName in ConfigurationManager.shared.listProfiles().sorted() {
                let indicator = profileName == config.activeProfile ? "→" : " "
                print("   \(indicator) \(profileName)")
            }
        }
    }
    
    private func printModuleStatus(modules: ModuleConfigs) {
        let moduleStatus = [
            ("Identity Spoofing", modules.identitySpoofing.enabled),
            ("Network Filter", modules.networkFilter.enabled),
            ("Sandbox Manager", modules.sandboxManager.enabled),
            ("Snapshot Manager", modules.snapshotManager.enabled),
            ("Syscall Hook", modules.syscallHook.enabled)
        ]
        
        for (name, enabled) in moduleStatus {
            let icon = enabled ? "✅" : "❌"
            print("   \(icon) \(name)")
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
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
        abstract: "Set a configuration value"
    )
    
    @Argument(help: "Configuration key path")
    var keyPath: String
    
    @Argument(help: "New value")
    var value: String
    
    func run() throws {
        print("⚠️  Configuration modification through CLI not yet implemented")
        print("Please edit ~/.privarion/config.json directly for now")
        throw ExitCode.failure
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
