import Foundation
import CryptoKit

/// Repository for managing MAC address backup and recovery data
/// Provides secure storage and integrity validation for original MAC addresses
public class MacAddressRepository: @unchecked Sendable {
    
    // MARK: - Types
    
    public struct BackupEntry: Codable {
        let interface: String
        let originalMAC: String
        let timestamp: Int64  // Unix timestamp in milliseconds for precision
        let checksum: String
        var currentMAC: String?
        
        init(interface: String, originalMAC: String, timestamp: Int64? = nil) {
            self.interface = interface
            self.originalMAC = originalMAC
            self.timestamp = timestamp ?? Int64(Date().timeIntervalSince1970 * 1000)
            self.checksum = Self.calculateChecksum(interface: interface, mac: originalMAC, timestamp: self.timestamp)
            self.currentMAC = nil
        }
        
        var isValid: Bool {
            return checksum == Self.calculateChecksum(interface: interface, mac: originalMAC, timestamp: timestamp)
        }
        
        private static func calculateChecksum(interface: String, mac: String, timestamp: Int64) -> String {
            guard let data = "\(interface):\(mac):\(timestamp)".data(using: .utf8) else {
                return ""
            }
            let hash = SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        }
        
        // Convenience property to get Date from timestamp
        var date: Date {
            return Date(timeIntervalSince1970: Double(timestamp) / 1000.0)
        }
    }
    
    private struct RepositoryData: Codable {
        var entries: [String: BackupEntry]
        let version: String
        let created: Date
        var lastModified: Date
        
        init() {
            self.entries = [:]
            self.version = "1.0"
            self.created = Date()
            self.lastModified = Date()
        }
        
        mutating func updateModified() {
            self.lastModified = Date()
        }
    }
    
    // MARK: - Properties
    
    private let logger: PrivarionLogger
    private let configurationManager: ConfigurationManager
    private var repositoryData: RepositoryData
    private let queue = DispatchQueue(label: "com.privarion.mac-repository", qos: .userInitiated)
    
    // Storage URLs - can be customized for testing
    private let customStorageURL: URL?
    private let customBackupURL: URL?
    
