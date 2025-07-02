import Foundation

/// Central manager for identity spoofing operations
/// Coordinates hardware and software fingerprint management with secure rollback capabilities
public class IdentitySpoofingManager {
    
    // MARK: - Types
    
    public enum SpoofingError: Error, LocalizedError {
        case adminPrivilegesRequired
        case systemIntegrityProtectionBlocked
        case rollbackDataCorrupted
        case unsupportedOperation
        case networkInterfaceNotFound
        case invalidIdentifierFormat
        
        public var errorDescription: String? {
            switch self {
            case .adminPrivilegesRequired:
                return "Administrative privileges required for identity spoofing operations"
            case .systemIntegrityProtectionBlocked:
                return "System Integrity Protection prevents this operation"
            case .rollbackDataCorrupted:
                return "Rollback data is corrupted or missing"
            case .unsupportedOperation:
                return "Operation not supported on this system"
            case .networkInterfaceNotFound:
                return "Network interface not found"
            case .invalidIdentifierFormat:
                return "Generated identifier has invalid format"
            }
        }
    }
    
    public enum IdentityType: String, CaseIterable {
        case macAddress = "mac_address"
        case hostname = "hostname"
        case serialNumber = "serial_number"
        case diskUUID = "disk_uuid"
        case networkInterface = "network_interface"
        // New identity types for comprehensive spoofing
        case systemVersion = "system_version"
        case kernelVersion = "kernel_version"
        case userID = "user_id"
        case groupID = "group_id"
        case username = "username"
        case homeDirectory = "home_directory"
        case processID = "process_id"
        case parentProcessID = "parent_process_id"
        case architecture = "architecture"
        case volumeUUID = "volume_uuid"
        case bootVolumeUUID = "boot_volume_uuid"
    }
    
    public struct SpoofingOptions {
        let types: Set<IdentityType>
        let profile: String
        let persistent: Bool
        let validateChanges: Bool
        
        public init(types: Set<IdentityType> = Set(IdentityType.allCases),
                   profile: String = "default",
                   persistent: Bool = false,
                   validateChanges: Bool = true) {
            self.types = types
            self.profile = profile
            self.persistent = persistent
            self.validateChanges = validateChanges
        }
    }
    
    // MARK: - Properties
    
    private let systemCommandExecutor: SystemCommandExecutor
    private let hardwareIdentifierEngine: HardwareIdentifierEngine
    private let rollbackManager: RollbackManager
    private let configurationProfileManager: ConfigurationProfileManager
    private let syscallHookManager: SyscallHookManager
    private let logger: PrivarionLogger
    
    // MARK: - Initialization
    
    public init(logger: PrivarionLogger = PrivarionLogger.shared) {
        self.logger = logger
        self.systemCommandExecutor = SystemCommandExecutor(logger: logger)
        self.hardwareIdentifierEngine = HardwareIdentifierEngine()
        self.rollbackManager = RollbackManager(logger: logger)
        self.configurationProfileManager = ConfigurationProfileManager()
        self.syscallHookManager = SyscallHookManager.shared
    }
    
    // MARK: - Public API
    
    /// Spoof system identities based on options
    public func spoofIdentity(options: SpoofingOptions) async throws {
        logger.info("Starting identity spoofing with profile: \(options.profile)")
        
        // Verify administrative privileges
        try await verifyAdministrativePrivileges()
        
        // Load configuration profile
        let profile = try configurationProfileManager.loadProfile(name: options.profile)
        
        // Create rollback point
        let rollbackID = try await rollbackManager.createRollbackPoint(for: options.types)
        
        do {
            // Execute spoofing operations
            try await executeSpoofingOperations(options: options, profile: profile)
            
            // Validate changes if requested
            if options.validateChanges {
                try await validateSpoofingChanges(options: options)
            }
            
            logger.info("Identity spoofing completed successfully")
            
        } catch {
            logger.error("Identity spoofing failed: \(error)")
            
            // Attempt rollback on failure
            do {
                try await rollbackManager.performRollback(rollbackID: rollbackID)
                logger.info("Rollback completed successfully")
            } catch {
                logger.error("Rollback failed: \(error)")
                throw SpoofingError.rollbackDataCorrupted
            }
            
            throw error
        }
    }
    
