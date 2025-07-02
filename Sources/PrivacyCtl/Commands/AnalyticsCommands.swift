import Foundation
import ArgumentParser
import PrivarionCore

/// Network analytics command group
/// Implements PATTERN-2025-001: Swift ArgumentParser CLI Structure
struct AnalyticsCommands: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "analytics",
        abstract: "Network analytics and monitoring commands",
        discussion: """
        Control network analytics collection, real-time monitoring, and data export.
        
        Examples:
          privarion analytics start                # Start analytics collection
          privarion analytics stop                 # Stop analytics collection
          privarion analytics status               # Show analytics status
          privarion analytics metrics              # Show current metrics
          privarion analytics export              # Export analytics data
          privarion analytics config              # Configure analytics settings
        """,
        subcommands: [
            StartCommand.self,
            StopCommand.self,
            StatusCommand.self,
            MetricsCommand.self,
            ExportCommand.self,
            ConfigCommand.self,
            ReportCommand.self
        ]
    )
}

// MARK: - Start/Stop Commands

extension AnalyticsCommands {
    
    struct StartCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start network analytics collection",
            discussion: """
            Starts real-time network analytics collection and processing.
            Analytics must be enabled in configuration first.
            """
        )
        
        @Flag(name: .long, help: "Enable verbose output")
        var verbose: Bool = false
        
        @Flag(name: .long, help: "Force start even if already running")
        var force: Bool = false
        
        func run() throws {
            let analytics = NetworkAnalyticsEngine.shared
            
            if verbose {
                print("Starting network analytics collection...")
            }
            
            do {
                try analytics.startAnalytics()
                
                if verbose {
                    print("✅ Network analytics started successfully")
                    
                    let config = ConfigurationManager.shared.getCurrentConfiguration().modules.networkAnalytics
                    print("  Real-time processing: \(config.realTimeProcessing ? "enabled" : "disabled")")
                    print("  Storage backend: \(config.storageBackend.rawValue)")
                    print("  Data retention: \(config.dataRetentionDays) days")
                } else {
                    print("Network analytics started")
                }
                
            } catch AnalyticsError.analyticsDisabled {
                print("❌ Error: Network analytics is disabled in configuration")
                print("Enable analytics in your configuration file first:")
                print("  modules.networkAnalytics.enabled = true")
                throw ExitCode.failure
                
            } catch {
                print("❌ Error starting analytics: \(error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct StopCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop network analytics collection",
            discussion: """
            Stops network analytics collection and saves current data.
            """
        )
        
        @Flag(name: .long, help: "Enable verbose output")
        var verbose: Bool = false
        
        func run() throws {
            let analytics = NetworkAnalyticsEngine.shared
            
            if verbose {
                print("Stopping network analytics collection...")
            }
            
            analytics.stopAnalytics()
            
            if verbose {
                print("✅ Network analytics stopped successfully")
            } else {
                print("Network analytics stopped")
            }
        }
    }
}

// MARK: - Status and Metrics Commands

extension AnalyticsCommands {
    
