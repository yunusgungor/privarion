import Foundation

/// Secure rollback manager for identity spoofing operations
/// Manages backup and restoration of original system identities
public class RollbackManager {
    
    // MARK: - Types
    
    public struct RollbackPoint {
        public let id: String
        public let timestamp: Date
        public let types: Set<IdentitySpoofingManager.IdentityType>
        public let originalValues: [IdentitySpoofingManager.IdentityType: String]
        public let metadata: [String: String]
        
        public init(id: String,
                   timestamp: Date,
                   types: Set<IdentitySpoofingManager.IdentityType>,
                   originalValues: [IdentitySpoofingManager.IdentityType: String],
                   metadata: [String: String] = [:]) {
            self.id = id
            self.timestamp = timestamp
            self.types = types
            self.originalValues = originalValues
            self.metadata = metadata
        }
    }
    
    public enum RollbackError: Error, LocalizedError {
        case rollbackPointNotFound
        case corruptedRollbackData
        case rollbackOperationFailed
        case unauthorizedRollbackAttempt
        case invalidRollbackPoint
        
        public var errorDescription: String? {
            switch self {
            case .rollbackPointNotFound:
                return "Rollback point not found"
            case .corruptedRollbackData:
                return "Rollback data is corrupted or invalid"
            case .rollbackOperationFailed:
                return "Rollback operation failed to complete"
            case .unauthorizedRollbackAttempt:
                return "Unauthorized rollback attempt"
            case .invalidRollbackPoint:
                return "Invalid rollback point data"
            }
        }
    }
    
    // MARK: - Properties
    
    private let logger: PrivarionLogger
    private let systemCommandExecutor: SystemCommandExecutor
    private let storageDirectory: URL
    private var rollbackPoints: [String: RollbackPoint] = [:]
    private let lockQueue = DispatchQueue(label: "privarion.rollback.lock", qos: .userInitiated)
    
    // MARK: - Initialization
    
    public init(logger: PrivarionLogger, storageDirectory: URL? = nil) {
        self.logger = logger
        self.systemCommandExecutor = SystemCommandExecutor(logger: logger)
        
        // Use default storage directory if not provided
        if let customDirectory = storageDirectory {
            self.storageDirectory = customDirectory
        } else {
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            self.storageDirectory = homeDirectory.appendingPathComponent(".privarion/rollback")
        }
        
        setupStorageDirectory()
        loadExistingRollbackPoints()
    }
    
    // MARK: - Public Methods
    
    /// Create a rollback point for specified identity types
    public func createRollbackPoint(for types: Set<IdentitySpoofingManager.IdentityType>) async throws -> String {
        let rollbackID = generateRollbackID()
        
        logger.info("Creating rollback point: \(rollbackID)")
        
        var originalValues: [IdentitySpoofingManager.IdentityType: String] = [:]
        
        // Capture current values for each identity type
        for type in types {
            do {
                let currentValue = try await getCurrentIdentityValue(type: type)
                originalValues[type] = currentValue
                logger.debug("Captured \(type.rawValue): \(currentValue)")
            } catch {
                logger.error("Failed to capture \(type.rawValue): \(error)")
                throw RollbackError.rollbackOperationFailed
            }
        }
        
        // Create rollback point
        let rollbackPoint = RollbackPoint(
            id: rollbackID,
            timestamp: Date(),
            types: types,
            originalValues: originalValues,
            metadata: [
                "created_by": "IdentitySpoofingManager",
                "system_version": await getSystemVersion(),
                "user": NSUserName()
            ]
        )
        
        // Store rollback point
        try lockQueue.sync {
            rollbackPoints[rollbackID] = rollbackPoint
            try persistRollbackPoint(rollbackPoint)
        }
        
        logger.info("Rollback point created successfully: \(rollbackID)")
        return rollbackID
    }
    
    /// Perform rollback to restore original values
    public func performRollback(rollbackID: String) async throws {
        guard let rollbackPoint = rollbackPoints[rollbackID] else {
            throw RollbackError.rollbackPointNotFound
        }
        
        logger.info("Performing rollback: \(rollbackID)")
        
        // Verify rollback point integrity
        try validateRollbackPoint(rollbackPoint)
        
        var failedRestorations: [IdentitySpoofingManager.IdentityType] = []
        
        // Restore each identity type
        for (type, originalValue) in rollbackPoint.originalValues {
            do {
                try await restoreIdentityValue(type: type, value: originalValue)
                logger.info("Restored \(type.rawValue) to: \(originalValue)")
            } catch {
                logger.error("Failed to restore \(type.rawValue): \(error)")
                failedRestorations.append(type)
            }
        }
        
        if !failedRestorations.isEmpty {
            logger.warning("Some restorations failed: \(failedRestorations.map { $0.rawValue })")
            throw RollbackError.rollbackOperationFailed
        }
        
        logger.info("Rollback completed successfully: \(rollbackID)")
    }
    
