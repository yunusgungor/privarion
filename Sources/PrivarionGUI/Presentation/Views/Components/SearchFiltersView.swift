//
//  SearchFiltersView.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import SwiftUI

/// Advanced search filters view with category, status, and date filtering
struct SearchFiltersView: View {
    
    // MARK: - Properties
    
    @ObservedObject var searchManager: SearchManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Local State
    
    @State private var selectedCategories: Set<String> = []
    @State private var selectedStatuses: Set<SearchableItemStatus> = []
    @State private var sortBy: SortOption = .name
    @State private var sortOrder: SortOrder = .ascending
    @State private var includeInactive: Bool = true
    @State private var dateFilterEnabled: Bool = false
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var exactMatch: Bool = false
    @State private var caseSensitive: Bool = false
    
    // Available options from search manager
    @State private var availableCategories: Set<String> = []
    @State private var availableStatuses: Set<SearchableItemStatus> = []
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Form {
                searchOptionsSection
                categoryFilterSection
                statusFilterSection
                sortingSection
                dateFilterSection
                advancedOptionsSection
            }
            .navigationTitle("Search Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        resetFilters()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentFilters()
                loadAvailableOptions()
            }
        }
    }
    
    // MARK: - Sections
    
    private var searchOptionsSection: some View {
        Section("Search Options") {
            Toggle("Exact match", isOn: $exactMatch)
            Toggle("Case sensitive", isOn: $caseSensitive)
            Toggle("Include inactive items", isOn: $includeInactive)
        }
    }
    
    private var categoryFilterSection: some View {
        Section("Categories") {
            ForEach(Array(availableCategories), id: \.self) { category in
                HStack {
                    Text(category)
                    Spacer()
                    if selectedCategories.contains(category) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleCategory(category)
                }
            }
        }
    }
    
    private var statusFilterSection: some View {
        Section("Status") {
            ForEach(Array(availableStatuses), id: \.self) { status in
                HStack {
                    StatusBadge(status: status)
                    Text(status.displayName)
                    Spacer()
                    if selectedStatuses.contains(status) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleStatus(status)
                }
            }
        }
    }
    
    private var sortingSection: some View {
        Section("Sorting") {
            Picker("Sort by", selection: $sortBy) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            
            Picker("Order", selection: $sortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.displayName).tag(order)
                }
            }
        }
    }
    
    private var dateFilterSection: some View {
        Section("Date Range") {
            Toggle("Filter by date", isOn: $dateFilterEnabled)
            
            if dateFilterEnabled {
                DatePicker("From", selection: $startDate, displayedComponents: .date)
                DatePicker("To", selection: $endDate, displayedComponents: .date)
                
                // Quick date range buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick ranges:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Last 7 days") {
                            setDateRange(.last7Days())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("Last 30 days") {
                            setDateRange(.last30Days())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Button("This month") {
                            setDateRange(.thisMonth())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                        Spacer()
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    private var advancedOptionsSection: some View {
        Section("Advanced") {
            HStack {
                Text("Applied filters:")
                Spacer()
                Text("\\(filterCount)")
                    .foregroundColor(.secondary)
            }
            
            if filterCount > 0 {
                Button("Clear all filters") {
                    clearAllFilters()
                }
                .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filterCount: Int {
        var count = 0
        if !selectedCategories.isEmpty { count += 1 }
        if !selectedStatuses.isEmpty { count += 1 }
        if dateFilterEnabled { count += 1 }
        if exactMatch { count += 1 }
        if caseSensitive { count += 1 }
        if !includeInactive { count += 1 }
        return count
    }
    
    // MARK: - Methods
    
    private func loadCurrentFilters() {
        let criteria = searchManager.criteria
        selectedCategories = criteria.categories
        selectedStatuses = criteria.statuses
        sortBy = criteria.sortBy
        sortOrder = criteria.sortOrder
        includeInactive = criteria.includeInactive
        exactMatch = criteria.exactMatch
        caseSensitive = criteria.caseSensitive
        
        if let dateRange = criteria.dateRange {
            dateFilterEnabled = true
            startDate = dateRange.startDate
            endDate = dateRange.endDate
        }
    }
    
    private func loadAvailableOptions() {
        // Load available categories
        searchManager.getAvailableCategories()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { categories in
                    availableCategories = categories
                }
            )
            .store(in: &searchManager.cancellables)
        
        // Load available statuses
        searchManager.getAvailableStatuses()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { statuses in
                    availableStatuses = statuses
                }
            )
            .store(in: &searchManager.cancellables)
    }
    
    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    private func toggleStatus(_ status: SearchableItemStatus) {
        if selectedStatuses.contains(status) {
            selectedStatuses.remove(status)
        } else {
            selectedStatuses.insert(status)
        }
    }
    
    private func setDateRange(_ range: DateRange) {
        startDate = range.startDate
        endDate = range.endDate
    }
    
    private func resetFilters() {
        selectedCategories.removeAll()
        selectedStatuses.removeAll()
        sortBy = .name
        sortOrder = .ascending
        includeInactive = true
        dateFilterEnabled = false
        exactMatch = false
        caseSensitive = false
        startDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        endDate = Date()
    }
    
    private func clearAllFilters() {
        resetFilters()
    }
    
    private func applyFilters() {
        let newCriteria = SearchCriteria(
            searchText: searchManager.criteria.searchText,
            caseSensitive: caseSensitive,
            exactMatch: exactMatch,
            categories: selectedCategories,
            excludeCategories: [],
            statuses: selectedStatuses,
            dateRange: dateFilterEnabled ? DateRange(startDate: startDate, endDate: endDate) : nil,
            sortBy: sortBy,
            sortOrder: sortOrder,
            includeInactive: includeInactive,
            maxResults: nil
        )
        
        searchManager.applyCriteria(newCriteria)
    }
}
