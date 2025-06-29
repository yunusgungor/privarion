//
//  SearchableView.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import SwiftUI

/// Generic searchable list component with SwiftUI native search
/// Based on Context7 research: searchable() modifier for native iOS experience
struct SearchableView<Item: SearchableItem, ItemView: View>: View {
    
    // MARK: - Properties
    
    @ObservedObject var searchManager: SearchManager
    let items: [Item]
    let itemBuilder: (Item) -> ItemView
    let onItemSelected: ((Item) -> Void)?
    
    // MARK: - Local State
    
    @State private var searchText: String = ""
    @State private var showingFilters: Bool = false
    
    // MARK: - Initialization
    
    init(
        searchManager: SearchManager,
        items: [Item],
        onItemSelected: ((Item) -> Void)? = nil,
        @ViewBuilder itemBuilder: @escaping (Item) -> ItemView
    ) {
        self.searchManager = searchManager
        self.items = items
        self.onItemSelected = onItemSelected
        self.itemBuilder = itemBuilder
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Results List
                if searchManager.hasResults || !searchText.isEmpty {
                    searchResultsList
                } else {
                    defaultContentList
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search items...")
            .onChange(of: searchText) { newValue in
                searchManager.updateSearchText(newValue)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(searchManager.criteria.hasActiveFilters ? .accentColor : .secondary)
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                SearchFiltersView(searchManager: searchManager)
            }
        }
    }
    
    // MARK: - Private Views
    
    private var searchResultsList: some View {
        Group {
            if searchManager.isSearching {
                VStack {
                    ProgressView("Searching...")
                        .padding()
                    Spacer()
                }
            } else if !searchManager.hasResults && !searchText.isEmpty {
                EmptySearchResultsView(searchText: searchText)
            } else {
                List {
                    searchResultsSection
                }
            }
        }
    }
    
    private var defaultContentList: some View {
        List {
            ForEach(items) { item in
                Button(action: {
                    onItemSelected?(item)
                }) {
                    itemBuilder(item)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var searchResultsSection: some View {
        Group {
            if !searchManager.moduleResults.isEmpty {
                Section("Modules (\(searchManager.moduleResults.count))") {
                    ForEach(searchManager.moduleResults, id: \.id) { module in
                        SearchResultRow(
                            title: module.name,
                            subtitle: module.description,
                            category: module.category,
                            status: module.status
                        ) {
                            // Handle module selection
                        }
                    }
                }
            }
            
            if !searchManager.profileResults.isEmpty {
                Section("Profiles (\(searchManager.profileResults.count))") {
                    ForEach(searchManager.profileResults, id: \.id) { profile in
                        SearchResultRow(
                            title: profile.name,
                            subtitle: profile.description,
                            category: profile.category,
                            status: profile.status
                        ) {
                            // Handle profile selection
                        }
                    }
                }
            }
            
            if !searchManager.activityResults.isEmpty {
                Section("Activity (\(searchManager.activityResults.count))") {
                    ForEach(searchManager.activityResults, id: \.id) { activity in
                        SearchResultRow(
                            title: activity.message,
                            subtitle: activity.formattedTimestamp,
                            category: activity.category,
                            status: activity.status
                        ) {
                            // Handle activity selection
                        }
                    }
                }
            }
        }
    }
}

/// Individual search result row component
struct SearchResultRow: View {
    let title: String
    let subtitle: String
    let category: String
    let status: SearchableItemStatus
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(category)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    StatusBadge(status: status)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Status badge component
struct StatusBadge: View {
    let status: SearchableItemStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch status {
        case .active: return .green
        case .inactive: return .gray
        case .pending: return .orange
        case .error: return .red
        case .success: return .green
        case .warning: return .yellow
        }
    }
}

/// Empty search results view
struct EmptySearchResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No results found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("No items match \"\(searchText)\"")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Try adjusting your search terms or filters")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Extensions

extension SearchableActivity {
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
