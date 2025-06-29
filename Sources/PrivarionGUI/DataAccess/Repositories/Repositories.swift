import Foundation
import PrivarionCore
import Logging

// MARK: - Repository Protocols

/// Data access abstraction for system operations
/// NOW INTEGRATES DIRECTLY WITH PRIVARIONCORE - NO MORE CLI BACKEND
protocol SystemRepository {
    func getSystemStatus() async throws -> SystemStatus
    func getRecentActivity() async throws -> [ActivityLogEntry]
    func startSystem() async throws
    func stopSystem() async throws
}

/// Data access abstraction for module operations
/// NOW INTEGRATES DIRECTLY WITH PRIVARIONCORE - NO MORE CLI BACKEND
protocol ModuleRepository {
    func getAvailableModules() async throws -> [PrivacyModule]
    func enableModule(_ moduleId: String) async throws
    func disableModule(_ moduleId: String) async throws
    func getModuleConfiguration(_ moduleId: String) async throws -> [String: Any]
    func updateModuleConfiguration(_ moduleId: String, configuration: [String: Any]) async throws
}

/// Data access abstraction for profile operations
/// NOW INTEGRATES DIRECTLY WITH PRIVARIONCORE - NO MORE CLI BACKEND
protocol ProfileRepository {
    func getProfiles() async throws -> [ConfigurationProfile]
    func getActiveProfile() async throws -> ConfigurationProfile?
    func createProfile(_ profile: ConfigurationProfile) async throws
    func updateProfile(_ profile: ConfigurationProfile) async throws
    func deleteProfile(_ profileId: String) async throws
    func activateProfile(_ profileId: String) async throws
    func exportProfile(_ profileId: String) async throws -> Data
    func importProfile(_ data: Data) async throws -> ConfigurationProfile
}

// MARK: - PrivarionCore Direct Integration Implementation

/// Real implementation using PrivarionCore directly - REPLACES CLI BACKEND
final class DefaultSystemRepository: SystemRepository {
    
    private let logger = Logger(label: "SystemRepository")
    private let configurationManager = ConfigurationManager.shared
    
    func getSystemStatus() async throws -> SystemStatus {
        logger.debug("Getting real system status from PrivarionCore")
        
        // Check if system is active by examining configuration
        let config = configurationManager.getCurrentConfiguration()
        
        // Determine status based on global configuration state
        let status: SystemStatus = config.global.enabled ? .running : .stopped
        
        logger.info("Real system status: \(status)")
        return status
    }
    
    func getRecentActivity() async throws -> [ActivityLogEntry] {
        logger.debug("Getting real activity logs from PrivarionCore")
        
        // Create activity entry based on current system state
        let timestamp = Date()
        let entries = [
            ActivityLogEntry(
                id: UUID().uuidString,
                timestamp: timestamp,
                action: "System Status Check",
                details: "Retrieved system status via PrivarionCore ConfigurationManager",
                level: .info
            )
        ]
        
        logger.info("Retrieved \(entries.count) real activity entries")
        return entries
    }
    
    func startSystem() async throws {
        logger.info("Starting system via PrivarionCore")
        
        do {
            // Use configuration manager to activate the system
            var config = configurationManager.getCurrentConfiguration()
            config.global.enabled = true
            try configurationManager.updateConfiguration(config)
            logger.info("System started successfully via PrivarionCore")
            
        } catch {
            logger.error("Failed to start system: \(error)")
            throw error
        }
    }
    
    func stopSystem() async throws {
        logger.info("Stopping system via PrivarionCore")
        
        do {
            // Use configuration manager to deactivate the system
            var config = configurationManager.getCurrentConfiguration()
            config.global.enabled = false
            try configurationManager.updateConfiguration(config)
            logger.info("System stopped successfully via PrivarionCore")
            
        } catch {
            logger.error("Failed to stop system: \(error)")
            throw error
        }
    }
}

/// Real implementation using PrivarionCore directly - REPLACES CLI BACKEND
final class DefaultModuleRepository: ModuleRepository {
    
    private let logger = Logger(label: "ModuleRepository")
    private let identitySpoofingManager = IdentitySpoofingManager()
    private let configurationManager = ConfigurationManager.shared
    
