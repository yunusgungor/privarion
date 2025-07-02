import SwiftUI
import Charts
import Combine
import Logging
import PrivarionCore

/// Advanced network analytics view with real-time charts and metrics
/// Implements PATTERN-2025-022: Real-time Monitoring with Efficient Aggregation
/// Uses Swift Charts for professional data visualization
struct AnalyticsView: View {
    
    @EnvironmentObject private var appState: AppState
    @StateObject private var analyticsState = AnalyticsViewState()
    private let logger = Logger(label: "AnalyticsView")
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Analytics Overview Section
                AnalyticsOverviewCard()
                
                // Real-time Charts Section
                NetworkChartsCard()
                
                // Metrics Table Section
                MetricsTableCard()
                
                // Event Stream Section
                EventStreamCard()
            }
            .padding()
        }
        .navigationTitle("Network Analytics")
        .navigationSubtitle(analyticsState.isActive ? "Active - Live Data" : "Inactive")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Analytics control buttons
                Button {
                    Task {
                        await analyticsState.toggleAnalytics()
                    }
                } label: {
                    Image(systemName: analyticsState.isActive ? "stop.circle" : "play.circle")
                }
                .disabled(analyticsState.isLoading)
                .help(analyticsState.isActive ? "Stop Analytics" : "Start Analytics")
                
                Button {
                    Task {
                        await analyticsState.exportAnalytics()
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(!analyticsState.hasData)
                .help("Export Analytics Data")
                
                Button {
                    analyticsState.showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Analytics Settings")
            }
        }
        .sheet(isPresented: $analyticsState.showSettings) {
            AnalyticsSettingsView()
                .environmentObject(analyticsState)
        }
        .refreshable {
            await analyticsState.refreshData()
        }
        .onAppear {
            analyticsState.startUpdates()
            logger.info("Analytics view appeared")
        }
        .onDisappear {
            analyticsState.stopUpdates()
            logger.info("Analytics view disappeared")
        }
    }
}

// MARK: - Analytics Overview Card

struct AnalyticsOverviewCard: View {
    @EnvironmentObject private var analyticsState: AnalyticsViewState
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: "Analytics Overview",
                    systemImage: "chart.bar.xaxis",
                    isLoading: analyticsState.isLoading
                )
                
                HStack(spacing: 24) {
                    AnalyticsMetric(
                        title: "Status",
                        value: analyticsState.isActive ? "Active" : "Inactive",
                        color: analyticsState.isActive ? .green : .gray,
                        systemImage: analyticsState.isActive ? "checkmark.circle" : "pause.circle"
                    )
                    
                    AnalyticsMetric(
                        title: "Events/sec",
                        value: String(format: "%.1f", analyticsState.eventsPerSecond),
                        color: .blue,
                        systemImage: "waveform.path.ecg"
                    )
                    
                    AnalyticsMetric(
                        title: "Total Events",
                        value: "\(analyticsState.totalEvents)",
                        color: .purple,
                        systemImage: "number"
                    )
                    
                    AnalyticsMetric(
                        title: "Session Time",
                        value: analyticsState.sessionTime,
                        color: .orange,
                        systemImage: "clock"
                    )
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Network Charts Card

struct NetworkChartsCard: View {
    @EnvironmentObject private var analyticsState: AnalyticsViewState
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: "Network Activity",
                    systemImage: "chart.line.uptrend.xyaxis",
                    isLoading: analyticsState.isLoading
                ) {
                    Picker("Chart Type", selection: $analyticsState.selectedChart) {
                        ForEach(ChartType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }
                
                // Chart content
                if analyticsState.chartData.isEmpty {
                    EmptyStateView(
                        systemImage: "chart.bar.xaxis",
                        title: "No Data Available",
                        subtitle: "Start analytics to see network activity"
                    )
                    .frame(height: 300)
                } else {
                    chartView
                        .frame(height: 300)
                }
            }
        }
    }
    
    @ViewBuilder
    private var chartView: some View {
        switch analyticsState.selectedChart {
        case .throughput:
            ThroughputChart()
        case .connections:
            ConnectionsChart()
        case .packets:
            PacketsChart()
        case .errors:
            ErrorsChart()
        }
    }
}

