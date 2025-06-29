//
//  AdvancedPreferencesView.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-01-16.
//  Copyright © 2025 Privarion. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// Enhanced preferences view with categorized settings and advanced controls
/// Following established UserSettings pattern with improved UX
struct AdvancedPreferencesView: View {
    
    // MARK: - Properties
    
    @ObservedObject var userSettings: UserSettings
    @ObservedObject var searchManager: SearchManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Local State
    
    @State private var selectedCategory: SettingsCategory = .general
    @State private var isSearching: Bool = false
    @State private var searchText: String = ""
    @State private var showingExportSheet: Bool = false
    @State private var showingImportSheet: Bool = false
    @State private var showingResetAlert: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        HSplitView {
            // Sidebar with categories
            categorySidebar
                .frame(minWidth: 200, maxWidth: 250)
            
            // Main content area
            settingsContent
                .frame(minWidth: 400)
        }
        .navigationTitle("Advanced Preferences")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search settings...")
        .onChange(of: searchText) { newValue in
            updateSearchMode(newValue)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button("Export Settings...") {
                        showingExportSheet = true
                    }
                    
                    Button("Import Settings...") {
                        showingImportSheet = true
                    }
                    
                    Divider()
                    
                    Button("Reset to Defaults...") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .fileExporter(
            isPresented: $showingExportSheet,
            document: SettingsDocument(settings: userSettings),
            contentType: .json,
            defaultFilename: "privarion-settings"
        ) { result in
            handleExportResult(result)
        }
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                userSettings.resetToDefaults()
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
    }
    
    // MARK: - Sidebar
    