    // File paths
    private var backupFilePath: URL {
        if let customURL = customStorageURL {
            return customURL
        }
        guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get application support directory")
            return URL(fileURLWithPath: "/tmp/privarion_mac_backup.json")
        }
        let privarionDir = appSupportDir.appendingPathComponent("Privarion")
        return privarionDir.appendingPathComponent("mac_backup.json")
    }
    
    private var legacyBackupFilePath: URL {
        if let customURL = customBackupURL {
            return customURL
        }
        guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("Failed to get application support directory")
            return URL(fileURLWithPath: "/tmp/privarion_mac_backup_legacy.json")
        }
        let privarionDir = appSupportDir.appendingPathComponent("Privarion")
        return privarionDir.appendingPathComponent("mac_backup_legacy.json")
    }
    
    // MARK: - Initialization
    
    public init(logger: PrivarionLogger? = nil, configurationManager: ConfigurationManager? = nil) {
        self.logger = logger ?? PrivarionLogger.shared
        self.configurationManager = configurationManager ?? ConfigurationManager.shared
        self.repositoryData = RepositoryData()
        self.customStorageURL = nil
        self.customBackupURL = nil
        
        setupDirectory()
        loadRepositoryData()
        performIntegrityCheck()
    }
    
    /// Initialize repository with custom storage URL (for testing)
    public init(storageURL: URL, logger: PrivarionLogger? = nil, configurationManager: ConfigurationManager? = nil) throws {
        // Use provided instances or create default ones
        self.logger = logger ?? PrivarionLogger.shared
        self.configurationManager = configurationManager ?? ConfigurationManager.shared
        self.repositoryData = RepositoryData()
        self.customStorageURL = storageURL
        self.customBackupURL = storageURL.appendingPathExtension("backup")
        
        // Create parent directory if needed
        let parentDirectory = storageURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
        
        loadRepositoryData()
        performIntegrityCheck()
    }
    
    // MARK: - Public Interface
    
    /// Backs up the original MAC address for an interface (synchronous)
    public func backupOriginalMACSync(interface: String, macAddress: String) throws {
        try queue.sync {
            logger.info("Backing up original MAC address for interface \(interface)")
            
            // Validate interface and MAC address format
            try validateInterface(interface)
            try validateMACAddress(macAddress)
            
            // Check if already backed up
            if repositoryData.entries[interface] != nil {
                logger.warning("MAC address for interface \(interface) is already backed up")
                throw RepositoryError.interfaceAlreadyBackedUp(interface)
            }
            
            // Create backup entry
            let entry = BackupEntry(interface: interface, originalMAC: macAddress)
            repositoryData.entries[interface] = entry
            repositoryData.updateModified()
            
            // Save to disk
            try saveRepositoryData()
            
            logger.info("Successfully backed up MAC address for interface \(interface)")
        }
    }
    
    /// Gets the original MAC address for an interface
    public func getOriginalMAC(for interface: String) -> String? {
        return queue.sync {
            guard let entry = repositoryData.entries[interface] else {
                return nil
            }
            
            // Validate entry integrity
            guard entry.isValid else {
                logger.error("Backup entry for interface \(interface) failed integrity check")
                return nil
            }
            
            return entry.originalMAC
        }
    }
    
    /// Checks if an interface is currently spoofed (has a backup)
    public func isSpoofed(interface: String) -> Bool {
        return queue.sync {
            return repositoryData.entries[interface] != nil
        }
    }
    
    /// Gets all interfaces that are currently spoofed
    public func getSpoofedInterfaces() -> [String] {
        return queue.sync {
            return Array(repositoryData.entries.keys)
        }
    }
    
    /// Marks an interface as successfully spoofed
    public func markAsSpoofed(interface: String, originalMAC: String) throws {
        try queue.sync {
            // This is mainly for validation - the backup should already exist
            guard let entry = repositoryData.entries[interface] else {
                throw RepositoryError.interfaceNotBackedUp(interface)
            }
            
            // Validate that the original MAC matches
            guard entry.originalMAC.lowercased() == originalMAC.lowercased() else {
                logger.error("Original MAC mismatch for interface \(interface)")
                throw RepositoryError.macAddressMismatch(interface, expected: entry.originalMAC, actual: originalMAC)
            }
            
            // Entry is already marked as spoofed by its existence
            logger.debug("Interface \(interface) confirmed as spoofed")
        }
    }
    
    /// Removes the backup for an interface (when restored)
    public func removeBackup(interface: String) throws {
        try queue.sync {
            logger.info("Removing backup for interface \(interface)")
            
            guard repositoryData.entries[interface] != nil else {
                logger.warning("No backup found for interface \(interface)")
                throw RepositoryError.interfaceNotBackedUp(interface)
            }
            
            repositoryData.entries.removeValue(forKey: interface)
            repositoryData.updateModified()
            
            try saveRepositoryData()
            
            logger.info("Successfully removed backup for interface \(interface)")
        }
    }
    
    /// Gets repository statistics
    public func getStatistics() -> RepositoryStatistics {
        return queue.sync {
            return RepositoryStatistics(
                totalBackups: repositoryData.entries.count,
                created: repositoryData.created,
                lastModified: repositoryData.lastModified,
                version: repositoryData.version,
                integrityStatus: validateAllEntries()
            )
        }
    }
    
    /// Performs a full integrity check and cleanup
    public func performIntegrityCheck() {
        queue.sync {
            logger.debug("Performing repository integrity check")
            
            var corruptedEntries: [String] = []
            
            for (interface, entry) in repositoryData.entries {
                if !entry.isValid {
                    logger.error("Corrupted backup entry found for interface \(interface)")
                    corruptedEntries.append(interface)
                }
            }
            
            // Remove corrupted entries
            for interface in corruptedEntries {
                repositoryData.entries.removeValue(forKey: interface)
                logger.warning("Removed corrupted backup entry for interface \(interface)")
            }
            
            if !corruptedEntries.isEmpty {
                repositoryData.updateModified()
                do {
                    try saveRepositoryData()
                } catch {
                    logger.error("Failed to save repository after corruption cleanup: \(error)")
                }
            }
            
            logger.debug("Integrity check completed. Removed \(corruptedEntries.count) corrupted entries")
        }
    }
    
    /// Emergency backup export for disaster recovery
    public func exportBackup() throws -> Data {
        return try queue.sync {
            logger.info("Exporting repository backup")
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            
            return try encoder.encode(repositoryData)
        }
    }
    
    /// Emergency backup import for disaster recovery
    public func importBackup(data: Data, merge: Bool = false) throws {
        try queue.sync {
            logger.info("Importing repository backup (merge: \(merge))")
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let importedData = try decoder.decode(RepositoryData.self, from: data)
            
            // Validate all imported entries
            for (interface, entry) in importedData.entries {
                guard entry.isValid else {
                    throw RepositoryError.corruptedBackupData(interface)
                }
            }
            
            if merge {
                // Merge with existing data
                for (interface, entry) in importedData.entries {
                    if repositoryData.entries[interface] == nil {
                        repositoryData.entries[interface] = entry
                    } else {
                        logger.warning("Skipping import of interface \(interface) - already exists")
                    }
                }
            } else {
                // Replace existing data
                repositoryData = importedData
            }
            
            repositoryData.updateModified()
            try saveRepositoryData()
            
            logger.info("Successfully imported repository backup")
        }
    }
    
    // MARK: - Async/Await Interface (Phase 2b)
    
    /// Async version of backupOriginalMAC for compatibility with modern Swift concurrency
    public func backupOriginalMAC(interface: String, macAddress: String) async throws {
        return try await Task.detached { [weak self] in
            guard let self = self else {
                throw RepositoryError.interfaceNotBackedUp("Repository deallocated")
            }
            try self.backupOriginalMACSync(interface: interface, macAddress: macAddress)
        }.value
    }
    
    /// Async version of getOriginalMAC
    public func getOriginalMAC(interface: String) async throws -> String? {
        return await Task.detached { [weak self] in
            guard let self = self else {
                return nil
            }
            return self.getOriginalMAC(for: interface)
        }.value
    }
    
    /// Restore original MAC address and remove backup (async)
    public func restoreOriginalMAC(interface: String) async throws -> String? {
        return try await Task.detached { [weak self] in
            guard let self = self else {
                throw RepositoryError.interfaceNotBackedUp("Repository deallocated")
            }
            return try self.syncRestoreOriginalMAC(interface: interface)
        }.value
    }
    
    /// Get all current backups (async)
    public func getAllBackups() async throws -> [String: BackupEntry] {
        return await Task.detached { [weak self] in
            guard let self = self else {
                return [:]
            }
            return self.repositoryData.entries
        }.value
    }
    
    /// Clear backup for specific interface (async)
    public func clearBackup(interface: String) async throws {
        return try await Task.detached { [weak self] in
            guard let self = self else {
                throw RepositoryError.interfaceNotBackedUp("Repository deallocated")
            }
            try self.syncClearBackup(interface: interface)
        }.value
    }
    
    /// Check if backup exists for interface (async)
    public func hasBackup(interface: String) async throws -> Bool {
        return await Task.detached { [weak self] in
            guard let self = self else {
                return false
            }
            return self.isSpoofed(interface: interface)
        }.value
    }
    
    /// Updates the current MAC address for an interface (async)
    public func updateCurrentMAC(interface: String, macAddress: String) async throws {
        try await Task {
            try queue.sync {
                logger.info("Updating current MAC address for interface \(interface)")
                
                // Validate interface and MAC address format
                try validateInterface(interface)
                try validateMACAddress(macAddress)
                
                // Check if interface has backup
                guard var entry = repositoryData.entries[interface] else {
                    logger.error("No backup found for interface \(interface)")
                    throw RepositoryError.interfaceNotBackedUp(interface)
                }
                
                // Update current MAC
                entry.currentMAC = macAddress
                repositoryData.entries[interface] = entry
                repositoryData.updateModified()
                
                // Save to disk
                try saveRepositoryData()
                
                logger.info("Successfully updated current MAC address for interface \(interface)")
            }
        }.value
    }

    // MARK: - Private Sync Methods for Async Wrappers
    
    private func syncRestoreOriginalMAC(interface: String) throws -> String? {
        logger.info("Restoring original MAC for interface \(interface)")
        
        guard let entry = repositoryData.entries[interface] else {
            throw RepositoryError.interfaceNotBackedUp(interface)
        }
        
        // Validate entry integrity
        guard entry.isValid else {
            logger.error("Backup entry for interface \(interface) failed integrity check")
            throw RepositoryError.corruptedBackupData(interface)
        }
        
        let originalMAC = entry.originalMAC
        
        // Remove backup entry
        repositoryData.entries.removeValue(forKey: interface)
        repositoryData.updateModified()
        
        // Save changes
        try saveRepositoryData()
        
        logger.info("Successfully restored and cleared backup for interface \(interface)")
        return originalMAC
    }
    
    private func syncClearBackup(interface: String) throws {
        logger.info("Clearing backup for interface \(interface)")
        
        guard repositoryData.entries[interface] != nil else {
            throw RepositoryError.interfaceNotBackedUp(interface)
        }
        
        repositoryData.entries.removeValue(forKey: interface)
        repositoryData.updateModified()
        
        try saveRepositoryData()
        
        logger.info("Successfully cleared backup for interface \(interface)")
    }
    
    // MARK: - Private Implementation
    
    private func setupDirectory() {
        let directory = backupFilePath.deletingLastPathComponent()
        
        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                logger.debug("Created repository directory: \(directory.path)")
            } catch {
                logger.error("Failed to create repository directory: \(error)")
            }
        }
    }
    
    private func loadRepositoryData() {
        // Try to load from primary location
        if FileManager.default.fileExists(atPath: backupFilePath.path) {
            do {
                let data = try Data(contentsOf: backupFilePath)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                repositoryData = try decoder.decode(RepositoryData.self, from: data)
                logger.debug("Loaded repository data from \(backupFilePath.path)")
                return
            } catch {
                logger.error("Failed to load repository data: \(error)")
                // Try legacy backup
                if loadLegacyBackup() {
                    return
                }
            }
        }
        
        // Initialize new repository
        repositoryData = RepositoryData()
        logger.debug("Initialized new repository")
    }
    
    private func loadLegacyBackup() -> Bool {
        guard FileManager.default.fileExists(atPath: legacyBackupFilePath.path) else {
            return false
        }
        
        do {
            let data = try Data(contentsOf: legacyBackupFilePath)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            repositoryData = try decoder.decode(RepositoryData.self, from: data)
            
            // Save to primary location
            try saveRepositoryData()
            
            // Remove legacy backup
            try FileManager.default.removeItem(at: legacyBackupFilePath)
            
            logger.info("Migrated legacy backup data")
            return true
        } catch {
            logger.error("Failed to load legacy backup: \(error)")
            return false
        }
    }
    
    private func saveRepositoryData() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(repositoryData)
        try data.write(to: backupFilePath, options: .atomic)
        
        logger.debug("Saved repository data to \(backupFilePath.path)")
    }
    
    private func validateMACAddress(_ mac: String) throws {
        let macPattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        let regex = try NSRegularExpression(pattern: macPattern)
        let range = NSRange(location: 0, length: mac.utf16.count)
        
        guard regex.firstMatch(in: mac, options: [], range: range) != nil else {
            throw RepositoryError.invalidMACFormat(mac)
        }
    }
    
    private func validateInterface(_ interface: String) throws {
        guard !interface.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw RepositoryError.invalidMACFormat("Interface name cannot be empty")
        }
    }
    
    private func validateAllEntries() -> IntegrityStatus {
        var validCount = 0
        var invalidCount = 0
        
        for entry in repositoryData.entries.values {
            if entry.isValid {
                validCount += 1
            } else {
                invalidCount += 1
            }
        }
        
        if invalidCount == 0 {
            return .good
        } else if invalidCount < validCount {
            return .warning
        } else {
            return .critical
        }
    }
}

