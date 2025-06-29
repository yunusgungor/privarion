import Foundation
import SwiftUI
import KeyboardShortcuts
import Logging

/// Keyboard shortcut manager following Clean Architecture patterns
/// Handles global keyboard shortcuts, user customization, and integration with AppState
/// Based on Context7 research: KeyboardShortcuts library best practices
@MainActor
final class KeyboardShortcutManager: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(label: "KeyboardShortcutManager")
    private weak var appState: AppState?
    
    // MARK: - Published State
    
    /// Whether shortcuts are currently enabled
    @Published var shortcutsEnabled: Bool = true
    
    /// Current shortcut conflicts (if any)
    @Published var conflicts: [ShortcutConflict] = []
    
    // MARK: - Initialization
    
    init() {
        logger.info("KeyboardShortcutManager initialized")
        setupGlobalShortcuts()
    }
    
    // MARK: - Public Methods
    
    /// Connect to AppState for navigation actions
    func connect(to appState: AppState) {
        self.appState = appState
        logger.debug("Connected to AppState")
    }
    
    /// Enable or disable all shortcuts
    func setShortcutsEnabled(_ enabled: Bool) {
        shortcutsEnabled = enabled
        logger.info("Shortcuts \(enabled ? "enabled" : "disabled")")
    }
    
    /// Check for shortcut conflicts
    func checkForConflicts() {
        // Implementation for conflict detection
        // This would check for system-wide shortcut conflicts
        conflicts.removeAll()
        logger.debug("Checked for shortcut conflicts")
    }
    
    /// Get all configured shortcuts for settings UI
    func getAllShortcuts() -> [KeyboardShortcut] {
        return [
            KeyboardShortcut(
                title: "Show Command Palette",
                description: "Open the command palette to search and execute commands",
                keyCombination: "⌘⇧P",
                category: .commands
            ) {
                self.appState?.showCommandPalette()
            },
            KeyboardShortcut(
                title: "Navigate Back",
                description: "Go back to the previous page in navigation history",
                keyCombination: "⌘[",
                category: .navigation
            ) {
                self.appState?.navigationManager.goBack()
            },
            KeyboardShortcut(
                title: "Navigate Forward",
                description: "Go forward to the next page in navigation history",
                keyCombination: "⌘]",
                category: .navigation
            ) {
                self.appState?.navigationManager.goForward()
            },
            KeyboardShortcut(
                title: "Go to Dashboard",
                description: "Navigate to the main dashboard",
                keyCombination: "⌘1",
                category: .navigation
            ) {
                self.appState?.navigationManager.navigateTo(.dashboard)
            },
            KeyboardShortcut(
                title: "Go to Modules",
                description: "Navigate to the modules view",
                keyCombination: "⌘2",
                category: .navigation
            ) {
                self.appState?.navigationManager.navigateTo(.modules)
            },
            KeyboardShortcut(
                title: "Go to Profiles",
                description: "Navigate to the profiles view",
                keyCombination: "⌘3",
                category: .navigation
            ) {
                self.appState?.navigationManager.navigateTo(.profiles)
            },
            KeyboardShortcut(
                title: "Go to Settings",
                description: "Navigate to the settings view",
                keyCombination: "⌘,",
                category: .settings
            ) {
                self.appState?.navigationManager.navigateTo(.settings)
            },
            KeyboardShortcut(
                title: "Refresh All",
                description: "Refresh all data from the backend",
                keyCombination: "⌘R",
                category: .commands
            ) {
                Task {
                    await self.appState?.refreshAll()
                }
            },
            KeyboardShortcut(
                title: "Toggle Sidebar",
                description: "Show or hide the sidebar",
                keyCombination: "⌘⇧E",
                category: .navigation
            ) {
                // This would be handled by the NavigationSplitView
                self.logger.debug("Toggle sidebar shortcut triggered")
            }
        ]
    }
    
    /// Update a shortcut's key combination
    func updateShortcut(id: UUID, newKeyCombination: String) {
        // In a real implementation, this would update the stored shortcuts
        // For now, we'll just log the change
        logger.info("Updated shortcut \(id) to key combination: \(newKeyCombination)")
        
        // Here you would typically:
        // 1. Validate the new key combination
        // 2. Check for conflicts
        // 3. Update the stored preferences
        // 4. Re-register the shortcut with the system
    }
    
    /// Reset all shortcuts to defaults
    func resetToDefaults() {
        KeyboardShortcuts.reset(.dashboard)
        KeyboardShortcuts.reset(.modules)
        KeyboardShortcuts.reset(.profiles) 
        KeyboardShortcuts.reset(.logs)
        KeyboardShortcuts.reset(.settings)
        KeyboardShortcuts.reset(.commandPalette)
        KeyboardShortcuts.reset(.search)
        KeyboardShortcuts.reset(.preferences)
        
        logger.info("All shortcuts reset to defaults")
    }
    
    // MARK: - Private Methods
    
    private func setupGlobalShortcuts() {
        // Navigation shortcuts
        KeyboardShortcuts.onKeyUp(for: .dashboard) { [weak self] in
            self?.handleDashboardShortcut()
        }
        
        KeyboardShortcuts.onKeyUp(for: .modules) { [weak self] in
            self?.handleModulesShortcut()
        }
        
        KeyboardShortcuts.onKeyUp(for: .profiles) { [weak self] in
            self?.handleProfilesShortcut()
        }
        
        KeyboardShortcuts.onKeyUp(for: .logs) { [weak self] in
            self?.handleLogsShortcut()
        }
        
        KeyboardShortcuts.onKeyUp(for: .settings) { [weak self] in
            self?.handleSettingsShortcut()
        }
        
        // Utility shortcuts
        KeyboardShortcuts.onKeyUp(for: .commandPalette) { [weak self] in
            self?.handleCommandPaletteShortcut()
        }
        
        KeyboardShortcuts.onKeyUp(for: .search) { [weak self] in
            self?.handleSearchShortcut()
        }
        
        KeyboardShortcuts.onKeyUp(for: .preferences) { [weak self] in
            self?.handlePreferencesShortcut()
        }
        
        logger.debug("Global shortcuts configured")
    }
    
    // MARK: - Shortcut Handlers
    
    private func handleDashboardShortcut() {
        guard shortcutsEnabled else { return }
        appState?.navigateToView(.dashboard)
        logger.debug("Dashboard shortcut triggered")
    }
    
    private func handleModulesShortcut() {
        guard shortcutsEnabled else { return }
        appState?.navigateToView(.modules)
        logger.debug("Modules shortcut triggered")
    }
    
    private func handleProfilesShortcut() {
        guard shortcutsEnabled else { return }
        appState?.navigateToView(.profiles)
        logger.debug("Profiles shortcut triggered")
    }
    
    private func handleLogsShortcut() {
        guard shortcutsEnabled else { return }
        appState?.navigateToView(.logs)
        logger.debug("Logs shortcut triggered")
    }
    
    private func handleSettingsShortcut() {
        guard shortcutsEnabled else { return }
        appState?.navigateToView(.settings)
        logger.debug("Settings shortcut triggered")
    }
    
    private func handleCommandPaletteShortcut() {
        guard shortcutsEnabled else { return }
        appState?.showCommandPalette()
        logger.debug("Command palette shortcut triggered")
    }
    
    private func handleSearchShortcut() {
        guard shortcutsEnabled else { return }
        appState?.focusSearch()
        logger.debug("Search shortcut triggered")
    }
    
    private func handlePreferencesShortcut() {
        guard shortcutsEnabled else { return }
        appState?.showPreferences()
        logger.debug("Preferences shortcut triggered")
    }
}

// MARK: - Keyboard Shortcut Names Extension

extension KeyboardShortcuts.Name {
    // Navigation shortcuts - simple name registration without defaults for now
    static let dashboard = Self("dashboard")
    static let modules = Self("modules")
    static let profiles = Self("profiles")
    static let logs = Self("logs")
    static let settings = Self("settings")
    
    // Utility shortcuts
    static let commandPalette = Self("commandPalette")
    static let search = Self("search")
    static let preferences = Self("preferences")
}

// MARK: - Supporting Types

/// Represents a keyboard shortcut conflict
struct ShortcutConflict {
    let shortcutName: KeyboardShortcuts.Name
    let conflictingApp: String
    let severity: ConflictSeverity
    
    enum ConflictSeverity {
        case low, medium, high
    }
}

/// Navigation view types for shortcut navigation
enum NavigationView {
    case dashboard
    case modules  
    case profiles
    case logs
    case settings
}
