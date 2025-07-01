import Foundation
import ArgumentParser
import PrivarionCore

/// MAC Address Spoofing Commands - Network Interface Privacy Management
struct MacAddressCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mac-address",
        abstract: "Manage MAC address spoofing for network interfaces",
        discussion: """
        Provides comprehensive MAC address spoofing capabilities for privacy protection.
        Change network interface MAC addresses to prevent tracking and enhance anonymity.
        
        COMMON USAGE PATTERNS:
        
        List Network Interfaces:
            privarion mac-address list                    # Show all interfaces
            privarion mac-address list --format json     # JSON output
        
        Spoof MAC Address:
            privarion mac-address spoof en0              # Random MAC for en0
            privarion mac-address spoof en0 02:00:00:00:00:01  # Specific MAC
            privarion mac-address spoof en0 --random     # Explicitly random
        
        Restore Original:
            privarion mac-address restore en0            # Restore specific interface
            privarion mac-address restore-all            # Restore all interfaces
        
        Check Status:
            privarion mac-address status                 # Show spoofing status
            privarion mac-address status --interface en0 # Status for specific interface
        
        SECURITY CONSIDERATIONS:
        • Requires administrator privileges (sudo) for most operations
        • Network connectivity may be temporarily interrupted during MAC changes
        • Some networks may reject spoofed MAC addresses
        • Original MAC addresses are securely stored for restoration
        
        For detailed help on any subcommand, use: privarion mac-address help <subcommand>
        """,
        version: "1.0.0",
        subcommands: [
            ListCommand.self,
            SpoofCommand.self,
            RestoreCommand.self,
            RestoreAllCommand.self,
            StatusCommand.self
        ]
    )
}

// MARK: - List Network Interfaces Command