    private var categorySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Categories")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            List(SettingsCategory.allCases, id: \.self, selection: $selectedCategory) { category in
                CategoryRow(
                    category: category,
                    isSelected: selectedCategory == category,
                    settingsCount: getSettingsCount(for: category)
                )
            }
            .listStyle(SidebarListStyle())
        }
    }
    
    // MARK: - Main Content
    
    private var settingsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if isSearching {
                    searchResults
                } else {
                    categorySettings
                }
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Search Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            if searchText.isEmpty {
                Text("Start typing to search settings...")
                    .foregroundColor(.secondary)
            } else {
                let filteredSettings = getFilteredSettings()
                if filteredSettings.isEmpty {
                    EmptySearchView(searchText: searchText)
                } else {
                    ForEach(filteredSettings, id: \.key) { setting in
                        SettingRow(setting: setting, userSettings: userSettings)
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }
    
    private var categorySettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Category header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedCategory.displayName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(selectedCategory.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if selectedCategory == .advanced {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .help("Advanced settings - modify with caution")
                }
            }
            
            // Settings groups for category
            ForEach(getSettingsGroups(for: selectedCategory), id: \.title) { group in
                SettingsGroup(group: group, userSettings: userSettings)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateSearchMode(_ searchText: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSearching = !searchText.isEmpty
        }
    }
    
    private func getSettingsCount(for category: SettingsCategory) -> Int {
        return getSettingsGroups(for: category)
            .reduce(0) { $0 + $1.settings.count }
    }
    
    private func getFilteredSettings() -> [(key: String, setting: SettingItem)] {
        let allSettings = SettingsCategory.allCases.flatMap { category in
            getSettingsGroups(for: category).flatMap { group in
                group.settings.map { (key: $0.key, setting: $0) }
            }
        }
        
        return allSettings.filter { setting in
            let searchLower = searchText.lowercased()
            return setting.setting.title.lowercased().contains(searchLower) ||
                   setting.setting.description.lowercased().contains(searchLower) ||
                   setting.key.lowercased().contains(searchLower)
        }
    }
    
    private func getSettingsGroups(for category: SettingsCategory) -> [SettingsGroupData] {
        switch category {
        case .general:
            return [
                SettingsGroupData(
                    title: "Appearance",
                    description: "Customize the look and feel of the application",
                    settings: [
                        SettingItem(
                            key: "theme",
                            title: "Theme",
                            description: "Choose between light and dark themes",
                            type: .picker(options: ["auto", "light", "dark"], current: userSettings.theme)
                        ),
                        SettingItem(
                            key: "colorScheme",
                            title: "Accent Color",
                            description: "Select your preferred accent color",
                            type: .colorPicker(current: userSettings.accentColor)
                        )
                    ]
                ),
                SettingsGroupData(
                    title: "Language & Region",
                    description: "Set your language and regional preferences",
                    settings: [
                        SettingItem(
                            key: "language",
                            title: "Language",
                            description: "Application language",
                            type: .picker(options: ["en", "tr", "de", "fr"], current: userSettings.language)
                        )
                    ]
                )
            ]
            
        case .privacy:
            return [
                SettingsGroupData(
                    title: "Data Collection",
                    description: "Control what data is collected and shared",
                    settings: [
                        SettingItem(
                            key: "analytics",
                            title: "Analytics",
                            description: "Allow anonymous usage analytics to improve the app",
                            type: .toggle(isOn: userSettings.enableAnalytics)
                        ),
                        SettingItem(
                            key: "crashReports",
                            title: "Crash Reports",
                            description: "Automatically send crash reports to help fix bugs",
                            type: .toggle(isOn: userSettings.enableCrashReporting)
                        )
                    ]
                ),
                SettingsGroupData(
                    title: "Module Privacy",
                    description: "Privacy settings for individual modules",
                    settings: [
                        SettingItem(
                            key: "moduleLogging",
                            title: "Module Activity Logging",
                            description: "Log module activities for debugging",
                            type: .toggle(isOn: userSettings.enableModuleLogging)
                        )
                    ]
                )
            ]
            
        case .performance:
            return [
                SettingsGroupData(
                    title: "Update Intervals",
                    description: "Configure how often data is refreshed",
                    settings: [
                        SettingItem(
                            key: "refreshInterval",
                            title: "Refresh Interval",
                            description: "How often to check for system status updates",
                            type: .stepper(value: userSettings.refreshInterval, range: 5...300, step: 5, unit: "seconds")
                        ),
                        SettingItem(
                            key: "logRetention",
                            title: "Log Retention",
                            description: "Number of log entries to keep in memory",
                            type: .slider(value: userSettings.maxLogEntries, range: 100...5000, step: 100)
                        )
                    ]
                ),
                SettingsGroupData(
                    title: "Background Processing",
                    description: "Control background tasks and processing",
                    settings: [
                        SettingItem(
                            key: "backgroundUpdates",
                            title: "Background Updates",
                            description: "Allow updates when app is in background",
                            type: .toggle(isOn: userSettings.enableBackgroundUpdates)
                        )
                    ]
                )
            ]
            
        case .advanced:
            return [
                SettingsGroupData(
                    title: "Developer Options",
                    description: "Advanced options for debugging and development",
                    settings: [
                        SettingItem(
                            key: "debugMode",
                            title: "Debug Mode",
                            description: "Enable detailed logging and debug information",
                            type: .toggle(isOn: userSettings.enableDebugMode)
                        ),
                        SettingItem(
                            key: "logLevel",
                            title: "Log Level",
                            description: "Minimum level for log messages",
                            type: .picker(options: ["trace", "debug", "info", "notice", "warning", "error", "critical"], current: userSettings.logLevel)
                        )
                    ]
                ),
                SettingsGroupData(
                    title: "Experimental Features",
                    description: "Experimental features that may be unstable",
                    settings: [
                        SettingItem(
                            key: "betaFeatures",
                            title: "Beta Features",
                            description: "Enable experimental features (requires restart)",
                            type: .toggle(isOn: userSettings.enableBetaFeatures)
                        )
                    ]
                )
            ]
        }
    }
    
    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            print("Settings export initiated to: \(url)")
            // Export the actual settings asynchronously
            Task { @MainActor in
                if let data = userSettings.exportSettings() {
                    try? data.write(to: url)
                }
            }
        case .failure(let error):
            print("Export failed: \(error)")
        }
    }
    
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task { @MainActor in
                    userSettings.importSettings(from: url)
                }
            }
        case .failure(let error):
            print("Import failed: \(error)")
        }
    }
}

// MARK: - Supporting Types