// MARK: - Chart Views

struct ThroughputChart: View {
    @EnvironmentObject private var analyticsState: AnalyticsViewState
    
    var body: some View {
        Chart(analyticsState.chartData) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("Throughput", dataPoint.throughput)
            )
            .foregroundStyle(.blue)
            .lineStyle(.init(lineWidth: 2))
            
            AreaMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("Throughput", dataPoint.throughput)
            )
            .foregroundStyle(.blue.opacity(0.3))
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .second, count: 30)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(date, format: .dateTime.hour().minute().second())
                    }
                    AxisGridLine()
                    AxisTick()
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let throughput = value.as(Double.self) {
                        Text("\(Int(throughput)) MB/s")
                    }
                }
                AxisGridLine()
                AxisTick()
            }
        }
        .animation(.easeInOut, value: analyticsState.chartData)
    }
}

struct ConnectionsChart: View {
    @EnvironmentObject private var analyticsState: AnalyticsViewState
    
    var body: some View {
        Chart(analyticsState.chartData) { dataPoint in
            BarMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("Connections", dataPoint.activeConnections)
            )
            .foregroundStyle(.green)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .second, count: 30))
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let connections = value.as(Int.self) {
                        Text("\(connections)")
                    }
                }
            }
        }
        .animation(.easeInOut, value: analyticsState.chartData)
    }
}

struct PacketsChart: View {
    @EnvironmentObject private var analyticsState: AnalyticsViewState
    
    var body: some View {
        Chart(analyticsState.chartData) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("Inbound", dataPoint.packetsIn)
            )
            .foregroundStyle(.blue)
            .lineStyle(.init(lineWidth: 2))
            
            LineMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("Outbound", dataPoint.packetsOut)
            )
            .foregroundStyle(.red)
            .lineStyle(.init(lineWidth: 2))
        }
        .chartForegroundStyleScale([
            "Inbound": .blue,
            "Outbound": .red
        ])
        .chartLegend(position: .top)
        .animation(.easeInOut, value: analyticsState.chartData)
    }
}

struct ErrorsChart: View {
    @EnvironmentObject private var analyticsState: AnalyticsViewState
    
    var body: some View {
        Chart(analyticsState.chartData) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("Errors", dataPoint.errorCount)
            )
            .foregroundStyle(.red)
            .lineStyle(.init(lineWidth: 2))
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let errors = value.as(Int.self) {
                        Text("\(errors)")
                    }
                }
            }
        }
        .animation(.easeInOut, value: analyticsState.chartData)
    }
}

// MARK: - Metrics Table Card

struct MetricsTableCard: View {
    @EnvironmentObject private var analyticsState: AnalyticsViewState
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: "Current Metrics",
                    systemImage: "table",
                    isLoading: analyticsState.isLoading
                )
                
                if let currentMetrics = analyticsState.currentMetrics {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        MetricRow(label: "Throughput", value: "\(String(format: "%.2f", currentMetrics.throughput)) MB/s")
                        MetricRow(label: "Active Connections", value: "\(currentMetrics.activeConnections)")
                        MetricRow(label: "Packets In", value: "\(currentMetrics.packetsIn)")
                        MetricRow(label: "Packets Out", value: "\(currentMetrics.packetsOut)")
                        MetricRow(label: "Errors", value: "\(currentMetrics.errorCount)")
                        MetricRow(label: "Latency", value: "\(String(format: "%.1f", currentMetrics.latency)) ms")
                    }
                } else {
                    EmptyStateView(
                        systemImage: "table.badge.more",
                        title: "No Metrics Available",
                        subtitle: "Start analytics to see current metrics"
                    )
                    .frame(height: 100)
                }
            }
        }
    }
}

// MARK: - Event Stream Card

struct EventStreamCard: View {
    @EnvironmentObject private var analyticsState: AnalyticsViewState
    
    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                CardHeader(
                    title: "Live Event Stream",
                    systemImage: "list.bullet.rectangle",
                    isLoading: analyticsState.isLoading
                ) {
                    Button("Clear") {
                        analyticsState.clearEvents()
                    }
                    .controlSize(.small)
                    .disabled(analyticsState.recentEvents.isEmpty)
                }
                