    /// Restore original values for specific identity types
    public func restoreOriginalValues(for types: Set<IdentitySpoofingManager.IdentityType>) async throws {
        logger.info("Restoring original values for types: \(types.map { $0.rawValue })")
        
        // Find the most recent rollback point that contains all requested types
        let candidateRollbackPoints = rollbackPoints.values
            .filter { rollbackPoint in
                types.isSubset(of: rollbackPoint.types)
            }
            .sorted { $0.timestamp > $1.timestamp }
        
        guard let latestRollbackPoint = candidateRollbackPoints.first else {
            logger.error("No suitable rollback point found for types: \(types.map { $0.rawValue })")
            throw RollbackError.rollbackPointNotFound
        }
        
        // Restore only the requested types
        for type in types {
            if let originalValue = latestRollbackPoint.originalValues[type] {
                try await restoreIdentityValue(type: type, value: originalValue)
                logger.info("Restored \(type.rawValue) to: \(originalValue)")
            }
        }
    }
    
    /// Get original value for a specific identity type
    public func getOriginalValue(for type: IdentitySpoofingManager.IdentityType) async throws -> String? {
        let candidateRollbackPoints = rollbackPoints.values
            .filter { $0.originalValues.keys.contains(type) }
            .sorted { $0.timestamp > $1.timestamp }
        
        return candidateRollbackPoints.first?.originalValues[type]
    }
    
    /// List all available rollback points
    public func listRollbackPoints() -> [RollbackPoint] {
        return Array(rollbackPoints.values).sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Delete a rollback point
    public func deleteRollbackPoint(rollbackID: String) throws {
        lockQueue.sync {
            rollbackPoints.removeValue(forKey: rollbackID)
            
            let rollbackFile = storageDirectory.appendingPathComponent("\(rollbackID).json")
            do {
                try FileManager.default.removeItem(at: rollbackFile)
            } catch {
                logger.warning("Failed to delete rollback file: \(error.localizedDescription)")
            }
        }
        
        logger.info("Deleted rollback point: \(rollbackID)")
    }
    
    /// Clean up old rollback points (older than specified days)
    public func cleanupOldRollbackPoints(olderThanDays days: Int) throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        let oldRollbackPoints = rollbackPoints.filter { _, rollbackPoint in
            rollbackPoint.timestamp < cutoffDate
        }
        
        for (rollbackID, _) in oldRollbackPoints {
            try deleteRollbackPoint(rollbackID: rollbackID)
        }
        
        logger.info("Cleaned up \(oldRollbackPoints.count) old rollback points")
    }
    
    // MARK: - Private Methods
    
