import SwiftUI
import Logging

// MARK: - Modules View

/// Privacy modules management view
struct ModulesView: View {
    
    @EnvironmentObject private var appState: AppState
    private let logger = Logger(label: "ModulesView")
    
    var body: some View {
        VStack {
            if appState.modules.isEmpty {
                EmptyStateView(
                    systemImage: "shield.slash",
                    title: "No Modules Available",
                    subtitle: "Privacy modules will appear here when available"
                )
            } else {
                List(appState.modules) { module in
                    ModuleRowView(module: module)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Privacy Modules")
        .navigationSubtitle("\\(appState.modules.count) modules available")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh") {
                    Task {
                        await appState.initialize()
                    }
                }
            }
        }
    }
}

struct ModuleRowView: View {
    let module: PrivacyModule
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(module.name)
                    .font(.headline)
                
                Text(module.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !module.dependencies.isEmpty {
                    Text("Dependencies: \(module.dependencies.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Button {
                    Task {
                        await appState.toggleModule(module.id)
                    }
                } label: {
                    Toggle("", isOn: .constant(module.isEnabled))
                        .labelsHidden()
                        .disabled(appState.isLoading["modules"] == true)
                }
                .buttonStyle(.plain)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(module.status.color)
                        .frame(width: 6, height: 6)
                    
                    Text(module.status.rawValue)
                        .font(.caption2)
                        .foregroundColor(module.status.color)
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(appState.isLoading["modules"] == true ? 0.6 : 1.0)
    }
}

// MARK: - Profiles View

/// Configuration profiles management view
struct ProfilesView: View {
    
    @EnvironmentObject private var appState: AppState
    private let logger = Logger(label: "ProfilesView")
    
