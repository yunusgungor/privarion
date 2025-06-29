import SwiftUI
import Foundation
import Logging

/// User settings and preferences management using @AppStorage
/// Following Context7 research: SwiftUI @AppStorage property wrappers for persistence
/// Based on Clean Architecture pattern with centralized settings management
@MainActor
final class UserSettings: ObservableObject {
    
    // MARK: - Application Settings
    
    /// Enable application logging
    @AppStorage("enableLogging") var enableLogging: Bool = true
    
    /// Application log level
    @AppStorage("logLevel") var logLevel: String = "Info"
    
    /// Auto start application on login
    @AppStorage("autoStart") var autoStart: Bool = false
    
    /// Show system notifications
    @AppStorage("showNotifications") var showNotifications: Bool = true
    
    /// Theme preference (light, dark, auto)
    @AppStorage("theme") var theme: String = "auto"
    
    /// Application accent color (stored as hex string)
    @AppStorage("accentColor") var accentColorHex: String = "#007AFF"
    
    /// Computed property for SwiftUI Color
    var accentColor: Color {
        get {
            // Simple color mapping for now
            switch accentColorHex {
            case "#007AFF": return .blue
            case "#FF3B30": return .red
            case "#34C759": return .green
            case "#FF9500": return .orange
            case "#AF52DE": return .purple
            case "#FF2D92": return .pink
            default: return .blue
            }
        }
        set {
            // Simple reverse mapping
            switch newValue {
            case .blue: accentColorHex = "#007AFF"
            case .red: accentColorHex = "#FF3B30"
            case .green: accentColorHex = "#34C759"
            case .orange: accentColorHex = "#FF9500"
            case .purple: accentColorHex = "#AF52DE"
            case .pink: accentColorHex = "#FF2D92"
            default: accentColorHex = "#007AFF"
            }
        }
    }
    
    /// Application language
    @AppStorage("language") var language: String = "en"
    
    /// Enable analytics
    @AppStorage("enableAnalytics") var enableAnalytics: Bool = true
    
    /// Enable crash reporting
    @AppStorage("enableCrashReporting") var enableCrashReporting: Bool = true
    
    /// Enable module logging
    @AppStorage("enableModuleLogging") var enableModuleLogging: Bool = true
    
    /// Maximum log entries to keep
    @AppStorage("maxLogEntries") var maxLogEntries: Double = 1000.0
    
    /// Enable background updates
    @AppStorage("enableBackgroundUpdates") var enableBackgroundUpdates: Bool = true
    
    /// Enable debug mode
    @AppStorage("enableDebugMode") var enableDebugMode: Bool = false
    
    /// Enable beta features
    @AppStorage("enableBetaFeatures") var enableBetaFeatures: Bool = false
    
    /// Refresh interval for real-time updates (in seconds)
    @AppStorage("refreshInterval") var refreshInterval: Int = 15
    
    /// Maximum number of recent activity entries to display
    @AppStorage("maxRecentActivity") var maxRecentActivity: Int = 100
    
    /// Show detailed module information
    @AppStorage("showDetailedModuleInfo") var showDetailedModuleInfo: Bool = true
    
    /// Enable sound notifications
    @AppStorage("enableSoundNotifications") var enableSoundNotifications: Bool = false
    
    /// Sidebar width preference
    @AppStorage("sidebarWidth") var sidebarWidth: Double = 250.0
    
    // MARK: - Privacy Settings
    
    /// Enable privacy analytics
    @AppStorage("enablePrivacyAnalytics") var enablePrivacyAnalytics: Bool = true
    
    /// Automatically apply privacy profiles
    @AppStorage("autoApplyProfiles") var autoApplyProfiles: Bool = false
    
    /// Show privacy status in menu bar
    @AppStorage("showPrivacyStatusInMenuBar") var showPrivacyStatusInMenuBar: Bool = true
    
    // MARK: - Developer Settings
    
    /// Enable debug mode
    @AppStorage("debugMode") var debugMode: Bool = false
    
    /// Show developer options
    @AppStorage("showDeveloperOptions") var showDeveloperOptions: Bool = false
    
    /// Enable verbose logging
    @AppStorage("verboseLogging") var verboseLogging: Bool = false
    
    // MARK: - Cache Settings
    
    /// Last selected profile ID
    @AppStorage("lastSelectedProfileId") var lastSelectedProfileId: String = ""
    
    /// Last used window frame (JSON string)
    @AppStorage("lastWindowFrame") var lastWindowFrame: String = ""
    
    /// Recently used module IDs (comma-separated)
    @AppStorage("recentlyUsedModules") var recentlyUsedModules: String = ""
    
