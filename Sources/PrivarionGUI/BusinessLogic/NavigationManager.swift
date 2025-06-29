//
//  NavigationManager.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import SwiftUI
import Combine
import Logging

/// Advanced navigation manager for breadcrumbs, history, and deep linking
/// Implements Clean Architecture - Business Logic Layer
final class NavigationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentRoute: NavigationRoute
    @Published var navigationHistory: [NavigationRoute] = []
    @Published var breadcrumbs: [BreadcrumbItem] = []
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    
    // MARK: - Private Properties
    
    private var historyIndex: Int = -1
    private let maxHistoryItems = 50
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(label: "NavigationManager")
    
    // MARK: - Weak Reference to AppState
    
    private weak var appState: AppState?
    
    // MARK: - Initialization
    
    init(initialRoute: NavigationRoute = .dashboard) {
        self.currentRoute = initialRoute
        setupBreadcrumbs()
        setupNavigationTracking()
    }
    
    // MARK: - Public Methods
    
    /// Connect to AppState for navigation actions
    func connectToAppState(_ appState: AppState) {
        self.appState = appState
        logger.debug("NavigationManager connected to AppState")
    }
    
    /// Navigate to a specific route
    func navigateTo(_ route: NavigationRoute) {
        guard route != currentRoute else { return }
        
        // Add current route to history if moving to a new route
        addToHistory(currentRoute)
        
        // Update current route
        currentRoute = route
        
        // Update breadcrumbs
        updateBreadcrumbs(for: route)
        
        // Update AppState if connected
        if let appState = appState {
            Task { @MainActor in
                appState.navigateTo(route.appView)
            }
        }
        
        logger.info("Navigated to route: \(route.path)")
    }
    
    /// Navigate back in history
    func goBack() {
        guard canGoBack, historyIndex > 0 else { return }
        
        historyIndex -= 1
        let previousRoute = navigationHistory[historyIndex]
        
        currentRoute = previousRoute
        updateBreadcrumbs(for: previousRoute)
        updateNavigationState()
        
        // Update AppState
        if let appState = appState {
            Task { @MainActor in
                appState.navigateTo(previousRoute.appView)
            }
        }
        
        logger.debug("Navigated back to: \(previousRoute.path)")
    }
    
    /// Navigate forward in history
    func goForward() {
        guard canGoForward, historyIndex < navigationHistory.count - 1 else { return }
        
        historyIndex += 1
        let nextRoute = navigationHistory[historyIndex]
        
        currentRoute = nextRoute
        updateBreadcrumbs(for: nextRoute)
        updateNavigationState()
        
        // Update AppState
        if let appState = appState {
            Task { @MainActor in
                appState.navigateTo(nextRoute.appView)
            }
        }
        
        logger.debug("Navigated forward to: \(nextRoute.path)")
    }
    
    /// Navigate to a breadcrumb item
    func navigateToBreadcrumb(_ breadcrumb: BreadcrumbItem) {
        guard let route = NavigationRoute.from(path: breadcrumb.path) else { return }
        navigateTo(route)
    }
    
    /// Handle deep linking from URL
    func handleDeepLink(_ url: URL) {
        guard let route = NavigationRoute.from(url: url) else {
            logger.warning("Invalid deep link URL: \(url)")
            return
        }
        
        navigateTo(route)
        logger.info("Handled deep link to: \(route.path)")
    }
    
    /// Get shareable URL for current route
    func getShareableURL() -> URL? {
        return currentRoute.shareableURL
    }
    
    /// Clear navigation history
    func clearHistory() {
        navigationHistory.removeAll()
        historyIndex = -1
        updateNavigationState()
        logger.debug("Navigation history cleared")
    }
    
    // MARK: - Private Methods
    
    /// Setup initial breadcrumbs
    private func setupBreadcrumbs() {
        updateBreadcrumbs(for: currentRoute)
    }
    
    /// Setup navigation state tracking
    private func setupNavigationTracking() {
        $currentRoute
            .sink { [weak self] route in
                self?.updateNavigationState()
            }
            .store(in: &cancellables)
    }
    
    /// Add route to navigation history
    private func addToHistory(_ route: NavigationRoute) {
        // Remove any forward history if we're not at the end
        if historyIndex < navigationHistory.count - 1 {
            navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
        }
        
        // Add new route to history
        navigationHistory.append(route)
        historyIndex = navigationHistory.count - 1
        
        // Limit history size
        if navigationHistory.count > maxHistoryItems {
            navigationHistory.removeFirst()
            historyIndex -= 1
        }
        
        updateNavigationState()
    }
    
    /// Update navigation state (back/forward availability)
    private func updateNavigationState() {
        canGoBack = historyIndex > 0
        canGoForward = historyIndex < navigationHistory.count - 1
    }
    
    /// Update breadcrumbs for current route
    private func updateBreadcrumbs(for route: NavigationRoute) {
        breadcrumbs = route.breadcrumbs
    }
}