extension MacAddressCommand {
    struct ListCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List all network interfaces with their MAC addresses",
            discussion: """
            Displays comprehensive information about all network interfaces including:
            • Interface name and type (Wi-Fi, Ethernet, etc.)
            • Current MAC address
            • Original MAC address (if spoofed)
            • Interface status (active/inactive)
            • Spoofing status
            
            Use --format json for programmatic access to interface data.
            """
        )
        
        @Option(name: .long, help: "Output format: table (default) or json")
        var format: OutputFormat = .table
        
        @Flag(name: .long, help: "Show only active network interfaces")
        var activeOnly = false
        
        @Flag(name: .long, help: "Include detailed interface information")
        var verbose = false
        
        func run() throws {
            let manager = MacAddressSpoofingManager()
            
            do {
                let interfaces = try runAsyncTask {
                    try await manager.getInterfaceStatus()
                }
                
                if interfaces.isEmpty {
                    print("No network interfaces found.")
                    return
                }
                
                let filteredInterfaces = activeOnly ? interfaces.filter { $0.isActive } : interfaces
                
                if filteredInterfaces.isEmpty {
                    print("No \(activeOnly ? "active " : "")network interfaces found.")
                    return
                }
                
                switch format {
                case .table:
                    displayInterfacesTable(filteredInterfaces)
                case .json:
                    displayInterfacesJSON(filteredInterfaces)
                }
                
            } catch let error as MacSpoofingError {
                throw PrivarionCLIError.macAddressOperationFailed(operation: "list", error: error)
            } catch {
                throw PrivarionCLIError.systemError(error.localizedDescription)
            }
        }
        
        private func displayInterfacesTable(_ interfaces: [InterfaceStatus]) {
            print("\nNetwork Interfaces:")
            print("┌─────────────┬──────────────────────┬──────────────────────┬──────────┬───────────┐")
            print("│ Interface   │ Current MAC          │ Original MAC         │ Status   │ Spoofed   │")
            print("├─────────────┼──────────────────────┼──────────────────────┼──────────┼───────────┤")
            
            for interface in interfaces {
                let name = interface.name.padding(toLength: 11, withPad: " ", startingAt: 0)
                let currentMAC = interface.currentMAC.padding(toLength: 20, withPad: " ", startingAt: 0)
                let originalMAC = (interface.originalMAC ?? "N/A").padding(toLength: 20, withPad: " ", startingAt: 0)
                let status = (interface.isActive ? "Active" : "Inactive").padding(toLength: 8, withPad: " ", startingAt: 0)
                let spoofed = (interface.isSpoofed ? "Yes" : "No").padding(toLength: 9, withPad: " ", startingAt: 0)
                
                print("│ \(name) │ \(currentMAC) │ \(originalMAC) │ \(status) │ \(spoofed) │")
                
                if verbose {
                    let typeInfo = "  Type: \(interface.interfaceType.rawValue)"
                    print("│ \(typeInfo.padding(toLength: 79, withPad: " ", startingAt: 0)) │")
                }
            }
            
            print("└─────────────┴──────────────────────┴──────────────────────┴──────────┴───────────┘")
            
            let totalCount = interfaces.count
            let activeCount = interfaces.filter { $0.isActive }.count
            let spoofedCount = interfaces.filter { $0.isSpoofed }.count
            
            print("\nSummary: \(totalCount) total, \(activeCount) active, \(spoofedCount) spoofed")
        }
        
        private func displayInterfacesJSON(_ interfaces: [InterfaceStatus]) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            do {
                let jsonData = try encoder.encode(interfaces)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } catch {
                print("Error encoding interfaces to JSON: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Spoof MAC Address Command

extension MacAddressCommand {
    struct SpoofCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "spoof",
            abstract: "Change the MAC address of a network interface",
            discussion: """
            Modifies the MAC address of the specified network interface for privacy protection.
            
            The new MAC address can be:
            • Automatically generated (random but valid)
            • Explicitly specified in standard format (XX:XX:XX:XX:XX:XX)
            • Generated with specific OUI (Organizationally Unique Identifier)
            
            IMPORTANT NOTES:
            • Requires administrator privileges (sudo)
            • Network connection may be temporarily interrupted
            • Original MAC address is automatically backed up for restoration
            • Interface will be brought down and up during the operation
            
            EXAMPLES:
            privarion mac-address spoof en0                    # Random MAC
            privarion mac-address spoof en0 02:00:00:00:00:01  # Specific MAC
            privarion mac-address spoof en0 --preserve-oui     # Keep vendor prefix
            """
        )
        
        @Argument(help: "Network interface name (e.g., en0, en1, bridge0)")
        var interface: String
        
        @Argument(help: "New MAC address in XX:XX:XX:XX:XX:XX format (optional, generates random if not provided)")
        var macAddress: String?
        
        @Flag(name: .long, help: "Generate a random MAC address (explicit)")
        var random = false
        
        @Flag(name: .long, help: "Preserve the original OUI (first 3 octets) when generating random MAC")
        var preserveOUI = false
        
        @Flag(name: .long, help: "Force operation even if interface is active")
        var force = false
        
        @Flag(name: .long, help: "Dry run - show what would be done without making changes")
        var dryRun = false
        
        func run() throws {
            let manager = MacAddressSpoofingManager()
            
            // Validate interface exists
            guard try runAsyncTask({
                let interfaces = try await manager.getInterfaceStatus()
                return interfaces.contains { $0.name == interface }
            }) else {
                throw PrivarionCLIError.macAddressInterfaceNotFound(interface, availableInterfaces: try getAvailableInterfaces())
            }
            
            // Determine target MAC address
            let targetMAC: String
            if let providedMAC = macAddress {
                // Validate provided MAC address format
                guard isValidMACAddress(providedMAC) else {
                    throw PrivarionCLIError.macAddressInvalidFormat(providedMAC)
                }
                targetMAC = providedMAC
            } else {
                // Generate random MAC address
                targetMAC = "random" // Placeholder - spoofMACAddress with nil customMAC will generate random
            }
            
            // Show operation details
            print("MAC Address Spoofing Operation:")
            print("  Interface: \(interface)")
            print("  Target MAC: \(targetMAC)")
            if preserveOUI {
                print("  Mode: Random with preserved OUI")
            } else if macAddress != nil {
                print("  Mode: Explicit MAC address")
            } else {
                print("  Mode: Fully random")
            }
            
            if dryRun {
                print("  *** DRY RUN - No changes will be made ***")
                return
            }
            
            // Confirm operation if interface is active
            if !force {
                let isActive = try runAsyncTask {
                    let interfaces = try await manager.getInterfaceStatus()
                    return interfaces.first { $0.name == interface }?.isActive ?? false
                }
                
                if isActive {
                    print("\nWarning: Interface \(interface) is currently active.")
                    print("Network connectivity may be temporarily interrupted.")
                    print("Continue? (y/N): ", terminator: "")
                    
                    let response = readLine()?.lowercased()
                    guard response == "y" || response == "yes" else {
                        print("Operation cancelled.")
                        return
                    }
                }
            }
            
            // Perform MAC address spoofing
            print("\nExecuting MAC address change...")
            
            do {
                try runAsyncTask {
                    if targetMAC == "random" {
                        try await manager.spoofMACAddress(interface: interface, customMAC: nil, preserveVendorPrefix: preserveOUI)
                    } else {
                        try await manager.spoofMACAddress(interface: interface, customMAC: targetMAC, preserveVendorPrefix: false)
                    }
                }
                
                print("✅ MAC address successfully changed.")
                print("  Interface: \(interface)")
                print("  New MAC: \(targetMAC)")
                print("\nUse 'privarion mac-address restore \(interface)' to restore the original MAC address.")
                
            } catch let error as MacSpoofingError {
                // Automatic rollback is handled by the manager
                throw PrivarionCLIError.macAddressOperationFailed(operation: "spoof", error: error)
            } catch {
                throw PrivarionCLIError.systemError(error.localizedDescription)
            }
        }
        
        private func getAvailableInterfaces() throws -> [String] {
            let manager = MacAddressSpoofingManager()
            return try runAsyncTask {
                let interfaces = try await manager.getInterfaceStatus()
                return interfaces.map { $0.name }
            }
        }
        
        private func isValidMACAddress(_ mac: String) -> Bool {
            let macRegex = "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"
            return mac.range(of: macRegex, options: .regularExpression) != nil
        }
    }
}

