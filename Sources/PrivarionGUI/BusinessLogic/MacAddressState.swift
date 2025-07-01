//
//  MacAddressState.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-07-01.
//  Copyright © 2025 Privarion. All rights reserved.
//

import SwiftUI
import Combine
import PrivarionCore
import Foundation

/// State management for MAC Address spoofing functionality
/// Following Clean Architecture pattern with ObservableObject
/// Based on Context7 SwiftUI patterns and AsyncPhase error handling
@MainActor
final class MacAddressState: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current list of network interfaces
    @Published var interfaces: [NetworkInterface] = []
    
    /// Loading state for different operations
    @Published var isLoading: Bool = false
    @Published var loadingOperation: String? = nil
    
    /// Error state management
    @Published var error: MacSpoofingError? = nil
    @Published var showingError: Bool = false
    
    /// Selected interface for detail view
    @Published var selectedInterface: NetworkInterface? = nil
    
    /// Operation result messages
    @Published var statusMessage: String? = nil
    @Published var showingStatusMessage: Bool = false
    
    // MARK: - Private Properties
    
    private let logger = Logger(label: "MacAddressState")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Dependencies
    
    private let macSpoofingManager: MacAddressSpoofingManager
    
    // MARK: - Initialization
    
    init(
        macSpoofingManager: MacAddressSpoofingManager = MacAddressSpoofingManager()
    ) {
        self.macSpoofingManager = macSpoofingManager
        
        setupSubscriptions()
        logger.info("MacAddressState initialized with Clean Architecture pattern")
    }
    
    // MARK: - Public Methods
    
    /// Load all network interfaces
    func loadInterfaces() async {
        await setLoading(true, operation: "Loading interfaces...")
        
        do {
            let fetchedInterfaces = try await macSpoofingManager.listAvailableInterfaces()
            await MainActor.run {
                self.interfaces = fetchedInterfaces
                self.clearError()
                logger.info("Successfully loaded \(fetchedInterfaces.count) network interfaces")
            }
        } catch {
            await handleError(error as? MacSpoofingError ?? .invalidNetworkInterface("Failed to load interfaces"))
        }
        
        await setLoading(false)
    }
    
    /// Spoof MAC address for a specific interface
    func spoofInterface(_ interface: NetworkInterface, customMAC: String? = nil) async {
        await setLoading(true, operation: "Spoofing \(interface.name)...")
        
        do {
            if let customMAC = customMAC {
                try await macSpoofingManager.spoofMACAddress(interface: interface.name, customMAC: customMAC)
            } else {
                try await macSpoofingManager.spoofMACAddress(interface: interface.name)
            }
            
            await MainActor.run {
                self.showStatusMessage("Successfully spoofed MAC address for \(interface.name)")
                logger.info("Successfully spoofed MAC address for interface: \(interface.name)")
            }
            
            // Refresh interfaces to show updated status
            await loadInterfaces()
            
        } catch {
            await handleError(error as? MacSpoofingError ?? .invalidNetworkInterface("Failed to spoof MAC address"))
        }
        
        await setLoading(false)
    }
    
    /// Restore original MAC address for a specific interface
    func restoreInterface(_ interface: NetworkInterface) async {
        await setLoading(true, operation: "Restoring \(interface.name)...")
        
        do {
            try await macSpoofingManager.restoreOriginalMAC(interface: interface.name)
            
            await MainActor.run {
                self.showStatusMessage("Successfully restored original MAC address for \(interface.name)")
                logger.info("Successfully restored MAC address for interface: \(interface.name)")
            }
            
            // Refresh interfaces to show updated status
            await loadInterfaces()
            
        } catch {
            await handleError(error as? MacSpoofingError ?? .invalidNetworkInterface("Failed to restore MAC address"))
        }
        
        await setLoading(false)
    }
    
    /// Restore all interfaces to original MAC addresses
    func restoreAllInterfaces() async {
        await setLoading(true, operation: "Restoring all interfaces...")
        
        do {
            try await macSpoofingManager.restoreAllInterfaces()
            
            await MainActor.run {
                self.showStatusMessage("Successfully restored all MAC addresses")
                logger.info("Successfully restored all MAC addresses")
            }
            
            // Refresh interfaces to show updated status
            await loadInterfaces()
            
        } catch {
            await handleError(error as? MacSpoofingError ?? .invalidNetworkInterface("Failed to restore all MAC addresses"))
        }
        
        await setLoading(false)
    }
    
    /// Get status for a specific interface
    func getInterfaceStatus(_ interface: NetworkInterface) async -> InterfaceStatus? {
        do {
            let allStatuses = try await macSpoofingManager.getInterfaceStatus()
            return allStatuses.first { $0.name == interface.name }
        } catch {
            logger.warning("Failed to get status for interface \(interface.name): \(error)")
            return nil
        }
    }
    
    /// Select an interface for detail view
    func selectInterface(_ interface: NetworkInterface) {
        selectedInterface = interface
        logger.debug("Selected interface: \(interface.name)")
    }
    
    /// Clear selection
    func clearSelection() {
        selectedInterface = nil
    }
    
    /// Clear current error
    func clearError() {
        error = nil
        showingError = false
    }
    
    /// Clear status message
    func clearStatusMessage() {
        statusMessage = nil
        showingStatusMessage = false
    }
    
    // MARK: - Private Methods
    
    private func setupSubscriptions() {
        // Auto-hide status messages after 3 seconds
        $showingStatusMessage
            .filter { $0 }
            .delay(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.clearStatusMessage()
            }
            .store(in: &cancellables)
        
        // Auto-clear errors when new operations start
        $isLoading
            .filter { $0 }
            .sink { [weak self] _ in
                self?.clearError()
            }
            .store(in: &cancellables)
    }
    
    private func setLoading(_ loading: Bool, operation: String? = nil) async {
        await MainActor.run {
            self.isLoading = loading
            self.loadingOperation = operation
        }
    }
    
    private func handleError(_ error: MacSpoofingError) async {
        await MainActor.run {
            self.error = error
            self.showingError = true
            logger.error("MAC Address operation failed: \(error.localizedDescription)")
        }
    }
    
    private func showStatusMessage(_ message: String) {
        statusMessage = message
        showingStatusMessage = true
    }
}

// MARK: - Helper Extensions

extension MacAddressState {
    
    /// Check if any interface is currently spoofed
    var hasAnySpoofedInterface: Bool {
        // This would need to be implemented by checking interface statuses
        // For now, return false as a placeholder
        return false
    }
    
    /// Get interface by name
    func interface(named name: String) -> NetworkInterface? {
        interfaces.first { $0.name == name }
    }
}

// MARK: - Logging Support

import Logging

extension MacAddressState {
    private static let logger = Logger(label: "MacAddressState")
}