// MARK: - Navigation Route

/// Represents a navigation route in the application
enum NavigationRoute: String, CaseIterable {
    case dashboard = "dashboard"
    case modules = "modules"
    case moduleDetails = "modules/details"
    case profiles = "profiles"
    case profileDetails = "profiles/details"
    case logs = "logs"
    case settings = "settings"
    case advancedSettings = "settings/advanced"
    case shortcuts = "settings/shortcuts"
    
    /// Human-readable title for the route
    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .modules:
            return "Modules"
        case .moduleDetails:
            return "Module Details"
        case .profiles:
            return "Profiles"
        case .profileDetails:
            return "Profile Details"
        case .logs:
            return "Logs"
        case .settings:
            return "Settings"
        case .advancedSettings:
            return "Advanced Settings"
        case .shortcuts:
            return "Shortcuts"
        }
    }
    
    /// URL path for the route
    var path: String {
        return rawValue
    }
    
    /// Icon for the route
    var icon: String {
        switch self {
        case .dashboard:
            return "house"
        case .modules, .moduleDetails:
            return "square.stack.3d.up"
        case .profiles, .profileDetails:
            return "person.2"
        case .logs:
            return "doc.text"
        case .settings, .advancedSettings:
            return "gear"
        case .shortcuts:
            return "keyboard"
        }
    }
    
    /// Corresponding AppView for AppState navigation
    var appView: AppView {
        switch self {
        case .dashboard:
            return .dashboard
        case .modules, .moduleDetails:
            return .modules
        case .profiles, .profileDetails:
            return .profiles
        case .logs:
            return .logs
        case .settings, .advancedSettings, .shortcuts:
            return .settings
        }
    }
    
    /// Breadcrumb items for this route
    var breadcrumbs: [BreadcrumbItem] {
        let components = path.split(separator: "/")
        var breadcrumbs: [BreadcrumbItem] = []
        var currentPath = ""
        
        for (index, component) in components.enumerated() {
            if index > 0 {
                currentPath += "/"
            }
            currentPath += String(component)
            
            if let route = NavigationRoute(rawValue: currentPath) {
                breadcrumbs.append(BreadcrumbItem(
                    title: route.title,
                    path: currentPath,
                    icon: route.icon,
                    isLast: index == components.count - 1
                ))
            }
        }
        
        return breadcrumbs
    }
    
    /// Shareable URL for this route
    var shareableURL: URL? {
        return URL(string: "privarion://\(path)")
    }
    
    /// Create route from path string
    static func from(path: String) -> NavigationRoute? {
        return NavigationRoute(rawValue: path)
    }
    
    /// Create route from URL
    static func from(url: URL) -> NavigationRoute? {
        guard url.scheme == "privarion" else { return nil }
        return NavigationRoute(rawValue: url.host ?? "")
    }
}

// MARK: - Breadcrumb Item

/// Represents a single breadcrumb item
struct BreadcrumbItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let path: String
    let icon: String
    let isLast: Bool
    
    static func == (lhs: BreadcrumbItem, rhs: BreadcrumbItem) -> Bool {
        return lhs.path == rhs.path
    }
}

// MARK: - Navigation History Item

/// Represents an item in navigation history
struct NavigationHistoryItem: Identifiable {
    let id = UUID()
    let route: NavigationRoute
    let timestamp: Date
    let title: String
    
    init(route: NavigationRoute) {
        self.route = route
        self.timestamp = Date()
        self.title = route.title
    }
}
