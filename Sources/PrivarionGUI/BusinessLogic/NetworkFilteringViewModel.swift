import Foundation
import Combine
import PrivarionCore
import Logging

/// ViewModel for Network Filtering view
/// Manages state and interactions with NetworkFilteringManager
@MainActor
class NetworkFilteringViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isActive: Bool = false
    @Published var isLoading: Bool = false
    @Published var statistics: FilteringStatistics?
    @Published var blockedDomains: [String] = []
    @Published var applicationRules: [String: ApplicationNetworkRule] = [:]
    @Published var recentActivity: [TrafficEvent] = []
    
    // MARK: - UI State
    
    @Published var showingError: Bool = false
    @Published var errorMessage: String?
    @Published var showingSettings: Bool = false
    @Published var showingAddDomain: Bool = false
    @Published var showingAddAppRule: Bool = false
    
    // MARK: - Private Properties
    
    private let networkManager = NetworkFilteringManager.shared
    private let logger = Logger(label: "privarion.gui.network.filtering")
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
        Task {
            await refreshData()
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() async {
        logger.info("Starting network filtering monitoring")
        
        // Start periodic updates
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshStatistics()
            }
        }
        
        await refreshData()
    }
    
    nonisolated func stopMonitoring() {
        logger.info("Stopping network filtering monitoring")
        Task { @MainActor in
            monitoringTimer?.invalidate()
            monitoringTimer = nil
        }
    }
    
    func startFiltering() async {
        logger.info("Starting network filtering")
        isLoading = true
        
        do {
            try networkManager.startFiltering()
            await refreshData()
        } catch {
            await handleError(error)
        }
        
        isLoading = false
    }
    
    func stopFiltering() async {
        logger.info("Stopping network filtering")
        isLoading = true
        
        networkManager.stopFiltering()
        await refreshData()
        
        isLoading = false
    }
    
    func refreshStatistics() async {
        statistics = networkManager.getFilteringStatistics()
    }
    
    func refreshData() async {
        logger.debug("Refreshing network filtering data")
        
        statistics = networkManager.getFilteringStatistics()
        isActive = statistics?.isActive ?? false
        blockedDomains = networkManager.getBlockedDomains()
        applicationRules = networkManager.getAllApplicationRules()
        
        logger.debug("Data refreshed - Active: \(isActive), Domains: \(blockedDomains.count), Rules: \(applicationRules.count)")
    }
    
    func addDomain(_ domain: String) async {
        logger.info("Adding domain to blocklist: \(domain)")
        
        do {
            try networkManager.addBlockedDomain(domain)
            await refreshData()
        } catch {
            await handleError(error)
        }
    }
    
    func removeDomain(_ domain: String) async {
        logger.info("Removing domain from blocklist: \(domain)")
        
        do {
            try networkManager.removeBlockedDomain(domain)
            await refreshData()
        } catch {
            await handleError(error)
        }
    }
    
    func addApplicationRule(_ rule: PrivarionCore.ApplicationNetworkRule) async {
        logger.info("Adding application rule for: \(rule.applicationId)")
        
        do {
            try networkManager.setApplicationRule(rule)
            await refreshData()
        } catch {
            await handleError(error)
        }
    }
    
    func removeApplicationRule(_ applicationId: String) async {
        logger.info("Removing application rule for: \(applicationId)")
        
        do {
            try networkManager.removeApplicationRule(for: applicationId)
            await refreshData()
        } catch {
            await handleError(error)
        }
    }
    
    func clearRecentActivity() {
        logger.info("Clearing recent activity")
        recentActivity.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Set up any additional bindings if needed
    }
    
    private func handleError(_ error: Error) async {
        logger.error("Network filtering error: \(error.localizedDescription)")
        errorMessage = error.localizedDescription
        showingError = true
    }
}

// MARK: - Supporting Types

/// Traffic event for real-time monitoring display
struct TrafficEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let domain: String
    let action: TrafficAction
    let source: String?
    
    enum TrafficAction {
        case allowed
        case blocked
    }
}
