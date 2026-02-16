import SwiftUI
import PrivarionCore
import Logging

/// Settings view for temporary permission management
/// Context7 Research: UserDefaults integration patterns for persistent user preferences
struct TemporaryPermissionSettingsView: View {
    
    @EnvironmentObject private var appState: AppState
    private let logger = Logger(label: "TemporaryPermissionSettings")
    
    // MARK: - Settings State
    
    @AppStorage("temp_permission_default_duration") private var defaultDuration: Int = 30 // minutes
    @AppStorage("temp_permission_auto_refresh") private var autoRefreshEnabled: Bool = true
    @AppStorage("temp_permission_refresh_interval") private var refreshInterval: Int = 60 // seconds
    @AppStorage("temp_permission_show_expiry_notifications") private var showExpiryNotifications: Bool = true
    @AppStorage("temp_permission_notification_advance_time") private var notificationAdvanceTime: Int = 5 // minutes
    @AppStorage("temp_permission_auto_revoke_expired") private var autoRevokeExpired: Bool = false
    @AppStorage("temp_permission_export_format") private var preferredExportFormat: String = "json"
    @AppStorage("temp_permission_sort_order") private var sortOrder: String = "remaining_time"
    @AppStorage("temp_permission_group_by_app") private var groupByApp: Bool = false
    @AppStorage("temp_permission_show_advanced_details") private var showAdvancedDetails: Bool = false
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Default Behavior")) {
                    HStack {
                        Text("Default Duration")
                        Spacer()
                        Picker("Duration", selection: $defaultDuration) {
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                            Text("1 hour").tag(60)
                            Text("2 hours").tag(120)
                            Text("4 hours").tag(240)
                            Text("8 hours").tag(480)
                            Text("24 hours").tag(1440)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 120)
                    }
                    
                    HStack {
                        Text("Sort Order")
                        Spacer()
                        Picker("Sort", selection: $sortOrder) {
                            Text("Remaining Time").tag("remaining_time")
                            Text("Creation Date").tag("creation_date")
                            Text("App Name").tag("app_name")
                            Text("Service Name").tag("service_name")
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 140)
                    }
                    