    /// User's preferred language
    @AppStorage("preferredLanguage") var preferredLanguage: String = "en"
    
    // MARK: - Singleton Instance
    
    static let shared = UserSettings()
    
    private let logger = Logger(label: "UserSettings")
    
    // MARK: - Initialization
    
    private init() {
        logger.info("UserSettings initialized with @AppStorage persistence")
        setupInitialSettings()
    }
    
    // MARK: - Public Methods
    
    /// Reset all settings to default values
    func resetToDefaults() {
        logger.info("Resetting all settings to defaults")
        
        enableLogging = true
        logLevel = "Info"
        autoStart = false
        showNotifications = true
        theme = "auto"
        refreshInterval = 15
        maxRecentActivity = 100
        showDetailedModuleInfo = true
        enableSoundNotifications = false
        sidebarWidth = 250.0
        
        language = "en"
        accentColorHex = "#007AFF"
        enableAnalytics = true
        enableCrashReporting = true
        enableModuleLogging = true
        maxLogEntries = 1000.0
        enableBackgroundUpdates = true
        enableDebugMode = false
        enableBetaFeatures = false
        
        enablePrivacyAnalytics = true
        autoApplyProfiles = false
        showPrivacyStatusInMenuBar = true
        
        debugMode = false
        showDeveloperOptions = false
        verboseLogging = false
        
        lastSelectedProfileId = ""
        lastWindowFrame = ""
        recentlyUsedModules = ""
        preferredLanguage = "en"
        
        logger.info("Settings reset completed")
    }
    
    /// Export settings as JSON
    func exportSettings() -> Data? {
        let settings: [String: Any] = [
            "enableLogging": enableLogging,
            "logLevel": logLevel,
            "autoStart": autoStart,
            "showNotifications": showNotifications,
            "theme": theme,
            "refreshInterval": refreshInterval,
            "maxRecentActivity": maxRecentActivity,
            "showDetailedModuleInfo": showDetailedModuleInfo,
            "enableSoundNotifications": enableSoundNotifications,
            "sidebarWidth": sidebarWidth,
            "language": language,
            "accentColorHex": accentColorHex,
            "enableAnalytics": enableAnalytics,
            "enableCrashReporting": enableCrashReporting,
            "enableModuleLogging": enableModuleLogging,
            "maxLogEntries": maxLogEntries,
            "enableBackgroundUpdates": enableBackgroundUpdates,
            "enableDebugMode": enableDebugMode,
            "enableBetaFeatures": enableBetaFeatures,
            "enablePrivacyAnalytics": enablePrivacyAnalytics,
            "autoApplyProfiles": autoApplyProfiles,
            "showPrivacyStatusInMenuBar": showPrivacyStatusInMenuBar,
            "debugMode": debugMode,
            "showDeveloperOptions": showDeveloperOptions,
            "verboseLogging": verboseLogging,
            "preferredLanguage": preferredLanguage
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            logger.info("Settings exported successfully")
            return data
        } catch {
            logger.error("Failed to export settings: \(error)")
            return nil
        }
    }
    
    /// Export settings as Data for FileDocument
    func exportData() throws -> Data {
        guard let data = exportSettings() else {
            throw PrivarionError.settingsExportFailed(reason: "Failed to serialize settings to JSON")
        }
        return data
    }
    
