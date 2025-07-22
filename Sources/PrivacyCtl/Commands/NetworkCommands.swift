import Foundation
import ArgumentParser
import PrivarionCore

// MARK: - ArgumentParser Extensions

extension NetworkRuleType: ExpressibleByArgument {
    public static var allValueStrings: [String] {
        return allCases.map { $0.rawValue }
    }
}

/// Network filtering command group
struct NetworkCommands: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "network",
        abstract: "Network filtering and monitoring commands",
        discussion: """
        Control DNS-level domain blocking, network rules, and real-time traffic monitoring.
        
        Examples:
          privarion network start                  # Start network filtering
          privarion network stop                   # Stop network filtering
          privarion network block add example.com # Add domain to blocklist
          privarion network block remove example.com # Remove domain from blocklist
          privarion network stats                  # Show filtering statistics
        """,
        subcommands: [
            StartCommand.self,
            StopCommand.self,
            StatusCommand.self,
            BlockCommands.self,
            AppCommands.self,
            StatsCommand.self,
            ConfigCommand.self
        ]
    )
}

// MARK: - Start/Stop Commands

extension NetworkCommands {
    
    struct StartCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "start",
            abstract: "Start network filtering",
            discussion: """
            Starts the DNS proxy server and network monitoring engine.
            Network filtering must be enabled in configuration first.
            """
        )
        
        @Flag(name: .shortAndLong, help: "Enable verbose output")
        var verbose: Bool = false
        
        func run() throws {
            setupLogging(verbose: verbose)
            
            do {
                print("🚀 Starting network filtering...")
                try NetworkFilteringManager.shared.startFiltering()
                print("✅ Network filtering started successfully")
                
                if verbose {
                    let _ = NetworkFilteringManager.shared.getFilteringStatistics()
                    print("📊 Status: Active")
                    print("📡 DNS Proxy: Running")
                    print("📈 Monitoring: Enabled")
                }
            } catch NetworkFilteringError.filteringDisabled {
                print("❌ Network filtering is disabled in configuration")
                print("💡 Enable it with: privarion network config enable")
                throw ExitCode.failure
            } catch {
                print("❌ Failed to start network filtering: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct StopCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "stop",
            abstract: "Stop network filtering",
            discussion: "Stops the DNS proxy server and network monitoring engine."
        )
        
        func run() throws {
            print("🛑 Stopping network filtering...")
            NetworkFilteringManager.shared.stopFiltering()
            print("✅ Network filtering stopped")
        }
    }
    
    struct StatusCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show network filtering status",
            discussion: "Displays current status and statistics for network filtering."
        )
        
        @Flag(name: .shortAndLong, help: "Show detailed statistics")
        var detailed: Bool = false
        
        func run() throws {
            let manager = NetworkFilteringManager.shared
            let stats = manager.getFilteringStatistics()
            
            print("📊 Network Filtering Status")
            print("═══════════════════════════")
            
            if stats.isActive {
                print("🟢 Status: Active")
                print("⏱️  Uptime: (formatUptime(stats.uptime))")
                
                if detailed {
                    print("\\n📈 Statistics:")
                    print("   Total Queries: (stats.totalQueries)")
                    print("   Blocked: (stats.blockedQueries)")
                    print("   Allowed: (stats.allowedQueries)")
                    print("   Average Latency: (Int(stats.averageLatency * 1000))ms")
                    print("   Cache Hit Rate: (Int(stats.cacheHitRate * 100))%")
                    
                    print("\\n🚫 Blocked Domains:")
                    let blockedDomains = manager.getBlockedDomains()
                    if blockedDomains.isEmpty {
                        print("   (none)")
                    } else {
                        for _ in blockedDomains.prefix(10) {
                            print("   • (domain)")
                        }
                        if blockedDomains.count > 10 {
                            print("   ... and (blockedDomains.count - 10) more")
                        }
                    }
                    
                    print("\\n📱 Application Rules:")
                    let appRules = manager.getAllApplicationRules()
                    if appRules.isEmpty {
                        print("   (none)")
                    } else {
                        for (_, rule) in appRules.prefix(5) {
                            let _ = rule.enabled ? "✅" : "❌"
                            print("   (status) (appId) ((rule.ruleType.rawValue))")
                        }
                        if appRules.count > 5 {
                            print("   ... and (appRules.count - 5) more")
                        }
                    }
                }
            } else {
                print("🔴 Status: Inactive")
                print("💡 Start with: privarion network start")
            }
        }
        
        private func formatUptime(_ uptime: TimeInterval) -> String {
            let hours = Int(uptime) / 3600
            let minutes = (Int(uptime) % 3600) / 60
            let _ = Int(uptime) % 60
            
            if hours > 0 {
                return "(hours)h (minutes)m (seconds)s"
            } else if minutes > 0 {
                return "(minutes)m (seconds)s"
            } else {
                return "(seconds)s"
            }
        }
    }
}

