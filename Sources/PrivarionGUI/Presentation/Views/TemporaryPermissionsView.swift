import SwiftUI
import PrivarionCore
import Logging
import AppKit
import UniformTypeIdentifiers
import OrderedCollections

/// Temporary Permissions View implementing Clean Architecture patterns
/// Based on Context7 research: Clean SwiftUI patterns + TCA state management
/// Integrates with TemporaryPermissionManager actor for permission management
struct TemporaryPermissionsView: View {
    
    @EnvironmentObject private var appState: AppState
    private let logger = Logger(label: "TemporaryPermissionsView")
    
    // Batch operations state - Context7 Research: OrderedSet for efficient selection management
    @State private var selectedPermissions: OrderedSet<PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant> = []
    @State private var isInSelectionMode: Bool = false
    @State private var showingBatchActionSheet = false
    
    // Export/Import state
    @State private var showingImportPicker = false
    @State private var showingExportSuccess = false
    @State private var showingExportError = false
    @State private var exportErrorMessage = ""
    @State private var showingSettings = false
    
    var body: some View {
        NavigationSplitView {
            PermissionListView(
                selectedPermissions: $selectedPermissions,
                isInSelectionMode: isInSelectionMode
            )
                .navigationTitle("Active Permissions")
                .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 400)
        } detail: {
            PermissionDetailView()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 8) {
                    // Batch operations toggle
                    Button(isInSelectionMode ? "Done" : "Select") {
                        toggleSelectionMode()
                    }
                    .disabled(appState.temporaryPermissionState.isLoading)
                    
                    // Batch actions (visible only in selection mode)
                    if isInSelectionMode && !selectedPermissions.isEmpty {
                        Button("Actions") {
                            showingBatchActionSheet = true
                        }
                        .disabled(appState.temporaryPermissionState.isLoading)
                    }
                    
                    Menu {
                        Button("Export to JSON") {
                            Task { await exportToJSON() }
                        }
                        Button("Export to CSV") {
                            Task { await exportToCSV() }
                        }
                        Divider()
                        Button("Import Templates") {
                            showingImportPicker = true
                        }
                    } label: {
                        Label("Export/Import", systemImage: "square.and.arrow.up")
                    }
                    .disabled(appState.temporaryPermissionState.isLoading)
                    
                    Button("Grant Permission") {
                        appState.temporaryPermissionState.showingGrantSheet = true
                    }
                    .disabled(appState.temporaryPermissionState.isLoading)
                }
            }
            
            ToolbarItem(placement: .secondaryAction) {
                HStack(spacing: 8) {
                    Button("Settings") {
                        showingSettings = true
                    }
                    .disabled(appState.temporaryPermissionState.isLoading)
                    
                    Button("Refresh") {
                        Task {
                            await appState.temporaryPermissionState.refresh()
                        }
                    }
                    .disabled(appState.temporaryPermissionState.isLoading)
                }
            }
        }
        .sheet(isPresented: $appState.temporaryPermissionState.showingGrantSheet) {
            GrantPermissionSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingSettings) {
            TemporaryPermissionSettingsView()
                .environmentObject(appState)
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleImport(result)
            }
        }
        .alert("Export Successful", isPresented: $showingExportSuccess) {
            Button("OK") { }
        } message: {
            Text("Permissions have been exported successfully.")
        }
        .alert("Export Failed", isPresented: $showingExportError) {
            Button("OK") { exportErrorMessage = "" }
        } message: {
            Text(exportErrorMessage)
        }
        .confirmationDialog("Batch Actions", isPresented: $showingBatchActionSheet) {
            Button("Revoke Selected (\(selectedPermissions.count))") {
                Task { await performBatchRevoke() }
            }
            .disabled(selectedPermissions.isEmpty)
            
            Button("Export Selected") {
                Task { await exportSelectedPermissions() }
            }
            .disabled(selectedPermissions.isEmpty)
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("\(selectedPermissions.count) permission(s) selected")
        }
        .task {
            await appState.temporaryPermissionState.refresh()
        }
    }
    
    // MARK: - Batch Operations Methods
    
    private func toggleSelectionMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isInSelectionMode.toggle()
            if !isInSelectionMode {
                selectedPermissions.removeAll()
            }
        }
    }
    
    private func performBatchRevoke() async {
        logger.info("Starting batch revoke operation for \(selectedPermissions.count) permissions")
        
        for permission in selectedPermissions {
            let success = await appState.temporaryPermissionState.revokePermission(grantID: permission.id)
            if success {
                logger.info("Successfully revoked permission: \(permission.id)")
            } else {
                logger.error("Failed to revoke permission: \(permission.id)")
            }
        }
        
        // Clear selection and refresh
        await MainActor.run {
            selectedPermissions.removeAll()
            isInSelectionMode = false
        }
        
        await appState.temporaryPermissionState.refresh()
        logger.info("Batch revoke operation completed")
    }
    
    private func exportSelectedPermissions() async {
        do {
            let permissionsArray = Array(selectedPermissions)
            let data = try await PermissionExportManager().exportToJSON(permissions: permissionsArray)
            await saveFile(data: data, fileName: "selected_permissions.json", contentType: .json)
        } catch {
            await MainActor.run {
                exportErrorMessage = error.localizedDescription
                showingExportError = true
            }
        }
    }
    
    // MARK: - Export/Import Methods
    
    private func exportToJSON() async {
        do {
            let data = try await appState.exportPermissionsToJSON()
            await saveFile(data: data, fileName: "permissions.json", contentType: .json)
        } catch {
            await MainActor.run {
                exportErrorMessage = error.localizedDescription
                showingExportError = true
            }
        }
    }
    
    private func exportToCSV() async {
        do {
            let data = try await appState.exportPermissionsToCSV()
            await saveFile(data: data, fileName: "permissions.csv", contentType: .commaSeparatedText)
        } catch {
            await MainActor.run {
                exportErrorMessage = error.localizedDescription
                showingExportError = true
            }
        }
    }
    
    private func saveFile(data: Data, fileName: String, contentType: UTType) async {
        await MainActor.run {
            let savePanel = NSSavePanel()
            savePanel.nameFieldStringValue = fileName
            savePanel.allowedContentTypes = [contentType]
            
            if savePanel.runModal() == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url)
                    showingExportSuccess = true
                } catch {
                    exportErrorMessage = "Failed to save file: \(error.localizedDescription)"
                    showingExportError = true
                }
            }
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let templates = try await appState.importPermissionTemplates(from: data)
                
                // TODO: Show import success and template management UI
                await MainActor.run {
                    logger.info("Imported \(templates.count) permission templates")
                }
            } catch {
                await MainActor.run {
                    exportErrorMessage = "Import failed: \(error.localizedDescription)"
                    showingExportError = true
                }
            }
            
        case .failure(let error):
            await MainActor.run {
                exportErrorMessage = "File selection failed: \(error.localizedDescription)"
                showingExportError = true
            }
        }
    }
}

