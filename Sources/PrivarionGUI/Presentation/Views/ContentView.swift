import SwiftUI
import Logging

/// Main content view of the application
/// Implements native macOS design patterns following Context7 research
/// Enhanced with comprehensive error handling system
struct ContentView: View {
    
    @EnvironmentObject private var appState: AppState
    private let logger = Logger(label: "ContentView")
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            NavigationBarView()
                .padding(.horizontal, 12)
                .padding(.top, 8)
            
            // Main Content
            NavigationSplitView {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
            } detail: {
                DetailView()
            }
            .navigationTitle("Privarion")
        }
        .sheet(isPresented: $appState.commandManager.isShowingPalette) {
            CommandPaletteView()
                .environmentObject(appState)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    // Toggle sidebar - handled by system
                } label: {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                }
            }
            
            ToolbarItemGroup(placement: .primaryAction) {
                // Refresh button
                Button {
                    Task {
                        await appState.refreshAll()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(appState.isLoading.values.contains(true))
                .help("Refresh all data")
                
                // Command Palette button
                Button {
                    appState.showCommandPalette()
                } label: {
                    Image(systemName: "command")
                }
                .help("Show Command Palette (⌘⇧P)")
                
                // System status with menu
                Menu {
                    Button("System Details") {
                        // TODO: Show system details
                    }
                    
                    Divider()
                    
                    Button("Start System") {
                        // TODO: Start system
                    }
                    .disabled(appState.systemStatus == .running)
                    
                    Button("Stop System") {
                        // TODO: Stop system
                    }
                    .disabled(appState.systemStatus == .stopped)
                } label: {
                    SystemStatusIndicator()
                }
            }
        }
        .withErrorHandling(errorManager: appState.errorManager)
        .onAppear {
            logger.info("ContentView appeared with error handling")
        }
    }
}

/// Sidebar navigation view
struct SidebarView: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        List(selection: Binding(
            get: { appState.currentView },
            set: { if let view = $0 { appState.navigateTo(view) } }
        )) {
            Section("Overview") {
                NavigationLink(value: AppView.dashboard) {
                    Label("Dashboard", systemImage: "speedometer")
                }
            }
            
            Section("Privacy") {
                NavigationLink(value: AppView.modules) {
                    HStack {
                        Label("Modules", systemImage: "shield.lefthalf.filled")
                        Spacer()
                        if !appState.modules.isEmpty {
                            Text("\(appState.modules.filter(\.isEnabled).count)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(appState.modules.filter(\.isEnabled).count > 0 ? Color.green : Color.gray)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                NavigationLink(value: AppView.profiles) {
                    HStack {
                        Label("Profiles", systemImage: "person.2.circle")
                        Spacer()
                        if !appState.profiles.isEmpty {
                            Text("\(appState.profiles.count)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                NavigationLink(value: AppView.macAddress) {
                    HStack {
                        Label("MAC Address", systemImage: "network")
                        Spacer()
                        if !appState.macAddressState.interfaces.isEmpty {
                            Text("\(appState.macAddressState.interfaces.count)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                NavigationLink(value: AppView.networkFiltering) {
                    HStack {
                        Label("Network Filtering", systemImage: "shield.lefthalf.filled.slash")
                        Spacer()
                        // Show status indicator
                        Circle()
                            .fill(appState.networkFilteringState.isActive ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                    }
                }
                
                NavigationLink(value: AppView.temporaryPermissions) {
                    HStack {
                        Label("Temporary Permissions", systemImage: "clock.badge.exclamationmark")
                        Spacer()
                        if !appState.temporaryPermissionState.activeGrants.isEmpty {
                            Text("\(appState.temporaryPermissionState.activeGrants.count)")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple)
                                .clipShape(Capsule())
                        }
                    }
                }
                
                NavigationLink(value: AppView.securityPolicy) {
                    HStack {
                        Label("Security Policies", systemImage: "shield.checkered")
                        Spacer()
                    }
                }
                
                NavigationLink(value: AppView.analytics) {
                    HStack {
                        Label("Network Analytics", systemImage: "chart.bar.xaxis")
                        Spacer()
                        // Show live indicator if analytics is active
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .opacity(0.8)
                            .scaleEffect(1.2)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: true)
                    }
                }
            }
            
            Section("System") {
                NavigationLink(value: AppView.logs) {
                    Label("Activity Logs", systemImage: "list.bullet.rectangle")
                }
                
                NavigationLink(value: AppView.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Privarion")
    }
}

/// Detail view showing selected content
struct DetailView: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        switch appState.currentView {
        case .dashboard:
            DashboardView()
                .frame(minWidth: 600, minHeight: 400)
        case .modules:
            ModulesView()
                .frame(minWidth: 600, minHeight: 400)
        case .profiles:
            ProfilesView()
                .frame(minWidth: 600, minHeight: 400)
        case .macAddress:
            MacAddressView()
                .frame(minWidth: 600, minHeight: 400)
        case .networkFiltering:
            NetworkFilteringView()
                .frame(minWidth: 800, minHeight: 600)
        case .temporaryPermissions:
            TemporaryPermissionsView()
                .frame(minWidth: 800, minHeight: 600)
        case .securityPolicy:
            SecurityPolicyView()
                .frame(minWidth: 800, minHeight: 600)
        case .analytics:
            AnalyticsView()
                .frame(minWidth: 800, minHeight: 600)
        case .logs:
            LogsView()
                .frame(minWidth: 600, minHeight: 400)
        case .settings:
            SettingsView()
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}

/// System status indicator in toolbar
struct SystemStatusIndicator: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.systemStatus.color)
                .frame(width: 8, height: 8)
            
            Text(appState.systemStatus.rawValue)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
}