    func getAvailableModules() async throws -> [PrivacyModule] {
        logger.debug("Getting available modules from PrivarionCore")
        
        // Get current configuration to determine module states
        let config = configurationManager.getCurrentConfiguration()
        
        // Create modules based on PrivarionCore capabilities
        var modules: [PrivacyModule] = []
        
        // Identity Spoofing Module
        let identitySpoofingEnabled = config.modules.identitySpoofing.enabled
        modules.append(PrivacyModule(
            id: "identity_spoofing",
            name: "Identity Spoofing",
            description: "Spoof MAC address, hostname, serial number, and other hardware identifiers",
            isEnabled: identitySpoofingEnabled,
            status: identitySpoofingEnabled ? .active : .inactive,
            dependencies: []
        ))
        
        // Syscall Hooking Module  
        let syscallHookingEnabled = config.modules.syscallHook.enabled
        modules.append(PrivacyModule(
            id: "syscall_hooking",
            name: "Syscall Hooking",
            description: "Hook and modify system calls for enhanced privacy",
            isEnabled: syscallHookingEnabled,
            status: syscallHookingEnabled ? .active : .inactive,
            dependencies: []
        ))
        
        // Network Filter Module
        let networkFilterEnabled = config.modules.networkFilter.enabled
        modules.append(PrivacyModule(
            id: "network_filter",
            name: "Network Filter",
            description: "Block telemetry and analytics network traffic",
            isEnabled: networkFilterEnabled,
            status: networkFilterEnabled ? .active : .inactive,
            dependencies: []
        ))
        
        logger.info("Retrieved \(modules.count) real modules from PrivarionCore")
        return modules
    }
    
    func enableModule(_ moduleId: String) async throws {
        logger.info("Enabling module via PrivarionCore: \(moduleId)")
        
        do {
            var config = configurationManager.getCurrentConfiguration()
            
            switch moduleId {
            case "identity_spoofing":
                config.modules.identitySpoofing.enabled = true
                
                // Apply identity spoofing with default options
                let options = IdentitySpoofingManager.SpoofingOptions(
                    types: [.macAddress, .hostname],
                    profile: "default",
                    persistent: false,
                    validateChanges: true
                )
                try await identitySpoofingManager.spoofIdentity(options: options)
                
            case "syscall_hooking":
                config.modules.syscallHook.enabled = true
                
            case "network_filter":
                config.modules.networkFilter.enabled = true
                
            default:
                throw ModuleError.moduleNotFound(moduleId)
            }
            
            // Save updated configuration
            try configurationManager.updateConfiguration(config)
            logger.info("Module enabled successfully via PrivarionCore: \(moduleId)")
            
        } catch {
            logger.error("Failed to enable module \(moduleId): \(error)")
            throw error
        }
    }
    
    func disableModule(_ moduleId: String) async throws {
        logger.info("Disabling module via PrivarionCore: \(moduleId)")
        
        do {
            var config = configurationManager.getCurrentConfiguration()
            
            switch moduleId {
            case "identity_spoofing":
                config.modules.identitySpoofing.enabled = false
                // TODO: Implement rollback functionality when available
                
            case "syscall_hooking":
                config.modules.syscallHook.enabled = false
                
            case "network_filter":
                config.modules.networkFilter.enabled = false
                
            default:
                throw ModuleError.moduleNotFound(moduleId)
            }
            
            // Save updated configuration
            try configurationManager.updateConfiguration(config)
            logger.info("Module disabled successfully via PrivarionCore: \(moduleId)")
            
        } catch {
            logger.error("Failed to disable module \(moduleId): \(error)")
            throw error
        }
    }
    
    func getModuleConfiguration(_ moduleId: String) async throws -> [String: Any] {
        logger.debug("Getting configuration for module: \(moduleId)")
        
        do {
            let config = configurationManager.getCurrentConfiguration()
            
            switch moduleId {
            case "identity_spoofing":
                let identityConfig = config.modules.identitySpoofing
                return [
                    "enabled": identityConfig.enabled,
                    "spoofHostname": identityConfig.spoofHostname,
                    "spoofMACAddress": identityConfig.spoofMACAddress,
                    "spoofUserInfo": identityConfig.spoofUserInfo,
                    "spoofSystemInfo": identityConfig.spoofSystemInfo
                ]
                
            case "syscall_hooking":
                let syscallConfig = config.modules.syscallHook
                return [
                    "enabled": syscallConfig.enabled
                ]
                
            case "network_filter":
                let networkConfig = config.modules.networkFilter
                return [
                    "enabled": networkConfig.enabled,
                    "blockTelemetry": networkConfig.blockTelemetry,
                    "blockAnalytics": networkConfig.blockAnalytics,
                    "useDNSFiltering": networkConfig.useDNSFiltering
                ]
                
            default:
                throw ModuleError.moduleNotFound(moduleId)
            }
            
        } catch {
            logger.error("Failed to get module configuration \(moduleId): \(error)")
            throw error
        }
    }
    