    struct StatusCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show analytics collection status",
            discussion: """
            Displays the current status of network analytics collection.
            """
        )
        
        @Flag(name: .long, help: "Output in JSON format")
        var json: Bool = false
        
        func run() throws {
            let analytics = NetworkAnalyticsEngine.shared
            let snapshot = analytics.getCurrentMetrics()
            let config = ConfigurationManager.shared.getCurrentConfiguration().modules.networkAnalytics
            
            if json {
                let statusData = AnalyticsStatusData(
                    enabled: config.enabled,
                    realTimeProcessing: config.realTimeProcessing,
                    storageBackend: config.storageBackend.rawValue,
                    dataRetentionDays: config.dataRetentionDays,
                    sessionId: snapshot.sessionId?.uuidString,
                    lastUpdate: snapshot.timestamp
                )
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(statusData)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
                
            } else {
                print("Network Analytics Status")
                print("========================")
                print("Enabled: \(config.enabled ? "✅ Yes" : "❌ No")")
                print("Real-time processing: \(config.realTimeProcessing ? "✅ Enabled" : "❌ Disabled")")
                print("Storage backend: \(config.storageBackend.rawValue)")
                print("Data retention: \(config.dataRetentionDays) days")
                
                if let sessionId = snapshot.sessionId {
                    print("Current session: \(sessionId)")
                    print("Last update: \(formatDate(snapshot.timestamp))")
                } else {
                    print("Status: Not actively collecting")
                }
            }
        }
        
        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    struct MetricsCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "metrics",
            abstract: "Show current analytics metrics",
            discussion: """
            Displays current network analytics metrics including bandwidth,
            connections, DNS queries, and application statistics.
            """
        )
        
        @Flag(name: .long, help: "Output in JSON format")
        var json: Bool = false
        
        @Option(name: .long, help: "Filter by application name")
        var application: String?
        
        @Flag(name: .long, help: "Show detailed metrics")
        var detailed: Bool = false
        
        func run() throws {
            let analytics = NetworkAnalyticsEngine.shared
            let snapshot = analytics.getCurrentMetrics()
            
            if json {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(snapshot)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
                
            } else {
                print("Network Analytics Metrics")
                print("=========================")
                print("Timestamp: \(formatDate(snapshot.timestamp))")
                print("")
                
                // Bandwidth metrics
                print("Bandwidth:")
                print("  Total data: \(formatBytes(snapshot.bandwidth.totalBytes))")
                print("  Current speed: \(String(format: "%.2f", snapshot.bandwidth.totalMbps)) Mbps")
                print("  Peak speed: \(String(format: "%.2f", snapshot.bandwidth.peakMbps)) Mbps")
                print("")
                
                // Connection metrics
                print("Connections:")
                print("  Active: \(snapshot.connections.activeCount)")
                print("  Total: \(snapshot.connections.totalConnections)")
                print("  Peak active: \(snapshot.connections.peakActiveConnections)")
                print("")
                
                // DNS metrics
                print("DNS Queries:")
                print("  Total: \(snapshot.dns.totalQueries)")
                print("  Rate: \(String(format: "%.1f", snapshot.dns.queriesPerSecond)) queries/sec")
                if detailed {
                    print("  Top domains:")
                    let sortedDomains = snapshot.dns.queriesByDomain.sorted { $0.value > $1.value }
                    for (domain, count) in sortedDomains.prefix(5) {
                        print("    \(domain): \(count)")
                    }
                }
                print("")
                
                // Application metrics
                print("Applications:")
                if let app = application {
                    if let appMetric = snapshot.applications.applicationData[app] {
                        displayApplicationMetric(name: app, metric: appMetric)
                    } else {
                        print("  No data for application: \(app)")
                    }
                } else {
                    let sortedApps = snapshot.applications.applicationData.sorted { $0.value.totalBytes > $1.value.totalBytes }
                    for (name, metric) in sortedApps.prefix(detailed ? 10 : 5) {
                        displayApplicationMetric(name: name, metric: metric)
                    }
                }
            }
        }
        
        private func displayApplicationMetric(name: String, metric: ApplicationMetric) {
            print("  \(name):")
            print("    Data: \(formatBytes(metric.totalBytes))")
            print("    Events: \(metric.eventCount)")
            print("    Connections: \(metric.connectionCount)")
            print("    Last activity: \(formatDate(metric.lastActivity))")
        }
        
        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
            return formatter.string(from: date)
        }
        
        private func formatBytes(_ bytes: UInt64) -> String {
            let units = ["B", "KB", "MB", "GB", "TB"]
            var size = Double(bytes)
            var unitIndex = 0
            
            while size >= 1024 && unitIndex < units.count - 1 {
                size /= 1024
                unitIndex += 1
            }
            
            return String(format: "%.1f %@", size, units[unitIndex])
        }
    }
}

