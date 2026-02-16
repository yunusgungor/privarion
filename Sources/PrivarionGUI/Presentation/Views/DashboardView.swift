import SwiftUI
import Logging

/// Dashboard view showing system overview and real-time status
/// Implements professional macOS UI patterns from Context7 research
struct DashboardView: View {
    
    @EnvironmentObject private var appState: AppState
    private let logger = Logger(label: "DashboardView")
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // System Overview Section
                SystemOverviewCard()
                
                // Modules Status Section
                ModulesStatusCard()
                
                // Active Profile Section
                ActiveProfileCard()
                
                // Recent Activity Section
                RecentActivityCard()
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .navigationSubtitle("System Overview")
        .refreshable {
            await appState.initialize()
        }
    }
}

/// System overview card showing key metrics
struct SystemOverviewCard: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: "System Status",
                    systemImage: "desktopcomputer",
                    isLoading: appState.isLoading["systemStatus"] == true
                )
                
                HStack(spacing: 24) {
                    StatusMetric(
                        title: "Status",
                        value: appState.systemStatus.rawValue,
                        color: appState.systemStatus.color
                    )
                    
                    StatusMetric(
                        title: "Active Modules",
                        value: "\(appState.modules.filter { $0.isEnabled }.count)",
                        color: .blue
                    )
                    
                    StatusMetric(
                        title: "Profiles",
                        value: "\(appState.profiles.count)",
                        color: .purple
                    )
                    
                    Spacer()
                }
            }
        }
    }
}

/// Modules status card showing module overview
struct ModulesStatusCard: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: "Privacy Modules",
                    systemImage: "shield.lefthalf.filled",
                    isLoading: appState.isLoading["modules"] == true
                ) {
                    Button("Manage") {
                        appState.navigateTo(.modules)
                    }
                    .controlSize(.small)
                }
                
                if appState.modules.isEmpty {
                    EmptyStateView(
                        systemImage: "shield.slash",
                        title: "No Modules Available",
                        subtitle: "Check system configuration"
                    )
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(appState.modules.prefix(6)) { module in
                            ModuleStatusCard(module: module)
                        }
                    }
                }
            }
        }
    }
}

/// Individual module status card
struct ModuleStatusCard: View {
    
    let module: PrivacyModule
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(module.status.color)
                    .frame(width: 8, height: 8)
                
                Text(module.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                // Toggle button
                Button {
                    Task {
                        await appState.toggleModule(module.id)
                    }
                } label: {
                    Image(systemName: module.isEnabled ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(module.isEnabled ? .green : .gray)
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(appState.isLoading["modules"] == true)
            }
            
            Text(module.status.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(appState.isLoading["modules"] == true ? 0.6 : 1.0)
    }
}

/// Active profile card
struct ActiveProfileCard: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: "Active Profile",
                    systemImage: "person.circle",
                    isLoading: appState.isLoading["profiles"] == true
                ) {
                    Button("Manage") {
                        appState.navigateTo(.profiles)
                    }
                    .controlSize(.small)
                }
                
                if let activeProfile = appState.activeProfile {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(activeProfile.name)
                                .font(.headline)
                            
                            Text(activeProfile.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(appState.profiles.filter { $0.id != appState.activeProfile?.id }) { profile in
                                Button(profile.name) {
                                    Task {
                                        await appState.switchProfile(profile.id)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Active")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .clipShape(Capsule())
                        }
                        .disabled(appState.isLoading["profiles"] == true)
                    }
                } else {
                    EmptyStateView(
                        systemImage: "person.circle.fill.badge.xmark",
                        title: "No Active Profile",
                        subtitle: "Select a profile to activate"
                    )
                }
            }
        }
    }
}

/// Recent activity card
struct RecentActivityCard: View {
    
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: "Recent Activity",
                    systemImage: "clock.arrow.circlepath",
                    isLoading: appState.isLoading["activity"] == true
                ) {
                    Button("View All") {
                        appState.navigateTo(.logs)
                    }
                    .controlSize(.small)
                }
                
                if appState.recentActivity.isEmpty {
                    EmptyStateView(
                        systemImage: "clock.badge.xmark",
                        title: "No Recent Activity",
                        subtitle: "System activity will appear here"
                    )
                } else {
                    VStack(spacing: 8) {
                        ForEach(appState.recentActivity.prefix(5)) { activity in
                            ActivityRowView(activity: activity)
                        }
                    }
                }
            }
        }
    }
}

/// Individual activity row
struct ActivityRowView: View {
    
    let activity: ActivityLogEntry
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(activity.level.color)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.action)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(activity.details)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(formatTime(activity.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

/// Reusable card container
struct Card<Content: View>: View {
    
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack {
            content
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

/// Card header with title and optional action
struct CardHeader<ActionContent: View>: View {
    
    let title: String
    let systemImage: String
    let isLoading: Bool
    let action: ActionContent?
    
    init(
        title: String,
        systemImage: String,
        isLoading: Bool = false,
        @ViewBuilder action: () -> ActionContent = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.action = action()
    }
    
    var body: some View {
        HStack {
            Label {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
            } icon: {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: systemImage)
                        .foregroundColor(.accentColor)
                }
            }
            
            Spacer()
            
            action
        }
    }
}

/// Status metric display
struct StatusMetric: View {
    
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
    }
}

/// Empty state view
struct EmptyStateView: View {
    
    let systemImage: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(AppState())
}