// MARK: - Restore MAC Address Command

extension MacAddressCommand {
    struct RestoreCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "restore",
            abstract: "Restore the original MAC address of a network interface",
            discussion: """
            Restores the factory/original MAC address of the specified network interface.
            
            This command:
            • Retrieves the backed-up original MAC address
            • Restores the interface to its original MAC address
            • Clears the spoofing state for the interface
            • Preserves network connectivity during the operation
            
            IMPORTANT NOTES:
            • Requires administrator privileges (sudo)
            • Network connection may be briefly interrupted
            • Only works for interfaces that have been previously spoofed
            • Original MAC must be available in the backup repository
            
            EXAMPLES:
            privarion mac-address restore en0      # Restore en0 to original
            privarion mac-address restore en1      # Restore en1 to original
            """
        )
        
        @Argument(help: "Network interface name to restore")
        var interface: String
        
        @Flag(name: .long, help: "Force restoration even if interface is active")
        var force = false
        
        @Flag(name: .long, help: "Dry run - show what would be done without making changes")
        var dryRun = false
        
        func run() throws {
            let manager = MacAddressSpoofingManager()
            
            // Validate interface exists
            guard try runAsyncTask({
                let interfaces = try await manager.getInterfaceStatus()
                return interfaces.contains { $0.name == interface }
            }) else {
                throw PrivarionCLIError.macAddressInterfaceNotFound(interface, availableInterfaces: try getAvailableInterfaces())
            }
            
            // Check if interface has been spoofed
            let interfaceInfo = try runAsyncTask {
                let interfaces = try await manager.getInterfaceStatus()
                return interfaces.first { $0.name == interface }
            }
            
            guard let info = interfaceInfo else {
                throw PrivarionCLIError.macAddressInterfaceNotFound(interface, availableInterfaces: try getAvailableInterfaces())
            }
            
            guard info.isSpoofed else {
                print("Interface \(interface) is not currently spoofed.")
                print("Current MAC: \(info.currentMAC)")
                return
            }
            
            guard let originalMAC = info.originalMAC else {
                throw PrivarionCLIError.macAddressOriginalNotFound(interface)
            }
            
            // Show operation details
            print("MAC Address Restoration Operation:")
            print("  Interface: \(interface)")
            print("  Current MAC: \(info.currentMAC)")
            print("  Original MAC: \(originalMAC)")
            
            if dryRun {
                print("  *** DRY RUN - No changes will be made ***")
                return
            }
            
            // Confirm operation if interface is active
            if !force && info.isActive {
                print("\nWarning: Interface \(interface) is currently active.")
                print("Network connectivity may be temporarily interrupted.")
                print("Continue? (y/N): ", terminator: "")
                
                let response = readLine()?.lowercased()
                guard response == "y" || response == "yes" else {
                    print("Operation cancelled.")
                    return
                }
            }
            
            // Perform MAC address restoration
            print("\nRestoring original MAC address...")
            
            do {
                try runAsyncTask {
                    try await manager.restoreOriginalMAC(interface: interface)
                }
                
                print("✅ MAC address successfully restored.")
                print("  Interface: \(interface)")
                print("  Restored MAC: \(originalMAC)")
                
            } catch let error as MacSpoofingError {
                throw PrivarionCLIError.macAddressOperationFailed(operation: "restore", error: error)
            } catch {
                throw PrivarionCLIError.systemError(error.localizedDescription)
            }
        }
        
        private func getAvailableInterfaces() throws -> [String] {
            let manager = MacAddressSpoofingManager()
            return try runAsyncTask {
                let interfaces = try await manager.getInterfaceStatus()
                return interfaces.map { $0.name }
            }
        }
    }
}

