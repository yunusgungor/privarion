//
//  MacAddressView.swift
//  PrivarionGUI
//
//  Created by AI Assistant on 2025-07-01.
//  Copyright © 2025 Privarion. All rights reserved.
//

import SwiftUI
import PrivarionCore
import Logging

/// MAC Address Spoofing Management View
/// Provides interface for managing network interface MAC addresses
/// Implements Clean Architecture with SwiftUI and async operations
/// Based on Context7 SwiftUI patterns and Atomic state management
struct MacAddressView: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // Left Panel - Interface List
                VStack(spacing: 0) {
                    Text("Network Interfaces")
                        .font(.headline)
                        .padding()
                    
                    InterfaceListView()
                }
                .frame(minWidth: 250, maxWidth: 300)
                .background(Color(.controlBackgroundColor))
                
                Divider()
                
                // Right Panel - Interface Details
                InterfaceDetailView()
                    .frame(maxWidth: .infinity)
            }
            .navigationTitle("MAC Address Spoofing")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") {
                        Task {
                            await appState.macAddressState.loadInterfaces()
                        }
                    }
                    .disabled(appState.macAddressState.isLoading)
                }
            }
            .onAppear {
                Task {
                    await appState.macAddressState.loadInterfaces()
                }
            }
        }
    }
    
    @ViewBuilder
    private func InterfaceListView() -> some View {
        List(appState.macAddressState.interfaces, id: \.name, selection: Binding(
            get: { appState.macAddressState.selectedInterface },
            set: { interface in
                appState.macAddressState.selectedInterface = interface
            }
        )) { interface in
            InterfaceListItem(interface: interface)
        }
        .listStyle(.sidebar)
        .overlay {
            if appState.macAddressState.interfaces.isEmpty && !appState.macAddressState.isLoading {
                EmptyInterfaceListView()
            }
        }
        .overlay {
            if appState.macAddressState.isLoading {
                ProgressView("Loading interfaces...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.controlBackgroundColor).opacity(0.8))
            }
        }
    }
    
    @ViewBuilder
    private func EmptyInterfaceListView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Network Interfaces")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("No network interfaces found that are eligible for MAC address spoofing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func InterfaceDetailView() -> some View {
        if let selectedInterface = appState.macAddressState.selectedInterface {
            InterfaceDetailContent(interface: selectedInterface)
        } else {
            InterfaceDetailEmptyView()
        }
    }
    
    @ViewBuilder
    private func InterfaceDetailEmptyView() -> some View {
        VStack(spacing: 16) {
            Image(systemName: "network")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Select an Interface")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Choose a network interface from the list to view its details and manage MAC address spoofing.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Interface List Item

struct InterfaceListItem: View {
    let interface: NetworkInterface
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconForInterfaceType(interface.type))
                    .foregroundStyle(colorForInterfaceType(interface.type))
                
                Text(interface.name)
                    .font(.headline)
                
                Spacer()
                
                if interface.isActive {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(interface.macAddress)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                Text(interface.type.rawValue.capitalized)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(colorForInterfaceType(interface.type).opacity(0.2))
                    .cornerRadius(4)
                
                if interface.isEligibleForSpoofing {
                    Text("Spoofable")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Interface Detail Content

struct InterfaceDetailContent: View {
    let interface: NetworkInterface
    @EnvironmentObject private var appState: AppState
    @State private var showingCustomMACInput = false
    @State private var customMAC = ""
    @State private var isValidMAC = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Interface Header
                InterfaceHeaderSection(interface: interface)
                
                // Current Status
                StatusSection(interface: interface)
                
                // MAC Address Information
                MacAddressInfoSection(interface: interface)
                
                // Actions
                if interface.isEligibleForSpoofing {
                    ActionsSection(interface: interface)
                }
                
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    private func InterfaceHeaderSection(interface: NetworkInterface) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconForInterfaceType(interface.type))
                    .font(.title)
                    .foregroundStyle(colorForInterfaceType(interface.type))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(interface.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(interface.type.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                MacAddressStatusBadge(isActive: interface.isActive)
            }
        }
    }
    
    @ViewBuilder
    private func StatusSection(interface: NetworkInterface) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interface Status")
                .font(.headline)
            
            VStack(spacing: 8) {
                InfoRow(label: "Status", value: interface.isActive ? "Active" : "Inactive")
                InfoRow(label: "Spoofing Eligible", value: interface.isEligibleForSpoofing ? "Yes" : "No")
                
                if let ipAddresses = interface.ipAddresses, !ipAddresses.isEmpty {
                    InfoRow(label: "IP Addresses", value: ipAddresses.joined(separator: ", "))
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func MacAddressInfoSection(interface: NetworkInterface) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MAC Address Information")
                .font(.headline)
            
            VStack(spacing: 8) {
                InfoRow(label: "Current MAC", value: interface.macAddress, isMonospaced: true)
                
                // TODO: Add spoofing status when available in MacAddressState
                // This feature will be implemented in a future version
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    @ViewBuilder
    private func ActionsSection(interface: NetworkInterface) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Quick Actions
                HStack(spacing: 12) {
                    Button("Generate Random MAC") {
                        Task {
                            await spoofRandomMAC(for: interface)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.macAddressState.isLoading)
                    
                    Button("Restore Original") {
                        Task {
                            await restoreOriginalMAC(for: interface)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(appState.macAddressState.isLoading)
                }
                
                // Custom MAC Input
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Custom MAC Address:")
                            .font(.subheadline)
                        Spacer()
                        Button(showingCustomMACInput ? "Cancel" : "Set Custom") {
                            showingCustomMACInput.toggle()
                            if !showingCustomMACInput {
                                customMAC = ""
                                isValidMAC = false
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                    
                    if showingCustomMACInput {
                        CustomMACInputView(
                            customMAC: $customMAC,
                            isValidMAC: $isValidMAC,
                            interface: interface
                        )
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private func spoofRandomMAC(for interface: NetworkInterface) async {
        await appState.macAddressState.spoofInterface(
            interface,
            customMAC: generateRandomMAC()
        )
    }
    
    private func restoreOriginalMAC(for interface: NetworkInterface) async {
        await appState.macAddressState.restoreInterface(interface)
    }
    
    private func generateRandomMAC() -> String {
        let bytes = (0..<6).map { _ in
            Int.random(in: 0...255)
        }
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}

// MARK: - Custom MAC Input View

struct CustomMACInputView: View {
    @Binding var customMAC: String
    @Binding var isValidMAC: Bool
    let interface: NetworkInterface
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("XX:XX:XX:XX:XX:XX", text: $customMAC)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .onChange(of: customMAC) { newValue in
                    isValidMAC = isValidMACAddress(newValue)
                }
            
            HStack {
                if !customMAC.isEmpty {
                    Image(systemName: isValidMAC ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isValidMAC ? .green : .red)
                    
                    Text(isValidMAC ? "Valid MAC address" : "Invalid MAC address format")
                        .font(.caption)
                        .foregroundStyle(isValidMAC ? .green : .red)
                }
                
                Spacer()
                
                Button("Apply") {
                    Task {
                        await appState.macAddressState.spoofInterface(
                            interface,
                            customMAC: customMAC.uppercased()
                        )
                        customMAC = ""
                        isValidMAC = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValidMAC || appState.macAddressState.isLoading)
            }
        }
    }
    
    private func isValidMACAddress(_ mac: String) -> Bool {
        let pattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: mac.utf16.count)
        return regex?.firstMatch(in: mac, options: [], range: range) != nil
    }
}

// MARK: - Helper Views

struct MacAddressStatusBadge: View {
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? .green : .red)
                .frame(width: 8, height: 8)
            
            Text(isActive ? "Active" : "Inactive")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((isActive ? Color.green : Color.red).opacity(0.1))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let isMonospaced: Bool
    
    init(label: String, value: String, isMonospaced: Bool = false) {
        self.label = label
        self.value = value
        self.isMonospaced = isMonospaced
    }
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(isMonospaced ? .caption : .body, design: isMonospaced ? .monospaced : .default))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Helper Functions

private func iconForInterfaceType(_ type: NetworkInterfaceType) -> String {
    switch type {
    case .wifi:
        return "wifi"
    case .ethernet:
        return "cable.connector"
    case .loopback:
        return "arrow.triangle.2.circlepath"
    case .vpn:
        return "lock.shield"
    case .bridge:
        return "network"
    case .other:
        return "questionmark.circle"
    }
}

private func colorForInterfaceType(_ type: NetworkInterfaceType) -> Color {
    switch type {
    case .wifi:
        return .blue
    case .ethernet:
        return .green
    case .loopback:
        return .gray
    case .vpn:
        return .purple
    case .bridge:
        return .orange
    case .other:
        return .gray
    }
}