enum SettingsCategory: String, CaseIterable {
    case general = "general"
    case privacy = "privacy"
    case performance = "performance"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .privacy: return "Privacy"
        case .performance: return "Performance"
        case .advanced: return "Advanced"
        }
    }
    
    var description: String {
        switch self {
        case .general: return "Basic application settings and appearance"
        case .privacy: return "Privacy and data collection preferences"
        case .performance: return "Performance tuning and optimization"
        case .advanced: return "Advanced options and developer settings"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .privacy: return "hand.raised"
        case .performance: return "speedometer"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

struct SettingsGroupData {
    let title: String
    let description: String
    let settings: [SettingItem]
}

struct SettingItem {
    let key: String
    let title: String
    let description: String
    let type: SettingType
}

enum SettingType {
    case toggle(isOn: Bool)
    case picker(options: [String], current: String)
    case slider(value: Double, range: ClosedRange<Double>, step: Double)
    case stepper(value: Int, range: ClosedRange<Int>, step: Int, unit: String)
    case colorPicker(current: Color)
    case textField(current: String, placeholder: String = "")
}

// MARK: - Supporting Views

struct CategoryRow: View {
    let category: SettingsCategory
    let isSelected: Bool
    let settingsCount: Int
    
    var body: some View {
        HStack {
            Image(systemName: category.icon)
                .foregroundColor(isSelected ? .white : .secondary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.body)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text("\(settingsCount) settings")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(6)
    }
}

struct SettingsGroup: View {
    let group: SettingsGroupData
    @ObservedObject var userSettings: UserSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(group.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                ForEach(group.settings, id: \.key) { setting in
                    SettingRow(setting: (key: setting.key, setting: setting), userSettings: userSettings)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct SettingRow: View {
    let setting: (key: String, setting: SettingItem)
    @ObservedObject var userSettings: UserSettings
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(setting.setting.title)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(setting.setting.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            settingControl
                .frame(minWidth: 120)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var settingControl: some View {
        switch setting.setting.type {
        case .toggle(let isOn):
            Toggle("", isOn: bindingForKey(setting.key, defaultValue: isOn))
                .toggleStyle(SwitchToggleStyle())
            
        case .picker(let options, let current):
            Picker("", selection: bindingForKey(setting.key, defaultValue: current)) {
                ForEach(options, id: \.self) { option in
                    Text(option.capitalized).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(minWidth: 100)
            
        case .slider(let value, let range, let step):
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(value))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(
                    value: bindingForKey(setting.key, defaultValue: value),
                    in: range,
                    step: step
                )
                .frame(width: 120)
            }
            
        case .stepper(let value, let range, let step, let unit):
            HStack {
                Stepper(
                    value: bindingForKey(setting.key, defaultValue: value),
                    in: range,
                    step: step
                ) {
                    Text("\(value) \(unit)")
                        .font(.caption)
                }
            }
            
        case .colorPicker(let current):
            ColorPicker("", selection: bindingForKey(setting.key, defaultValue: current))
                .frame(width: 50)
            
        case .textField(let current, let placeholder):
            TextField(placeholder, text: bindingForKey(setting.key, defaultValue: current))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 120)
        }
    }
    
    private func bindingForKey<T>(_ key: String, defaultValue: T) -> Binding<T> {
        return Binding<T>(
            get: {
                switch key {
                // Boolean settings
                case "analytics":
                    return userSettings.enableAnalytics as? T ?? defaultValue
                case "crashReports":
                    return userSettings.enableCrashReporting as? T ?? defaultValue
                case "moduleLogging":
                    return userSettings.enableModuleLogging as? T ?? defaultValue
                case "backgroundUpdates":
                    return userSettings.enableBackgroundUpdates as? T ?? defaultValue
                case "debugMode":
                    return userSettings.enableDebugMode as? T ?? defaultValue
                case "betaFeatures":
                    return userSettings.enableBetaFeatures as? T ?? defaultValue
                    
                // String settings
                case "theme":
                    return userSettings.theme as? T ?? defaultValue
                case "language":
                    return userSettings.language as? T ?? defaultValue
                case "logLevel":
                    return userSettings.logLevel as? T ?? defaultValue
                    
                // Numeric settings
                case "refreshInterval":
                    return userSettings.refreshInterval as? T ?? defaultValue
                case "logRetention":
                    return userSettings.maxLogEntries as? T ?? defaultValue
                    
                // Color settings
                case "colorScheme":
                    return userSettings.accentColor as? T ?? defaultValue
                    
                default:
                    return defaultValue
                }
            },
            set: { newValue in
                switch key {
                // Boolean settings
                case "analytics":
                    if let value = newValue as? Bool { userSettings.enableAnalytics = value }
                case "crashReports":
                    if let value = newValue as? Bool { userSettings.enableCrashReporting = value }
                case "moduleLogging":
                    if let value = newValue as? Bool { userSettings.enableModuleLogging = value }
                case "backgroundUpdates":
                    if let value = newValue as? Bool { userSettings.enableBackgroundUpdates = value }
                case "debugMode":
                    if let value = newValue as? Bool { userSettings.enableDebugMode = value }
                case "betaFeatures":
                    if let value = newValue as? Bool { userSettings.enableBetaFeatures = value }
                    
                // String settings
                case "theme":
                    if let value = newValue as? String { userSettings.theme = value }
                case "language":
                    if let value = newValue as? String { userSettings.language = value }
                case "logLevel":
                    if let value = newValue as? String { userSettings.logLevel = value }
                    
                // Numeric settings
                case "refreshInterval":
                    if let value = newValue as? Int { userSettings.refreshInterval = value }
                case "logRetention":
                    if let value = newValue as? Double { userSettings.maxLogEntries = value }
                    
                // Color settings
                case "colorScheme":
                    if let value = newValue as? Color { userSettings.accentColor = value }
                    
                default:
                    break
                }
            }
        )
    }
}

struct EmptySearchView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text("No settings found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("No settings match \"\(searchText)\"")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Document Type for Export

struct SettingsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var settingsData: Data
    
    init(settings: UserSettings) {
        // We'll handle the export asynchronously
        self.settingsData = Data()
    }
    
    init(configuration: ReadConfiguration) throws {
        // For import functionality
        self.settingsData = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: settingsData)
    }
}
