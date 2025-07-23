import Foundation
import SwiftUI
import Combine
import PrivarionCore

/// ObservableObject class for managing permission search and filtering
/// Implements real-time search and multiple filter combinations
class PermissionSearchManager: ObservableObject {
    
    // MARK: - Search State
    
    /// Current search text
    @Published var searchText: String = "" {
        didSet {
            performSearch()
        }
    }
    
    /// Active filters
    @Published var activeFilters: Set<PermissionFilter> = [] {
        didSet {
            performSearch()
        }
    }
    
    /// Filtered and sorted permissions
    @Published var filteredPermissions: [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant] = []
    
    /// Original permissions list (source of truth)
    private var allPermissions: [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant] = []
    
    // MARK: - Search Configuration
    
    /// Search is case-insensitive by default
    @Published var isCaseSensitive: Bool = false {
        didSet {
            performSearch()
        }
    }
    
    /// Enable regex search mode
    @Published var isRegexMode: Bool = false {
        didSet {
            performSearch()
        }
    }
    
    // MARK: - Public Methods
    
    /// Updates the source permissions and triggers search
    /// - Parameter permissions: New permissions list to search within
    func updatePermissions(_ permissions: [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant]) {
        allPermissions = permissions
        performSearch()
    }
    
    /// Adds a filter to the active filter set
    /// - Parameter filter: Filter to add
    func addFilter(_ filter: PermissionFilter) {
        activeFilters.insert(filter)
    }
    
    /// Removes a filter from the active filter set
    /// - Parameter filter: Filter to remove
    func removeFilter(_ filter: PermissionFilter) {
        activeFilters.remove(filter)
    }
    
    /// Clears all active filters
    func clearFilters() {
        activeFilters.removeAll()
    }
    
    /// Clears search text
    func clearSearch() {
        searchText = ""
    }
    
    /// Clears both search and filters
    func clearAll() {
        searchText = ""
        activeFilters.removeAll()
    }
    
    // MARK: - Private Search Logic
    
    private func performSearch() {
        var results = allPermissions
        
        // Apply text search if search text is not empty
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            results = applyTextSearch(to: results)
        }
        
        // Apply filters
        results = applyFilters(to: results)
        
        // Sort results (active first, then by creation date)
        results.sort { lhs, rhs in
            if lhs.isExpired != rhs.isExpired {
                return !lhs.isExpired // Active permissions first
            }
            return lhs.grantedAt > rhs.grantedAt // Newer first
        }
        
        filteredPermissions = results
    }
    
    private func applyTextSearch(to permissions: [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant]) -> [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant] {
        let query = isCaseSensitive ? searchText : searchText.lowercased()
        
        return permissions.filter { permission in
            if isRegexMode {
                return matchesRegex(permission: permission, pattern: query)
            } else {
                return matchesText(permission: permission, query: query)
            }
        }
    }
    
    private func matchesText(permission: PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant, query: String) -> Bool {
        let bundleId = isCaseSensitive ? permission.bundleIdentifier : permission.bundleIdentifier.lowercased()
        let serviceName = isCaseSensitive ? permission.serviceName : permission.serviceName.lowercased()
        
        return bundleId.contains(query) || serviceName.contains(query)
    }
    
    private func matchesRegex(permission: PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: isCaseSensitive ? [] : .caseInsensitive) else {
            // Fall back to text search if regex is invalid
            return matchesText(permission: permission, query: pattern)
        }
        
        let bundleIdRange = NSRange(location: 0, length: permission.bundleIdentifier.utf16.count)
        let serviceNameRange = NSRange(location: 0, length: permission.serviceName.utf16.count)
        
        return regex.firstMatch(in: permission.bundleIdentifier, options: [], range: bundleIdRange) != nil ||
               regex.firstMatch(in: permission.serviceName, options: [], range: serviceNameRange) != nil
    }
    
    private func applyFilters(to permissions: [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant]) -> [PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant] {
        guard !activeFilters.isEmpty else { return permissions }
        
        return permissions.filter { permission in
            activeFilters.allSatisfy { filter in
                filter.matches(permission)
            }
        }
    }
}

