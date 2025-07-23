import Foundation
import ArgumentParser
import PrivarionCore

@available(macOS 12.0, *)
/// Permission management commands for TCC permission system
struct PermissionCommands: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "permission",
        abstract: "Manage TCC permissions and temporary grants",
        subcommands: [
            ListPermissions.self,
            GrantTemporary.self,
            RevokeGrant.self,
            ShowGrant.self,
            ExportGrants.self,
            CleanupExpired.self,
            PermissionStatus.self
        ]
    )
}

// MARK: - List Permissions Command

@available(macOS 12.0, *)
struct ListPermissions: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List active temporary permissions"
    )
    
    @Option(name: .shortAndLong, help: "Filter by bundle identifier")
    var bundle: String?
    
    @Flag(name: .shortAndLong, help: "Show only expiring soon (within 5 minutes)")
    var expiring: Bool = false
    
    @Flag(name: .shortAndLong, help: "Output in JSON format")
    var json: Bool = false
    
    @Flag(name: .shortAndLong, help: "Show detailed information")
    var verbose: Bool = false
    
    func run() async throws {
        let manager = TemporaryPermissionManager()
        
        if json {
            let jsonOutput = try await manager.exportGrantsToJSON()
            print(jsonOutput)
        } else {
            let output = await manager.listGrantsForCLI()
            print(output)
            
            if verbose {
                let (successRate, avgCleanup, totalGrants) = await manager.getReliabilityMetrics()
                print("\nSystem Statistics:")
                print("=================")
                print("Total Active Grants: \(totalGrants)")
                print("Cleanup Success Rate: \(String(format: "%.2f%%", successRate * 100))")
                print("Average Cleanup Time: \(String(format: "%.3fs", avgCleanup))")
            }
        }
    }
}

// MARK: - Grant Temporary Permission Command

@available(macOS 12.0, *)
struct GrantTemporary: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "grant",
        abstract: "Grant temporary permission to an application"
    )
    
    @Argument(help: "Bundle identifier (e.g., com.example.app)")
    var bundleIdentifier: String
    
    @Argument(help: "Service name (Camera, Microphone, ScreenRecording, etc.)")
    var service: String
    
    @Argument(help: "Duration (e.g., 30m, 2h, 300s)")
    var duration: String
    
    @Option(name: .shortAndLong, help: "Reason for granting permission")
    var reason: String = ""
    
    @Flag(name: .shortAndLong, help: "Force grant even if permission already exists")
    var force: Bool = false
    
    @Flag(name: .shortAndLong, help: "Quiet mode - minimal output")
    var quiet: Bool = false
    
    func run() async throws {
        // Parse duration
        guard let durationSeconds = TemporaryPermissionManager.parseDuration(duration) else {
            throw ValidationError("Invalid duration format. Use formats like: 30s, 5m, 2h")
        }
        
        // Normalize service name
        let serviceName = normalizeServiceName(service)
        
        let manager = TemporaryPermissionManager()
        let request = TemporaryPermissionManager.GrantRequest(
            bundleIdentifier: bundleIdentifier,
            serviceName: serviceName,
            duration: durationSeconds,
            reason: reason,
            requestedBy: "cli"
        )
        
        do {
            let result = try await manager.grantPermission(request)
            
            if !quiet {
                let output = await manager.formatGrantResultForCLI(result)
                print(output)
            }
            
            // Exit with appropriate code
            switch result {
            case .granted:
                if !quiet { print("\n✅ Use 'privarion permission list' to view all active grants") }
            case .denied:
                Foundation.exit(1)
            case .alreadyExists where !force:
                if !quiet { print("\n💡 Use --force to replace existing grant") }
                Foundation.exit(2)
            case .alreadyExists:
                break // Force was used
            case .invalidRequest:
                Foundation.exit(3)
            }
            
        } catch {
            print("❌ Error: \(error.localizedDescription)")
            Foundation.exit(4)
        }
    }
    
    private func normalizeServiceName(_ service: String) -> String {
        let serviceMap = [
            "camera": "kTCCServiceCamera",
            "microphone": "kTCCServiceMicrophone", 
            "location": "kTCCServiceLocationManager",
            "contacts": "kTCCServiceAddressBook",
            "calendar": "kTCCServiceCalendar",
            "reminders": "kTCCServiceReminders",
            "photos": "kTCCServicePhotos",
            "fulldiskaccess": "kTCCServiceSystemPolicyAllFiles",
            "accessibility": "kTCCServiceAccessibility",
            "screenrecording": "kTCCServiceScreenCapture",
            "inputmonitoring": "kTCCServiceListenEvent"
        ]
        
        let lowercased = service.lowercased().replacingOccurrences(of: " ", with: "")
        return serviceMap[lowercased] ?? service
    }
}