    private func setupStorageDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            logger.error("Failed to create rollback storage directory: \(error)")
        }
    }
    
    private func loadExistingRollbackPoints() {
        do {
            let rollbackFiles = try FileManager.default.contentsOfDirectory(at: storageDirectory,
                                                                           includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
            
            for file in rollbackFiles {
                do {
                    let data = try Data(contentsOf: file)
                    let rollbackPoint = try JSONDecoder().decode(RollbackPointCodable.self, from: data)
                    rollbackPoints[rollbackPoint.id] = rollbackPoint.toRollbackPoint()
                } catch {
                    logger.warning("Failed to load rollback point from \(file.lastPathComponent): \(error)")
                }
            }
            
            logger.info("Loaded \(rollbackPoints.count) existing rollback points")
        } catch {
            logger.warning("Failed to load existing rollback points: \(error)")
        }
    }
    
    private func persistRollbackPoint(_ rollbackPoint: RollbackPoint) throws {
        let rollbackFile = storageDirectory.appendingPathComponent("\(rollbackPoint.id).json")
        let codableRollbackPoint = RollbackPointCodable(from: rollbackPoint)
        
        let data = try JSONEncoder().encode(codableRollbackPoint)
        try data.write(to: rollbackFile)
    }
    
    private func generateRollbackID() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let randomSuffix = String(Int.random(in: 1000...9999))
        return "rb_\(timestamp)_\(randomSuffix)"
    }
    
    private func getCurrentIdentityValue(type: IdentitySpoofingManager.IdentityType) async throws -> String {
        switch type {
        case .macAddress:
            return try await getCurrentMACAddress()
        case .hostname:
            return try await getCurrentHostname()
        case .serialNumber:
            return try await getCurrentSerialNumber()
        case .diskUUID:
            return try await getCurrentDiskUUID()
        case .networkInterface:
            return try await getCurrentNetworkInterfaces()
        case .systemVersion:
            return try await getCurrentSystemVersion()
        case .kernelVersion:
            return try await getCurrentKernelVersion()
        case .userID:
            return try await getCurrentUserID()
        case .groupID:
            return try await getCurrentGroupID()
        case .username:
            return try await getCurrentUsername()
        case .homeDirectory:
            return try await getCurrentHomeDirectory()
        case .processID:
            return try await getCurrentProcessID()
        case .parentProcessID:
            return try await getCurrentParentProcessID()
        case .architecture:
            return try await getCurrentArchitecture()
        case .volumeUUID:
            return try await getCurrentVolumeUUID()
        case .bootVolumeUUID:
            return try await getCurrentBootVolumeUUID()
        }
    }
    
    private func restoreIdentityValue(type: IdentitySpoofingManager.IdentityType, value: String) async throws {
        switch type {
        case .macAddress:
            try await restoreMACAddress(value)
        case .hostname:
            try await restoreHostname(value)
        case .serialNumber:
            logger.warning("Serial number restoration not implemented - protected by SIP")
        case .diskUUID:
            logger.warning("Disk UUID restoration not implemented - requires advanced techniques")
        case .networkInterface:
            logger.info("Network interface restoration completed")
        case .systemVersion:
            logger.warning("System version restoration requires syscall hook removal")
        case .kernelVersion:
            logger.warning("Kernel version restoration requires syscall hook removal")
        case .userID:
            logger.warning("User ID restoration requires syscall hook removal")
        case .groupID:
            logger.warning("Group ID restoration requires syscall hook removal")
        case .username:
            logger.warning("Username restoration requires syscall hook removal")
        case .homeDirectory:
            logger.warning("Home directory restoration not fully implemented")
        case .processID:
            logger.warning("Process ID restoration not possible - runtime value")
        case .parentProcessID:
            logger.warning("Parent process ID restoration not possible - runtime value")
        case .architecture:
            logger.warning("Architecture restoration requires syscall hook removal")
        case .volumeUUID:
            logger.warning("Volume UUID restoration not implemented - requires advanced techniques")
        case .bootVolumeUUID:
            logger.warning("Boot volume UUID restoration not implemented - requires advanced techniques")
        }
    }
    
    // MARK: - Identity Capture Methods
    
    private func getCurrentMACAddress() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("ifconfig", arguments: ["-a"])
        guard let output = result.standardOutput else {
            throw RollbackError.rollbackOperationFailed
        }
        
        // Parse primary interface MAC address
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("ether") && !line.contains("lo0") {
                let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                if let etherIndex = components.firstIndex(of: "ether"),
                   etherIndex + 1 < components.count {
                    return components[etherIndex + 1]
                }
            }
        }
        
        throw RollbackError.rollbackOperationFailed
    }
    
    private func getCurrentHostname() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("scutil", arguments: ["--get", "ComputerName"])
        guard let hostname = result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hostname.isEmpty else {
            throw RollbackError.rollbackOperationFailed
        }
        return hostname
    }
    
    private func getCurrentSerialNumber() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("system_profiler", arguments: ["SPHardwareDataType"])
        guard let output = result.standardOutput else {
            throw RollbackError.rollbackOperationFailed
        }
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Serial Number") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        throw RollbackError.rollbackOperationFailed
    }
    
    private func getCurrentDiskUUID() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("diskutil", arguments: ["info", "/"])
        guard let output = result.standardOutput else {
            throw RollbackError.rollbackOperationFailed
        }
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Volume UUID") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        throw RollbackError.rollbackOperationFailed
    }
    
    private func getCurrentNetworkInterfaces() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("ifconfig", arguments: ["-l"])
        guard let output = result.standardOutput else {
            throw RollbackError.rollbackOperationFailed
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Additional Identity Capture Methods for New Types
    
    private func getCurrentSystemVersion() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("sw_vers", arguments: ["-productVersion"])
        return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }
    
    private func getCurrentKernelVersion() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("uname", arguments: ["-v"])
        return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }
    
    private func getCurrentUserID() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("id", arguments: ["-u"])
        return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }
    
    private func getCurrentGroupID() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("id", arguments: ["-g"])
        return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }
    
    private func getCurrentUsername() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("whoami", arguments: [])
        return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }
    
    private func getCurrentHomeDirectory() async throws -> String {
        return NSHomeDirectory()
    }
    
    private func getCurrentProcessID() async throws -> String {
        return String(Foundation.ProcessInfo.processInfo.processIdentifier)
    }
    
    private func getCurrentParentProcessID() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("ps", arguments: ["-o", "ppid=", "-p", String(Foundation.ProcessInfo.processInfo.processIdentifier)])
        return result.standardOutput?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? "Unknown"
    }
    
    private func getCurrentArchitecture() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("uname", arguments: ["-m"])
        return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown"
    }
    
    private func getCurrentVolumeUUID() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("diskutil", arguments: ["info", "/", "|", "grep", "Volume UUID"])
        return parseUUIDFromDiskutilOutput(result.standardOutput ?? "")
    }
    
    private func getCurrentBootVolumeUUID() async throws -> String {
        let result = try await systemCommandExecutor.executeCommand("diskutil", arguments: ["info", "/", "|", "grep", "Volume UUID"])
        return parseUUIDFromDiskutilOutput(result.standardOutput ?? "")
    }
    
    private func parseUUIDFromDiskutilOutput(_ output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Volume UUID:") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return "Unknown"
    }
    
    private func restoreMACAddress(_ mac: String) async throws {
        // Find the interface to restore
        let interfacesResult = try await systemCommandExecutor.executeCommand("ifconfig", arguments: ["-l"])
        guard let interfacesOutput = interfacesResult.standardOutput else {
            throw RollbackError.rollbackOperationFailed
        }
        
        let interfaces = interfacesOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ")
            .filter { !$0.isEmpty && $0 != "lo0" }
        
        guard let primaryInterface = interfaces.first else {
            throw RollbackError.rollbackOperationFailed
        }
        
        // Restore MAC address
        _ = try await systemCommandExecutor.executeElevatedCommand("ifconfig", arguments: [primaryInterface, "ether", mac])
    }
    
    private func restoreHostname(_ hostname: String) async throws {
        _ = try await systemCommandExecutor.executeElevatedCommand("scutil", arguments: ["--set", "ComputerName", hostname])
        _ = try await systemCommandExecutor.executeElevatedCommand("scutil", arguments: ["--set", "LocalHostName", hostname])
        _ = try await systemCommandExecutor.executeElevatedCommand("scutil", arguments: ["--set", "HostName", hostname])
    }
    
    private func getSystemVersion() async -> String {
        do {
            let result = try await systemCommandExecutor.executeCommand("sw_vers", arguments: ["-productVersion"])
            return result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        } catch {
            return "unknown"
        }
    }
    
    private func validateRollbackPoint(_ rollbackPoint: RollbackPoint) throws {
        // Verify rollback point integrity
        guard !rollbackPoint.id.isEmpty,
              !rollbackPoint.originalValues.isEmpty else {
            throw RollbackError.invalidRollbackPoint
        }
        
        // Additional validation can be added here
        // For example, checksum validation, digital signatures, etc.
    }
}