// MARK: - Permission List View

/// List view showing active temporary permissions
/// Implements reactive updates with @Published state
private struct PermissionListView: View {
    
    @EnvironmentObject private var appState: AppState
    @Binding var selectedPermissions: OrderedSet<PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant>
    let isInSelectionMode: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with stats
            PermissionStatsHeader()
            
            // Permission list
            VStack {
                if appState.temporaryPermissionState.isLoading && appState.temporaryPermissionState.activeGrants.isEmpty {
                    LoadingView()
                } else if appState.temporaryPermissionState.activeGrants.isEmpty {
                    PermissionsEmptyStateView()
                } else {
                    List(appState.temporaryPermissionState.activeGrants, id: \.id, selection: isInSelectionMode ? nil : $appState.temporaryPermissionState.selectedGrant) { grant in
                        PermissionRowView(
                            grant: grant,
                            selectedPermissions: $selectedPermissions,
                            isInSelectionMode: isInSelectionMode
                        )
                        .tag(grant)
                    }
                    .listStyle(.inset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            if appState.temporaryPermissionState.isLoading && !appState.temporaryPermissionState.activeGrants.isEmpty {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding()
            }
        }
    }
}

// MARK: - Permission Stats Header

/// Header showing permission statistics
private struct PermissionStatsHeader: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 16) {
            PermissionStatCard(
                title: "Active",
                value: "\(appState.temporaryPermissionState.activeGrants.count)",
                color: .blue
            )
            
            PermissionStatCard(
                title: "Expiring Soon",
                value: "\(expiringSoonCount)",
                color: .orange
            )
            
