//
//  SearchManager.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import Foundation
import Combine

/// Business logic manager for search and filtering operations
/// Follows Clean Architecture principles with reactive programming
@MainActor
class SearchManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current search criteria
    @Published var criteria: SearchCriteria = SearchCriteria()
    
    /// Search results for different data types
    @Published var moduleResults: [SearchableModule] = []
    @Published var profileResults: [SearchableProfile] = []
    @Published var activityResults: [SearchableActivity] = []
    
    /// Search state
    @Published var isSearching: Bool = false
    @Published var searchError: PrivarionError?
    @Published var hasResults: Bool = false
    
    /// Search analytics
    @Published var searchHistory: [SearchHistoryEntry] = []
    @Published var recentSearches: [String] = []
    
    // MARK: - Private Properties
    
    var cancellables = Set<AnyCancellable>()
    private let debounceInterval: TimeInterval = 0.5
    private let maxRecentSearches: Int = 10
    private let maxSearchHistory: Int = 100
    
    // Data sources
    private var moduleDataSource: GenericSearchableDataSource<SearchableModule>?
    private var profileDataSource: GenericSearchableDataSource<SearchableProfile>?
    private var activityDataSource: GenericSearchableDataSource<SearchableActivity>?
    
    // MARK: - Initialization
    
    init() {
        setupSearchDebouncing()
        loadSearchHistory()
    }
    
    // MARK: - Public Methods
    
    /// Configure data sources for search
    func configureDataSources(
        modules: [SearchableModule],
        profiles: [SearchableProfile],
        activities: [SearchableActivity]
    ) {
        moduleDataSource = GenericSearchableDataSource(items: modules)
        profileDataSource = GenericSearchableDataSource(items: profiles)
        activityDataSource = GenericSearchableDataSource(items: activities)
    }
    
    /// Update search text with debouncing
    func updateSearchText(_ text: String) {
        criteria.searchText = text
    }
    
    /// Apply advanced search criteria
    func applyCriteria(_ newCriteria: SearchCriteria) {
        criteria = newCriteria
    }
    
    /// Reset search to initial state
    func resetSearch() {
        criteria = SearchCriteria()
        clearResults()
        searchError = nil
    }
    
    /// Clear all search results
    func clearResults() {
        moduleResults = []
        profileResults = []
        activityResults = []
        hasResults = false
    }
    
    /// Add search text to recent searches
    func addToRecentSearches(_ text: String) {
        guard !text.isEmpty && !recentSearches.contains(text) else { return }
        
        recentSearches.insert(text, at: 0)
        if recentSearches.count > maxRecentSearches {
            recentSearches.removeLast()
        }
        
        saveRecentSearches()
    }
    
    /// Get available categories across all data sources
    func getAvailableCategories() -> AnyPublisher<Set<String>, PrivarionError> {
        let publishers: [AnyPublisher<Set<String>, PrivarionError>] = [
            moduleDataSource?.availableCategories() ?? Empty().eraseToAnyPublisher(),
            profileDataSource?.availableCategories() ?? Empty().eraseToAnyPublisher(),
            activityDataSource?.availableCategories() ?? Empty().eraseToAnyPublisher()
        ]
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { categorySets in
                categorySets.reduce(Set<String>()) { result, categories in
                    result.union(categories)
                }
            }
            .eraseToAnyPublisher()
    }
    
    /// Get available statuses across all data sources
    func getAvailableStatuses() -> AnyPublisher<Set<SearchableItemStatus>, PrivarionError> {
        let publishers: [AnyPublisher<Set<SearchableItemStatus>, PrivarionError>] = [
            moduleDataSource?.availableStatuses() ?? Empty().eraseToAnyPublisher(),
            profileDataSource?.availableStatuses() ?? Empty().eraseToAnyPublisher(),
            activityDataSource?.availableStatuses() ?? Empty().eraseToAnyPublisher()
        ]
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { statusSets in
                statusSets.reduce(Set<SearchableItemStatus>()) { result, statuses in
                    result.union(statuses)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func setupSearchDebouncing() {
        // Debounce search text changes
        $criteria
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] criteria in
                self?.performSearch(with: criteria)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(with criteria: SearchCriteria) {
        guard criteria.hasActiveFilters else {
            clearResults()
            return
        }
        
        isSearching = true
        searchError = nil
        
        let startTime = Date()
        
        // Perform parallel searches
        let moduleSearch = moduleDataSource?.search(with: criteria) ?? Empty<[SearchableModule], PrivarionError>().eraseToAnyPublisher()
        let profileSearch = profileDataSource?.search(with: criteria) ?? Empty<[SearchableProfile], PrivarionError>().eraseToAnyPublisher()
        let activitySearch = activityDataSource?.search(with: criteria) ?? Empty<[SearchableActivity], PrivarionError>().eraseToAnyPublisher()
        
        Publishers.CombineLatest3(moduleSearch, profileSearch, activitySearch)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    
                    self.isSearching = false
                    
                    switch completion {
                    case .finished:
                        self.recordSearchCompletion(criteria: criteria, startTime: startTime, success: true)
                        if !criteria.searchText.isEmpty {
                            self.addToRecentSearches(criteria.searchText)
                        }
                    case .failure(let error):
                        self.searchError = error
                        self.recordSearchCompletion(criteria: criteria, startTime: startTime, success: false)
                    }
                },
                receiveValue: { [weak self] modules, profiles, activities in
                    guard let self = self else { return }
                    
                    self.moduleResults = modules
                    self.profileResults = profiles
                    self.activityResults = activities
                    self.hasResults = !modules.isEmpty || !profiles.isEmpty || !activities.isEmpty
                }
            )
            .store(in: &cancellables)
    }
    
    private func recordSearchCompletion(
        criteria: SearchCriteria,
        startTime: Date,
        success: Bool
    ) {
        let duration = Date().timeIntervalSince(startTime)
        let entry = SearchHistoryEntry(
            criteria: criteria,
            timestamp: Date(),
            duration: duration,
            resultCount: moduleResults.count + profileResults.count + activityResults.count,
            success: success
        )
        
        searchHistory.insert(entry, at: 0)
        if searchHistory.count > maxSearchHistory {
            searchHistory.removeLast()
        }
        
        saveSearchHistory()
    }
    
    // MARK: - Persistence (Simplified - In-Memory Only)
    
    private func loadSearchHistory() {
        // For now, only load recent searches from UserDefaults
        if let recent = UserDefaults.standard.array(forKey: "RecentSearches") as? [String] {
            recentSearches = recent
        }
    }
    
    private func saveSearchHistory() {
        // For now, don't persist complex search history
        // Only persist simple data
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "RecentSearches")
    }
}