                    Toggle("Group by Application", isOn: $groupByApp)
                    Toggle("Show Advanced Details", isOn: $showAdvancedDetails)
                }
                
                Section(header: Text("Auto-Refresh")) {
                    Toggle("Enable Auto-Refresh", isOn: $autoRefreshEnabled)
                    
                    if autoRefreshEnabled {
                        HStack {
                            Text("Refresh Interval")
                            Spacer()
                            Picker("Interval", selection: $refreshInterval) {
                                Text("30 seconds").tag(30)
                                Text("1 minute").tag(60)
                                Text("2 minutes").tag(120)
                                Text("5 minutes").tag(300)
                                Text("10 minutes").tag(600)
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 100)
                        }
                    }
                }
                
                Section(header: Text("Notifications")) {
                    Toggle("Show Expiry Notifications", isOn: $showExpiryNotifications)
                    
                    if showExpiryNotifications {
                        HStack {
                            Text("Notification Advance Time")
                            Spacer()
                            Picker("Advance Time", selection: $notificationAdvanceTime) {
                                Text("1 minute").tag(1)
                                Text("5 minutes").tag(5)
                                Text("10 minutes").tag(10)
                                Text("15 minutes").tag(15)
                                Text("30 minutes").tag(30)
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(width: 100)
                        }
                    }
                }
                
                Section(header: Text("Automation")) {
                    Toggle("Auto-Revoke Expired Permissions", isOn: $autoRevokeExpired)
                        .help("Automatically revoke permissions when they expire")
                }
                
                Section(header: Text("Export/Import")) {
                    HStack {
                        Text("Preferred Export Format")
                        Spacer()
                        Picker("Format", selection: $preferredExportFormat) {
                            Text("JSON").tag("json")
                            Text("CSV").tag("csv")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 120)
                    }
                }
                
                Section(header: Text("Actions")) {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Export Settings") {
                        Task { await exportSettings() }
                    }
                    
                    Button("Import Settings") {
                        importSettings()
                    }
                }
            }
            .navigationTitle("Permission Settings")
            .frame(minWidth: 500, minHeight: 600)
        }
        .onAppear {
            configureAutoRefresh()
        }
        .onChange(of: autoRefreshEnabled) { _ in
            configureAutoRefresh()
        }
        .onChange(of: refreshInterval) { _ in
            configureAutoRefresh()
        }
    }
    
    // MARK: - Settings Management
    
    private func resetToDefaults() {
        logger.info("Resetting temporary permission settings to defaults")
        
        defaultDuration = 30
        autoRefreshEnabled = true
        refreshInterval = 60
        showExpiryNotifications = true
        notificationAdvanceTime = 5
        autoRevokeExpired = false
        preferredExportFormat = "json"
        sortOrder = "remaining_time"
        groupByApp = false
        showAdvancedDetails = false
        
        configureAutoRefresh()
    }
    
    private func exportSettings() async {
        let settings = TemporaryPermissionSettings(
            defaultDuration: defaultDuration,
            autoRefreshEnabled: autoRefreshEnabled,
            refreshInterval: refreshInterval,
            showExpiryNotifications: showExpiryNotifications,
            notificationAdvanceTime: notificationAdvanceTime,
            autoRevokeExpired: autoRevokeExpired,
            preferredExportFormat: preferredExportFormat,
            sortOrder: sortOrder,
            groupByApp: groupByApp,
            showAdvancedDetails: showAdvancedDetails
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            
            await MainActor.run {
                let savePanel = NSSavePanel()
                savePanel.nameFieldStringValue = "temp_permission_settings.json"
                savePanel.allowedContentTypes = [.json]
                
                if savePanel.runModal() == .OK, let url = savePanel.url {
                    do {
                        try data.write(to: url)
                        logger.info("Settings exported successfully to: \(url.path)")
                    } catch {
                        logger.error("Failed to export settings: \(error)")
                    }
                }
            }
        } catch {
            logger.error("Failed to encode settings: \(error)")
        }
    }
    
    private func importSettings() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let settings = try JSONDecoder().decode(TemporaryPermissionSettings.self, from: data)
                
                defaultDuration = settings.defaultDuration
                autoRefreshEnabled = settings.autoRefreshEnabled
                refreshInterval = settings.refreshInterval
                showExpiryNotifications = settings.showExpiryNotifications
                notificationAdvanceTime = settings.notificationAdvanceTime
                autoRevokeExpired = settings.autoRevokeExpired
                preferredExportFormat = settings.preferredExportFormat
                sortOrder = settings.sortOrder
                groupByApp = settings.groupByApp
                showAdvancedDetails = settings.showAdvancedDetails
                
                logger.info("Settings imported successfully from: \(url.path)")
            } catch {
                logger.error("Failed to import settings: \(error)")
            }
        }
    }
    
    private func configureAutoRefresh() {
        if autoRefreshEnabled {
            logger.info("Configuring auto-refresh with interval: \(refreshInterval) seconds")
            // TODO: Set up timer-based auto-refresh in AppState
        } else {
            logger.info("Auto-refresh disabled")
            // TODO: Cancel auto-refresh timer in AppState
        }
    }
}

// MARK: - Settings Model

/// Codable model for settings export/import
private struct TemporaryPermissionSettings: Codable {
    let defaultDuration: Int
    let autoRefreshEnabled: Bool
    let refreshInterval: Int
    let showExpiryNotifications: Bool
    let notificationAdvanceTime: Int
    let autoRevokeExpired: Bool
    let preferredExportFormat: String
    let sortOrder: String
    let groupByApp: Bool
    let showAdvancedDetails: Bool
}

// MARK: - Settings Extensions

extension TemporaryPermissionSettingsView {
    /// Get current settings as a dictionary for use in other components
    static func getCurrentSettings() -> [String: Any] {
        let defaults = UserDefaults.standard
        return [
            "defaultDuration": defaults.integer(forKey: "temp_permission_default_duration"),
            "autoRefreshEnabled": defaults.bool(forKey: "temp_permission_auto_refresh"),
            "refreshInterval": defaults.integer(forKey: "temp_permission_refresh_interval"),
            "showExpiryNotifications": defaults.bool(forKey: "temp_permission_show_expiry_notifications"),
            "notificationAdvanceTime": defaults.integer(forKey: "temp_permission_notification_advance_time"),
            "autoRevokeExpired": defaults.bool(forKey: "temp_permission_auto_revoke_expired"),
            "preferredExportFormat": defaults.string(forKey: "temp_permission_export_format") ?? "json",
            "sortOrder": defaults.string(forKey: "temp_permission_sort_order") ?? "remaining_time",
            "groupByApp": defaults.bool(forKey: "temp_permission_group_by_app"),
            "showAdvancedDetails": defaults.bool(forKey: "temp_permission_show_advanced_details")
        ]
    }
}