    var body: some View {
        VStack {
            if appState.profiles.isEmpty {
                EmptyStateView(
                    systemImage: "person.2.circle",
                    title: "No Profiles Available",
                    subtitle: "Configuration profiles will appear here"
                )
            } else {
                List(appState.profiles) { profile in
                    ProfileRowView(profile: profile)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Configuration Profiles")
        .navigationSubtitle("\\(appState.profiles.count) profiles available")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Create Profile") {
                        // TODO: Implement profile creation
                    }
                    
                    Button("Import Profile") {
                        // TODO: Implement profile import
                    }
                    
                    Divider()
                    
                    Button("Refresh") {
                        Task {
                            await appState.initialize()
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

struct ProfileRowView: View {
    let profile: ConfigurationProfile
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    
                    if profile.isActive {
                        Text("ACTIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(Capsule())
                    }
                }
                
                Text(profile.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Modified: \(formatDate(profile.modifiedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("\(profile.settings.count) settings configured")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                Button(profile.isActive ? "Active" : "Activate") {
                    if !profile.isActive {
                        Task {
                            await appState.switchProfile(profile.id)
                        }
                    }
                }
                .disabled(profile.isActive || appState.isLoading["profiles"] == true)
                .controlSize(.small)
                
                Menu {
                    Button("Export") {
                        // TODO: Export profile
                    }
                    
                    if !profile.isActive {
                        Button("Delete", role: .destructive) {
                            // TODO: Delete profile
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .controlSize(.small)
                .disabled(appState.isLoading["profiles"] == true)
            }
        }
        .padding(.vertical, 4)
        .opacity(appState.isLoading["profiles"] == true ? 0.6 : 1.0)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Logs View

/// Activity logs and system monitoring view
struct LogsView: View {
    
    @EnvironmentObject private var appState: AppState
    private let logger = Logger(label: "LogsView")
    
    var body: some View {
        VStack {
            if appState.recentActivity.isEmpty {
                EmptyStateView(
                    systemImage: "list.bullet.rectangle",
                    title: "No Activity Logs",
                    subtitle: "System activity and logs will appear here"
                )
            } else {
                List(appState.recentActivity) { activity in
                    LogEntryRowView(activity: activity)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .navigationTitle("Activity Logs")
        .navigationSubtitle("\\(appState.recentActivity.count) entries")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Refresh") {
                        Task {
                            await appState.initialize()
                        }
                    }
                    
                    Button("Export Logs") {
                        // TODO: Implement log export
                    }
                    
                    Button("Clear Logs") {
                        // TODO: Implement log clearing
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}

struct LogEntryRowView: View {
    let activity: ActivityLogEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(activity.level.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(activity.action)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(formatTimestamp(activity.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(activity.details)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Settings View

/// Application settings and preferences view
struct SettingsView: View {
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var userSettings = UserSettings.shared
    private let logger = Logger(label: "SettingsView")
    
    @State private var showingExportAlert = false
    @State private var showingImportAlert = false
    @State private var showingResetAlert = false
    @State private var importError: String?
    
    var body: some View {
        // Check the current navigation route to determine which settings view to show
        switch appState.navigationManager.currentRoute {
        case .shortcuts:
            ShortcutSettingsView()
        case .advancedSettings:
            AdvancedPreferencesView(
                userSettings: userSettings,
                searchManager: appState.searchManager
            )
        default:
            generalSettingsView
        }
    }
    
    // MARK: - General Settings View
    
    private var generalSettingsView: some View {
        Form {
            // Application Settings Section
            Section("Application") {
                Toggle("Enable Logging", isOn: $userSettings.enableLogging)
                    .onChange(of: userSettings.enableLogging) { _ in
                        logger.info("Logging \(userSettings.enableLogging ? "enabled" : "disabled")")
                    }
                
                Picker("Log Level", selection: $userSettings.logLevel) {
                    Text("Debug").tag("Debug")
                    Text("Info").tag("Info")
                    Text("Warning").tag("Warning")
                    Text("Error").tag("Error")
                }
                .disabled(!userSettings.enableLogging)
                
                Toggle("Auto Start on Login", isOn: $userSettings.autoStart)
                    .onChange(of: userSettings.autoStart) { _ in
                        logger.info("Auto start \(userSettings.autoStart ? "enabled" : "disabled")")
                    }
                
                Toggle("Show Notifications", isOn: $userSettings.showNotifications)
                
                Toggle("Enable Sound Notifications", isOn: $userSettings.enableSoundNotifications)
                    .disabled(!userSettings.showNotifications)
            }
            
            // Interface Settings Section
            Section("Interface") {
                Picker("Theme", selection: $userSettings.theme) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("Auto").tag("auto")
                }
                
                HStack {
                    Text("Refresh Interval")
                    Spacer()
                    Text("\(userSettings.refreshInterval)s")
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(userSettings.refreshInterval) },
                        set: { userSettings.refreshInterval = Int($0) }
                    ),
                    in: 5...300,
                    step: 5
                ) {
                    Text("Refresh Interval")
                } minimumValueLabel: {
                    Text("5s")
                } maximumValueLabel: {
                    Text("5m")
                }
                .onChange(of: userSettings.refreshInterval) { _ in
                    appState.updateRefreshInterval()
                }
                
                HStack {
                    Text("Max Recent Activity")
                    Spacer()
                    Text("\(userSettings.maxRecentActivity)")
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { Double(userSettings.maxRecentActivity) },
                        set: { userSettings.maxRecentActivity = Int($0) }
                    ),
                    in: 10...1000,
                    step: 10
                ) {
                    Text("Max Recent Activity")
                } minimumValueLabel: {
                    Text("10")
                } maximumValueLabel: {
                    Text("1000")
                }
                
                Toggle("Show Detailed Module Info", isOn: $userSettings.showDetailedModuleInfo)
                
                HStack {
                    Text("Sidebar Width")
                    Spacer()
                    Text("\(Int(userSettings.sidebarWidth))px")
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: $userSettings.sidebarWidth,
                    in: 200...400,
                    step: 10
                ) {
                    Text("Sidebar Width")
                } minimumValueLabel: {
                    Text("200")
                } maximumValueLabel: {
                    Text("400")
                }
            }
            
            // Privacy Settings Section
            Section("Privacy") {
                Toggle("Enable Privacy Analytics", isOn: $userSettings.enablePrivacyAnalytics)
                
                Toggle("Auto Apply Profiles", isOn: $userSettings.autoApplyProfiles)
                
                Toggle("Show Privacy Status in Menu Bar", isOn: $userSettings.showPrivacyStatusInMenuBar)
            }
            
            // Developer Settings Section
            if userSettings.showDeveloperOptions {
                Section("Developer") {
                    Toggle("Debug Mode", isOn: $userSettings.debugMode)
                    
                    Toggle("Show Developer Options", isOn: $userSettings.showDeveloperOptions)
                    
                    Toggle("Verbose Logging", isOn: $userSettings.verboseLogging)
                        .disabled(!userSettings.enableLogging)
                }
            }
            
            // System Information Section
            Section("System") {
                HStack {
                    Text("Configuration Directory")
                    Spacer()
                    Text("~/.privarion")
                        .foregroundColor(.secondary)
                    Button("Open") {
                        openConfigurationDirectory()
                    }
                    .controlSize(.small)
                }
                
                HStack {
                    Text("Log Directory")
                    Spacer()
                    Text("~/.privarion/logs")
                        .foregroundColor(.secondary)
                    Button("Open") {
                        openLogDirectory()
                    }
                    .controlSize(.small)
                }
                
                HStack {
                    Text("Cache Size")
                    Spacer()
                    Text("~2.5 MB")
                        .foregroundColor(.secondary)
                    Button("Clear") {
                        clearCache()
                    }
                    .controlSize(.small)
                }
            }
            
            // Settings Management Section
            Section("Settings Management") {
                NavigationLink("Advanced Preferences") {
                    AdvancedPreferencesView(
                        userSettings: userSettings, 
                        searchManager: appState.searchManager
                    )
                }
                .buttonStyle(.plain)
                
                HStack {
                    Button("Export Settings") {
                        exportSettings()
                    }
                    
                    Spacer()
                    
                    Button("Import Settings") {
                        importSettings()
                    }
                    
                    Spacer()
                    
                    Button("Reset to Defaults") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            
            // About Section
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("2025.06.30")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Swift Version")
                    Spacer()
                    Text("6.0")
                        .foregroundColor(.secondary)
                }
                
                Link("GitHub Repository", destination: URL(string: "https://github.com/privarion/privarion")!)
                
                Link("Documentation", destination: URL(string: "https://docs.privarion.app")!)
                
                if userSettings.debugMode {
                    Button("Show Developer Options") {
                        userSettings.showDeveloperOptions.toggle()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationSubtitle("Application Preferences")
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                userSettings.resetToDefaults()
                appState.applyUserSettings()
                logger.info("Settings reset to defaults")
            }
        } message: {
            Text("This will reset all settings to their default values. This action cannot be undone.")
        }
        .alert("Export Error", isPresented: $showingExportAlert) {
            Button("OK") { }
        } message: {
            Text("Failed to export settings. Please try again.")
        }
        .alert("Import Error", isPresented: $showingImportAlert) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "Failed to import settings.")
        }
        .onAppear {
            logger.debug("Settings view appeared")
        }
    }
    
    // MARK: - Private Methods
    
    private func exportSettings() {
        guard let data = userSettings.exportSettings() else {
            showingExportAlert = true
            return
        }
        
        let panel = NSSavePanel()
        panel.title = "Export Settings"
        panel.nameFieldStringValue = "privarion-settings.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            do {
                try data.write(to: url)
                logger.info("Settings exported to \(url.path)")
            } catch {
                logger.error("Failed to write settings file: \(error)")
                showingExportAlert = true
            }
        }
    }
    
    private func importSettings() {
        let panel = NSOpenPanel()
        panel.title = "Import Settings"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        panel.begin { response in
            guard response == .OK, let url = panel.urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                if userSettings.importSettings(from: data) {
                    appState.applyUserSettings()
                    logger.info("Settings imported from \(url.path)")
                } else {
                    importError = "Invalid settings file format."
                    showingImportAlert = true
                }
            } catch {
                logger.error("Failed to read settings file: \(error)")
                importError = error.localizedDescription
                showingImportAlert = true
            }
        }
    }
    
    private func openConfigurationDirectory() {
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".privarion")
        NSWorkspace.shared.open(url)
        logger.debug("Opened configuration directory")
    }
    
    private func openLogDirectory() {
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".privarion/logs")
        NSWorkspace.shared.open(url)
        logger.debug("Opened log directory")
    }
    
    private func clearCache() {
        // TODO: Implement cache clearing
        logger.info("Cache clearing requested")
    }
}

// MARK: - Preview

#if canImport(SwiftUI) && os(macOS)
#Preview("Modules") {
    ModulesView()
        .environmentObject(AppState())
}

#Preview("Profiles") {
    ProfilesView()
        .environmentObject(AppState())
}

#Preview("Logs") {
    LogsView()
        .environmentObject(AppState())
}

#Preview("Settings") {
    SettingsView()
        .environmentObject(AppState())
}
#endif