            PermissionStatCard(
                title: "Total Duration",
                value: totalDurationText,
                color: .green
            )
        }
        .padding()
        .background(.quaternary.opacity(0.5))
    }
    
    private var expiringSoonCount: Int {
        appState.temporaryPermissionState.activeGrants.filter(\.isExpiringSoon).count
    }
    
    private var totalDurationText: String {
        let totalMinutes = appState.temporaryPermissionState.activeGrants
            .reduce(0) { $0 + $1.remainingTime / 60 }
        return "\(Int(totalMinutes))m"
    }
}

// MARK: - Permission Stat Card Component

/// Reusable stat card component for permissions
private struct PermissionStatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - Permission Row View

/// Individual permission row in the list
private struct PermissionRowView: View {
    let grant: PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant
    @Binding var selectedPermissions: OrderedSet<PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant>
    let isInSelectionMode: Bool
    
    private var isSelected: Bool {
        selectedPermissions.contains(grant)
    }
    
    var body: some View {
        HStack {
            // Selection checkbox (visible only in selection mode)
            if isInSelectionMode {
                Button(action: toggleSelection) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .secondary)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(grant.bundleIdentifier)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(grant.serviceName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Label {
                        Text(remainingTimeText)
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.caption2)
                    .foregroundColor(grant.isExpiringSoon ? .orange : .secondary)
                    
                    if !grant.reason.isEmpty {
                        Label {
                            Text(grant.reason)
                                .lineLimit(1)
                        } icon: {
                            Image(systemName: "text.quote")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                Text(grant.grantedBy)
                    .font(.caption2)
                    .foregroundColor(Color(.tertiaryLabelColor))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if isInSelectionMode {
                toggleSelection()
            }
        }
    }
    
    private func toggleSelection() {
        if isSelected {
            selectedPermissions.remove(grant)
        } else {
            selectedPermissions.append(grant)
        }
    }
    
    private var remainingTimeText: String {
        let minutes = Int(grant.remainingTime / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
    
    private var statusColor: Color {
        if grant.isExpired {
            return .red
        } else if grant.isExpiringSoon {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - Permission Detail View

/// Detail view for selected permission
private struct PermissionDetailView: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Group {
            if let selectedGrant = appState.temporaryPermissionState.selectedGrant {
                PermissionDetailContent(grant: selectedGrant)
            } else {
                EmptyDetailView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.controlBackgroundColor))
    }
}

// MARK: - Permission Detail Content

/// Content view for permission details
private struct PermissionDetailContent: View {
    let grant: PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant
    @EnvironmentObject private var appState: AppState
    @State private var showingRevokeConfirmation = false
    @State private var isRevoking = false
    @State private var showingRevokeSuccess = false
    @State private var revokeError: String?
    
    private var statusColor: Color {
        grant.isExpired ? .red : .green
    }
    
    private var statusText: String {
        grant.isExpired ? "Expired" : "Active"
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(grant.bundleIdentifier)
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)
                                
                                Text(statusText)
                                    .font(.caption)
                                    .foregroundColor(statusColor)
                                    .fontWeight(.medium)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            if grant.isExpired {
                                Text("Expired")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.red.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            Button(action: {
                                showingRevokeConfirmation = true
                            }) {
                                HStack {
                                    if isRevoking {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "trash")
                                    }
                                    Text("Revoke")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(appState.temporaryPermissionState.isLoading || isRevoking || grant.isExpired)
                        }
                    }
                    
                    Text(grant.serviceName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                // Status and timing
                PermissionStatusSection(grant: grant)
                
                // Details
                PermissionDetailsSection(grant: grant)
                
                Spacer()
            }
            .padding()
        }
        .confirmationDialog(
            "Are you sure you want to revoke this permission?",
            isPresented: $showingRevokeConfirmation,
            titleVisibility: .visible
        ) {
            Button("Revoke", role: .destructive) {
                Task {
                    await revokePermission()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. The application \"\(grant.bundleIdentifier)\" will lose \"\(grant.serviceName)\" permission immediately.")
        }
        .alert("Permission Revoked", isPresented: $showingRevokeSuccess) {
            Button("OK") { }
        } message: {
            Text("Permission for \"\(grant.bundleIdentifier)\" has been successfully revoked.")
        }
        .alert("Revoke Failed", isPresented: .init(
            get: { revokeError != nil },
            set: { if !$0 { revokeError = nil } }
        )) {
            Button("OK") { revokeError = nil }
        } message: {
            Text(revokeError ?? "An unknown error occurred")
        }
    }
    
    private func revokePermission() async {
        isRevoking = true
        
        let success = await appState.temporaryPermissionState.revokePermission(grantID: grant.id)
        
        await MainActor.run {
            isRevoking = false
            if success {
                showingRevokeSuccess = true
            } else {
                revokeError = "Failed to revoke permission. Please try again."
            }
        }
    }
}

// MARK: - Permission Status Section

private struct PermissionStatusSection: View {
    let grant: PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Status")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                InfoCard(
                    title: "Status",
                    value: statusText,
                    icon: "checkmark.circle.fill",
                    color: statusColor
                )
                
                InfoCard(
                    title: "Remaining Time",
                    value: remainingTimeText,
                    icon: "clock.fill",
                    color: grant.isExpiringSoon ? .orange : .blue
                )
                
                InfoCard(
                    title: "Granted",
                    value: RelativeDateTimeFormatter().localizedString(for: grant.grantedAt, relativeTo: Date()),
                    icon: "calendar",
                    color: .green
                )
                
                InfoCard(
                    title: "Expires",
                    value: RelativeDateTimeFormatter().localizedString(for: grant.expiresAt, relativeTo: Date()),
                    icon: "alarm",
                    color: .red
                )
            }
        }
    }
    
    private var statusText: String {
        if grant.isExpired {
            return "Expired"
        } else if grant.isExpiringSoon {
            return "Expiring Soon"
        } else {
            return "Active"
        }
    }
    
    private var statusColor: Color {
        if grant.isExpired {
            return .red
        } else if grant.isExpiringSoon {
            return .orange
        } else {
            return .green
        }
    }
    
    private var remainingTimeText: String {
        let minutes = Int(grant.remainingTime / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
}

// MARK: - Permission Details Section

private struct PermissionDetailsSection: View {
    let grant: PrivarionCore.TemporaryPermissionManager.TemporaryPermissionGrant
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)
            
            VStack(spacing: 8) {
                DetailRow(title: "Bundle Identifier", value: grant.bundleIdentifier)
                DetailRow(title: "Service Name", value: grant.serviceName)
                DetailRow(title: "Granted By", value: grant.grantedBy)
                
                if !grant.reason.isEmpty {
                    DetailRow(title: "Reason", value: grant.reason)
                }
                
                DetailRow(title: "Auto Revoke", value: grant.autoRevoke ? "Enabled" : "Disabled")
                DetailRow(title: "Grant ID", value: grant.id)
            }
        }
    }
}