// MARK: - Restore All MAC Addresses Command

extension MacAddressCommand {
    struct RestoreAllCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "restore-all",
            abstract: "Restore original MAC addresses for all spoofed interfaces",
            discussion: """
            Restores the factory/original MAC addresses for all network interfaces 
            that have been previously spoofed.
            
            This command:
            • Identifies all interfaces with spoofed MAC addresses
            • Restores each interface to its original MAC address
            • Provides progress updates during bulk operations
            • Continues with remaining interfaces if one fails
            
            IMPORTANT NOTES:
            • Requires administrator privileges (sudo)
            • Network connections may be briefly interrupted
            • Only affects interfaces that have been previously spoofed
            • Shows detailed progress and results for each interface
            
            SAFETY FEATURES:
            • Confirms operation before proceeding
            • Provides rollback information for failed operations
            • Maintains operation log for troubleshooting
            """
        )
        
        @Flag(name: .long, help: "Force restoration without confirmation")
        var force = false
        
        @Flag(name: .long, help: "Dry run - show what would be done without making changes")
        var dryRun = false
        
        @Flag(name: .long, help: "Continue with remaining interfaces if one fails")
        var continueOnError = false
        
        func run() throws {
            let manager = MacAddressSpoofingManager()
            
            // Get all spoofed interfaces
            let spoofedInterfaces = try runAsyncTask {
                let interfaces = try await manager.getInterfaceStatus()
                return interfaces.filter { $0.isSpoofed }
            }
            
            if spoofedInterfaces.isEmpty {
                print("No spoofed interfaces found. All interfaces are using their original MAC addresses.")
                return
            }
            
            // Show operation details
            print("MAC Address Bulk Restoration Operation:")
            print("  Spoofed interfaces found: \(spoofedInterfaces.count)")
            print("")
            
            for interface in spoofedInterfaces {
                print("  • \(interface.name): \(interface.currentMAC) → \(interface.originalMAC ?? "N/A")")
            }
            
            if dryRun {
                print("\n  *** DRY RUN - No changes will be made ***")
                return
            }
            
            // Confirm operation
            if !force {
                print("\nThis will restore original MAC addresses for \(spoofedInterfaces.count) interface(s).")
                print("Network connectivity may be temporarily interrupted.")
                print("Continue? (y/N): ", terminator: "")
                
                let response = readLine()?.lowercased()
                guard response == "y" || response == "yes" else {
                    print("Operation cancelled.")
                    return
                }
            }
            
            // Perform bulk restoration
            print("\nRestoring MAC addresses...")
            
            var successCount = 0
            var failureCount = 0
            var failures: [(String, Error)] = []
            
            for interface in spoofedInterfaces {
                print("  Restoring \(interface.name)...", terminator: " ")
                
                do {
                    try runAsyncTask {
                        try await manager.restoreOriginalMAC(interface: interface.name)
                    }
                    print("✅")
                    successCount += 1
                } catch {
                    print("❌")
                    failures.append((interface.name, error))
                    failureCount += 1
                    
                    if !continueOnError {
                        print("\nOperation stopped due to error. Use --continue-on-error to continue with remaining interfaces.")
                        break
                    }
                }
            }
            
            // Show results summary
            print("\nRestoration Summary:")
            print("  ✅ Successful: \(successCount)")
            print("  ❌ Failed: \(failureCount)")
            
            if !failures.isEmpty {
                print("\nFailed Interfaces:")
                for (interfaceName, error) in failures {
                    print("  • \(interfaceName): \(error.localizedDescription)")
                }
                
                if !continueOnError && failureCount > 0 {
                    throw PrivarionCLIError.macAddressBulkOperationFailed(
                        operation: "restore-all",
                        successCount: successCount,
                        failureCount: failureCount
                    )
                }
            }
            
            if successCount > 0 {
                print("\n✅ \(successCount) interface(s) successfully restored to original MAC addresses.")
            }
        }
    }
}