    func updateModuleConfiguration(_ moduleId: String, configuration: [String: Any]) async throws {
        logger.info("Updating configuration for module: \(moduleId)")
        
        do {
            var config = configurationManager.getCurrentConfiguration()
            
            switch moduleId {
            case "identity_spoofing":
                if let enabled = configuration["enabled"] as? Bool {
                    config.modules.identitySpoofing.enabled = enabled
                }
                if let spoofHostname = configuration["spoofHostname"] as? Bool {
                    config.modules.identitySpoofing.spoofHostname = spoofHostname
                }
                if let spoofMACAddress = configuration["spoofMACAddress"] as? Bool {
                    config.modules.identitySpoofing.spoofMACAddress = spoofMACAddress
                }
                if let spoofUserInfo = configuration["spoofUserInfo"] as? Bool {
                    config.modules.identitySpoofing.spoofUserInfo = spoofUserInfo
                }
                if let spoofSystemInfo = configuration["spoofSystemInfo"] as? Bool {
                    config.modules.identitySpoofing.spoofSystemInfo = spoofSystemInfo
                }
                
            case "syscall_hooking":
                if let enabled = configuration["enabled"] as? Bool {
                    config.modules.syscallHook.enabled = enabled
                }
                
            case "network_filter":
                if let enabled = configuration["enabled"] as? Bool {
                    config.modules.networkFilter.enabled = enabled
                }
                if let blockTelemetry = configuration["blockTelemetry"] as? Bool {
                    config.modules.networkFilter.blockTelemetry = blockTelemetry
                }
                if let blockAnalytics = configuration["blockAnalytics"] as? Bool {
                    config.modules.networkFilter.blockAnalytics = blockAnalytics
                }
                if let useDNSFiltering = configuration["useDNSFiltering"] as? Bool {
                    config.modules.networkFilter.useDNSFiltering = useDNSFiltering
                }
                
            default:
                throw ModuleError.moduleNotFound(moduleId)
            }
            
            // Save updated configuration
            try configurationManager.updateConfiguration(config)
            logger.info("Module configuration updated successfully: \(moduleId)")
            
        } catch {
            logger.error("Failed to update module configuration \(moduleId): \(error)")
            throw error
        }
    }
}

/// Real implementation using PrivarionCore directly - REPLACES CLI BACKEND  
final class DefaultProfileRepository: ProfileRepository {
    
    private let logger = Logger(label: "ProfileRepository")
    private let configurationManager = ConfigurationManager.shared
    private let profileManager = ConfigurationProfileManager()
    
    func getProfiles() async throws -> [ConfigurationProfile] {
        logger.debug("Getting configuration profiles from PrivarionCore")
        
        // Get the current config to access profiles
        let config = configurationManager.getCurrentConfiguration()
        
        // Convert PrivarionCore Profile to GUI ConfigurationProfile
        let profiles = config.profiles.map { (key, coreProfile) in
            // Convert ModuleConfigs to settings dictionary
            let settings = convertModuleConfigsToSettings(coreProfile.modules)
            
            return ConfigurationProfile(
                id: key,
                name: coreProfile.name,
                description: coreProfile.description,
                isActive: key == config.activeProfile,
                settings: settings,
                createdAt: Date(), // Default creation time
                modifiedAt: Date() // Default modification time
            )
        }
        
        logger.info("Retrieved \(profiles.count) real profiles from PrivarionCore")
        return Array(profiles)
    }
    