// MARK: - Helper Views

private struct InfoCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(.quaternary.opacity(0.5))
        .cornerRadius(8)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

private struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Select a Permission")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Choose a temporary permission from the list to view its details")
                .font(.subheadline)
                .foregroundColor(Color(.tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 300)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading permissions...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PermissionsEmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Active Permissions")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("There are no temporary permissions currently active. Grant a new permission to get started.")
                .font(.subheadline)
                .foregroundColor(Color(.tertiaryLabelColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 300)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Grant Permission Sheet

/// Sheet for granting new temporary permissions
private struct GrantPermissionSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var bundleIdentifier = ""
    @State private var serviceName = ""
    @State private var duration: TimeInterval = 3600 // 1 hour default
    @State private var reason = ""
    @State private var selectedDuration = DurationOption.oneHour
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var bundleIdentifierError: String?
    @State private var serviceNameError: String?
    @State private var durationError: String?
    
    private enum DurationOption: String, CaseIterable {
        case fifteenMinutes = "15 minutes"
        case thirtyMinutes = "30 minutes"
        case oneHour = "1 hour"
        case twoHours = "2 hours"
        case fourHours = "4 hours"
        case eightHours = "8 hours"
        case twentyFourHours = "24 hours"
        case custom = "Custom"
        
        var timeInterval: TimeInterval {
            switch self {
            case .fifteenMinutes: return 15 * 60
            case .thirtyMinutes: return 30 * 60
            case .oneHour: return 60 * 60
            case .twoHours: return 2 * 60 * 60
            case .fourHours: return 4 * 60 * 60
            case .eightHours: return 8 * 60 * 60
            case .twentyFourHours: return 24 * 60 * 60
            case .custom: return 0
            }
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Text("Grant Permission")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                
                Button("Grant") {
                    Task {
                        await grantPermission()
                    }
                }
                .disabled(!isFormValid || appState.temporaryPermissionState.isLoading)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Form {
                Section(header: Text("Permission Details")) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Bundle Identifier", text: $bundleIdentifier)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: bundleIdentifier) { newValue in
                                validateBundleIdentifier(newValue)
                            }
                        
                        if let error = bundleIdentifierError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("e.g., com.apple.Safari")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Service Name", text: $serviceName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: serviceName) { newValue in
                                validateServiceName(newValue)
                            }
                        
                        if let error = serviceNameError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        } else {
                            Text("e.g., kTCCServiceCamera, kTCCServiceMicrophone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Duration")) {
                    Picker("Duration", selection: $selectedDuration) {
                        ForEach(DurationOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if selectedDuration == DurationOption.custom {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Hours:")
                                Spacer()
                                TextField("Hours", value: Binding(
                                    get: { duration / 3600 },
                                    set: { newValue in
                                        duration = max(0.25, min(168, newValue)) * 3600 // 15 min to 7 days
                                        validateDuration()
                                    }
                                ), formatter: NumberFormatter())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            }
                            
                            if let error = durationError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else {
                                Text("Between 15 minutes and 7 days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Additional Information")) {
                    TextField("Reason (optional)", text: $reason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onChange(of: selectedDuration) { newValue in
            if newValue != DurationOption.custom {
                duration = newValue.timeInterval
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Validation Functions
    
    private func validateBundleIdentifier(_ value: String) {
        bundleIdentifierError = nil
        
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            bundleIdentifierError = "Bundle identifier is required"
            return
        }
        
        // Basic bundle identifier format validation
        let bundleRegex = #"^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z][a-zA-Z0-9]*)+$"#
        let predicate = NSPredicate(format: "SELF MATCHES %@", bundleRegex)
        
        if !predicate.evaluate(with: trimmed) {
            bundleIdentifierError = "Invalid format. Use reverse DNS format (e.g., com.company.app)"
        }
    }
    
    private func validateServiceName(_ value: String) {
        serviceNameError = nil
        
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            serviceNameError = "Service name is required"
            return
        }
        
        // Common TCC service names validation
        let validServices = [
            "kTCCServiceCamera", "kTCCServiceMicrophone", "kTCCServicePhotos",
            "kTCCServiceContacts", "kTCCServiceCalendars", "kTCCServiceReminders",
            "kTCCServiceAddressBook", "kTCCServiceAccessibility", "kTCCServicePostEvent",
            "kTCCServiceSystemPolicyAllFiles", "kTCCServiceSystemPolicyDesktopFolder",
            "kTCCServiceSystemPolicyDocumentsFolder", "kTCCServiceSystemPolicyDownloadsFolder",
            "kTCCServiceSystemPolicyNetworkVolumes", "kTCCServiceSystemPolicyRemovableVolumes",
            "kTCCServiceScreenCapture", "kTCCServiceListenEvent", "kTCCServiceDeveloperTool"
        ]
        
        if !validServices.contains(trimmed) && !trimmed.hasPrefix("kTCCService") {
            serviceNameError = "Should be a valid TCC service name (e.g., kTCCServiceCamera)"
        }
    }
    
    private func validateDuration() {
        durationError = nil
        
        let hours = duration / 3600
        
        if hours < 0.25 {
            durationError = "Minimum duration is 15 minutes"
        } else if hours > 168 {
            durationError = "Maximum duration is 7 days"
        }
    }
    
    private var isFormValid: Bool {
        let trimmedBundle = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedService = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return !trimmedBundle.isEmpty &&
               !trimmedService.isEmpty &&
               duration > 0 &&
               bundleIdentifierError == nil &&
               serviceNameError == nil &&
               durationError == nil
    }
    
    private func grantPermission() async {
        // Clear any previous errors
        errorMessage = ""
        showingError = false
        
        // Validate all fields
        validateBundleIdentifier(bundleIdentifier)
        validateServiceName(serviceName)
        validateDuration()
        
        // Check if validation passed
        if !isFormValid {
            return
        }
        
        let request = PrivarionCore.TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
            serviceName: serviceName.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: duration,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines),
            requestedBy: "gui"
        )
        
        let success = await appState.temporaryPermissionState.grantPermission(request)
        
        if success {
            dismiss()
        } else {
            // Show error if grant failed
            errorMessage = appState.temporaryPermissionState.error ?? "Failed to grant permission"
            showingError = true
        }
    }
}

// MARK: - Preview

#Preview {
    TemporaryPermissionsView()
        .environmentObject(AppState())
        .frame(width: 1200, height: 800)
}
