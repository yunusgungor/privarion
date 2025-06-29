//
//  CommandManager.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import SwiftUI
import Combine

/// Command system for command palette functionality
/// Implements Clean Architecture - Business Logic Layer
/// Based on Context7 patterns for command/action systems
final class CommandManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var filteredCommands: [Command] = []
    @Published var searchText: String = "" {
        didSet {
            filterCommands()
        }
    }
    @Published var selectedCommandIndex: Int = 0
    @Published var recentCommands: [Command] = []
    @Published var isShowingPalette: Bool = false
    
    // MARK: - Private Properties
    
    private var allCommands: [Command] = []
    private let maxRecentCommands = 10
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Weak Reference to AppState (Clean Architecture)
    
    private weak var appState: AppState?
    
    // MARK: - Initialization
    
    init(appState: AppState? = nil) {
        self.appState = appState
        setupCommands()
        loadRecentCommands()
    }
    
    // MARK: - Public Methods
    
    /// Show command palette
    func showCommandPalette() {
        isShowingPalette = true
        searchText = ""
        selectedCommandIndex = 0
        filterCommands()
    }
    
    /// Hide command palette
    func hideCommandPalette() {
        isShowingPalette = false
        searchText = ""
        selectedCommandIndex = 0
    }
    
    /// Execute selected command
    func executeSelectedCommand() {
        guard !filteredCommands.isEmpty,
              selectedCommandIndex < filteredCommands.count else {
            return
        }
        
        let command = filteredCommands[selectedCommandIndex]
        executeCommand(command)
    }
    
    /// Execute specific command
    func executeCommand(_ command: Command) {
        // Add to recent commands
        addToRecentCommands(command)
        
        // Execute the command action
        command.action()
        
        // Hide palette after execution
        hideCommandPalette()
    }
    
    /// Navigate selection up
    func navigateUp() {
        if selectedCommandIndex > 0 {
            selectedCommandIndex -= 1
        } else {
            selectedCommandIndex = max(0, filteredCommands.count - 1)
        }
    }
    
    /// Navigate selection down
    func navigateDown() {
        if selectedCommandIndex < filteredCommands.count - 1 {
            selectedCommandIndex += 1
        } else {
            selectedCommandIndex = 0
        }
    }
    
    /// Get command by ID
    func getCommand(by id: String) -> Command? {
        return allCommands.first { $0.id == id }
    }
    
    /// Connect to AppState for command execution
    func connectToAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Private Methods
    
    /// Setup all available commands
    private func setupCommands() {
        allCommands = [
            // Navigation Commands
            Command(
                id: "nav.dashboard",
                title: "Go to Dashboard",
                description: "Navigate to the main dashboard",
                category: .navigation,
                shortcut: "⌘1",
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.navigateToDashboard()
                    }
                }
            ),
            Command(
                id: "nav.configuration",
                title: "Go to Configuration",
                description: "Navigate to configuration settings",
                category: .navigation,
                shortcut: "⌘2",
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.navigateToConfiguration()
                    }
                }
            ),
            Command(
                id: "nav.monitoring",
                title: "Go to Monitoring",
                description: "Navigate to system monitoring",
                category: .navigation,
                shortcut: "⌘3",
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.navigateToMonitoring()
                    }
                }
            ),
            Command(
                id: "nav.preferences",
                title: "Open Preferences",
                description: "Open application preferences",
                category: .navigation,
                shortcut: "⌘,",
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.showPreferences()
                    }
                }
            ),
            
            // Action Commands
            Command(
                id: "action.search",
                title: "Search",
                description: "Open search interface",
                category: .action,
                shortcut: "⌘F",
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.showSearch()
                    }
                }
            ),
            Command(
                id: "action.refresh",
                title: "Refresh",
                description: "Refresh current view",
                category: .action,
                shortcut: "⌘R",
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.refreshCurrentView()
                    }
                }
            ),
            Command(
                id: "action.export",
                title: "Export Data",
                description: "Export current data",
                category: .action,
                shortcut: "⌘E",
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.exportData()
                    }
                }
            ),
            
            // System Commands
            Command(
                id: "system.quit",
                title: "Quit Application",
                description: "Quit Privarion",
                category: .system,
                shortcut: "⌘Q",
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.quitApplication()
                    }
                }
            ),
            Command(
                id: "system.minimize",
                title: "Minimize Window",
                description: "Minimize application window",
                category: .system,
                shortcut: "⌘M",
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.minimizeWindow()
                    }
                }
            ),
            
            // Settings Commands
            Command(
                id: "settings.shortcuts",
                title: "Keyboard Shortcuts",
                description: "View and edit keyboard shortcuts",
                category: .settings,
                shortcut: "⌘K",
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.showShortcutSettings()
                    }
                }
            ),
            Command(
                id: "settings.advanced",
                title: "Advanced Preferences",
                description: "Open advanced preferences",
                category: .settings,
                shortcut: nil,
                action: { [weak self] in
                    Task { @MainActor in
                        self?.appState?.showAdvancedPreferences()
                    }
                }
            )
        ]
        
        filterCommands()
    }
    
    /// Filter commands based on search text using fuzzy search
    private func filterCommands() {
        if searchText.isEmpty {
            // Show recent commands first, then all commands
            let recentIds = Set(recentCommands.map { $0.id })
            let otherCommands = allCommands.filter { !recentIds.contains($0.id) }
            filteredCommands = recentCommands + otherCommands
        } else {
            // Fuzzy search implementation
            filteredCommands = allCommands
                .compactMap { command in
                    let score = fuzzyScore(for: command, searchText: searchText)
                    return score > 0 ? (command: command, score: score) : nil
                }
                .sorted { $0.score > $1.score }
                .map { $0.command }
        }
        
        // Reset selection
        selectedCommandIndex = 0
    }
    
    /// Simple fuzzy search scoring algorithm
    private func fuzzyScore(for command: Command, searchText: String) -> Int {
        let query = searchText.lowercased()
        let title = command.title.lowercased()
        let description = command.description.lowercased()
        let category = command.category.rawValue.lowercased()
        
        var score = 0
        
        // Exact matches get highest score
        if title.contains(query) {
            score += 100
        }
        if description.contains(query) {
            score += 50
        }
        if category.contains(query) {
            score += 30
        }
        
        // Character matching for fuzzy search
        var queryIndex = query.startIndex
        for char in title {
            if queryIndex < query.endIndex && char == query[queryIndex] {
                score += 10
                queryIndex = query.index(after: queryIndex)
            }
        }
        
        // Bonus for shorter matches
        if score > 0 {
            score += max(0, 50 - title.count)
        }
        
        return score
    }
    
    /// Add command to recent commands
    private func addToRecentCommands(_ command: Command) {
        // Remove if already exists
        recentCommands.removeAll { $0.id == command.id }
        
        // Add to beginning
        recentCommands.insert(command, at: 0)
        
        // Limit to max recent commands
        if recentCommands.count > maxRecentCommands {
            recentCommands = Array(recentCommands.prefix(maxRecentCommands))
        }
        
        saveRecentCommands()
    }
    
    /// Load recent commands from UserDefaults
    private func loadRecentCommands() {
        guard let data = UserDefaults.standard.data(forKey: "RecentCommands"),
              let commandIds = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        
        recentCommands = commandIds.compactMap { id in
            allCommands.first { $0.id == id }
        }
    }
    
    /// Save recent commands to UserDefaults
    private func saveRecentCommands() {
        let commandIds = recentCommands.map { $0.id }
        if let data = try? JSONEncoder().encode(commandIds) {
            UserDefaults.standard.set(data, forKey: "RecentCommands")
        }
    }
}

// MARK: - Command Model

/// Represents a command in the command palette
struct Command: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let category: CommandCategory
    let shortcut: String?
    let action: () -> Void
    
    // MARK: - Hashable Conformance
    
    static func == (lhs: Command, rhs: Command) -> Bool {
        return lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Command Category

enum CommandCategory: String, CaseIterable {
    case navigation = "Navigation"
    case action = "Action"
    case system = "System"
    case settings = "Settings"
    
    var icon: String {
        switch self {
        case .navigation:
            return "location"
        case .action:
            return "bolt"
        case .system:
            return "gear"
        case .settings:
            return "slider.horizontal.3"
        }
    }
    
    var color: Color {
        switch self {
        case .navigation:
            return .blue
        case .action:
            return .green
        case .system:
            return .orange
        case .settings:
            return .purple
        }
    }
}