// MARK: - Permission Filter

enum PermissionFilter: Hashable, CaseIterable {
    case active
    case expired
    case expiringSoon
    case camera
    case microphone
    case contacts
    case calendar
    case photos
    case location
    case shortTerm // < 1 hour
    case mediumTerm // 1 hour - 1 day
    case longTerm // > 1 day
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .expired: return "Expired"
        case .expiringSoon: return "Expiring Soon"
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .contacts: return "Contacts"
        case .calendar: return "Calendar"
        case .photos: return "Photos"
        case .location: return "Location"
        case .shortTerm: return "Short Term"
        case .mediumTerm: return "Medium Term"
        case .longTerm: return "Long Term"
        }
    }
    
    var systemImage: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .expired: return "xmark.circle.fill"
        case .expiringSoon: return "exclamationmark.triangle.fill"
        case .camera: return "camera.fill"
        case .microphone: return "mic.fill"
        case .contacts: return "person.2.fill"
        case .calendar: return "calendar"
        case .photos: return "photo.fill"
        case .location: return "location.fill"
        case .shortTerm: return "clock.badge.checkmark"
        case .mediumTerm: return "clock"
        case .longTerm: return "clock.badge"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .green
        case .expired: return .red
        case .expiringSoon: return .orange
        case .camera: return .blue
        case .microphone: return .purple
        case .contacts: return .indigo
        case .calendar: return .cyan
        case .photos: return .pink
        case .location: return .mint
        case .shortTerm: return .yellow
        case .mediumTerm: return .orange
        case .longTerm: return .red
        }
    }
    
    func matches(_ permission: PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant) -> Bool {
        switch self {
        case .active:
            return !permission.isExpired
        case .expired:
            return permission.isExpired
        case .expiringSoon:
            return permission.isExpiringSoon
        case .camera:
            return permission.serviceName.contains("Camera")
        case .microphone:
            return permission.serviceName.contains("Microphone")
        case .contacts:
            return permission.serviceName.contains("Contacts")
        case .calendar:
            return permission.serviceName.contains("Calendar")
        case .photos:
            return permission.serviceName.contains("Photos")
        case .location:
            return permission.serviceName.contains("Location")
        case .shortTerm:
            let duration = permission.expiresAt.timeIntervalSince(permission.grantedAt)
            return duration < 3600 // < 1 hour
        case .mediumTerm:
            let duration = permission.expiresAt.timeIntervalSince(permission.grantedAt)
            return duration >= 3600 && duration <= 86400 // 1 hour - 1 day
        case .longTerm:
            let duration = permission.expiresAt.timeIntervalSince(permission.grantedAt)
            return duration > 86400 // > 1 day
        }
    }
}

// MARK: - Filter Categories

extension PermissionFilter {
    
    static var statusFilters: [PermissionFilter] {
        [.active, .expired, .expiringSoon]
    }
    
    static var serviceFilters: [PermissionFilter] {
        [.camera, .microphone, .contacts, .calendar, .photos, .location]
    }
    
    static var durationFilters: [PermissionFilter] {
        [.shortTerm, .mediumTerm, .longTerm]
    }
    
    var category: FilterCategory {
        if Self.statusFilters.contains(self) {
            return .status
        } else if Self.serviceFilters.contains(self) {
            return .service
        } else {
            return .duration
        }
    }
}

enum FilterCategory: String, CaseIterable {
    case status = "Status"
    case service = "Service"
    case duration = "Duration"
    
    var filters: [PermissionFilter] {
        switch self {
        case .status: return PermissionFilter.statusFilters
        case .service: return PermissionFilter.serviceFilters
        case .duration: return PermissionFilter.durationFilters
        }
    }
}