// MARK: - Export and Configuration Commands

extension AnalyticsCommands {
    
    struct ExportCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export analytics data",
            discussion: """
            Export collected analytics data in various formats.
            Supports JSON, CSV, and JSON Lines formats.
            """
        )
        
        @Option(name: .long, help: "Export format (json, csv, jsonl)")
        var format: ExportFormat = .json
        
        @Option(name: .long, help: "Output file path")
        var output: String?
        
        @Option(name: .long, help: "Export data from the last N hours")
        var lastHours: Int?
        
        @Option(name: .long, help: "Export data from the last N days")
        var lastDays: Int?
        
        @Flag(name: .long, help: "Enable verbose output")
        var verbose: Bool = false
        
        func run() throws {
            let analytics = NetworkAnalyticsEngine.shared
            
            // Determine time range
            let timeRange: DateInterval?
            if let hours = lastHours {
                let endTime = Date()
                let startTime = endTime.addingTimeInterval(TimeInterval(-hours * 3600))
                timeRange = DateInterval(start: startTime, end: endTime)
            } else if let days = lastDays {
                let endTime = Date()
                let startTime = endTime.addingTimeInterval(TimeInterval(-days * 24 * 3600))
                timeRange = DateInterval(start: startTime, end: endTime)
            } else {
                timeRange = nil
            }
            
            if verbose {
                if let range = timeRange {
                    print("Exporting data from \(range.start) to \(range.end)")
                } else {
                    print("Exporting all available data")
                }
            }
            
            // Export data
            let data = try analytics.exportAnalytics(format: format.analyticsFormat, timeRange: timeRange)
            
            // Write to file or stdout
            if let outputPath = output {
                try data.write(to: URL(fileURLWithPath: outputPath))
                if verbose {
                    print("✅ Data exported to: \(outputPath)")
                    print("   Size: \(data.count) bytes")
                }
            } else {
                print(String(data: data, encoding: .utf8) ?? "")
            }
        }
        
        enum ExportFormat: String, ExpressibleByArgument, CaseIterable {
            case json, csv, jsonl
            
            var analyticsFormat: AnalyticsExportFormat {
                switch self {
                case .json: return .json
                case .csv: return .csv
                case .jsonl: return .jsonl
                }
            }
        }
    }
    
    struct ConfigCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "config",
            abstract: "Configure analytics settings",
            discussion: """
            View and modify network analytics configuration.
            """
        )
        
        @Flag(name: .long, help: "Show current configuration")
        var show: Bool = false
        
        @Flag(name: .long, help: "Enable analytics")
        var enable: Bool = false
        
        @Flag(name: .long, help: "Disable analytics")
        var disable: Bool = false
        
        @Option(name: .long, help: "Set data retention period in days")
        var retentionDays: Int?
        
        @Flag(name: .long, help: "Output in JSON format")
        var json: Bool = false
        
        func run() throws {
            let configManager = ConfigurationManager.shared
            var config = configManager.getCurrentConfiguration()
            
            if show {
                if json {
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    let jsonData = try encoder.encode(config.modules.networkAnalytics)
                    print(String(data: jsonData, encoding: .utf8) ?? "{}")
                } else {
                    print("Network Analytics Configuration")
                    print("==============================")
                    print("Enabled: \(config.modules.networkAnalytics.enabled)")
                    print("Real-time processing: \(config.modules.networkAnalytics.realTimeProcessing)")
                    print("Data retention: \(config.modules.networkAnalytics.dataRetentionDays) days")
                    print("Storage backend: \(config.modules.networkAnalytics.storageBackend.rawValue)")
                    print("Max events in memory: \(config.modules.networkAnalytics.maxEventsInMemory)")
                }
                return
            }
            
            var changed = false
            
            if enable {
                config.modules.networkAnalytics.enabled = true
                changed = true
            }
            
            if disable {
                config.modules.networkAnalytics.enabled = false
                changed = true
            }
            
            if let retention = retentionDays {
                config.modules.networkAnalytics.dataRetentionDays = retention
                changed = true
            }
            
            if changed {
                try configManager.updateConfiguration(config)
                print("✅ Analytics configuration updated")
            } else {
                print("No changes made. Use --show to view current configuration.")
            }
        }
    }
    
    struct ReportCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "report",
            abstract: "Generate analytics reports",
            discussion: """
            Generate comprehensive analytics reports for specified time periods.
            """
        )
        
        @Option(name: .long, help: "Report period in hours")
        var hours: Int = 24
        
        @Flag(name: .long, help: "Include detailed breakdown")
        var detailed: Bool = false
        
        @Flag(name: .long, help: "Output in JSON format")
        var json: Bool = false
        
        func run() throws {
            let analytics = NetworkAnalyticsEngine.shared
            let endTime = Date()
            let startTime = endTime.addingTimeInterval(TimeInterval(-hours * 3600))
            let timeRange = DateInterval(start: startTime, end: endTime)
            
            // This would need to be implemented in the analytics engine
            // For now, show a basic report using current metrics
            let snapshot = analytics.getCurrentMetrics()
            
            if json {
                let report = AnalyticsReport(
                    period: timeRange,
                    totalBandwidth: snapshot.bandwidth.totalBytes,
                    totalConnections: snapshot.connections.totalConnections,
                    totalDNSQueries: snapshot.dns.totalQueries,
                    topApplications: Array(snapshot.applications.applicationData.prefix(10))
                )
                
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(report)
                print(String(data: jsonData, encoding: .utf8) ?? "{}")
                
            } else {
                print("Analytics Report (\(hours)h period)")
                print("==================================")
                print("Period: \(formatDate(startTime)) - \(formatDate(endTime))")
                print("")
                print("Summary:")
                print("  Total bandwidth: \(formatBytes(snapshot.bandwidth.totalBytes))")
                print("  Total connections: \(snapshot.connections.totalConnections)")
                print("  DNS queries: \(snapshot.dns.totalQueries)")
                print("")
                
                if detailed {
                    print("Top Applications:")
                    let sortedApps = snapshot.applications.applicationData.sorted { $0.value.totalBytes > $1.value.totalBytes }
                    for (name, metric) in sortedApps.prefix(10) {
                        print("  \(name): \(formatBytes(metric.totalBytes))")
                    }
                }
            }
        }
        
        private func formatDate(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        
        private func formatBytes(_ bytes: UInt64) -> String {
            let units = ["B", "KB", "MB", "GB", "TB"]
            var size = Double(bytes)
            var unitIndex = 0
            
            while size >= 1024 && unitIndex < units.count - 1 {
                size /= 1024
                unitIndex += 1
            }
            
            return String(format: "%.1f %@", size, units[unitIndex])
        }
    }
}

// MARK: - Supporting Types

struct AnalyticsStatusData: Codable {
    let enabled: Bool
    let realTimeProcessing: Bool
    let storageBackend: String
    let dataRetentionDays: Int
    let sessionId: String?
    let lastUpdate: Date
}

struct AnalyticsReport: Codable {
    let period: DateInterval
    let totalBandwidth: UInt64
    let totalConnections: UInt64
    let totalDNSQueries: UInt64
    let topApplicationsCount: Int
    
    init(period: DateInterval, totalBandwidth: UInt64, totalConnections: UInt64, totalDNSQueries: UInt64, topApplications: [(key: String, value: ApplicationMetric)]) {
        self.period = period
        self.totalBandwidth = totalBandwidth
        self.totalConnections = totalConnections
        self.totalDNSQueries = totalDNSQueries
        self.topApplicationsCount = topApplications.count
    }
}