// MARK: - Supporting Types

/// Search history entry for analytics
struct SearchHistoryEntry: Identifiable {
    let id = UUID()
    let criteria: SearchCriteria
    let timestamp: Date
    let duration: TimeInterval
    let resultCount: Int
    let success: Bool
    
    var formattedDuration: String {
        return String(format: "%.2fs", duration)
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Searchable Item Implementations

/// Searchable wrapper for Module
struct SearchableModule: SearchableItem {
    let id: String
    let name: String
    let description: String
    let category: String
    let status: SearchableItemStatus
    let isEnabled: Bool
    let dateCreated: Date
    let dateModified: Date
    
    var searchableText: String { name }
    var searchableKeywords: [String] { [description, category] }
    var isActive: Bool { isEnabled }
}

/// Searchable wrapper for Profile
struct SearchableProfile: SearchableItem {
    let id: String
    let name: String
    let description: String
    let category: String
    let status: SearchableItemStatus
    let isActive: Bool
    let dateCreated: Date
    let dateModified: Date
    
    var searchableText: String { name }
    var searchableKeywords: [String] { [description, category] }
}

/// Searchable wrapper for Activity Log Entry
struct SearchableActivity: SearchableItem {
    let id: String
    let message: String
    let level: String
    let category: String
    let status: SearchableItemStatus
    let timestamp: Date
    let dateCreated: Date
    let dateModified: Date
    
    var searchableText: String { message }
    var searchableKeywords: [String] { [level, category] }
    var isActive: Bool { true }
}

// MARK: - SearchCriteria Codable Extension

extension SearchCriteria: Codable {
    enum CodingKeys: String, CodingKey {
        case searchText, caseSensitive, exactMatch
        case categories, excludeCategories, statuses
        case dateRange, sortBy, sortOrder
        case includeInactive, maxResults
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        searchText = try container.decode(String.self, forKey: .searchText)
        caseSensitive = try container.decode(Bool.self, forKey: .caseSensitive)
        exactMatch = try container.decode(Bool.self, forKey: .exactMatch)
        categories = try container.decode(Set<String>.self, forKey: .categories)
        excludeCategories = try container.decode(Set<String>.self, forKey: .excludeCategories)
        statuses = try container.decode(Set<SearchableItemStatus>.self, forKey: .statuses)
        dateRange = try container.decodeIfPresent(DateRange.self, forKey: .dateRange)
        sortBy = try container.decode(SortOption.self, forKey: .sortBy)
        sortOrder = try container.decode(SortOrder.self, forKey: .sortOrder)
        includeInactive = try container.decode(Bool.self, forKey: .includeInactive)
        maxResults = try container.decodeIfPresent(Int.self, forKey: .maxResults)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(searchText, forKey: .searchText)
        try container.encode(caseSensitive, forKey: .caseSensitive)
        try container.encode(exactMatch, forKey: .exactMatch)
        try container.encode(categories, forKey: .categories)
        try container.encode(excludeCategories, forKey: .excludeCategories)
        try container.encode(statuses, forKey: .statuses)
        try container.encodeIfPresent(dateRange, forKey: .dateRange)
        try container.encode(sortBy, forKey: .sortBy)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(includeInactive, forKey: .includeInactive)
        try container.encodeIfPresent(maxResults, forKey: .maxResults)
    }
}