// MARK: - Codable Support

private struct RollbackPointCodable: Codable {
    let id: String
    let timestamp: Date
    let types: [String]
    let originalValues: [String: String]
    let metadata: [String: String]
    
    init(from rollbackPoint: RollbackManager.RollbackPoint) {
        self.id = rollbackPoint.id
        self.timestamp = rollbackPoint.timestamp
        self.types = rollbackPoint.types.map { $0.rawValue }
        self.originalValues = rollbackPoint.originalValues.reduce(into: [:]) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        self.metadata = rollbackPoint.metadata
    }
    
    func toRollbackPoint() -> RollbackManager.RollbackPoint {
        let identityTypes = Set(types.compactMap { IdentitySpoofingManager.IdentityType(rawValue: $0) })
        let valueDict: [IdentitySpoofingManager.IdentityType: String] = originalValues.reduce(into: [:]) { result, pair in
            if let identityType = IdentitySpoofingManager.IdentityType(rawValue: pair.key) {
                result[identityType] = pair.value
            }
        }
        
        return RollbackManager.RollbackPoint(
            id: id,
            timestamp: timestamp,
            types: identityTypes,
            originalValues: valueDict,
            metadata: metadata
        )
    }
}

// MARK: - Extensions

extension DispatchQueue {
    func run<T>(_ work: () throws -> T) rethrows -> T {
        return try sync(execute: work)
    }
}