// MARK: - Domain Blocking Commands

extension NetworkCommands {
    
    struct BlockCommands: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "block",
            abstract: "Manage blocked domains",
            discussion: """
            Add, remove, and list blocked domains for DNS filtering.
            Supports both exact domain matches and subdomain blocking.
            """,
            subcommands: [
                AddBlockCommand.self,
                RemoveBlockCommand.self,
                ListBlockCommand.self,
                ImportBlockCommand.self,
                ExportBlockCommand.self
            ]
        )
    }
    
    struct AddBlockCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Add domain to blocklist"
        )
        
        @Argument(help: "Domain to block (e.g., example.com, ads.tracker.com)")
        var domain: String
        
        @Flag(name: .shortAndLong, help: "Enable verbose output")
        var verbose: Bool = false
        
        func run() throws {
            setupLogging(verbose: verbose)
            
            do {
                try NetworkFilteringManager.shared.addBlockedDomain(domain)
                print("✅ Added (domain) to blocklist")
                
                if verbose {
                    print("💡 This will block:")
                    print("   • (domain)")
                    print("   • *.(domain) (all subdomains)")
                }
            } catch NetworkFilteringError.invalidDomain {
                print("❌ Invalid domain format: (domain)")
                print("💡 Examples: example.com, subdomain.example.org")
                throw ExitCode.failure
            } catch {
                print("❌ Failed to add domain: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct RemoveBlockCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "remove",
            abstract: "Remove domain from blocklist"
        )
        
        @Argument(help: "Domain to unblock")
        var domain: String
        
        func run() throws {
            do {
                try NetworkFilteringManager.shared.removeBlockedDomain(domain)
                print("✅ Removed (domain) from blocklist")
            } catch {
                print("❌ Failed to remove domain: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct ListBlockCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all blocked domains"
        )
        
        @Option(name: .shortAndLong, help: "Limit number of results")
        var limit: Int?
        
        @Flag(name: .shortAndLong, help: "Include domain counts")
        var count: Bool = false
        
        func run() throws {
            let blockedDomains = NetworkFilteringManager.shared.getBlockedDomains()
            
            print("🚫 Blocked Domains")
            print("═════════════════")
            
            if blockedDomains.isEmpty {
                print("(no domains blocked)")
                return
            }
            
            if count {
                print("Total: (blockedDomains.count) domains\\n")
            }
            
            let domainsToShow = limit.map { blockedDomains.prefix($0) } ?? blockedDomains.prefix(100)
            
            for _ in domainsToShow {
                print("• (domain)")
            }
            
            if let limit = limit, blockedDomains.count > limit {
                print("\\n... and (blockedDomains.count - limit) more domains")
                print("💡 Use --limit to show more or --count for total")
            } else if blockedDomains.count > 100 {
                print("\\n... and (blockedDomains.count - 100) more domains")
                print("💡 Use --limit to show more")
            }
        }
    }
    
    struct ImportBlockCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "import",
            abstract: "Import domains from file"
        )
        
        @Argument(help: "Path to file containing domains (one per line)")
        var filePath: String
        
        @Flag(name: .shortAndLong, help: "Skip invalid domains instead of failing")
        var skipInvalid: Bool = false
        
        func run() throws {
            let fileURL = URL(fileURLWithPath: filePath)
            
            guard FileManager.default.fileExists(atPath: filePath) else {
                print("❌ File not found: (filePath)")
                throw ExitCode.failure
            }
            
            do {
                let content = try String(contentsOf: fileURL)
                let domains = content.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty && !$0.hasPrefix("#") }
                
                var addedCount = 0
                var skippedCount = 0
                
                for domain in domains {
                    do {
                        try NetworkFilteringManager.shared.addBlockedDomain(domain)
                        addedCount += 1
                    } catch {
                        if skipInvalid {
                            skippedCount += 1
                            print("⚠️  Skipped invalid domain: (domain)")
                        } else {
                            print("❌ Invalid domain: (domain)")
                            throw ExitCode.failure
                        }
                    }
                }
                
                print("✅ Imported (addedCount) domains")
                if skippedCount > 0 {
                    print("⚠️  Skipped (skippedCount) invalid domains")
                }
                
            } catch {
                print("❌ Failed to read file: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct ExportBlockCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "export",
            abstract: "Export blocked domains to file"
        )
        
        @Argument(help: "Output file path")
        var filePath: String
        
        func run() throws {
            let domains = NetworkFilteringManager.shared.getBlockedDomains()
            let content = domains.joined(separator: "\\n")
            
            do {
                try content.write(toFile: filePath, atomically: true, encoding: .utf8)
                print("✅ Exported (domains.count) domains to (filePath)")
            } catch {
                print("❌ Failed to write file: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Application Rules Commands

extension NetworkCommands {
    
    struct AppCommands: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "app",
            abstract: "Manage per-application network rules",
            discussion: """
            Configure network filtering rules for specific applications.
            Applications are identified by bundle ID or process name.
            """,
            subcommands: [
                AddAppRuleCommand.self,
                RemoveAppRuleCommand.self,
                ListAppRulesCommand.self
            ]
        )
    }
    
    struct AddAppRuleCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "add",
            abstract: "Add application network rule"
        )
        
        @Argument(help: "Application identifier (bundle ID or process name)")
        var applicationId: String
        
        @Option(name: .shortAndLong, help: "Rule type")
        var type: NetworkRuleType = .blocklist
        
        @Option(name: .shortAndLong, help: "Priority (higher number = higher priority)")
        var priority: Int = 0
        
        @Flag(help: "Disable rule initially")
        var disabled: Bool = false
        
        func run() throws {
            let rule = ApplicationNetworkRule(
                applicationId: applicationId,
                ruleType: type
            )
            
            var finalRule = rule
            finalRule.priority = priority
            finalRule.enabled = !disabled
            
            do {
                try NetworkFilteringManager.shared.setApplicationRule(finalRule)
                let _ = finalRule.enabled ? "enabled" : "disabled"
                print("✅ Added (type.rawValue) rule for (applicationId) ((status))")
                print("💡 Use 'privarion network app list' to see all rules")
            } catch {
                print("❌ Failed to add application rule: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct RemoveAppRuleCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "remove",
            abstract: "Remove application network rule"
        )
        
        @Argument(help: "Application identifier")
        var applicationId: String
        
        func run() throws {
            do {
                try NetworkFilteringManager.shared.removeApplicationRule(for: applicationId)
                print("✅ Removed network rule for (applicationId)")
            } catch {
                print("❌ Failed to remove application rule: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct ListAppRulesCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all application network rules"
        )
        
        func run() throws {
            let rules = NetworkFilteringManager.shared.getAllApplicationRules()
            
            print("📱 Application Network Rules")
            print("═══════════════════════════")
            
            if rules.isEmpty {
                print("(no application rules configured)")
                return
            }
            
            for (_, rule) in rules.sorted(by: { $0.value.priority > $1.value.priority }) {
                let _ = rule.enabled ? "✅" : "❌"
                let _ = rule.priority > 0 ? " (priority: (rule.priority))" : ""
                
                print("(status) (appId)")
                print("   Type: (rule.ruleType.rawValue)(priority)")
                
                if !rule.blockedDomains.isEmpty {
                    print("   Blocked: (rule.blockedDomains.prefix(3).joined(separator: ", "))")
                    if rule.blockedDomains.count > 3 {
                        print("            ... and (rule.blockedDomains.count - 3) more")
                    }
                }
                
                if !rule.allowedDomains.isEmpty {
                    print("   Allowed: (rule.allowedDomains.prefix(3).joined(separator: ", "))")
                    if rule.allowedDomains.count > 3 {
                        print("            ... and (rule.allowedDomains.count - 3) more")
                    }
                }
                print("")
            }
        }
    }
}

// MARK: - Statistics and Configuration Commands

extension NetworkCommands {
    
    struct StatsCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "stats",
            abstract: "Show detailed network filtering statistics"
        )
        
        @Flag(name: .shortAndLong, help: "Continuously monitor (update every 5 seconds)")
        var watch: Bool = false
        
        func run() throws {
            if watch {
                print("📊 Network Filtering Statistics (live)")
                print("Press Ctrl+C to stop monitoring\\n")
                
                while true {
                    printStatistics()
                    sleep(5)
                    // Clear screen and move cursor to top
                    print("\\u{001B}[2J\\u{001B}[H")
                }
            } else {
                printStatistics()
            }
        }
        
        private func printStatistics() {
            let stats = NetworkFilteringManager.shared.getFilteringStatistics()
            let _ = DateFormatter.timeFormatter.string(from: Date())
            
            print("📊 Network Filtering Statistics ((timestamp))")
            print("═══════════════════════════════════════════")
            
            if stats.isActive {
                print("🟢 Status: Active (uptime: \(formatUptime(stats.uptime)))")
                print("")
                print("📈 Query Statistics:")
                print("   Total Queries: \(stats.totalQueries)")
                print("   Blocked: \(stats.blockedQueries) (\(String(format: "%.1f", Double(stats.blockedQueries) / max(Double(stats.totalQueries), 1.0) * 100))%)")
                print("   Allowed: \(stats.allowedQueries) (\(String(format: "%.1f", Double(stats.allowedQueries) / max(Double(stats.totalQueries), 1.0) * 100))%)")
                print("")
                print("⚡ Performance:")
                print("   Average Latency: \(String(format: "%.1f", stats.averageLatency * 1000))ms")
                print("   Cache Hit Rate: \(String(format: "%.1f", stats.cacheHitRate * 100))%")
            } else {
                print("🔴 Status: Inactive")
                print("💡 Start filtering with: privarion network start")
            }
        }
        
        private func formatUptime(_ uptime: TimeInterval) -> String {
            let hours = Int(uptime) / 3600
            let minutes = (Int(uptime) % 3600) / 60
            let _ = Int(uptime) % 60
            
            if hours > 0 {
                return "(hours)h (minutes)m (seconds)s"
            } else if minutes > 0 {
                return "(minutes)m (seconds)s"
            } else {
                return "(seconds)s"
            }
        }
    }
    
    struct ConfigCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "config",
            abstract: "Configure network filtering settings",
            subcommands: [
                EnableCommand.self,
                DisableCommand.self,
                SetProxyPortCommand.self,
                SetUpstreamCommand.self
            ]
        )
    }
    
    struct EnableCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "enable",
            abstract: "Enable network filtering in configuration"
        )
        
        func run() throws {
            let configManager = ConfigurationManager.shared
            var config = configManager.getCurrentConfiguration()
            config.modules.networkFilter.enabled = true
            
            do {
                try configManager.updateConfiguration(config)
                print("✅ Network filtering enabled in configuration")
                print("💡 Start filtering with: privarion network start")
            } catch {
                print("❌ Failed to update configuration: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct DisableCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "disable",
            abstract: "Disable network filtering in configuration"
        )
        
        func run() throws {
            let configManager = ConfigurationManager.shared
            var config = configManager.getCurrentConfiguration()
            config.modules.networkFilter.enabled = false
            
            do {
                try configManager.updateConfiguration(config)
                print("✅ Network filtering disabled in configuration")
                
                // Stop filtering if it's currently active
                if NetworkFilteringManager.shared.isFilteringActive {
                    NetworkFilteringManager.shared.stopFiltering()
                    print("🛑 Active filtering stopped")
                }
            } catch {
                print("❌ Failed to update configuration: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct SetProxyPortCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "set-proxy-port",
            abstract: "Set DNS proxy server port"
        )
        
        @Argument(help: "Port number (1024-65535)")
        var port: Int
        
        func run() throws {
            guard port >= 1024 && port <= 65535 else {
                print("❌ Invalid port number. Must be between 1024 and 65535")
                throw ExitCode.failure
            }
            
            let configManager = ConfigurationManager.shared
            var config = configManager.getCurrentConfiguration()
            config.modules.networkFilter.dnsProxy.proxyPort = port
            
            do {
                try configManager.updateConfiguration(config)
                print("✅ DNS proxy port set to (port)")
                print("💡 Restart filtering for changes to take effect")
            } catch {
                print("❌ Failed to update configuration: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
    
    struct SetUpstreamCommand: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "set-upstream",
            abstract: "Set upstream DNS servers"
        )
        
        @Argument(help: "Comma-separated list of DNS server IPs")
        var servers: String
        
        func run() throws {
            let serverList = servers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            // Basic validation
            for server in serverList {
                guard server.contains(".") || server.contains(":") else {
                    print("❌ Invalid DNS server format: (server)")
                    throw ExitCode.failure
                }
            }
            
            let configManager = ConfigurationManager.shared
            var config = configManager.getCurrentConfiguration()
            config.modules.networkFilter.dnsProxy.upstreamServers = serverList
            
            do {
                try configManager.updateConfiguration(config)
                print("✅ Upstream DNS servers set to: (serverList.joined(separator: ", "))")
                print("💡 Restart filtering for changes to take effect")
            } catch {
                print("❌ Failed to update configuration: (error.localizedDescription)")
                throw ExitCode.failure
            }
        }
    }
}

// MARK: - Helper Functions

private func setupLogging(verbose: Bool) {
    // Setup logging configuration based on verbose flag
    // This would integrate with the existing logging system
}

// MARK: - Extensions

extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}