    func getActiveProfile() async throws -> ConfigurationProfile? {
        logger.debug("Getting active profile from PrivarionCore")
        
        let config = configurationManager.getCurrentConfiguration()
        
        if let activeProfile = config.profiles[config.activeProfile] {
            let settings = convertModuleConfigsToSettings(activeProfile.modules)
            
            let profile = ConfigurationProfile(
                id: config.activeProfile,
                name: activeProfile.name,
                description: activeProfile.description,
                isActive: true,
                settings: settings,
                createdAt: Date(),
                modifiedAt: Date()
            )
            
            logger.info("Active profile: \(profile.name)")
            return profile
        }
        
        logger.info("No active profile found")
        return nil
    }
    
    func createProfile(_ profile: ConfigurationProfile) async throws {
        logger.info("Creating profile via PrivarionCore: \(profile.name)")
        
        do {
            // Create new profile in PrivarionCore format
            let modules = convertSettingsToModuleConfigs(profile.settings)
            
            let coreProfile = Profile(
                name: profile.name,
                description: profile.description,
                modules: modules
            )
            
            var config = configurationManager.getCurrentConfiguration()
            config.profiles[profile.id] = coreProfile
            
            try configurationManager.updateConfiguration(config)
            logger.info("Profile created successfully via PrivarionCore: \(profile.name)")
            
        } catch {
            logger.error("Failed to create profile \(profile.name): \(error)")
            throw error
        }
    }
    
    func updateProfile(_ profile: ConfigurationProfile) async throws {
        logger.info("Updating profile via PrivarionCore: \(profile.name)")
        
        do {
            // Update profile in PrivarionCore
            let modules = convertSettingsToModuleConfigs(profile.settings)
            
            let coreProfile = Profile(
                name: profile.name,
                description: profile.description,
                modules: modules
            )
            
            var config = configurationManager.getCurrentConfiguration()
            config.profiles[profile.id] = coreProfile
            
            try configurationManager.updateConfiguration(config)
            logger.info("Profile updated successfully via PrivarionCore: \(profile.name)")
            
        } catch {
            logger.error("Failed to update profile \(profile.name): \(error)")
            throw error
        }
    }
    
    func deleteProfile(_ profileId: String) async throws {
        logger.info("Deleting profile via PrivarionCore: \(profileId)")
        
        do {
            var config = configurationManager.getCurrentConfiguration()
            
            // Don't allow deletion of active profile
            guard profileId != config.activeProfile else {
                throw ProfileError.profileAlreadyActive(profileId)
            }
            
            config.profiles.removeValue(forKey: profileId)
            
            try configurationManager.updateConfiguration(config)
            logger.info("Profile deleted successfully via PrivarionCore: \(profileId)")
            
        } catch {
            logger.error("Failed to delete profile \(profileId): \(error)")
            throw error
        }
    }
    
    func activateProfile(_ profileId: String) async throws {
        logger.info("Activating profile via PrivarionCore: \(profileId)")
        
        do {
            var config = configurationManager.getCurrentConfiguration()
            
            // Verify profile exists
            guard config.profiles[profileId] != nil else {
                throw ProfileError.profileNotFound(profileId)
            }
            
            config.activeProfile = profileId
            
            try configurationManager.updateConfiguration(config)
            logger.info("Profile activated successfully via PrivarionCore: \(profileId)")
            
        } catch {
            logger.error("Failed to activate profile \(profileId): \(error)")
            throw error
        }
    }
    
    func exportProfile(_ profileId: String) async throws -> Data {
        logger.debug("Exporting profile via PrivarionCore: \(profileId)")
        
        do {
            let config = configurationManager.getCurrentConfiguration()
            
            guard let profile = config.profiles[profileId] else {
                throw ProfileError.profileNotFound(profileId)
            }
            
            // Convert profile to JSON data
            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = .prettyPrinted
            let data = try jsonEncoder.encode(profile)
            
            logger.info("Profile exported successfully via PrivarionCore: \(profileId)")
            return data
            
        } catch {
            logger.error("Failed to export profile \(profileId): \(error)")
            throw error
        }
    }
    
