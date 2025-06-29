//
//  SearchCriteria.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import Foundation

/// Search criteria value type for configuring search and filtering operations
struct SearchCriteria: Equatable {
    
    // MARK: - Text Search
    var searchText: String
    var caseSensitive: Bool
    var exactMatch: Bool
    
    // MARK: - Category Filtering
    var categories: Set<String>
    var excludeCategories: Set<String>
    
    // MARK: - Status Filtering
    var statuses: Set<SearchableItemStatus>
    
    // MARK: - Date Range Filtering
    var dateRange: DateRange?
    
    // MARK: - Sorting
    var sortBy: SortOption
    var sortOrder: SortOrder
    
    // MARK: - Advanced Options
    var includeInactive: Bool
    var maxResults: Int?
    
    // MARK: - Initializer
    init(
        searchText: String = "",
        caseSensitive: Bool = false,
        exactMatch: Bool = false,
        categories: Set<String> = [],
        excludeCategories: Set<String> = [],
        statuses: Set<SearchableItemStatus> = [],
        dateRange: DateRange? = nil,
        sortBy: SortOption = .name,
        sortOrder: SortOrder = .ascending,
        includeInactive: Bool = true,
        maxResults: Int? = nil
    ) {
        self.searchText = searchText
        self.caseSensitive = caseSensitive
        self.exactMatch = exactMatch
        self.categories = categories
        self.excludeCategories = excludeCategories
        self.statuses = statuses
        self.dateRange = dateRange
        self.sortBy = sortBy
        self.sortOrder = sortOrder
        self.includeInactive = includeInactive
        self.maxResults = maxResults
    }
    
    // MARK: - Helper Methods
    var hasActiveFilters: Bool {
        return !searchText.isEmpty ||
               !categories.isEmpty ||
               !excludeCategories.isEmpty ||
               !statuses.isEmpty ||
               dateRange != nil ||
               !includeInactive ||
               maxResults != nil
    }
    
    func reset() -> SearchCriteria {
        return SearchCriteria()
    }
}

// MARK: - Supporting Types

enum SearchableItemStatus: String, CaseIterable, Equatable, Codable {
    case active = "active"
    case inactive = "inactive"
    case pending = "pending"
    case error = "error"
    case success = "success"
    case warning = "warning"
    
    var displayName: String {
        switch self {
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .pending: return "Pending"
        case .error: return "Error"
        case .success: return "Success"
        case .warning: return "Warning"
        }
    }
}

enum SortOption: String, CaseIterable, Equatable, Codable {
    case name = "name"
    case dateCreated = "dateCreated"
    case dateModified = "dateModified"
    case status = "status"
    case category = "category"
    case relevance = "relevance"
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .dateCreated: return "Date Created"
        case .dateModified: return "Date Modified"
        case .status: return "Status"
        case .category: return "Category"
        case .relevance: return "Relevance"
        }
    }
}

enum SortOrder: String, CaseIterable, Equatable, Codable {
    case ascending = "ascending"
    case descending = "descending"
    
    var displayName: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }
}

struct DateRange: Equatable, Codable {
    let startDate: Date
    let endDate: Date
    
    init(startDate: Date, endDate: Date) {
        self.startDate = startDate
        self.endDate = endDate
    }
    
    static func last7Days() -> DateRange {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        return DateRange(startDate: startDate, endDate: endDate)
    }
    
    static func last30Days() -> DateRange {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate) ?? endDate
        return DateRange(startDate: startDate, endDate: endDate)
    }
    
    static func thisMonth() -> DateRange {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        return DateRange(startDate: startOfMonth, endDate: endOfMonth)
    }
}