// MARK: - Revoke Grant Command

@available(macOS 12.0, *)
struct RevokeGrant: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "revoke",
        abstract: "Revoke temporary permission grant"
    )
    
    @Argument(help: "Grant ID or bundle identifier")
    var identifier: String
    
    @Flag(name: .shortAndLong, help: "Revoke all grants for the specified bundle identifier")
    var all: Bool = false
    
    @Flag(name: .shortAndLong, help: "Confirm dangerous operations without prompting")
    var force: Bool = false
    
    func run() async throws {
        let manager = TemporaryPermissionManager()
        
        if all {
            // Revoke all grants for bundle identifier
            if !force {
                print("⚠️  This will revoke ALL temporary permissions for '\(identifier)'")
                print("Are you sure? [y/N]: ", terminator: "")
                
                guard let input = readLine()?.lowercased(),
                      input == "y" || input == "yes" else {
                    print("Cancelled.")
                    return
                }
            }
            
            let revokedCount = await manager.revokeAllPermissions(bundleIdentifier: identifier)
            
            if revokedCount > 0 {
                print("✅ Revoked \(revokedCount) temporary permission(s) for '\(identifier)'")
            } else {
                print("ℹ️  No active temporary permissions found for '\(identifier)'")
                Foundation.exit(1)
            }
            
        } else {
            // Revoke specific grant by ID
            let success = await manager.revokePermission(grantID: identifier)
            
            if success {
                print("✅ Successfully revoked grant '\(identifier)'")
            } else {
                print("❌ Grant '\(identifier)' not found or already expired")
                Foundation.exit(1)
            }
        }
    }
}

// MARK: - Show Grant Details Command

@available(macOS 12.0, *)
struct ShowGrant: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show detailed information about a temporary grant"
    )
    
    @Argument(help: "Grant ID")
    var grantID: String
    
    @Flag(name: .shortAndLong, help: "Output in JSON format")
    var json: Bool = false
    
    func run() async throws {
        let manager = TemporaryPermissionManager()
        
        guard let grant = await manager.getGrant(id: grantID) else {
            print("❌ Grant '\(grantID)' not found or has expired")
            Foundation.exit(1)
        }
        
        if json {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(grant)
            if let jsonString = String(data: data, encoding: .utf8) {
                print(jsonString)
            }
        } else {
            print("Temporary Permission Grant Details")
            print("================================")
            print("Grant ID: \(grant.id)")
            print("Bundle ID: \(grant.bundleIdentifier)")
            print("Service: \(grant.serviceName.replacingOccurrences(of: "kTCCService", with: ""))")
            print("Granted: \(DateFormatter.localizedString(from: grant.grantedAt, dateStyle: .medium, timeStyle: .medium))")
            print("Expires: \(DateFormatter.localizedString(from: grant.expiresAt, dateStyle: .medium, timeStyle: .medium))")
            print("Remaining: \(formatDuration(grant.remainingTime))")
            print("Granted By: \(grant.grantedBy)")
            print("Auto Revoke: \(grant.autoRevoke ? "Yes" : "No")")
            
            if !grant.reason.isEmpty {
                print("Reason: \(grant.reason)")
            }
            
            if grant.isExpiringSoon {
                print("\n⚠️  This grant is expiring soon!")
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.0fs", duration)
        } else if duration < 3600 {
            return String(format: "%.0fm", duration / 60)
        } else {
            return String(format: "%.1fh", duration / 3600)
        }
    }
}

// MARK: - Export Grants Command