                if analyticsState.recentEvents.isEmpty {
                    EmptyStateView(
                        systemImage: "list.bullet.rectangle.portrait",
                        title: "No Events",
                        subtitle: "Network events will appear here"
                    )
                    .frame(height: 150)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(analyticsState.recentEvents.prefix(20), id: \.id) { event in
                                EventRow(event: event)
                            }
                        }
                    }
                    .frame(height: 300)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct AnalyticsMetric: View {
    let title: String
    let value: String
    let color: Color
    let systemImage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                    .font(.caption)
                
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
            }
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

struct EventRow: View {
    let event: AnalyticsEventDisplayModel
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(event.severityColor)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(event.type)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(event.timestamp, format: .dateTime.hour().minute().second())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(event.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Analytics Settings View

struct AnalyticsSettingsView: View {
    @EnvironmentObject private var analyticsState: AnalyticsViewState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Collection Settings") {
                    Toggle("Real-time Processing", isOn: $analyticsState.realTimeProcessing)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Update Interval")
                        Slider(
                            value: Binding(
                                get: { Double(analyticsState.updateInterval) },
                                set: { analyticsState.updateInterval = Int($0) }
                            ),
                            in: 1...30,
                            step: 1
                        ) {
                            Text("Update Interval")
                        } minimumValueLabel: {
                            Text("1s")
                        } maximumValueLabel: {
                            Text("30s")
                        }
                        Text("\(analyticsState.updateInterval) seconds")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Data Storage") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Retention Period")
                        Slider(
                            value: Binding(
                                get: { Double(analyticsState.retentionDays) },
                                set: { analyticsState.retentionDays = Int($0) }
                            ),
                            in: 1...30,
                            step: 1
                        ) {
                            Text("Retention Period")
                        } minimumValueLabel: {
                            Text("1d")
                        } maximumValueLabel: {
                            Text("30d")
                        }
                        Text("\(analyticsState.retentionDays) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max Events in Memory")
                        Slider(
                            value: Binding(
                                get: { Double(analyticsState.maxEvents) },
                                set: { analyticsState.maxEvents = Int($0) }
                            ),
                            in: 100...10000,
                            step: 100
                        ) {
                            Text("Max Events")
                        } minimumValueLabel: {
                            Text("100")
                        } maximumValueLabel: {
                            Text("10K")
                        }
                        Text("\(analyticsState.maxEvents) events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Export Options") {
                    Toggle("Auto Export", isOn: $analyticsState.autoExport)
                    
                    if analyticsState.autoExport {
                        Picker("Export Format", selection: $analyticsState.exportFormat) {
                            Text("JSON").tag("json")
                            Text("CSV").tag("csv")
                            Text("XML").tag("xml")
                        }
                    }
                }
            }
            .navigationTitle("Analytics Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await analyticsState.saveSettings()
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum ChartType: CaseIterable {
    case throughput, connections, packets, errors
    
    var displayName: String {
        switch self {
        case .throughput: return "Throughput"
        case .connections: return "Connections"
        case .packets: return "Packets"
        case .errors: return "Errors"
        }
    }
}

struct AnalyticsDataPoint: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let throughput: Double
    let activeConnections: Int
    let packetsIn: Int
    let packetsOut: Int
    let errorCount: Int
    let latency: Double
    
    static func == (lhs: AnalyticsDataPoint, rhs: AnalyticsDataPoint) -> Bool {
        return lhs.timestamp == rhs.timestamp &&
               lhs.throughput == rhs.throughput &&
               lhs.activeConnections == rhs.activeConnections &&
               lhs.packetsIn == rhs.packetsIn &&
               lhs.packetsOut == rhs.packetsOut &&
               lhs.errorCount == rhs.errorCount &&
               lhs.latency == rhs.latency
    }
}

struct AnalyticsEventDisplayModel: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: String
    let description: String
    let severity: EventSeverity
    
    var severityColor: Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
    
    enum EventSeverity {
        case info, warning, error, critical
    }
}

// MARK: - Preview

#Preview {
    AnalyticsView()
        .environmentObject(AppState())
        .environmentObject(AnalyticsViewState())
}
