import Foundation
import Combine
import PrivarionCore
import Logging

// MARK: - Error Types

/// Module operation errors
enum ModuleError: Error {
    case moduleNotFound(String)
    case moduleAlreadyEnabled(String)
    case moduleAlreadyDisabled(String)
    case dependencyError(String)
    case configurationError(String)
}

/// Profile operation errors
enum ProfileError: Error {
    case profileNotFound(String)
    case profileAlreadyActive(String)
    case invalidProfileData
    case exportError(String)
    case importError(String)
}

// MARK: - System Interactor Protocol

/// Business logic for system operations and status management
/// Following Clean Architecture pattern - coordinates between UI and Data Access
protocol SystemInteractor {
    func getSystemStatus() async throws -> SystemStatus
    func getRecentActivity() async throws -> [ActivityLogEntry]
    func startSystem() async throws
    func stopSystem() async throws
}

// MARK: - Module Interactor Protocol

/// Business logic for privacy module management
protocol ModuleInteractor {
    func getAvailableModules() async throws -> [PrivacyModule]
    func enableModule(_ moduleId: String) async throws
    func disableModule(_ moduleId: String) async throws
    func toggleModule(_ moduleId: String) async throws
    func getModuleConfiguration(_ moduleId: String) async throws -> [String: Any]
    func updateModuleConfiguration(_ moduleId: String, configuration: [String: Any]) async throws
}

// MARK: - Profile Interactor Protocol

/// Business logic for configuration profile management
protocol ProfileInteractor {
    func getProfiles() async throws -> [ConfigurationProfile]
    func getActiveProfile() async throws -> ConfigurationProfile?
    func createProfile(_ profile: ConfigurationProfile) async throws
    func updateProfile(_ profile: ConfigurationProfile) async throws
    func deleteProfile(_ profileId: String) async throws
    func activateProfile(_ profileId: String) async throws
    func exportProfile(_ profileId: String) async throws -> Data
    func importProfile(_ data: Data) async throws -> ConfigurationProfile
}

// MARK: - Default Implementations

/// Default implementation of SystemInteractor using CLI backend
final class DefaultSystemInteractor: SystemInteractor {
    
    private let logger = Logger(label: "SystemInteractor")
    private let systemRepository: SystemRepository
    
    init(systemRepository: SystemRepository = DefaultSystemRepository()) {
        self.systemRepository = systemRepository
    }
    
    func getSystemStatus() async throws -> SystemStatus {
        logger.debug("Getting system status")
        let status = try await systemRepository.getSystemStatus()
        logger.info("System status retrieved: \\(status)")
        return status
    }
    
    func getRecentActivity() async throws -> [ActivityLogEntry] {
        logger.debug("Getting recent activity")
        let activity = try await systemRepository.getRecentActivity()
        logger.info("Retrieved \\(activity.count) activity entries")
        return activity
    }
    
    func startSystem() async throws {
        logger.info("Starting system")
        try await systemRepository.startSystem()
        logger.info("System started successfully")
    }
    
    func stopSystem() async throws {
        logger.info("Stopping system")
        try await systemRepository.stopSystem()
        logger.info("System stopped successfully")
    }
}

/// Default implementation of ModuleInteractor using CLI backend
final class DefaultModuleInteractor: ModuleInteractor {
    
    private let logger = Logger(label: "ModuleInteractor")
    private let moduleRepository: ModuleRepository
    
    init(moduleRepository: ModuleRepository = DefaultModuleRepository()) {
        self.moduleRepository = moduleRepository
    }
    
    func getAvailableModules() async throws -> [PrivacyModule] {
        logger.debug("Getting available modules")
        let modules = try await moduleRepository.getAvailableModules()
        logger.info("Retrieved \\(modules.count) modules")
        return modules
    }
    
    func enableModule(_ moduleId: String) async throws {
        logger.info("Enabling module: \\(moduleId)")
        try await moduleRepository.enableModule(moduleId)
        logger.info("Module enabled successfully: \\(moduleId)")
    }
    
