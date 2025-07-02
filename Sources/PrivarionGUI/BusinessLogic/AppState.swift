import SwiftUI
import Combine
import PrivarionCore
import Logging

/// Central state managing all GUI application state
/// Following Clean Architecture pattern with Combine for reactive updates
/// Based on Context7 research: AppState + @EnvironmentObject pattern
@MainActor
final class AppState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current application screen/view state
    @Published var currentView: AppView = .dashboard
    
    /// System status information
    @Published var systemStatus: SystemStatus = .unknown
    
    /// Available privacy modules and their status
    @Published var modules: [PrivacyModule] = []
    
    /// Current configuration profiles
    @Published var profiles: [PrivarionGUI.ConfigurationProfile] = []
    
    /// Active configuration profile
    @Published var activeProfile: PrivarionGUI.ConfigurationProfile?
    
    /// Recent activity log entries
    @Published var recentActivity: [ActivityLogEntry] = []
    
    /// Loading states for different operations
    @Published var isLoading: [String: Bool] = [:]
    
    // MARK: - MAC Address Management
    
    /// MAC Address spoofing state management
    @Published var macAddressState: MacAddressState
    
    // MARK: - Private Properties
    
    private let logger = Logger(label: "AppState")
    private var cancellables = Set<AnyCancellable>()
    
    /// Indicates if we're running in test environment
    private var isTestEnvironment: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    // MARK: - Dependencies (Interactors)
    
    let systemInteractor: SystemInteractor
    let moduleInteractor: ModuleInteractor  
    let profileInteractor: ProfileInteractor
    
    // MARK: - Error Management
    
    let errorManager: ErrorManager
    
    // MARK: - User Settings
    
    let userSettings: UserSettings
    
    // MARK: - Search Management
    
    let searchManager: SearchManager
    
    // MARK: - Keyboard Shortcut Management
    
    let keyboardShortcutManager: KeyboardShortcutManager
    
    // MARK: - Command Management
    
    @Published var commandManager: CommandManager
    
    // MARK: - Navigation Management
    
    @Published var navigationManager: NavigationManager
    
    // MARK: - Initialization
    
    init(
        systemInteractor: SystemInteractor = DefaultSystemInteractor(),
        moduleInteractor: ModuleInteractor = DefaultModuleInteractor(),
        profileInteractor: ProfileInteractor = DefaultProfileInteractor()
    ) {
        self.systemInteractor = systemInteractor
        self.moduleInteractor = moduleInteractor
        self.profileInteractor = profileInteractor
        self.errorManager = ErrorManager.shared
        self.userSettings = UserSettings.shared
        self.searchManager = SearchManager()
        self.keyboardShortcutManager = KeyboardShortcutManager()
        
        // Initialize MAC Address State
        self.macAddressState = MacAddressState()
        
        // Initialize CommandManager and NavigationManager
        self.commandManager = CommandManager()
        self.navigationManager = NavigationManager()
        
        setupSubscriptions()
        setupSearchManager()
        setupKeyboardShortcuts()
        setupCommandManager()
        setupNavigationManager()
        
        logger.info("AppState initialized with Clean Architecture pattern, ErrorManager, UserSettings, SearchManager, KeyboardShortcutManager, CommandManager, NavigationManager, and MacAddressState")
    }
    
    // MARK: - Public Methods
    
    /// Initialize application data from CLI backend
    func initialize() async {
        logger.info("Initializing application state")
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadSystemStatus() }
            group.addTask { await self.loadModules() }
            group.addTask { await self.loadProfiles() }
            group.addTask { await self.loadRecentActivity() }
        }
        
        logger.info("Application state initialization completed")
    }
    
    /// Navigate to a specific view
    func navigateTo(_ view: AppView) {
        logger.debug("Navigating to view: \\(view)")
        currentView = view
    }
     /// Toggle module enable/disable state
    func toggleModule(_ moduleId: String) async {
        logger.info("Toggling module: \\(moduleId)")
        
        guard let moduleIndex = modules.firstIndex(where: { $0.id == moduleId }) else {
            let error = PrivarionError.moduleNotFound(moduleId: moduleId)
            handleError(error, context: "AppState.toggleModule", operation: "module toggle")
            return
        }

        do {
            setLoading("modules", true)
            let currentModule = modules[moduleIndex]
            let newState = !currentModule.isEnabled
            
            // Update via interactor
            try await moduleInteractor.toggleModule(moduleId)
            
            // Update local state
            modules[moduleIndex] = PrivacyModule(
                id: currentModule.id,
                name: currentModule.name,
                description: currentModule.description,
                isEnabled: newState,
                status: newState ? .active : .inactive,
                dependencies: currentModule.dependencies
            )
            
            setLoading("modules", false)
            logger.info("Module \(moduleId) toggled to: \(newState ? "enabled" : "disabled")")
            
            // Refresh modules to get updated status
            await refreshModules()
            
        } catch {
            setLoading("modules", false)
            let privarionError = PrivarionError.moduleToggleFailed(moduleId: moduleId, reason: error.localizedDescription)
            handleError(privarionError, context: "AppState.toggleModule", operation: "module toggle")
        }
    }
    
    /// Switch to a different configuration profile
    func switchProfile(_ profileId: String) async {
        logger.info("Switching to profile: \\(profileId)")
        
        guard let profile = profiles.first(where: { $0.id == profileId }) else {
            let error = PrivarionError.profileNotFound(profileId: profileId)
            handleError(error, context: "AppState.switchProfile", operation: "profile switch")
            return
        }
        
        do {
            setLoading("profiles", true)
            
            // Switch via interactor
            try await profileInteractor.activateProfile(profileId)
            
            // Update local state
            activeProfile = profile
            
            setLoading("profiles", false)
            logger.info("Profile switched to: \\(profile.name)")
            
            // Refresh all data since profile switch may affect everything
            await initialize()
            
        } catch {
            setLoading("profiles", false)
            let privarionError = PrivarionError.profileSwitchFailed(
                fromProfile: activeProfile?.name ?? "unknown",
                toProfile: profile.name,
                reason: error.localizedDescription
            )
            handleError(privarionError, context: "AppState.switchProfile", operation: "profile switch")
        }
    }
    
    /// Refresh all data manually
    func refreshAll() async {
        logger.info("Manual refresh requested")
        await initialize()
    }
    
    /// Set loading state for an operation
    func setLoading(_ key: String, _ loading: Bool) {
        isLoading[key] = loading
    }
    
    /// Display error message to user using ErrorManager
    func showError(_ message: String, context: String? = nil, operation: String? = nil) {
        logger.error("Error displayed to user: \\(message)")
        let error = PrivarionError.internalError(code: "GUI-001", details: message)
        errorManager.handleError(error, context: context, operation: operation)
    }
    
    /// Display specific error using ErrorManager
    func handleError(_ error: Error, context: String? = nil, operation: String? = nil) {
        logger.error("Error handled by ErrorManager: \\(error)")
        errorManager.handleError(error, context: context, operation: operation)
    }
    
    /// Clear current error notifications
    func clearErrors() {
        errorManager.dismissAllErrors()
    }
    
    /// Update refresh interval and restart subscriptions
    func updateRefreshInterval() {
        // Cancel existing subscriptions
        cancellables.removeAll()
        
        // Setup new subscriptions with updated interval
        setupSubscriptions()
        
        logger.info("Refresh interval updated to \(userSettings.refreshInterval)s")
    }
    
    /// Apply user settings to current state
    func applyUserSettings() {
        // Update recent activity limit
        if recentActivity.count > userSettings.maxRecentActivity {
            recentActivity = Array(recentActivity.prefix(userSettings.maxRecentActivity))
        }
        
        // Update refresh subscriptions if needed
        updateRefreshInterval()
        
        logger.info("User settings applied to AppState")
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Setup reactive subscriptions for real-time updates
        // Update system status based on user's refresh interval setting
        Timer.publish(every: TimeInterval(userSettings.refreshInterval), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshSystemStatus()
                }
            }
            .store(in: &cancellables)
        
        // Update module status with adaptive interval
        let moduleRefreshInterval = userSettings.refreshInterval <= 15 ? 15 : userSettings.refreshInterval
        Timer.publish(every: TimeInterval(moduleRefreshInterval), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshModules()
                }
            }
            .store(in: &cancellables)
        
        logger.debug("Real-time update subscriptions configured with refresh interval: \(userSettings.refreshInterval)s")
    }
    
    /// Setup search manager with current data
    private func setupSearchManager() {
        // Configure search manager with initial data
        updateSearchManagerData()
        
        // Subscribe to data changes to update search manager
        $modules
            .sink { [weak self] _ in
                self?.updateSearchManagerData()
            }
            .store(in: &cancellables)
        
        $profiles
            .sink { [weak self] _ in
                self?.updateSearchManagerData()
            }
            .store(in: &cancellables)
        
        $recentActivity
            .sink { [weak self] _ in
                self?.updateSearchManagerData()
            }
            .store(in: &cancellables)
        
        logger.debug("SearchManager configured with reactive data updates")
    }
    
    /// Update search manager with current data
    private func updateSearchManagerData() {
        let searchableModules = modules.map { module in
            SearchableModule(
                id: module.id,
                name: module.name,
                description: module.description,
                category: "Privacy Module",
                status: module.isEnabled ? .active : .inactive,
                isEnabled: module.isEnabled,
                dateCreated: Date(), // Default since not available in PrivacyModule
                dateModified: Date() // Default since not available in PrivacyModule
            )
        }
        
        let searchableProfiles = profiles.map { profile in
            SearchableProfile(
                id: profile.id,
                name: profile.name,
                description: profile.description,
                category: "Profile",
                status: profile.isActive ? .active : .inactive,
                isActive: profile.isActive,
                dateCreated: profile.createdAt,
                dateModified: profile.modifiedAt
            )
        }
        
        let searchableActivities = recentActivity.map { activity in
            SearchableActivity(
                id: activity.id,
                message: activity.action,
                level: activity.level.rawValue,
                category: "Activity",
                status: .active,
                timestamp: activity.timestamp,
                dateCreated: activity.timestamp,
                dateModified: activity.timestamp
            )
        }
        
        searchManager.configureDataSources(
            modules: searchableModules,
            profiles: searchableProfiles,
            activities: searchableActivities
        )
    }
    
    /// Refresh system status from backend
    private func refreshSystemStatus() async {
        do {
            setLoading("systemStatus", true)
            let newStatus = try await systemInteractor.getSystemStatus()
            if newStatus != systemStatus {
                systemStatus = newStatus
                logger.info("System status updated to: \(newStatus)")
            }
            setLoading("systemStatus", false)
        } catch {
            setLoading("systemStatus", false)
            logger.error("Failed to refresh system status: \(error)")
        }
    }
    
    /// Refresh modules from backend
    private func refreshModules() async {
        do {
            setLoading("modules", true)
            let newModules = try await moduleInteractor.getAvailableModules()
            if newModules.count != modules.count {
                modules = newModules
                logger.info("Modules updated: \(newModules.count) modules available")
            }
            setLoading("modules", false)
        } catch {
            setLoading("modules", false)
            logger.error("Failed to refresh modules: \(error)")
        }
    }
    
    private func loadSystemStatus() async {
        do {
            setLoading("systemStatus", true)
            systemStatus = try await systemInteractor.getSystemStatus()
            setLoading("systemStatus", false)
        } catch {
            setLoading("systemStatus", false)
            let privarionError = PrivarionError.systemStatusUnavailable
            handleError(privarionError, context: "AppState.loadSystemStatus", operation: "system status load")
        }
    }
    
    private func loadModules() async {
        do {
            setLoading("modules", true)
            modules = try await moduleInteractor.getAvailableModules()
            setLoading("modules", false)
        } catch {
            setLoading("modules", false)
            handleError(error, context: "AppState.loadModules", operation: "modules load")
        }
    }
    
    private func loadProfiles() async {
        do {
            setLoading("profiles", true)
            profiles = try await profileInteractor.getProfiles()
            activeProfile = try await profileInteractor.getActiveProfile()
            setLoading("profiles", false)
        } catch {
            setLoading("profiles", false)
            handleError(error, context: "AppState.loadProfiles", operation: "profiles load")
        }
    }
    
    private func loadRecentActivity() async {
        do {
            setLoading("activity", true)
            recentActivity = try await systemInteractor.getRecentActivity()
            setLoading("activity", false)
        } catch {
            setLoading("activity", false)
            handleError(error, context: "AppState.loadRecentActivity", operation: "activity load")
        }
    }
    
    /// Setup keyboard shortcut manager and connect to AppState
    private func setupKeyboardShortcuts() {
        keyboardShortcutManager.connect(to: self)
        logger.debug("Keyboard shortcut manager connected to AppState")
    }
    
    /// Setup command manager and connect to AppState
    private func setupCommandManager() {
        commandManager.connectToAppState(self)
        logger.debug("Command manager connected to AppState")
    }
    
    /// Setup navigation manager and connect to AppState
    private func setupNavigationManager() {
        navigationManager.connectToAppState(self)
        logger.debug("Navigation manager connected to AppState")
    }
    
    // MARK: - Keyboard Shortcut Actions
    
    /// Navigate to a specific view using shortcuts
    func navigateToView(_ view: NavigationView) {
        switch view {
        case .dashboard:
            currentView = .dashboard
        case .modules:
            currentView = .modules
        case .profiles:
            currentView = .profiles
        case .logs:
            currentView = .logs
        case .settings:
            currentView = .settings
        }
        logger.debug("Navigated to \(view) via keyboard shortcut")
    }
    
    /// Show command palette
    func showCommandPalette() {
        commandManager.showCommandPalette()
        logger.debug("Command palette requested via keyboard shortcut")
    }
    
    /// Focus search functionality
    func focusSearch() {
        // Implementation will be added for search focus
        logger.debug("Search focus requested via keyboard shortcut")
    }
    
    /// Show preferences (Advanced Preferences)
    func showPreferences() {
        // Implementation will be added for preferences navigation
        logger.debug("Preferences requested via keyboard shortcut")
    }
    
    // MARK: - Command Manager Integration Methods
    
    /// Navigate to dashboard
    func navigateToDashboard() {
        currentView = .dashboard
        logger.debug("Navigated to dashboard via command")
    }
    
    /// Navigate to configuration
    func navigateToConfiguration() {
        currentView = .modules  // Configuration maps to modules view
        logger.debug("Navigated to configuration via command")
    }
    
    /// Navigate to monitoring
    func navigateToMonitoring() {
        currentView = .logs  // Monitoring maps to logs view
        logger.debug("Navigated to monitoring via command")
    }
    
    /// Show search interface
    func showSearch() {
        // Focus search in current view
        focusSearch()
        logger.debug("Search shown via command")
    }
    
    /// Refresh current view
    func refreshCurrentView() {
        Task {
            switch currentView {
            case .dashboard:
                await loadSystemStatus()
                await loadRecentActivity()
            case .modules:
                await refreshModules()
            case .profiles:
                await loadProfiles()
            case .logs:
                await loadRecentActivity()
            case .macAddress:
                await macAddressState.loadInterfaces()
            case .analytics:
                // Analytics view manages its own refresh
                break
            case .settings:
                // Settings don't need refreshing typically
                break
            }
        }
        logger.debug("Current view refreshed via command")
    }
    
    /// Export data from current view
    func exportData() {
        // Implementation for data export will be added
        logger.debug("Data export requested via command")
    }
    
    /// Quit application
    func quitApplication() {
        NSApplication.shared.terminate(nil)
        logger.debug("Application quit requested via command")
    }
    
    /// Minimize application window
    func minimizeWindow() {
        NSApplication.shared.keyWindow?.miniaturize(nil)
        logger.debug("Window minimized via command")
    }
    
    /// Show keyboard shortcut settings
    func showShortcutSettings() {
        // This will navigate to shortcut settings when implemented
        currentView = .settings
        logger.debug("Shortcut settings requested via command")
    }
    
    /// Show advanced preferences
    func showAdvancedPreferences() {
        // This will show advanced preferences when implemented
        currentView = .settings
        logger.debug("Advanced preferences requested via command")
    }
}