// MARK: - Supporting Types

/// Repository statistics
public struct RepositoryStatistics {
    public let totalBackups: Int
    public let created: Date
    public let lastModified: Date
    public let version: String
    public let integrityStatus: IntegrityStatus
}

/// Integrity status
public enum IntegrityStatus: String, CaseIterable {
    case good = "good"
    case warning = "warning"
    case critical = "critical"
}

/// Repository-specific errors
public enum RepositoryError: Error, LocalizedError {
    case interfaceAlreadyBackedUp(String)
    case interfaceNotBackedUp(String)
    case invalidMACFormat(String)
    case macAddressMismatch(String, expected: String, actual: String)
    case corruptedBackupData(String)
    case fileSystemError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .interfaceAlreadyBackedUp(let interface):
            return "Interface \(interface) is already backed up"
        case .interfaceNotBackedUp(let interface):
            return "Interface \(interface) is not backed up"
        case .invalidMACFormat(let mac):
            return "Invalid MAC address format: \(mac)"
        case .macAddressMismatch(let interface, let expected, let actual):
            return "MAC address mismatch for interface \(interface): expected \(expected), got \(actual)"
        case .corruptedBackupData(let interface):
            return "Corrupted backup data for interface \(interface)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        }
    }
}

/// Alias for backward compatibility with tests
public typealias MacRepositoryError = RepositoryError

/// Additional MacRepositoryError cases for tests
public extension RepositoryError {
    static func backupAlreadyExists(_ interface: String) -> RepositoryError {
        return .interfaceAlreadyBackedUp(interface)
    }
    
    static func backupNotFound(_ interface: String) -> RepositoryError {
        return .interfaceNotBackedUp(interface)
    }
    
    static func validationError(_ message: String) -> RepositoryError {
        return .invalidMACFormat(message)
    }
}
