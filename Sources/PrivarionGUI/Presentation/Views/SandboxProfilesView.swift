import SwiftUI
import PrivarionCore

struct SandboxProfilesView: View {
    
    @StateObject private var viewModel = SandboxProfileViewModel()
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            SandboxProfileHeader(profiles: viewModel.profiles, isLoading: viewModel.isLoading)
                .padding()
            
            Divider()
            
            HSplitView {
                ProfileListSection(viewModel: viewModel)
                    .frame(minWidth: 250, idealWidth: 300)
                
                ProfileDetailSection(viewModel: viewModel)
                    .frame(minWidth: 400)
            }
        }
        .navigationTitle("Sandbox Profiles")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.loadProfiles()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                
                Button {
                    viewModel.createNewProfile()
                } label: {
                    Image(systemName: "plus")
                }
                
                Button {
                    Task {
                        await viewModel.applyReadOnlyProfile()
                    }
                } label: {
                    Image(systemName: "lock.shield")
                }
                .help("Apply Read-Only Profile")
            }
        }
        .sheet(isPresented: $viewModel.showingCreateProfile) {
            ProfileEditorSheet(viewModel: viewModel, isNew: true)
        }
        .sheet(isPresented: $viewModel.showingEditProfile) {
            ProfileEditorSheet(viewModel: viewModel, isNew: false)
        }
        .alert("Delete Profile", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.profileToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let profile = viewModel.profileToDelete {
                    Task {
                        await viewModel.deleteProfile(profile)
                    }
                }
            }
        } message: {
            if let profile = viewModel.profileToDelete {
                Text("Are you sure you want to delete '\(profile.name)'? This action cannot be undone.")
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

struct SandboxProfileHeader: View {
    let profiles: [SandboxManager.SandboxProfile]
    let isLoading: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    Text("Sandbox Profiles")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("\(profiles.count) profiles")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
                
                Text("Manage application sandbox configurations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
}

struct ProfileListSection: View {
    @ObservedObject var viewModel: SandboxProfileViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Profiles")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            if viewModel.profiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No profiles")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Create a new profile to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.profiles, id: \.name, selection: Binding(
                    get: { viewModel.selectedProfile?.name },
                    set: { name in
                        if let name = name,
                           let profile = viewModel.profiles.first(where: { $0.name == name }) {
                            viewModel.selectProfile(profile)
                        }
                    }
                )) { profile in
                    ProfileRow(profile: profile)
                        .tag(profile.name)
                }
                .listStyle(.sidebar)
            }
        }
    }
}

struct ProfileRow: View {
    let profile: SandboxManager.SandboxProfile
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: profile.strictMode ? "lock.shield.fill" : "shield.fill")
                        .foregroundColor(profile.strictMode ? .red : .blue)
                        .font(.caption)
                    
                    Text(profile.name)
                        .font(.system(.body, design: .default))
                        .fontWeight(.medium)
                }
                
                Text(profile.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ProfileDetailSection: View {
    @ObservedObject var viewModel: SandboxProfileViewModel
    
    var body: some View {
        if let profile = viewModel.selectedProfile {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ProfileInfoCard(profile: profile)
                    PathsCard(profile: profile)
                    NetworkCard(profile: profile)
                    ResourcesCard(profile: profile)
                    
                    HStack {
                        Spacer()
                        Button("Edit Profile") {
                            viewModel.selectProfile(profile)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Delete", role: .destructive) {
                            viewModel.confirmDelete(profile)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top)
                }
                .padding()
            }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("Select a profile")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("Choose a profile from the list to view its details")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ProfileInfoCard: View {
    let profile: SandboxManager.SandboxProfile
    
    var body: some View {
        GroupBox("Profile Information") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Name")
                        .foregroundColor(.secondary)
                    Text(profile.name)
                        .fontWeight(.medium)
                }
                GridRow {
                    Text("Description")
                        .foregroundColor(.secondary)
                    Text(profile.description)
                }
                GridRow {
                    Text("Strict Mode")
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: profile.strictMode ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(profile.strictMode ? .red : .gray)
                        Text(profile.strictMode ? "Enabled" : "Disabled")
                    }
                }
            }
            .padding(8)
        }
    }
}

struct PathsCard: View {
    let profile: SandboxManager.SandboxProfile
    
    var body: some View {
        GroupBox("File System Paths") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allowed Paths")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if profile.allowedPaths.isEmpty {
                        Text("None")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(profile.allowedPaths, id: \.self) { path in
                            HStack {
                                Image(systemName: "checkmark.circle")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text(path)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blocked Paths")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if profile.blockedPaths.isEmpty {
                        Text("None")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(profile.blockedPaths, id: \.self) { path in
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                Text(path)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
            }
            .padding(8)
        }
    }
}

struct NetworkCard: View {
    let profile: SandboxManager.SandboxProfile
    