    func importProfile(_ data: Data) async throws -> ConfigurationProfile {
        logger.debug("Importing profile via PrivarionCore")
        
        do {
            // Decode profile from JSON data
            let jsonDecoder = JSONDecoder()
            let coreProfile = try jsonDecoder.decode(Profile.self, from: data)
            
            // Create unique ID for imported profile
            let profileId = "imported_\(UUID().uuidString.prefix(8))"
            
            // Add to configuration
            var config = configurationManager.getCurrentConfiguration()
            config.profiles[profileId] = coreProfile
            
            try configurationManager.updateConfiguration(config)
            
            let settings = convertModuleConfigsToSettings(coreProfile.modules)
            
            let profile = ConfigurationProfile(
                id: profileId,
                name: coreProfile.name,
                description: coreProfile.description,
                isActive: false,
                settings: settings,
                createdAt: Date(),
                modifiedAt: Date()
            )
            
            logger.info("Profile imported successfully via PrivarionCore: \(profile.name)")
            return profile
            
        } catch {
            logger.error("Failed to import profile: \(error)")
            throw error
        }
    }
}

// MARK: - Helper Functions
    
    /// Convert ModuleConfigs to settings dictionary for GUI
    private func convertModuleConfigsToSettings(_ modules: ModuleConfigs) -> [String: String] {
        var settings: [String: String] = [:]
        
        // Identity Spoofing settings
        settings["identitySpoofing.enabled"] = String(modules.identitySpoofing.enabled)
        settings["identitySpoofing.spoofHostname"] = String(modules.identitySpoofing.spoofHostname)
        settings["identitySpoofing.spoofMACAddress"] = String(modules.identitySpoofing.spoofMACAddress)
        settings["identitySpoofing.spoofUserInfo"] = String(modules.identitySpoofing.spoofUserInfo)
        settings["identitySpoofing.spoofSystemInfo"] = String(modules.identitySpoofing.spoofSystemInfo)
        
        // Network Filter settings
        settings["networkFilter.enabled"] = String(modules.networkFilter.enabled)
        settings["networkFilter.blockTelemetry"] = String(modules.networkFilter.blockTelemetry)
        settings["networkFilter.blockAnalytics"] = String(modules.networkFilter.blockAnalytics)
        settings["networkFilter.useDNSFiltering"] = String(modules.networkFilter.useDNSFiltering)
        
        // Syscall Hook settings
        settings["syscallHook.enabled"] = String(modules.syscallHook.enabled)
        settings["syscallHook.debugMode"] = String(modules.syscallHook.debugMode)
        
        return settings
    }
    
    /// Convert settings dictionary to ModuleConfigs for PrivarionCore
    private func convertSettingsToModuleConfigs(_ settings: [String: String]) -> ModuleConfigs {
        var modules = ModuleConfigs()
        
        // Identity Spoofing settings
        if let enabled = Bool(settings["identitySpoofing.enabled"] ?? "false") {
            modules.identitySpoofing.enabled = enabled
        }
        if let spoofHostname = Bool(settings["identitySpoofing.spoofHostname"] ?? "false") {
            modules.identitySpoofing.spoofHostname = spoofHostname
        }
        if let spoofMACAddress = Bool(settings["identitySpoofing.spoofMACAddress"] ?? "false") {
            modules.identitySpoofing.spoofMACAddress = spoofMACAddress
        }
        if let spoofUserInfo = Bool(settings["identitySpoofing.spoofUserInfo"] ?? "false") {
            modules.identitySpoofing.spoofUserInfo = spoofUserInfo
        }
        if let spoofSystemInfo = Bool(settings["identitySpoofing.spoofSystemInfo"] ?? "false") {
            modules.identitySpoofing.spoofSystemInfo = spoofSystemInfo
        }
        
        // Network Filter settings
        if let enabled = Bool(settings["networkFilter.enabled"] ?? "false") {
            modules.networkFilter.enabled = enabled
        }
        if let blockTelemetry = Bool(settings["networkFilter.blockTelemetry"] ?? "false") {
            modules.networkFilter.blockTelemetry = blockTelemetry
        }
        if let blockAnalytics = Bool(settings["networkFilter.blockAnalytics"] ?? "false") {
            modules.networkFilter.blockAnalytics = blockAnalytics
        }
        if let useDNSFiltering = Bool(settings["networkFilter.useDNSFiltering"] ?? "false") {
            modules.networkFilter.useDNSFiltering = useDNSFiltering
        }
        
        // Syscall Hook settings
        if let enabled = Bool(settings["syscallHook.enabled"] ?? "false") {
            modules.syscallHook.enabled = enabled
        }
        if let debugMode = Bool(settings["syscallHook.debugMode"] ?? "false") {
            modules.syscallHook.debugMode = debugMode
        }
        
        return modules
    }