    func disableModule(_ moduleId: String) async throws {
        logger.info("Disabling module: \\(moduleId)")
        try await moduleRepository.disableModule(moduleId)
        logger.info("Module disabled successfully: \\(moduleId)")
    }
    
    func toggleModule(_ moduleId: String) async throws {
        logger.info("Toggling module: \(moduleId)")
        // First get the current state, then toggle it
        let modules = try await moduleRepository.getAvailableModules()
        guard let module = modules.first(where: { $0.id == moduleId }) else {
            throw ModuleError.moduleNotFound(moduleId)
        }
        
        if module.isEnabled {
            try await disableModule(moduleId)
        } else {
            try await enableModule(moduleId)
        }
        logger.info("Module toggled successfully: \(moduleId)")
    }
    
    func getModuleConfiguration(_ moduleId: String) async throws -> [String: Any] {
        logger.debug("Getting configuration for module: \\(moduleId)")
        let config = try await moduleRepository.getModuleConfiguration(moduleId)
        logger.info("Retrieved configuration for module: \\(moduleId)")
        return config
    }
    
    func updateModuleConfiguration(_ moduleId: String, configuration: [String: Any]) async throws {
        logger.info("Updating configuration for module: \\(moduleId)")
        try await moduleRepository.updateModuleConfiguration(moduleId, configuration: configuration)
        logger.info("Configuration updated for module: \\(moduleId)")
    }
}

/// Default implementation of ProfileInteractor using CLI backend
final class DefaultProfileInteractor: ProfileInteractor {
    
    private let logger = Logger(label: "ProfileInteractor")
    private let profileRepository: ProfileRepository
    
    init(profileRepository: ProfileRepository = DefaultProfileRepository()) {
        self.profileRepository = profileRepository
    }
    
    func getProfiles() async throws -> [ConfigurationProfile] {
        logger.debug("Getting configuration profiles")
        let profiles = try await profileRepository.getProfiles()
        logger.info("Retrieved \\(profiles.count) profiles")
        return profiles
    }
    
    func getActiveProfile() async throws -> ConfigurationProfile? {
        logger.debug("Getting active profile")
        let profile = try await profileRepository.getActiveProfile()
        if let profile = profile {
            logger.info("Active profile: \(profile.name)")
        } else {
            logger.info("No active profile")
        }
        return profile
    }
    
    func createProfile(_ profile: ConfigurationProfile) async throws {
        logger.info("Creating profile: \\(profile.name)")
        try await profileRepository.createProfile(profile)
        logger.info("Profile created successfully: \\(profile.name)")
    }
    
    func updateProfile(_ profile: ConfigurationProfile) async throws {
        logger.info("Updating profile: \\(profile.name)")
        try await profileRepository.updateProfile(profile)
        logger.info("Profile updated successfully: \\(profile.name)")
    }
    
    func deleteProfile(_ profileId: String) async throws {
        logger.info("Deleting profile: \\(profileId)")
        try await profileRepository.deleteProfile(profileId)
        logger.info("Profile deleted successfully: \\(profileId)")
    }
    
    func activateProfile(_ profileId: String) async throws {
        logger.info("Activating profile: \\(profileId)")
        try await profileRepository.activateProfile(profileId)
        logger.info("Profile activated successfully: \\(profileId)")
    }
    
    func exportProfile(_ profileId: String) async throws -> Data {
        logger.debug("Exporting profile: \\(profileId)")
        let data = try await profileRepository.exportProfile(profileId)
        logger.info("Profile exported successfully: \\(profileId)")
        return data
    }
    
    func importProfile(_ data: Data) async throws -> ConfigurationProfile {
        logger.debug("Importing profile from data")
        let profile = try await profileRepository.importProfile(data)
        logger.info("Profile imported successfully: \(profile.name)")
        return profile
    }
}
