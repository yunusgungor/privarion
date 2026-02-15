import SwiftUI
import PrivarionCore
import Logging

/// Security Policy Management View
/// Provides comprehensive interface for managing security policies
/// Integrates with SecurityPolicyEngine for unified security management
struct SecurityPolicyView: View {
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = SecurityPolicyViewModel()
    private let logger = Logger(label: "SecurityPolicyView")
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            SecurityPolicyHeader(viewModel: viewModel)
                .padding()
            
            Divider()
            
            // Main content
            HSplitView {
                // Left panel: Policy List
                PolicyListSection(viewModel: viewModel)
                    .frame(minWidth: 300)
                    .padding()
                
                // Right panel: Policy Details & Editor
                PolicyDetailSection(viewModel: viewModel)
                    .frame(minWidth: 450)
                    .padding()
            }
        }
        .navigationTitle("Security Policies")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.createNewPolicy()
                } label: {
                    Image(systemName: "plus")
                }
                .help("Create New Policy")
                
                Button {
                    Task {
                        await viewModel.refresh()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                
                Menu {
                    Button("Export Policies") {
                        Task {
                            await viewModel.exportPolicies()
                        }
                    }
                    Button("Import Policies") {
                        viewModel.showingImport = true
                    }
                    Divider()
                    Button("Reset to Defaults") {
                        viewModel.showingResetConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingPolicyEditor) {
            PolicyEditorSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingImport) {
            PolicyImportSheet(viewModel: viewModel)
        }
        .alert("Reset Policies", isPresented: $viewModel.showingResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                Task {
                    await viewModel.resetToDefaults()
                }
            }
        } message: {
            Text("This will reset all security policies to their default values. This action cannot be undone.")
        }
        .task {
            await viewModel.loadPolicies()
        }
        .onAppear {
            logger.info("Security policy view appeared")
        }
    }
}

// MARK: - Header

struct SecurityPolicyHeader: View {
    @ObservedObject var viewModel: SecurityPolicyViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Security Policy Management")
                    .font(.headline)
                Text("\(viewModel.policies.count) policies configured")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // Status indicators
                PolicyStatusIndicator(
                    title: "Active",
                    count: viewModel.activePolicyCount,
                    color: .green
                )
                PolicyStatusIndicator(
                    title: "Disabled",
                    count: viewModel.disabledPolicyCount,
                    color: .gray
                )
            }
        }
    }
}

struct PolicyStatusIndicator: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Policy List Section

struct PolicyListSection: View {
    @ObservedObject var viewModel: SecurityPolicyViewModel
    @State private var searchText = ""
    