    /// Import settings from URL
    func importSettings(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let success = importSettings(from: data)
            if !success {
                logger.error("Failed to import settings from URL: \(url)")
            }
        } catch {
            logger.error("Failed to read settings file: \(error)")
        }
    }
    
    /// Import settings from JSON
    func importSettings(from data: Data) -> Bool {
        do {
            guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                logger.error("Invalid settings format")
                return false
            }
            
            // Apply settings with validation
            if let value = settings["enableLogging"] as? Bool { enableLogging = value }
            if let value = settings["logLevel"] as? String, isValidLogLevel(value) { logLevel = value }
            if let value = settings["autoStart"] as? Bool { autoStart = value }
            if let value = settings["showNotifications"] as? Bool { showNotifications = value }
            if let value = settings["theme"] as? String, isValidTheme(value) { theme = value }
            if let value = settings["refreshInterval"] as? Int, value >= 5 && value <= 300 { refreshInterval = value }
            if let value = settings["maxRecentActivity"] as? Int, value >= 10 && value <= 1000 { maxRecentActivity = value }
            if let value = settings["showDetailedModuleInfo"] as? Bool { showDetailedModuleInfo = value }
            if let value = settings["enableSoundNotifications"] as? Bool { enableSoundNotifications = value }
            if let value = settings["sidebarWidth"] as? Double, value >= 200 && value <= 400 { sidebarWidth = value }
            if let value = settings["language"] as? String, isValidLanguage(value) { language = value }
            if let value = settings["accentColorHex"] as? String { accentColorHex = value }
            if let value = settings["enableAnalytics"] as? Bool { enableAnalytics = value }
            if let value = settings["enableCrashReporting"] as? Bool { enableCrashReporting = value }
            if let value = settings["enableModuleLogging"] as? Bool { enableModuleLogging = value }
            if let value = settings["maxLogEntries"] as? Double, value >= 100 && value <= 10000 { maxLogEntries = value }
            if let value = settings["enableBackgroundUpdates"] as? Bool { enableBackgroundUpdates = value }
            if let value = settings["enableDebugMode"] as? Bool { enableDebugMode = value }
            if let value = settings["enableBetaFeatures"] as? Bool { enableBetaFeatures = value }
            if let value = settings["enablePrivacyAnalytics"] as? Bool { enablePrivacyAnalytics = value }
            if let value = settings["autoApplyProfiles"] as? Bool { autoApplyProfiles = value }
            if let value = settings["showPrivacyStatusInMenuBar"] as? Bool { showPrivacyStatusInMenuBar = value }
            if let value = settings["debugMode"] as? Bool { debugMode = value }
            if let value = settings["showDeveloperOptions"] as? Bool { showDeveloperOptions = value }
            if let value = settings["verboseLogging"] as? Bool { verboseLogging = value }
            if let value = settings["preferredLanguage"] as? String, isValidLanguage(value) { preferredLanguage = value }
            
            logger.info("Settings imported successfully")
            return true
        } catch {
            logger.error("Failed to import settings: \(error)")
            return false
        }
    }
    
    /// Get recently used module IDs as array
    var recentlyUsedModulesList: [String] {
        return recentlyUsedModules.isEmpty ? [] : recentlyUsedModules.components(separatedBy: ",")
    }
    
    /// Add module to recently used list
    func addRecentlyUsedModule(_ moduleId: String) {
        var modules = recentlyUsedModulesList
        
        // Remove if already exists
        modules.removeAll { $0 == moduleId }
        
        // Add to front
        modules.insert(moduleId, at: 0)
        
        // Keep only last 10
        if modules.count > 10 {
            modules = Array(modules.prefix(10))
        }
        
        recentlyUsedModules = modules.joined(separator: ",")
        logger.debug("Added module \(moduleId) to recently used")
    }
    
    // MARK: - Private Methods
    
    private func setupInitialSettings() {
        // Log current settings on startup
        logger.debug("Current settings - Logging: \(enableLogging), Level: \(logLevel), Auto-start: \(autoStart)")
        logger.debug("Refresh interval: \(refreshInterval)s, Max activity: \(maxRecentActivity)")
    }
    
    private func isValidLogLevel(_ level: String) -> Bool {
        return ["Debug", "Info", "Warning", "Error"].contains(level)
    }
    
    private func isValidTheme(_ theme: String) -> Bool {
        return ["light", "dark", "auto"].contains(theme)
    }
    
    private func isValidLanguage(_ language: String) -> Bool {
        return ["en", "tr", "de", "fr", "es"].contains(language)
    }
}

// MARK: - Settings Categories

extension UserSettings {
    
    /// Application-related settings
    var applicationSettings: ApplicationSettings {
        ApplicationSettings(
            enableLogging: enableLogging,
            logLevel: logLevel,
            autoStart: autoStart,
            showNotifications: showNotifications,
            themePreference: theme,
            refreshInterval: refreshInterval
        )
    }
    
    /// Privacy-related settings
    var privacySettings: PrivacySettings {
        PrivacySettings(
            enablePrivacyAnalytics: enablePrivacyAnalytics,
            autoApplyProfiles: autoApplyProfiles,
            showPrivacyStatusInMenuBar: showPrivacyStatusInMenuBar
        )
    }
    
    /// Developer-related settings
    var developerSettings: DeveloperSettings {
        DeveloperSettings(
            debugMode: debugMode,
            showDeveloperOptions: showDeveloperOptions,
            verboseLogging: verboseLogging
        )
    }
}

// MARK: - Settings Structures

struct ApplicationSettings {
    let enableLogging: Bool
    let logLevel: String
    let autoStart: Bool
    let showNotifications: Bool
    let themePreference: String
    let refreshInterval: Int
}

struct PrivacySettings {
    let enablePrivacyAnalytics: Bool
    let autoApplyProfiles: Bool
    let showPrivacyStatusInMenuBar: Bool
}

struct DeveloperSettings {
    let debugMode: Bool
    let showDeveloperOptions: Bool
    let verboseLogging: Bool
}