@available(macOS 12.0, *)
struct ExportGrants: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Export temporary grants to file"
    )
    
    @Option(name: .shortAndLong, help: "Output file path")
    var output: String?
    
    @Option(name: .shortAndLong, help: "Output format (json, csv)")
    var format: String = "json"
    
    func run() async throws {
        let manager = TemporaryPermissionManager()
        
        let outputData: String
        
        switch format.lowercased() {
        case "json":
            outputData = try await manager.exportGrantsToJSON()
        case "csv":
            outputData = try await exportToCSV(manager)
        default:
            throw ValidationError("Unsupported format '\(format)'. Use 'json' or 'csv'")
        }
        
        if let outputPath = output {
            try outputData.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("✅ Exported to '\(outputPath)'")
        } else {
            print(outputData)
        }
    }
    
    @available(macOS 12.0, *)
    private func exportToCSV(_ manager: TemporaryPermissionManager) async throws -> String {
        let grants = await manager.getActiveGrants()
        
        var csv = "Grant ID,Bundle ID,Service,Granted At,Expires At,Remaining Time,Granted By,Reason\n"
        
        for grant in grants {
            let escapedReason = grant.reason.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(grant.id)\",\"\(grant.bundleIdentifier)\",\"\(grant.serviceName)\",\"\(grant.grantedAt)\",\"\(grant.expiresAt)\",\"\(grant.remainingTime)\",\"\(grant.grantedBy)\",\"\(escapedReason)\"\n"
        }
        
        return csv
    }
}

// MARK: - Cleanup Expired Grants Command

@available(macOS 12.0, *)
struct CleanupExpired: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cleanup",
        abstract: "Force cleanup of expired temporary grants"
    )
    
    @Flag(name: .shortAndLong, help: "Show detailed cleanup statistics")
    var verbose: Bool = false
    
    func run() async throws {
        let manager = TemporaryPermissionManager()
        
        print("🧹 Running cleanup...")
        let stats = await manager.cleanupExpiredGrants()
        
        print("✅ Cleanup completed")
        print("Expired grants removed: \(stats.expiredCleaned)")
        print("Cleanup duration: \(String(format: "%.3fs", stats.cleanupDuration))")
        
        if verbose {
            print("\nDetailed Statistics:")
            print("==================")
            print("Total grants processed: \(stats.totalGrants)")
            print("Success rate: \(String(format: "%.2f%%", stats.successRate * 100))")
            print("Notifications sent: \(stats.notificationsSent)")
            print("Timestamp: \(stats.timestamp)")
        }
    }
}

// MARK: - Permission Status Command

@available(macOS 12.0, *)
struct PermissionStatus: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Show system permission status and statistics"
    )
    
    @Flag(name: .shortAndLong, help: "Show detailed system statistics")
    var verbose: Bool = false
    
    func run() async throws {
        let manager = TemporaryPermissionManager()
        let (successRate, avgCleanup, totalGrants) = await manager.getReliabilityMetrics()
        let activeGrants = await manager.getActiveGrants()
        
        print("Temporary Permission System Status")
        print("=================================")
        print("Active Grants: \(totalGrants)")
        print("System Reliability: \(String(format: "%.2f%%", successRate * 100))")
        print("Average Cleanup Time: \(String(format: "%.3fs", avgCleanup))")
        
        let expiringSoon = activeGrants.filter { $0.isExpiringSoon }
        if !expiringSoon.isEmpty {
            print("⚠️  Grants expiring soon: \(expiringSoon.count)")
        }
        
        if verbose {
            print("\nCleanup History:")
            print("===============")
            let cleanupStats = await manager.getCleanupStats()
            let recentStats = cleanupStats.suffix(5)
            
            for stat in recentStats {
                print("\(stat.timestamp): \(stat.expiredCleaned) cleaned, \(String(format: "%.3fs", stat.cleanupDuration))")
            }
        }
        
        // Health check
        let healthIssues = await checkSystemHealth(manager)
        if !healthIssues.isEmpty {
            print("\n⚠️  Health Issues:")
            for issue in healthIssues {
                print("  • \(issue)")
            }
        } else {
            print("\n✅ System is healthy")
        }
    }
    
    @available(macOS 12.0, *)
    private func checkSystemHealth(_ manager: TemporaryPermissionManager) async -> [String] {
        var issues: [String] = []
        let (successRate, avgCleanup, totalGrants) = await manager.getReliabilityMetrics()
        
        if successRate < 0.99 {
            issues.append("Cleanup success rate below 99%: \(String(format: "%.2f%%", successRate * 100))")
        }
        
        if avgCleanup > 5.0 {
            issues.append("Average cleanup time too high: \(String(format: "%.3fs", avgCleanup))")
        }
        
        if totalGrants > 50 {
            issues.append("High number of active grants: \(totalGrants)")
        }
        
        return issues
    }
}

// MARK: - Helper Extensions

extension ValidationError: @retroactive LocalizedError {
    public var errorDescription: String? {
        return message
    }
}
