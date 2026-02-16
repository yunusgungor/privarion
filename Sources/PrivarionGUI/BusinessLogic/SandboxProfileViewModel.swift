import Foundation
import Combine
import PrivarionCore
import Logging

@MainActor
class SandboxProfileViewModel: ObservableObject {
    
    @Published var profiles: [SandboxManager.SandboxProfile] = []
    @Published var selectedProfile: SandboxManager.SandboxProfile?
    @Published var isLoading: Bool = false
    @Published var isActive: Bool = false
    
    @Published var editingName: String = ""
    @Published var editingDescription: String = ""
    @Published var editingStrictMode: Bool = false
    @Published var editingAllowedPaths: String = ""
    @Published var editingBlockedPaths: String = ""
    @Published var editingNetworkAccess: NetworkAccessType = .restricted
    @Published var editingAllowedDomains: String = ""
    @Published var editingMaxProcesses: Int = 10
    @Published var editingMaxMemoryMB: Int = 512
    @Published var editingMaxCPUPercent: Double = 50.0
    @Published var editingMaxFileDescriptors: Int = 256
    @Published var editingMaxOpenFiles: Int = 128
    @Published var editingDiskQuotaMB: Int = 1024
    @Published var editingTimeoutSeconds: Int = 300
    
    @Published var showingError: Bool = false
    @Published var errorMessage: String?
    @Published var showingCreateProfile: Bool = false
    @Published var showingEditProfile: Bool = false
    @Published var showingDeleteConfirmation: Bool = false
    @Published var profileToDelete: SandboxManager.SandboxProfile?
    
    enum NetworkAccessType: String, CaseIterable {
        case blocked = "Blocked"
        case restricted = "Restricted"
        case unlimited = "Unlimited"
    }
    