    /// Restore original identities
    public func restoreIdentity(types: Set<IdentityType>? = nil) async throws {
        logger.info("Starting identity restoration")
        
        let typesToRestore = types ?? Set(IdentityType.allCases)
        try await rollbackManager.restoreOriginalValues(for: typesToRestore)
        
        logger.info("Identity restoration completed")
    }
    
    /// Get current identity status
    public func getIdentityStatus() async throws -> [IdentityType: (current: String, original: String?)] {
        var status: [IdentityType: (current: String, original: String?)] = [:]
        
        for type in IdentityType.allCases {
            let current = try await getCurrentIdentity(type: type)
            let original = try? await rollbackManager.getOriginalValue(for: type)
            status[type] = (current: current, original: original)
        }
        
        return status
    }
    
    // MARK: - Private Methods
    
    private func verifyAdministrativePrivileges() async throws {
        let result = try await systemCommandExecutor.executeCommand("id", arguments: ["-u"])
        guard let output = result.standardOutput,
              let uid = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)),
              uid == 0 else {
            throw SpoofingError.adminPrivilegesRequired
        }
    }
    
    private func executeSpoofingOperations(options: SpoofingOptions, profile: ConfigurationProfile) async throws {
        // Process each identity type based on profile settings
        for type in options.types {
            guard profile.isEnabled(for: type) else {
                logger.info("Skipping \(type.rawValue) - disabled in profile")
                continue
            }
            
            do {
                try await spoofIdentityType(type, profile: profile, persistent: options.persistent)
                logger.info("Successfully spoofed \(type.rawValue)")
            } catch {
                logger.error("Failed to spoof \(type.rawValue): \(error)")
                
                // Continue with other types unless critical failure
                if profile.isCritical(for: type) {
                    throw error
                }
            }
        }
    }
    
    private func spoofIdentityType(_ type: IdentityType, profile: ConfigurationProfile, persistent: Bool) async throws {
        switch type {
        case .macAddress:
            try await spoofMACAddress(profile: profile, persistent: persistent)
        case .hostname:
            try await spoofHostname(profile: profile, persistent: persistent)
        case .serialNumber:
            logger.warning("Serial number spoofing not implemented - may be protected by SIP")
        case .diskUUID:
            try await spoofDiskUUID(profile: profile, persistent: persistent)
        case .networkInterface:
            try await spoofNetworkInterface(profile: profile, persistent: persistent)
        case .systemVersion:
            try await spoofSystemVersion(profile: profile, persistent: persistent)
        case .kernelVersion:
            try await spoofKernelVersion(profile: profile, persistent: persistent)
        case .userID:
            try await spoofUserID(profile: profile, persistent: persistent)
        case .groupID:
            try await spoofGroupID(profile: profile, persistent: persistent)
        case .username:
            try await spoofUsername(profile: profile, persistent: persistent)
        case .homeDirectory:
            try await spoofHomeDirectory(profile: profile, persistent: persistent)
        case .processID:
            try await spoofProcessID(profile: profile, persistent: persistent)
        case .parentProcessID:
            try await spoofParentProcessID(profile: profile, persistent: persistent)
        case .architecture:
            try await spoofArchitecture(profile: profile, persistent: persistent)
        case .volumeUUID:
            try await spoofVolumeUUID(profile: profile, persistent: persistent)
        case .bootVolumeUUID:
            try await spoofBootVolumeUUID(profile: profile, persistent: persistent)
        }
    }
    
    private func spoofMACAddress(profile: ConfigurationProfile, persistent: Bool) async throws {
        let interfaces = try await getNetworkInterfaces()
        
        for interface in interfaces {
            let newMAC = hardwareIdentifierEngine.generateMACAddress(strategy: profile.macStrategy)
            
            // Validate MAC address format
            guard isValidMACAddress(newMAC) else {
                throw SpoofingError.invalidIdentifierFormat
            }
            
            // Apply MAC address change
            let result = try await systemCommandExecutor.executeCommand("ifconfig", arguments: [interface, "ether", newMAC])
            if !result.isSuccess {
                throw SpoofingError.unsupportedOperation
            }
            
            logger.info("Changed MAC address for \(interface) to \(newMAC)")
        }
    }
    
    private func spoofHostname(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newHostname = hardwareIdentifierEngine.generateHostname(strategy: profile.hostnameStrategy)
        
        // Validate hostname format
        guard isValidHostname(newHostname) else {
            throw SpoofingError.invalidIdentifierFormat
        }
        
        // Initialize syscall hook manager if needed
        try syscallHookManager.initialize()
        
        // Create a new configuration with fake hostname data
        var config = SyscallHookConfiguration()
        
        // Update fake hostname
        config.fakeData.hostname = newHostname
        config.fakeData.systemInfo.nodename = newHostname
        
        // Enable gethostname and uname hooks to spoof hostname
        config.hooks.gethostname = true
        config.hooks.uname = true
        
        try syscallHookManager.updateConfiguration(config)
        let installedHooks = try syscallHookManager.installConfiguredHooks()
        
        logger.info("Hostname spoofing configured: \(newHostname) with hooks: \(installedHooks.keys)")
        
        // For persistent hostname changes, also use system command
        if persistent {
            let computerNameResult = try await systemCommandExecutor.executeCommand("scutil", arguments: ["--set", "ComputerName", newHostname])
            let localHostNameResult = try await systemCommandExecutor.executeCommand("scutil", arguments: ["--set", "LocalHostName", newHostname])
            let hostNameResult = try await systemCommandExecutor.executeCommand("scutil", arguments: ["--set", "HostName", newHostname])
            
            if !computerNameResult.isSuccess || !localHostNameResult.isSuccess || !hostNameResult.isSuccess {
                logger.warning("Failed to set persistent hostname, but syscall hooks are active")
            }
        }
    }
    
    private func spoofNetworkInterface(profile: ConfigurationProfile, persistent: Bool) async throws {
        // Additional network interface manipulation beyond MAC address
        // Could include interface renaming, DHCP client ID changes, etc.
        logger.info("Network interface spoofing not yet implemented")
    }
    
    private func spoofSystemVersion(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newSystemVersion = hardwareIdentifierEngine.generateSystemVersion(strategy: .realistic)
        logger.info("Generated system version: \(newSystemVersion)")
        
        // Initialize syscall hook manager if needed
        try syscallHookManager.initialize()
        
        // Create a new configuration with fake system version data
        var config = SyscallHookConfiguration()
        
        // Update fake system info with new version
        config.fakeData.systemInfo.version = "Darwin Kernel Version \(newSystemVersion)"
        config.fakeData.systemInfo.release = newSystemVersion
        
        // Enable uname hook to spoof system version
        config.hooks.uname = true
        
        try syscallHookManager.updateConfiguration(config)
        let installedHooks = try syscallHookManager.installConfiguredHooks()
        
        logger.info("System version spoofing configured with uname hook: \(installedHooks.keys)")
    }
    
    private func spoofKernelVersion(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newKernelVersion = hardwareIdentifierEngine.generateKernelVersion(strategy: .realistic)
        logger.info("Generated kernel version: \(newKernelVersion)")
        
        // Initialize syscall hook manager if needed
        try syscallHookManager.initialize()
        
        // Create a new configuration with fake kernel version data
        var config = SyscallHookConfiguration()
        
        // Update fake system info with new kernel version
        config.fakeData.systemInfo.version = newKernelVersion
        config.fakeData.systemInfo.release = extractReleaseFromKernelVersion(newKernelVersion)
        
        // Enable uname hook to spoof kernel version
        config.hooks.uname = true
        
        try syscallHookManager.updateConfiguration(config)
        let installedHooks = try syscallHookManager.installConfiguredHooks()
        
        logger.info("Kernel version spoofing configured with uname hook: \(installedHooks.keys)")
    }
    
    private func spoofUserID(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newUserID = hardwareIdentifierEngine.generateUserID(strategy: .realistic)
        logger.info("Generated user ID: \(newUserID)")
        
        // Initialize syscall hook manager if needed
        try syscallHookManager.initialize()
        
        // Create a new configuration with fake user ID data
        var config = SyscallHookConfiguration()
        
        // Update fake user ID
        config.fakeData.userId = UInt32(newUserID)
        
        // Enable getuid hook to spoof user ID
        config.hooks.getuid = true
        
        try syscallHookManager.updateConfiguration(config)
        let installedHooks = try syscallHookManager.installConfiguredHooks()
        
        logger.info("User ID spoofing configured with getuid hook: \(installedHooks.keys)")
    }
    
    private func spoofGroupID(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newGroupID = hardwareIdentifierEngine.generateGroupID(strategy: .realistic)
        logger.info("Generated group ID: \(newGroupID)")
        
        // Initialize syscall hook manager if needed
        try syscallHookManager.initialize()
        
        // Create a new configuration with fake group ID data
        var config = SyscallHookConfiguration()
        
        // Update fake group ID
        config.fakeData.groupId = UInt32(newGroupID)
        
        // Enable getgid hook to spoof group ID
        config.hooks.getgid = true
        
        try syscallHookManager.updateConfiguration(config)
        let installedHooks = try syscallHookManager.installConfiguredHooks()
        
        logger.info("Group ID spoofing configured with getgid hook: \(installedHooks.keys)")
    }
    
    private func spoofUsername(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newUsername = hardwareIdentifierEngine.generateUsername(strategy: .realistic)
        logger.info("Generated username: \(newUsername)")
        
        // Note: Username spoofing requires syscall hooking to intercept getpwuid() calls
        logger.warning("Username spoofing requires syscall hooking - planned for future implementation")
    }
    
    private func spoofHomeDirectory(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newHomeDirectory = hardwareIdentifierEngine.generateHomeDirectory(strategy: .realistic)
        logger.info("Generated home directory: \(newHomeDirectory)")
        
        // Note: Home directory spoofing requires syscall hooking and environment manipulation
        logger.warning("Home directory spoofing requires syscall hooking - planned for future implementation")
    }
    
    private func spoofProcessID(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newProcessID = hardwareIdentifierEngine.generateProcessID(strategy: .realistic)
        logger.info("Generated process ID: \(newProcessID)")
        
        // Note: Process ID spoofing requires very advanced syscall hooking
        logger.warning("Process ID spoofing requires advanced syscall hooking - planned for future implementation")
    }
    
    private func spoofParentProcessID(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newParentProcessID = hardwareIdentifierEngine.generateParentProcessID(strategy: .realistic)
        logger.info("Generated parent process ID: \(newParentProcessID)")
        
        // Note: Parent process ID spoofing requires very advanced syscall hooking
        logger.warning("Parent process ID spoofing requires advanced syscall hooking - planned for future implementation")
    }
    
    private func spoofArchitecture(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newArchitecture = hardwareIdentifierEngine.generateArchitecture(strategy: .realistic)
        logger.info("Generated architecture: \(newArchitecture)")
        
        // Initialize syscall hook manager if needed
        try syscallHookManager.initialize()
        
        // Create a new configuration with fake architecture data
        var config = SyscallHookConfiguration()
        
        // Update fake architecture in system info
        config.fakeData.systemInfo.machine = newArchitecture
        
        // Enable uname hook to spoof architecture
        config.hooks.uname = true
        
        try syscallHookManager.updateConfiguration(config)
        let installedHooks = try syscallHookManager.installConfiguredHooks()
        
        logger.info("Architecture spoofing configured: \(newArchitecture) with uname hook: \(installedHooks.keys)")
    }
    
    private func spoofVolumeUUID(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newVolumeUUID = hardwareIdentifierEngine.generateVolumeUUID(strategy: .realistic)
        logger.info("Generated volume UUID: \(newVolumeUUID)")
        
        // Note: Volume UUID spoofing requires low-level disk manipulation or syscall hooking
        logger.warning("Volume UUID spoofing requires advanced techniques - planned for future implementation")
    }
    
    private func spoofBootVolumeUUID(profile: ConfigurationProfile, persistent: Bool) async throws {
        let newBootVolumeUUID = hardwareIdentifierEngine.generateBootVolumeUUID(strategy: .realistic)
        logger.info("Generated boot volume UUID: \(newBootVolumeUUID)")
        
        // Note: Boot volume UUID spoofing requires low-level disk manipulation or syscall hooking
        logger.warning("Boot volume UUID spoofing requires advanced techniques - planned for future implementation")
    }
    
    /// Get available network interfaces 
    /// Internal for testing purposes
    /// Get available network interfaces
    /// Public for CLI access
    public func getNetworkInterfaces() async throws -> [String] {
        let result = try await systemCommandExecutor.executeCommand("ifconfig", arguments: ["-l"])
        guard let output = result.standardOutput else {
            throw SpoofingError.networkInterfaceNotFound
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty && $0 != "lo0" } // Exclude loopback
    }
    
    /// Get current identity value for given type
    /// Public for CLI access
    public func getCurrentIdentity(type: IdentityType) async throws -> String {
        switch type {
        case .macAddress:
            // Get primary interface MAC
            let interfaces = try await getNetworkInterfaces()
            guard let primaryInterface = interfaces.first else {
                throw SpoofingError.networkInterfaceNotFound
            }
            let result = try await systemCommandExecutor.executeCommand("ifconfig", arguments: [primaryInterface])
            // Parse MAC from ifconfig output
            return parseMACFromIfconfig(result.standardOutput ?? "")
            
        case .hostname:
            let result = try await systemCommandExecutor.executeCommand("scutil", arguments: ["--get", "ComputerName"])
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
        case .serialNumber:
            let result = try await systemCommandExecutor.executeCommand("system_profiler", arguments: ["SPHardwareDataType"])
            return parseSerialFromSystemProfiler(result.standardOutput ?? "")
            
        case .diskUUID:
            let result = try await systemCommandExecutor.executeCommand("diskutil", arguments: ["info", "/"])
            return parseUUIDFromDiskutil(result.standardOutput ?? "")
            
        case .networkInterface:
            return try await getNetworkInterfaces().joined(separator: ",")
            
        case .systemVersion:
            let result = try await systemCommandExecutor.executeCommand("sw_vers", arguments: ["-productVersion"])
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
        case .kernelVersion:
            let result = try await systemCommandExecutor.executeCommand("uname", arguments: ["-r"])
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
        case .userID:
            let result = try await systemCommandExecutor.executeCommand("id", arguments: ["-u"])
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
        case .groupID:
            let result = try await systemCommandExecutor.executeCommand("id", arguments: ["-g"])
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
        case .username:
            let result = try await systemCommandExecutor.executeCommand("whoami")
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
        case .homeDirectory:
            let result = try await systemCommandExecutor.executeCommand("echo", arguments: ["$HOME"])
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
        case .processID:
            let result = try await systemCommandExecutor.executeCommand("echo", arguments: ["$$"])
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
        case .parentProcessID:
            let result = try await systemCommandExecutor.executeCommand("ps", arguments: ["-o", "ppid=", "-p", "\(getpid())"])
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
        case .architecture:
            let result = try await systemCommandExecutor.executeCommand("uname", arguments: ["-m"])
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
        case .volumeUUID:
            let result = try await systemCommandExecutor.executeCommand("diskutil", arguments: ["info", "/"])
            return parseUUIDFromDiskutil(result.standardOutput ?? "")
            
        case .bootVolumeUUID:
            // Assuming boot volume is the first mounted volume
            let result = try await systemCommandExecutor.executeCommand("diskutil", arguments: ["list", "internal", "-plist"])
            return parseBootVolumeUUIDFromDiskutil(result.standardOutput ?? "")
        }
    }
    
    private func validateSpoofingChanges(options: SpoofingOptions) async throws {
        logger.info("Validating spoofing changes")
        
        for type in options.types {
            do {
                let current = try await getCurrentIdentity(type: type)
                logger.info("Current \(type.rawValue): \(current)")
            } catch {
                logger.warning("Failed to validate \(type.rawValue): \(error)")
            }
        }
    }
    
    // MARK: - Validation Helpers
    
    private func isValidMACAddress(_ mac: String) -> Bool {
        let macRegex = #"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"#
        return mac.range(of: macRegex, options: .regularExpression) != nil
    }
    
    private func isValidHostname(_ hostname: String) -> Bool {
        let hostnameRegex = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$"#
        return hostname.range(of: hostnameRegex, options: .regularExpression) != nil
    }
    
    // MARK: - Parsing Helpers
    
    private func parseMACFromIfconfig(_ output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("ether") {
                let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                if let etherIndex = components.firstIndex(of: "ether"),
                   etherIndex + 1 < components.count {
                    return components[etherIndex + 1]
                }
            }
        }
        return ""
    }
    
    private func parseSerialFromSystemProfiler(_ output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Serial Number") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }
    
    private func parseUUIDFromDiskutil(_ output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Volume UUID") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }
    
    private func parseBootVolumeUUIDFromDiskutil(_ output: String) -> String {
        // Assuming the first internal disk is the boot disk
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("UUID") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }
    
    private func spoofDiskUUID(profile: ConfigurationProfile, persistent: Bool) async throws {
        // Disk UUID spoofing logic - requires advanced techniques and may be SIP protected
        logger.warning("Disk UUID spoofing requires advanced techniques and may be blocked by SIP")
        
        // For now, we'll log that this functionality needs to be implemented with syscall hooks
        logger.info("Disk UUID spoofing will be implemented via syscall hooks in future versions")
    }
    
    // MARK: - Helper Methods
    
    /// Extract release version from kernel version string
    /// Example: "Darwin Kernel Version 21.6.0" -> "21.6.0"
    private func extractReleaseFromKernelVersion(_ kernelVersion: String) -> String {
        let components = kernelVersion.components(separatedBy: " ")
        for (index, component) in components.enumerated() {
            if component.lowercased() == "version" && index + 1 < components.count {
                return components[index + 1]
            }
        }
        // Fallback: try to extract version pattern
        let versionPattern = "[0-9]+\\.[0-9]+\\.[0-9]+"
        if let regex = try? NSRegularExpression(pattern: versionPattern),
           let match = regex.firstMatch(in: kernelVersion, range: NSRange(kernelVersion.startIndex..., in: kernelVersion)) {
            return String(kernelVersion[Range(match.range, in: kernelVersion)!])
        }
        return "21.6.0" // Default fallback
    }
    
    /// Configure comprehensive identity spoofing with multiple types
    /// This method sets up syscall hooks for multiple identity types efficiently
    private func configureComprehensiveSpoofing(identities: [IdentityType: String], profile: ConfigurationProfile) async throws {
        logger.info("Configuring comprehensive identity spoofing for \(identities.count) identity types")
        
        // Initialize syscall hook manager if needed
        try syscallHookManager.initialize()
        
        // Create a comprehensive configuration
        var config = SyscallHookConfiguration()
        
        // Configure based on provided identities
        for (type, value) in identities {
            switch type {
            case .hostname:
                config.fakeData.hostname = value
                config.fakeData.systemInfo.nodename = value
                config.hooks.gethostname = true
                config.hooks.uname = true
                
            case .systemVersion, .kernelVersion:
                config.fakeData.systemInfo.version = value
                config.fakeData.systemInfo.release = extractReleaseFromKernelVersion(value)
                config.hooks.uname = true
                
            case .architecture:
                config.fakeData.systemInfo.machine = value
                config.hooks.uname = true
                
            case .userID:
                if let uid = UInt32(value) {
                    config.fakeData.userId = uid
                    config.hooks.getuid = true
                }
                
            case .groupID:
                if let gid = UInt32(value) {
                    config.fakeData.groupId = gid
                    config.hooks.getgid = true
                }
                
            case .username:
                config.fakeData.username = value
                // Note: Username spoofing requires additional hooks not yet implemented
                
            default:
                logger.warning("Identity type \(type.rawValue) not yet supported by syscall hooks")
            }
        }
        
        try syscallHookManager.updateConfiguration(config)
        let installedHooks = try syscallHookManager.installConfiguredHooks()
        
        logger.info("Comprehensive identity spoofing configured with hooks: \(installedHooks.keys)")
    }
}
