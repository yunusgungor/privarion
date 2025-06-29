//
//  SearchableDataSource.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import Foundation
import Combine

/// Protocol for making data sources searchable and filterable
protocol SearchableDataSource {
    associatedtype Item: SearchableItem
    
    /// Search and filter items based on criteria
    func search(with criteria: SearchCriteria) -> AnyPublisher<[Item], PrivarionError>
    
    /// Get all available categories for filtering
    func availableCategories() -> AnyPublisher<Set<String>, PrivarionError>
    
    /// Get all available statuses for filtering
    func availableStatuses() -> AnyPublisher<Set<SearchableItemStatus>, PrivarionError>
    
    /// Validate search criteria
    func validateCriteria(_ criteria: SearchCriteria) -> PrivarionError?
}

/// Protocol for items that can be searched
protocol SearchableItem: Identifiable, Equatable {
    /// Primary text to search in
    var searchableText: String { get }
    
    /// Additional searchable keywords
    var searchableKeywords: [String] { get }
    
    /// Category for filtering
    var category: String { get }
    
    /// Status for filtering
    var status: SearchableItemStatus { get }
    
    /// Creation date for date-based filtering
    var dateCreated: Date { get }
    
    /// Last modification date
    var dateModified: Date { get }
    
    /// Whether item is currently active
    var isActive: Bool { get }
    
    /// Calculate relevance score for a search query
    func relevanceScore(for query: String) -> Double
}

// MARK: - Default Implementation

extension SearchableItem {
    func relevanceScore(for query: String) -> Double {
        guard !query.isEmpty else { return 0.0 }
        
        let searchableText = self.searchableText.lowercased()
        let searchableKeywords = self.searchableKeywords.map { $0.lowercased() }
        let queryLower = query.lowercased()
        
        var score: Double = 0.0
        
        // Exact match in primary text gets highest score
        if searchableText == queryLower {
            score += 100.0
        }
        
        // Prefix match in primary text
        if searchableText.hasPrefix(queryLower) {
            score += 80.0
        }
        
        // Contains match in primary text
        if searchableText.contains(queryLower) {
            score += 60.0
        }
        
        // Keyword matches
        for keyword in searchableKeywords {
            if keyword == queryLower {
                score += 40.0
            } else if keyword.hasPrefix(queryLower) {
                score += 30.0
            } else if keyword.contains(queryLower) {
                score += 20.0
            }
        }
        
        // Boost for active items
        if isActive {
            score *= 1.1
        }
        
        // Boost for recent items (within last 30 days)
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        if dateModified > thirtyDaysAgo {
            score *= 1.05
        }
        
        return score
    }
}

// MARK: - Generic Implementation

/// Generic searchable data source implementation
class GenericSearchableDataSource<Item: SearchableItem>: SearchableDataSource {
    
    private let items: [Item]
    
    init(items: [Item]) {
        self.items = items
    }
    
    func search(with criteria: SearchCriteria) -> AnyPublisher<[Item], PrivarionError> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(.invalidState("DataSource deallocated")))
                return
            }
            
            if let validationError = self.validateCriteria(criteria) {
                promise(.failure(validationError))
                return
            }
            
            var filteredItems = self.items
            
            // Apply text search
            if !criteria.searchText.isEmpty {
                filteredItems = filteredItems.filter { item in
                    let searchText = criteria.caseSensitive ? item.searchableText : item.searchableText.lowercased()
                    let query = criteria.caseSensitive ? criteria.searchText : criteria.searchText.lowercased()
                    
                    if criteria.exactMatch {
                        return searchText == query || item.searchableKeywords.contains { keyword in
                            let keywordText = criteria.caseSensitive ? keyword : keyword.lowercased()
                            return keywordText == query
                        }
                    } else {
                        return searchText.contains(query) || item.searchableKeywords.contains { keyword in
                            let keywordText = criteria.caseSensitive ? keyword : keyword.lowercased()
                            return keywordText.contains(query)
                        }
                    }
                }
            }
            
            // Apply category filtering
            if !criteria.categories.isEmpty {
                filteredItems = filteredItems.filter { criteria.categories.contains($0.category) }
            }
            
            if !criteria.excludeCategories.isEmpty {
                filteredItems = filteredItems.filter { !criteria.excludeCategories.contains($0.category) }
            }
            
            // Apply status filtering
            if !criteria.statuses.isEmpty {
                filteredItems = filteredItems.filter { criteria.statuses.contains($0.status) }
            }
            
            // Apply date range filtering
            if let dateRange = criteria.dateRange {
                filteredItems = filteredItems.filter { item in
                    return item.dateModified >= dateRange.startDate && item.dateModified <= dateRange.endDate
                }
            }
            
            // Apply active/inactive filtering
            if !criteria.includeInactive {
                filteredItems = filteredItems.filter { $0.isActive }
            }
            
            // Apply sorting
            filteredItems = self.sortItems(filteredItems, by: criteria.sortBy, order: criteria.sortOrder, query: criteria.searchText)
            
            // Apply result limit
            if let maxResults = criteria.maxResults {
                filteredItems = Array(filteredItems.prefix(maxResults))
            }
            
            promise(.success(filteredItems))
        }
        .eraseToAnyPublisher()
    }
    
    func availableCategories() -> AnyPublisher<Set<String>, PrivarionError> {
        return Just(Set(items.map { $0.category }))
            .setFailureType(to: PrivarionError.self)
            .eraseToAnyPublisher()
    }
    
    func availableStatuses() -> AnyPublisher<Set<SearchableItemStatus>, PrivarionError> {
        return Just(Set(items.map { $0.status }))
            .setFailureType(to: PrivarionError.self)
            .eraseToAnyPublisher()
    }
    
    func validateCriteria(_ criteria: SearchCriteria) -> PrivarionError? {
        // Validate search text length
        if criteria.searchText.count > 1000 {
            return .inputTooLong("Search text exceeds maximum length")
        }
        
        // Validate max results
        if let maxResults = criteria.maxResults, maxResults <= 0 {
            return .invalidRange("Max results must be positive")
        }
        
        // Validate date range
        if let dateRange = criteria.dateRange, dateRange.startDate > dateRange.endDate {
            return .invalidDateRange("Start date must be before end date")
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func sortItems(_ items: [Item], by sortOption: SortOption, order: SortOrder, query: String) -> [Item] {
        let sorted: [Item]
        
        switch sortOption {
        case .name:
            sorted = items.sorted { $0.searchableText.localizedCaseInsensitiveCompare($1.searchableText) == .orderedAscending }
        case .dateCreated:
            sorted = items.sorted { $0.dateCreated < $1.dateCreated }
        case .dateModified:
            sorted = items.sorted { $0.dateModified < $1.dateModified }
        case .status:
            sorted = items.sorted { $0.status.rawValue.localizedCaseInsensitiveCompare($1.status.rawValue) == .orderedAscending }
        case .category:
            sorted = items.sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
        case .relevance:
            sorted = items.sorted { $0.relevanceScore(for: query) > $1.relevanceScore(for: query) }
        }
        
        return order == .descending ? sorted.reversed() : sorted
    }
}
