//
//  ShortcutSettingsView.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import SwiftUI

/// Keyboard shortcut settings view
/// Allows users to configure keyboard shortcuts for commands and navigation
struct ShortcutSettingsView: View {
    
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""
    @State private var selectedCategory: ShortcutCategory = .all
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Keyboard Shortcuts")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Configure keyboard shortcuts for commands and navigation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            // Filters
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search shortcuts...", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(maxWidth: 300)
                
                Spacer()
                
                // Category filter
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ShortcutCategory.allCases, id: \.self) { category in
                        Text(category.title).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding(.horizontal)
            
            Divider()
                .padding(.vertical, 8)
            
            // Shortcuts list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredShortcuts, id: \.id) { shortcut in
                        ShortcutRowView(shortcut: shortcut)
                        Divider()
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Computed Properties
    
    private var filteredShortcuts: [KeyboardShortcut] {
        let allShortcuts = appState.keyboardShortcutManager.getAllShortcuts()
        
        return allShortcuts.filter { shortcut in
            let matchesSearch = searchText.isEmpty || 
                shortcut.title.localizedCaseInsensitiveContains(searchText) ||
                shortcut.description.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == .all || shortcut.category == selectedCategory
            
            return matchesSearch && matchesCategory
        }
    }
}

/// Individual shortcut row view
struct ShortcutRowView: View {
    
    let shortcut: KeyboardShortcut
    @EnvironmentObject private var appState: AppState
    @State private var isEditing = false
    @State private var newKeyCombination = ""
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shortcut.title)
                    .font(.headline)
                
                Text(shortcut.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isEditing {
                HStack {
                    TextField("Press keys...", text: $newKeyCombination)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 120)
                        .onSubmit {
                            saveShortcut()
                        }
                    
                    Button("Save") {
                        saveShortcut()
                    }
                    .keyboardShortcut(.return)
                    
                    Button("Cancel") {
                        cancelEditing()
                    }
                    .keyboardShortcut(.escape)
                }
            } else {
                HStack {
                    Text(shortcut.keyCombination)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary)
                        .cornerRadius(6)
                    
                    Button("Edit") {
                        startEditing()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Private Methods
    
    private func startEditing() {
        isEditing = true
        newKeyCombination = shortcut.keyCombination
    }
    
    private func cancelEditing() {
        isEditing = false
        newKeyCombination = ""
    }
    
    private func saveShortcut() {
        guard !newKeyCombination.isEmpty else { return }
        
        appState.keyboardShortcutManager.updateShortcut(
            id: shortcut.id,
            newKeyCombination: newKeyCombination
        )
        
        isEditing = false
        newKeyCombination = ""
    }
}

// MARK: - Supporting Types

enum ShortcutCategory: String, CaseIterable {
    case all = "all"
    case navigation = "navigation"
    case commands = "commands"
    case modules = "modules"
    case profiles = "profiles"
    case settings = "settings"
    
    var title: String {
        switch self {
        case .all:
            return "All"
        case .navigation:
            return "Navigation"
        case .commands:
            return "Commands"
        case .modules:
            return "Modules"
        case .profiles:
            return "Profiles"
        case .settings:
            return "Settings"
        }
    }
}

struct KeyboardShortcut: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let keyCombination: String
    let category: ShortcutCategory
    let action: () -> Void
    
    init(title: String, description: String, keyCombination: String, category: ShortcutCategory, action: @escaping () -> Void) {
        self.title = title
        self.description = description
        self.keyCombination = keyCombination
        self.category = category
        self.action = action
    }
}

#Preview {
    ShortcutSettingsView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}