    private let sandboxManager = SandboxManager.shared
    private let logger = Logger(label: "privarion.gui.sandbox.profile")
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Task {
            await loadProfiles()
        }
    }
    
    func loadProfiles() async {
        isLoading = true
        profiles = sandboxManager.getAvailableProfiles()
        isLoading = false
    }
    
    func selectProfile(_ profile: SandboxManager.SandboxProfile) {
        selectedProfile = profile
        loadProfileIntoEditor(profile)
        showingEditProfile = true
    }
    
    func createNewProfile() {
        editingName = "New Profile"
        editingDescription = ""
        editingStrictMode = false
        editingAllowedPaths = ""
        editingBlockedPaths = ""
        editingNetworkAccess = .restricted
        editingAllowedDomains = ""
        editingMaxProcesses = 10
        editingMaxMemoryMB = 512
        editingMaxCPUPercent = 50.0
        editingMaxFileDescriptors = 256
        editingMaxOpenFiles = 128
        editingDiskQuotaMB = 1024
        editingTimeoutSeconds = 300
        
        showingCreateProfile = true
    }
    
    func saveProfile() async {
        let allowedPathsArray = editingAllowedPaths
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let blockedPathsArray = editingBlockedPaths
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let allowedDomainsArray = editingAllowedDomains
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let networkAccess: SandboxManager.SandboxProfile.NetworkAccessLevel
        switch editingNetworkAccess {
        case .blocked:
            networkAccess = .blocked
        case .restricted:
            networkAccess = .restricted(allowedDomains: allowedDomainsArray)
        case .unlimited:
            networkAccess = .unlimited
        }
        
        let profile = SandboxManager.SandboxProfile(
            name: editingName,
            description: editingDescription,
            strictMode: editingStrictMode,
            allowedPaths: allowedPathsArray,
            blockedPaths: blockedPathsArray,
            networkAccess: networkAccess,
            systemCallFilters: [],
            processGroupLimits: SandboxManager.SandboxProfile.ProcessGroupLimits(
                maxProcesses: editingMaxProcesses,
                maxMemoryMB: editingMaxMemoryMB,
                maxCPUPercent: editingMaxCPUPercent,
                priorityLevel: 10
            ),
            resourceLimits: SandboxManager.SandboxProfile.ResourceLimits(
                maxFileDescriptors: editingMaxFileDescriptors,
                maxOpenFiles: editingMaxOpenFiles,
                diskQuotaMB: editingDiskQuotaMB,
                executionTimeoutSeconds: editingTimeoutSeconds
            )
        )
        
        sandboxManager.addProfile(profile)
        await loadProfiles()
        
        showingCreateProfile = false
        showingEditProfile = false
    }
    
    func updateProfile() async {
        guard let selected = selectedProfile else { return }
        
        do {
            try sandboxManager.removeProfile(selected.name)
        } catch {
            await handleError(error)
            return
        }
        
        await saveProfile()
    }
    
    func deleteProfile(_ profile: SandboxManager.SandboxProfile) async {
        do {
            try sandboxManager.removeProfile(profile.name)
            await loadProfiles()
            
            if selectedProfile?.name == profile.name {
                selectedProfile = nil
            }
        } catch {
            await handleError(error)
        }
        
        showingDeleteConfirmation = false
        profileToDelete = nil
    }
    
    func confirmDelete(_ profile: SandboxManager.SandboxProfile) {
        profileToDelete = profile
        showingDeleteConfirmation = true
    }
    
    func applyReadOnlyProfile() async {
        let readonlyProfile = SandboxManager.SandboxProfile(
            name: "readonly",
            description: "Read-only sandbox - denies all write operations",
            strictMode: true,
            allowedPaths: ["$HOME/Documents", "$HOME/Downloads", "$HOME/Desktop", "/tmp"],
            blockedPaths: ["/System", "/usr/libexec", "/Applications"],
            networkAccess: .restricted(allowedDomains: ["localhost"]),
            systemCallFilters: ["write", "create", "delete"],
            processGroupLimits: SandboxManager.SandboxProfile.ProcessGroupLimits(
                maxProcesses: 1,
                maxMemoryMB: 256,
                maxCPUPercent: 25.0,
                priorityLevel: 5
            ),
            resourceLimits: SandboxManager.SandboxProfile.ResourceLimits(
                maxFileDescriptors: 32,
                maxOpenFiles: 16,
                diskQuotaMB: 512,
                executionTimeoutSeconds: 600
            )
        )
        
        sandboxManager.addProfile(readonlyProfile)
        await loadProfiles()
    }
    
    private func loadProfileIntoEditor(_ profile: SandboxManager.SandboxProfile) {
        editingName = profile.name
        editingDescription = profile.description
        editingStrictMode = profile.strictMode
        editingAllowedPaths = profile.allowedPaths.joined(separator: "\n")
        editingBlockedPaths = profile.blockedPaths.joined(separator: "\n")
        
        switch profile.networkAccess {
        case .blocked:
            editingNetworkAccess = .blocked
            editingAllowedDomains = ""
        case .restricted(let domains):
            editingNetworkAccess = .restricted
            editingAllowedDomains = domains.joined(separator: "\n")
        case .unlimited:
            editingNetworkAccess = .unlimited
            editingAllowedDomains = ""
        }
        
        editingMaxProcesses = profile.processGroupLimits.maxProcesses
        editingMaxMemoryMB = profile.processGroupLimits.maxMemoryMB
        editingMaxCPUPercent = profile.processGroupLimits.maxCPUPercent
        
        editingMaxFileDescriptors = profile.resourceLimits.maxFileDescriptors
        editingMaxOpenFiles = profile.resourceLimits.maxOpenFiles
        editingDiskQuotaMB = profile.resourceLimits.diskQuotaMB
        editingTimeoutSeconds = profile.resourceLimits.executionTimeoutSeconds
    }
    
    private func handleError(_ error: Error) async {
        errorMessage = error.localizedDescription
        showingError = true
    }
}