// MARK: - Status Command

extension MacAddressCommand {
    struct StatusCommand: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "status",
            abstract: "Show MAC address spoofing status for interfaces",
            discussion: """
            Displays the current MAC address spoofing status for network interfaces.
            
            Information shown includes:
            • Which interfaces are currently spoofed
            • Current vs original MAC addresses
            • Interface activity status
            • Spoofing session details (when available)
            
            Use --interface to check status for a specific interface only.
            Use --format json for programmatic access to status data.
            """
        )
        
        @Option(name: .long, help: "Check status for specific interface only")
        var interface: String?
        
        @Option(name: .long, help: "Output format: table (default) or json")
        var format: OutputFormat = .table
        
        @Flag(name: .long, help: "Show only spoofed interfaces")
        var spoofedOnly = false
        
        func run() throws {
            let manager = MacAddressSpoofingManager()
            
            do {
                let allInterfaces = try runAsyncTask {
                    try await manager.getInterfaceStatus()
                }
                
                let interfaces: [InterfaceStatus]
                if let specificInterface = interface {
                    interfaces = allInterfaces.filter { $0.name == specificInterface }
                    if interfaces.isEmpty {
                        throw PrivarionCLIError.macAddressInterfaceNotFound(
                            specificInterface,
                            availableInterfaces: allInterfaces.map { $0.name }
                        )
                    }
                } else {
                    interfaces = spoofedOnly ? allInterfaces.filter { $0.isSpoofed } : allInterfaces
                }
                
                if interfaces.isEmpty {
                    if spoofedOnly {
                        print("No spoofed interfaces found.")
                    } else {
                        print("No network interfaces found.")
                    }
                    return
                }
                
                switch format {
                case .table:
                    displayStatusTable(interfaces)
                case .json:
                    displayStatusJSON(interfaces)
                }
                
            } catch let error as MacSpoofingError {
                throw PrivarionCLIError.macAddressOperationFailed(operation: "status", error: error)
            } catch {
                throw PrivarionCLIError.systemError(error.localizedDescription)
            }
        }
        
        private func displayStatusTable(_ interfaces: [InterfaceStatus]) {
            print("\nMAC Address Spoofing Status:")
            print("┌─────────────┬──────────────────────┬──────────────────────┬──────────┬───────────┐")
            print("│ Interface   │ Current MAC          │ Original MAC         │ Status   │ Spoofed   │")
            print("├─────────────┼──────────────────────┼──────────────────────┼──────────┼───────────┤")
            
            for interface in interfaces {
                let name = interface.name.padding(toLength: 11, withPad: " ", startingAt: 0)
                let currentMAC = interface.currentMAC.padding(toLength: 20, withPad: " ", startingAt: 0)
                let originalMAC = (interface.originalMAC ?? "N/A").padding(toLength: 20, withPad: " ", startingAt: 0)
                let status = (interface.isActive ? "Active" : "Inactive").padding(toLength: 8, withPad: " ", startingAt: 0)
                let spoofed = (interface.isSpoofed ? "Yes" : "No").padding(toLength: 9, withPad: " ", startingAt: 0)
                
                print("│ \(name) │ \(currentMAC) │ \(originalMAC) │ \(status) │ \(spoofed) │")
            }
            
            print("└─────────────┴──────────────────────┴──────────────────────┴──────────┴───────────┘")
            
            let totalCount = interfaces.count
            let spoofedCount = interfaces.filter { $0.isSpoofed }.count
            let activeCount = interfaces.filter { $0.isActive }.count
            
            print("\nSummary:")
            print("  Total interfaces: \(totalCount)")
            print("  Currently spoofed: \(spoofedCount)")
            print("  Active interfaces: \(activeCount)")
            
            if spoofedCount > 0 {
                print("\n💡 Use 'privarion mac-address restore <interface>' to restore original MAC addresses.")
                print("💡 Use 'privarion mac-address restore-all' to restore all spoofed interfaces.")
            }
        }
        
        private func displayStatusJSON(_ interfaces: [InterfaceStatus]) {
            let statusData = interfaces.map { interface in
                return [
                    "interface": interface.name,
                    "currentMAC": interface.currentMAC,
                    "originalMAC": interface.originalMAC ?? "N/A",
                    "isActive": interface.isActive,
                    "isSpoofed": interface.isSpoofed,
                    "type": interface.interfaceType.rawValue
                ]
            }
            
            let summary = [
                "totalInterfaces": interfaces.count,
                "spoofedInterfaces": interfaces.filter { $0.isSpoofed }.count,
                "activeInterfaces": interfaces.filter { $0.isActive }.count
            ]
            
            let result = [
                "interfaces": statusData,
                "summary": summary,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ] as [String: Any]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            } catch {
                print("Error encoding status to JSON: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Supporting Types and Utilities

enum OutputFormat: String, ExpressibleByArgument, CaseIterable {
    case table
    case json
    
    static var allValueStrings: [String] {
        return OutputFormat.allCases.map { $0.rawValue }
    }
}

// MARK: - CLI Error Extensions

extension PrivarionCLIError {
    static func macAddressOperationFailed(operation: String, error: MacSpoofingError) -> PrivarionCLIError {
        return .configurationSetFailed(
            key: "mac-address-\(operation)",
            value: "operation",
            underlyingError: error
        )
    }
    
    static func macAddressInterfaceNotFound(_ interface: String, availableInterfaces: [String]) -> PrivarionCLIError {
        return .profileNotFound(interface, availableProfiles: availableInterfaces)
    }
    
    static func macAddressInvalidFormat(_ macAddress: String) -> PrivarionCLIError {
        return .configurationValidationFailed("Invalid MAC address format: \(macAddress). Expected format: XX:XX:XX:XX:XX:XX")
    }
    
    static func macAddressOriginalNotFound(_ interface: String) -> PrivarionCLIError {
        return .configurationValidationFailed("Original MAC address not found for interface: \(interface)")
    }
    
    static func macAddressBulkOperationFailed(operation: String, successCount: Int, failureCount: Int) -> PrivarionCLIError {
        return .configurationValidationFailed("Bulk \(operation) completed with \(successCount) successes and \(failureCount) failures")
    }
    
    static func systemError(_ message: String) -> PrivarionCLIError {
        return .systemStartupFailed(underlyingError: NSError(domain: "PrivarionCLI", code: 1, userInfo: [NSLocalizedDescriptionKey: message]))
    }
}

// MARK: - Async-to-Sync Bridge Utility

/// Utility function to bridge async operations to synchronous CLI context
func runAsyncTask<T>(_ operation: @escaping () async throws -> T) throws -> T {
    var result: Result<T, Error>?
    let semaphore = DispatchSemaphore(value: 0)
    
    Task {
        do {
            let value = try await operation()
            result = .success(value)
        } catch {
            result = .failure(error)
        }
        semaphore.signal()
    }
    
    semaphore.wait()
    
    switch result! {
    case .success(let value):
        return value
    case .failure(let error):
        throw error
    }
}