    var body: some View {
        GroupBox("Network Access") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Access Level")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(networkAccessText)
                        .fontWeight(.medium)
                }
                
                if case .restricted(let domains) = profile.networkAccess, !domains.isEmpty {
                    Divider()
                    Text("Allowed Domains")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    ForEach(domains, id: \.self) { domain in
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .font(.caption)
                            Text(domain)
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                }
            }
            .padding(8)
        }
    }
    
    private var networkAccessText: String {
        switch profile.networkAccess {
        case .blocked:
            return "Blocked"
        case .restricted:
            return "Restricted"
        case .unlimited:
            return "Unlimited"
        }
    }
}

struct ResourcesCard: View {
    let profile: SandboxManager.SandboxProfile
    
    var body: some View {
        GroupBox("Resource Limits") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Max Processes")
                        .foregroundColor(.secondary)
                    Text("\(profile.processGroupLimits.maxProcesses)")
                }
                GridRow {
                    Text("Max Memory")
                        .foregroundColor(.secondary)
                    Text("\(profile.processGroupLimits.maxMemoryMB) MB")
                }
                GridRow {
                    Text("Max CPU")
                        .foregroundColor(.secondary)
                    Text("\(Int(profile.processGroupLimits.maxCPUPercent))%")
                }
                GridRow {
                    Text("Max File Descriptors")
                        .foregroundColor(.secondary)
                    Text("\(profile.resourceLimits.maxFileDescriptors)")
                }
                GridRow {
                    Text("Max Open Files")
                        .foregroundColor(.secondary)
                    Text("\(profile.resourceLimits.maxOpenFiles)")
                }
                GridRow {
                    Text("Disk Quota")
                        .foregroundColor(.secondary)
                    Text("\(profile.resourceLimits.diskQuotaMB) MB")
                }
                GridRow {
                    Text("Timeout")
                        .foregroundColor(.secondary)
                    Text("\(profile.resourceLimits.executionTimeoutSeconds) seconds")
                }
            }
            .padding(8)
        }
    }
}

struct ProfileEditorSheet: View {
    @ObservedObject var viewModel: SandboxProfileViewModel
    let isNew: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Profile Name", text: $viewModel.editingName)
                    TextField("Description", text: $viewModel.editingDescription)
                    Toggle("Strict Mode", isOn: $viewModel.editingStrictMode)
                }
                
                Section("Allowed Paths (one per line)") {
                    TextEditor(text: $viewModel.editingAllowedPaths)
                        .frame(height: 80)
                        .font(.system(.caption, design: .monospaced))
                }
                
                Section("Blocked Paths (one per line)") {
                    TextEditor(text: $viewModel.editingBlockedPaths)
                        .frame(height: 80)
                        .font(.system(.caption, design: .monospaced))
                }
                
                Section("Network Access") {
                    Picker("Access Level", selection: $viewModel.editingNetworkAccess) {
                        ForEach(SandboxProfileViewModel.NetworkAccessType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    if viewModel.editingNetworkAccess == .restricted {
                        TextField("Allowed Domains (one per line)", text: $viewModel.editingAllowedDomains)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                Section("Process Limits") {
                    Stepper("Max Processes: \(viewModel.editingMaxProcesses)", value: $viewModel.editingMaxProcesses, in: 1...100)
                    Stepper("Max Memory (MB): \(viewModel.editingMaxMemoryMB)", value: $viewModel.editingMaxMemoryMB, in: 64...4096, step: 64)
                    Stepper("Max CPU (%): \(Int(viewModel.editingMaxCPUPercent))", value: $viewModel.editingMaxCPUPercent, in: 5...100, step: 5)
                }
                
                Section("Resource Limits") {
                    Stepper("Max File Descriptors: \(viewModel.editingMaxFileDescriptors)", value: $viewModel.editingMaxFileDescriptors, in: 16...1024, step: 16)
                    Stepper("Max Open Files: \(viewModel.editingMaxOpenFiles)", value: $viewModel.editingMaxOpenFiles, in: 8...512, step: 8)
                    Stepper("Disk Quota (MB): \(viewModel.editingDiskQuotaMB)", value: $viewModel.editingDiskQuotaMB, in: 128...10240, step: 128)
                    Stepper("Timeout (seconds): \(viewModel.editingTimeoutSeconds)", value: $viewModel.editingTimeoutSeconds, in: 60...3600, step: 60)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(isNew ? "New Profile" : "Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if isNew {
                                await viewModel.saveProfile()
                            } else {
                                await viewModel.updateProfile()
                            }
                        }
                    }
                    .disabled(viewModel.editingName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    SandboxProfilesView()
        .environmentObject(AppState())
}