    var filteredPolicies: [SecurityPolicyViewModel.PolicyItem] {
        if searchText.isEmpty {
            return viewModel.policies
        }
        return viewModel.policies.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search policies...", text: $searchText)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Policy list
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredPolicies.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shield.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Policies Found")
                        .font(.headline)
                    Text(searchText.isEmpty ? "Create your first security policy" : "No matching policies")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding(
                    get: { viewModel.selectedPolicy?.id },
                    set: { id in
                        viewModel.selectedPolicy = viewModel.policies.first { $0.id == id }
                    }
                )) {
                    ForEach(filteredPolicies) { policy in
                        PolicyListRow(policy: policy, isSelected: viewModel.selectedPolicy?.id == policy.id)
                            .tag(policy.id)
                            .onTapGesture {
                                viewModel.selectedPolicy = policy
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
}

struct PolicyListRow: View {
    let policy: SecurityPolicyViewModel.PolicyItem
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(policy.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(policy.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(policy.isEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Policy Detail Section

struct PolicyDetailSection: View {
    @ObservedObject var viewModel: SecurityPolicyViewModel
    
    var body: some View {
        if let policy = viewModel.selectedPolicy {
            PolicyDetailView(policy: policy, viewModel: viewModel)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "shield")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary)
                Text("Select a Policy")
                    .font(.headline)
                Text("Choose a policy from the list to view its details")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct PolicyDetailView: View {
    let policy: SecurityPolicyViewModel.PolicyItem
    @ObservedObject var viewModel: SecurityPolicyViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Policy header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(policy.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(policy.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Toggle
                    Toggle(isOn: Binding(
                        get: { policy.isEnabled },
                        set: { _ in viewModel.togglePolicy(policy) }
                    )) {
                        Text(policy.isEnabled ? "Enabled" : "Disabled")
                    }
                    .toggleStyle(.switch)
                }
                
                Divider()
                
                // Policy rules
                VStack(alignment: .leading, spacing: 12) {
                    Text("Rules")
                        .font(.headline)
                    
                    ForEach(policy.rules, id: \.id) { rule in
                        PolicyRuleRow(rule: rule)
                    }
                }
                
                Divider()
                
                // Actions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Actions")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button("Edit") {
                            viewModel.editPolicy(policy)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Duplicate") {
                            viewModel.duplicatePolicy(policy)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Delete", role: .destructive) {
                            viewModel.deletePolicy(policy)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
                
                Divider()
                
                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Text("Metadata")
                        .font(.headline)
                    
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        GridRow {
                            Text("ID:")
                                .foregroundColor(.secondary)
                            Text(policy.id)
                                .font(.system(.body, design: .monospaced))
                        }
                        GridRow {
                            Text("Priority:")
                                .foregroundColor(.secondary)
                            Text("\(policy.priority)")
                        }
                        GridRow {
                            Text("Created:")
                                .foregroundColor(.secondary)
                            Text(policy.createdAt, style: .date)
                        }
                        GridRow {
                            Text("Modified:")
                                .foregroundColor(.secondary)
                            Text(policy.modifiedAt, style: .date)
                        }
                    }
                    .font(.caption)
                }
            }
            .padding()
        }
    }
}

struct PolicyRuleRow: View {
    let rule: SecurityPolicyViewModel.PolicyRule
    
    var body: some View {
        HStack {
            Image(systemName: rule.isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(rule.isEnabled ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.body)
                Text(rule.condition)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(rule.action)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(actionColor(for: rule.action).opacity(0.2))
                .clipShape(Capsule())
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    func actionColor(for action: String) -> Color {
        switch action.lowercased() {
        case "allow": return .green
        case "deny": return .red
        case "log": return .blue
        case "alert": return .orange
        default: return .gray
        }
    }
}

// MARK: - Policy Editor Sheet

struct PolicyEditorSheet: View {
    @ObservedObject var viewModel: SecurityPolicyViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(viewModel.editingPolicy == nil ? "New Policy" : "Edit Policy")
                    .font(.headline)
                
                Spacer()
                
                Button("Save") {
                    Task {
                        await viewModel.savePolicy()
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.editingPolicy?.name.isEmpty ?? true)
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                Section("Basic Information") {
                    TextField("Policy Name", text: Binding(
                        get: { viewModel.editingPolicy?.name ?? "" },
                        set: { viewModel.editingPolicy?.name = $0 }
                    ))
                    
                    TextField("Description", text: Binding(
                        get: { viewModel.editingPolicy?.description ?? "" },
                        set: { viewModel.editingPolicy?.description = $0 }
                    ))
                }
                
                Section("Rules") {
                    // Rule editor would go here
                    Text("Rule editor")
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Import Sheet

struct PolicyImportSheet: View {
    @ObservedObject var viewModel: SecurityPolicyViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Import Policies")
                .font(.headline)
            
            Button("Select File") {
                // File picker would go here
            }
            .buttonStyle(.borderedProminent)
            
            Button("Cancel") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

// MARK: - ViewModel

@MainActor
class SecurityPolicyViewModel: ObservableObject {
    @Published var policies: [PolicyItem] = []
    @Published var selectedPolicy: PolicyItem?
    @Published var editingPolicy: PolicyItem?
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    @Published var showingPolicyEditor: Bool = false
    @Published var showingImport: Bool = false
    @Published var showingResetConfirmation: Bool = false
    
    var activePolicyCount: Int {
        policies.filter(\.isEnabled).count
    }
    
    var disabledPolicyCount: Int {
        policies.filter { !$0.isEnabled }.count
    }
    
    struct PolicyItem: Identifiable, Hashable {
        var id: String
        var name: String
        var description: String
        var isEnabled: Bool
        var priority: Int
        var rules: [PolicyRule]
        var createdAt: Date
        var modifiedAt: Date
    }
    
    struct PolicyRule: Identifiable, Hashable {
        let id: String
        var name: String
        var condition: String
        var action: String
        var isEnabled: Bool
    }
    
    func loadPolicies() async {
        isLoading = true
        // Load from SecurityPolicyEngine
        // For now, add some sample data
        policies = [
            PolicyItem(
                id: "policy-001",
                name: "Camera Access Control",
                description: "Controls camera access for applications",
                isEnabled: true,
                priority: 10,
                rules: [
                    PolicyRule(id: "rule-001", name: "Deny unknown apps", condition: "client_type == unknown", action: "Deny", isEnabled: true),
                    PolicyRule(id: "rule-002", name: "Allow known apps", condition: "client_type == known", action: "Allow", isEnabled: true)
                ],
                createdAt: Date(),
                modifiedAt: Date()
            ),
            PolicyItem(
                id: "policy-002",
                name: "Network Monitoring",
                description: "Monitors network traffic for suspicious activity",
                isEnabled: true,
                priority: 5,
                rules: [
                    PolicyRule(id: "rule-003", name: "Log all connections", condition: "true", action: "Log", isEnabled: true)
                ],
                createdAt: Date(),
                modifiedAt: Date()
            )
        ]
        isLoading = false
    }
    
    func refresh() async {
        await loadPolicies()
    }
    
    func createNewPolicy() {
        editingPolicy = PolicyItem(
            id: UUID().uuidString,
            name: "",
            description: "",
            isEnabled: true,
            priority: 1,
            rules: [],
            createdAt: Date(),
            modifiedAt: Date()
        )
        showingPolicyEditor = true
    }
    
    func editPolicy(_ policy: PolicyItem) {
        editingPolicy = policy
        showingPolicyEditor = true
    }
    
    func duplicatePolicy(_ policy: PolicyItem) {
        var newPolicy = policy
        newPolicy.id = UUID().uuidString
        newPolicy.name = "\(policy.name) (Copy)"
        newPolicy.createdAt = Date()
        newPolicy.modifiedAt = Date()
        policies.append(newPolicy)
    }
    
    func deletePolicy(_ policy: PolicyItem) {
        policies.removeAll { $0.id == policy.id }
        if selectedPolicy?.id == policy.id {
            selectedPolicy = nil
        }
    }
    
    func togglePolicy(_ policy: PolicyItem) {
        if let index = policies.firstIndex(where: { $0.id == policy.id }) {
            policies[index].isEnabled.toggle()
            policies[index].modifiedAt = Date()
        }
    }
    
    func savePolicy() async {
        guard var policy = editingPolicy else { return }
        policy.modifiedAt = Date()
        
        if let index = policies.firstIndex(where: { $0.id == policy.id }) {
            policies[index] = policy
        } else {
            policies.append(policy)
        }
        
        editingPolicy = nil
    }
    
    func exportPolicies() async {
        // Export to JSON
    }
    
    func resetToDefaults() async {
        policies = []
        await loadPolicies()
    }
}

// MARK: - Preview

#Preview {
    SecurityPolicyView()
        .environmentObject(AppState())
}
