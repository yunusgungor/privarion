import SwiftUI
import PrivarionCore
import Combine
import Logging

/// Network Filtering management view
/// Provides comprehensive DNS-level blocking, per-application rules, and real-time monitoring
struct NetworkFilteringView: View {
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = NetworkFilteringViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            NetworkFilteringHeader(isActive: viewModel.isActive, stats: viewModel.statistics)
                .padding()
            
            Divider()
            
            // Main content
            HSplitView {
                // Left panel: Controls and Settings
                VStack(spacing: 16) {
                    FilteringControlsSection(viewModel: viewModel)
                    BlocklistManagementSection(viewModel: viewModel)
                    ApplicationRulesSection(viewModel: viewModel)
                }
                .frame(minWidth: 300, idealWidth: 350)
                .padding()
                
                // Right panel: Monitoring and Statistics
                VStack(spacing: 16) {
                    TrafficStatisticsSection(stats: viewModel.statistics)
                    RealtimeMonitoringSection(viewModel: viewModel)
                }
                .frame(minWidth: 450)
                .padding()
            }
        }
        .navigationTitle("Network Filtering")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    Task {
                        await viewModel.refreshStatistics()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                
                Button {
                    viewModel.showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            NetworkFilteringSettingsView(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            await viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }
}

// MARK: - Header Section

struct NetworkFilteringHeader: View {
    let isActive: Bool
    let stats: FilteringStatistics?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundColor(isActive ? .green : .gray)
                        .font(.title2)
                    
                    Text("Network Filtering")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(isActive ? "Active" : "Inactive")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(isActive ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .foregroundColor(isActive ? .green : .gray)
                        .clipShape(Capsule())
                }
                
                if let stats = stats {
                    Text("Uptime: \(formatUptime(stats.uptime)) • \(stats.totalQueries) queries • \(stats.blockedQueries) blocked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let stats = stats {
                HStack(spacing: 20) {
                    StatCard(title: "Block Rate", value: "\(Int((Double(stats.blockedQueries) / max(Double(stats.totalQueries), 1)) * 100))%", color: .red)
                    StatCard(title: "Avg Latency", value: "\(Int(stats.averageLatency * 1000))ms", color: .blue)
                }
            }
        }
    }
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 80)
    }
}

// MARK: - Control Sections

struct FilteringControlsSection: View {
    @ObservedObject var viewModel: NetworkFilteringViewModel
    
    var body: some View {
        GroupBox("Filtering Controls") {
            VStack(spacing: 12) {
                HStack {
                    Button {
                        Task {
                            if viewModel.isActive {
                                await viewModel.stopFiltering()
                            } else {
                                await viewModel.startFiltering()
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: viewModel.isActive ? "stop.fill" : "play.fill")
                            Text(viewModel.isActive ? "Stop Filtering" : "Start Filtering")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isLoading)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Actions")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Button("Block Domain") {
                            viewModel.showingAddDomain = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Add App Rule") {
                            viewModel.showingAddAppRule = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

struct BlocklistManagementSection: View {
    @ObservedObject var viewModel: NetworkFilteringViewModel
    
    var body: some View {
        GroupBox("Blocklist Management") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Blocked Domains")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button {
                        viewModel.showingAddDomain = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.blockedDomains, id: \.self) { domain in
                            HStack {
                                Image(systemName: "shield.slash")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                
                                Text(domain)
                                    .font(.system(.caption, design: .monospaced))
                                
                                Spacer()
                                
                                Button {
                                    Task {
                                        await viewModel.removeDomain(domain)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

struct ApplicationRulesSection: View {
    @ObservedObject var viewModel: NetworkFilteringViewModel
    
    var body: some View {
        GroupBox("Application Rules") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Per-App Rules")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button {
                        viewModel.showingAddAppRule = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(viewModel.applicationRules.keys), id: \.self) { appId in
                            if let rule = viewModel.applicationRules[appId] {
                                ApplicationRuleRow(appId: appId, rule: rule, viewModel: viewModel)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
        }
    }
}

struct ApplicationRuleRow: View {
    let appId: String
    let rule: PrivarionCore.ApplicationNetworkRule
    @ObservedObject var viewModel: NetworkFilteringViewModel
    
    var body: some View {
        HStack {
            Image(systemName: rule.enabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(rule.enabled ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(appId)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(rule.ruleType.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                Task {
                    await viewModel.removeApplicationRule(appId)
                }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct TrafficStatisticsSection: View {
    let stats: FilteringStatistics?
    
    var body: some View {
        GroupBox("Traffic Statistics") {
            if let stats = stats {
                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 12) {
                    GridRow {
                        StatisticItem(label: "Total Queries", value: "\(stats.totalQueries)")
                        StatisticItem(label: "Blocked", value: "\(stats.blockedQueries)")
                    }
                    GridRow {
                        StatisticItem(label: "Allowed", value: "\(stats.allowedQueries)")
                        StatisticItem(label: "Block Rate", value: "\(Int((Double(stats.blockedQueries) / max(Double(stats.totalQueries), 1)) * 100))%")
                    }
                    GridRow {
                        StatisticItem(label: "Avg Latency", value: "\(Int(stats.averageLatency * 1000))ms")
                        StatisticItem(label: "Cache Hit Rate", value: "\(Int(stats.cacheHitRate * 100))%")
                    }
                }
            } else {
                Text("No statistics available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

struct StatisticItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RealtimeMonitoringSection: View {
    @ObservedObject var viewModel: NetworkFilteringViewModel
    
    var body: some View {
        GroupBox("Real-time Monitoring") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Activity")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button {
                        viewModel.clearRecentActivity()
                    } label: {
                        Text("Clear")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(viewModel.recentActivity, id: \.id) { event in
                            RecentActivityRow(event: event)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
    }
}

struct RecentActivityRow: View {
    let event: TrafficEvent
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: event.action == .blocked ? "shield.slash" : "shield")
                .foregroundColor(event.action == .blocked ? .red : .green)
                .font(.caption)
            
            Text(event.domain)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
            
            Spacer()
            
            Text(formatTime(event.timestamp))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Settings Sheet

struct NetworkFilteringSettingsView: View {
    @ObservedObject var viewModel: NetworkFilteringViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("DNS Configuration") {
                    // DNS settings would go here
                    Text("DNS settings coming soon...")
                        .foregroundColor(.secondary)
                }
                
                Section("Performance") {
                    // Performance settings
                    Text("Performance settings coming soon...")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Network Filtering Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NetworkFilteringView()
        .environmentObject(AppState())
}