// MARK: - Supporting Types

/// Application view states for navigation
enum AppView: String, CaseIterable {
    case dashboard = "Dashboard"
    case modules = "Modules"
    case profiles = "Profiles"
    case macAddress = "MAC Address"
    case analytics = "Analytics"
    case settings = "Settings"
    case logs = "Logs"
}

/// System status enumeration
enum SystemStatus: String, CaseIterable {
    case unknown = "Unknown"
    case running = "Running"
    case stopped = "Stopped"
    case error = "Error"
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .running: return .green
        case .stopped: return .orange
        case .error: return .red
        }
    }
}

/// Privacy module representation
struct PrivacyModule: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let isEnabled: Bool
    let status: ModuleStatus
    let dependencies: [String]
}

/// Module status enumeration
enum ModuleStatus: String, Codable, CaseIterable {
    case active = "Active"
    case inactive = "Inactive"
    case error = "Error"
    case loading = "Loading"
    
    var color: Color {
        switch self {
        case .active: return .green
        case .inactive: return .gray
        case .error: return .red
        case .loading: return .blue
        }
    }
}

/// Configuration profile representation
struct ConfigurationProfile: Identifiable {
    let id: String
    let name: String
    let description: String
    let isActive: Bool
    let settings: [String: String] // Changed from Any to String for simplicity
    let createdAt: Date
    let modifiedAt: Date
}

/// Activity log entry representation
struct ActivityLogEntry: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let action: String
    let details: String
    let level: LogLevel
    
    enum LogLevel: String, Codable, CaseIterable {
        case info = "Info"
        case warning = "Warning"
        case error = "Error"
        case success = "Success"
        
        var color: Color {
            switch self {
            case .info: return .blue
            case .warning: return .orange
            case .error: return .red
            case .success: return .green
            }
        }
    }
}
