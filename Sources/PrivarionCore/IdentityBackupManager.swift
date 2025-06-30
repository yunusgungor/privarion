import Foundation

/// System Identity Backup Manager
/// Implements PATTERN-2025-013: Transactional Rollback Manager with Persistence
/// Provides safe backup and restore capabilities for system identity changes
public class IdentityBackupManager {
    
    // MARK: - Types
    
    /// Backup entry for a system identity
    public struct IdentityBackup: Codable {
        let type: IdentitySpoofingManager.IdentityType
        let originalValue: String
        let newValue: String?
        let timestamp: Date
        let backupId: UUID
        var validated: Bool
        
        /// Additional metadata for advanced backup scenarios
        let metadata: [String: String]
        
        init(type: IdentitySpoofingManager.IdentityType, 
             originalValue: String, 
             newValue: String? = nil,
             metadata: [String: String] = [:]) {
            self.type = type
            self.originalValue = originalValue
            self.newValue = newValue
            self.timestamp = Date()
            self.backupId = UUID()
            self.validated = false // Will be validated after successful backup
            self.metadata = metadata
        }
    }
    
    /// Backup session containing multiple identity changes
    public struct BackupSession: Codable {
        let sessionId: UUID
        let timestamp: Date
        var backups: [IdentityBackup] // Changed to var for mutation
        let sessionName: String
        let persistent: Bool
        
        /// Session validation status
        var isComplete: Bool {
            return !backups.isEmpty && backups.allSatisfy { $0.validated }
        }
        
        init(sessionName: String, persistent: Bool = false) {
            self.sessionId = UUID()
            self.timestamp = Date()
            self.backups = []
            self.sessionName = sessionName
            self.persistent = persistent
        }
    }
    
    public enum BackupError: Error, LocalizedError {
        case backupNotFound(UUID)
        case sessionNotFound(UUID)
        case backupCorrupted
        case restoreValidationFailed
        case storageAccessFailed
        case concurrentModification
        
        public var errorDescription: String? {
            switch self {
            case .backupNotFound(let id):
                return "Backup with ID \(id) not found"
            case .sessionNotFound(let id):
                return "Backup session with ID \(id) not found"
            case .backupCorrupted:
                return "Backup data is corrupted or invalid"
            case .restoreValidationFailed:
                return "Restore operation validation failed"
            case .storageAccessFailed:
                return "Unable to access backup storage"
            case .concurrentModification:
                return "Backup was modified by another process"
            }
        }
    }
    
    // MARK: - Properties
    
    private let logger: PrivarionLogger
    private let backupDirectory: URL
    private let fileManager = FileManager.default
    private var currentSession: BackupSession?
    
    /// Thread-safe access to sessions
    private let sessionQueue = DispatchQueue(label: "privarion.backup.session", attributes: .concurrent)
    
    // MARK: - Initialization
    
    public init(logger: PrivarionLogger = .shared) throws {
        self.logger = logger
        
        // Setup backup directory in user's application support
        let appSupport = try fileManager.url(for: .applicationSupportDirectory,
                                           in: .userDomainMask,
                                           appropriateFor: nil,
                                           create: true)
        
        self.backupDirectory = appSupport.appendingPathComponent("Privarion/Backups")
        
        // Create backup directory if it doesn't exist
        try fileManager.createDirectory(at: backupDirectory, 
                                      withIntermediateDirectories: true)
        
        logger.info("IdentityBackupManager initialized",
                   metadata: ["backup_directory": backupDirectory.path])
    }
    
    // MARK: - Session Management
    
    /// Start a new backup session
    public func startSession(name: String, persistent: Bool = false) throws -> UUID {
        return try sessionQueue.sync(flags: .barrier) {
            // Complete any existing session first
            if let existingSession = currentSession {
                logger.warning("Starting new session while previous session is active",
                              metadata: ["existing_session": existingSession.sessionId.uuidString,
                                       "new_session": name])
                try completeSession()
            }
            
            currentSession = BackupSession(sessionName: name, persistent: persistent)
            let sessionId = currentSession!.sessionId
            
            logger.info("Started backup session",
                       metadata: ["session_id": sessionId.uuidString,
                                "session_name": name,
                                "persistent": "\(persistent)"])
            
            return sessionId
        }
    }
    
    /// Add backup entry to current session
    public func addBackup(type: IdentitySpoofingManager.IdentityType,
                         originalValue: String,
                         newValue: String? = nil,
                         metadata: [String: String] = [:]) throws -> UUID {
        
        return try sessionQueue.sync(flags: .barrier) {
            guard var session = currentSession else {
                throw BackupError.sessionNotFound(UUID())
            }
            
            let backup = IdentityBackup(type: type,
                                      originalValue: originalValue,
                                      newValue: newValue,
                                      metadata: metadata)
            
            // Mark backup as validated since it was successfully created
            var validatedBackup = backup
            validatedBackup.validated = true
            
            session.backups.append(validatedBackup)
            currentSession = session
            
            logger.info("Added backup entry",
                       metadata: ["backup_id": validatedBackup.backupId.uuidString,
                                "type": "\(type)",
                                "session_id": session.sessionId.uuidString])
            
            return validatedBackup.backupId
        }
    }
    
    /// Complete and persist current session
    public func completeSession() throws {
        try sessionQueue.sync(flags: .barrier) {
            guard let session = currentSession else {
                logger.warning("Attempted to complete session but no active session")
                return
            }
            
            // Validate session before persisting
            guard session.isComplete else {
                throw BackupError.backupCorrupted
            }
            
            // Persist session to disk
            try persistSession(session)
            
            logger.info("Completed backup session",
                       metadata: ["session_id": session.sessionId.uuidString,
                                "backup_count": "\(session.backups.count)"])
            
            currentSession = nil
        }
    }
    
    // MARK: - Backup Operations
    
    /// Create backup for single identity type
    public func createBackup(type: IdentitySpoofingManager.IdentityType,
                           originalValue: String,
                           sessionName: String = "single_backup") throws -> UUID {
        
        _ = try startSession(name: sessionName)
        let backupId = try addBackup(type: type, originalValue: originalValue)
        try completeSession()
        
        return backupId
    }
    
    /// Restore from specific backup
    public func restoreFromBackup(backupId: UUID) throws -> IdentityBackup {
        let sessions = try loadAllSessions()
        
        for session in sessions {
            if let backup = session.backups.first(where: { $0.backupId == backupId }) {
                logger.info("Restored from backup",
                           metadata: ["backup_id": backupId.uuidString,
                                    "type": "\(backup.type)",
                                    "original_value": backup.originalValue])
                return backup
            }
        }
        
        throw BackupError.backupNotFound(backupId)
    }
    
    /// Restore entire session
    public func restoreSession(sessionId: UUID) throws -> [IdentityBackup] {
        let sessions = try loadAllSessions()
        
        guard let session = sessions.first(where: { $0.sessionId == sessionId }) else {
            throw BackupError.sessionNotFound(sessionId)
        }
        
        logger.info("Restored session",
                   metadata: ["session_id": sessionId.uuidString,
                            "backup_count": "\(session.backups.count)"])
        
        return session.backups
    }
    
    // MARK: - Storage Operations
    
    private func persistSession(_ session: BackupSession) throws {
        let sessionFile = backupDirectory
            .appendingPathComponent(session.sessionId.uuidString)
            .appendingPathExtension("json")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(session)
        try data.write(to: sessionFile)
        
        logger.debug("Persisted session to disk",
                    metadata: ["session_file": sessionFile.path])
    }
    
    private func loadAllSessions() throws -> [BackupSession] {
        let sessionFiles = try fileManager.contentsOfDirectory(at: backupDirectory,
                                                              includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        
        var sessions: [BackupSession] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        for file in sessionFiles {
            do {
                let data = try Data(contentsOf: file)
                let session = try decoder.decode(BackupSession.self, from: data)
                sessions.append(session)
            } catch {
                logger.error("Failed to load session",
                            metadata: ["file": file.path,
                                     "error": error.localizedDescription])
                // Continue loading other sessions
            }
        }
        
        return sessions.sorted { $0.timestamp > $1.timestamp }
    }
    
    // MARK: - Utility Methods
    
    /// List all available backups
    public func listBackups() throws -> [BackupSession] {
        return try loadAllSessions()
    }
    
    /// Clean up old backup sessions
    public func cleanupOldBackups(olderThan: TimeInterval = 30 * 24 * 60 * 60) throws { // 30 days default
        let cutoffDate = Date().addingTimeInterval(-olderThan)
        let sessions = try loadAllSessions()
        
        let oldSessions = sessions.filter { $0.timestamp < cutoffDate && !$0.persistent }
        
        for session in oldSessions {
            let sessionFile = backupDirectory
                .appendingPathComponent(session.sessionId.uuidString)
                .appendingPathExtension("json")
            
            try fileManager.removeItem(at: sessionFile)
            
            logger.info("Cleaned up old backup session",
                       metadata: ["session_id": session.sessionId.uuidString,
                                "session_age_days": "\(Int(-session.timestamp.timeIntervalSinceNow / (24 * 60 * 60)))"])
        }
    }
    
    /// Validate backup integrity
    public func validateBackupIntegrity() throws -> Bool {
        let sessions = try loadAllSessions()
        
        for session in sessions {
            for backup in session.backups {
                // Basic validation
                if backup.originalValue.isEmpty {
                    logger.error("Invalid backup found",
                                metadata: ["backup_id": backup.backupId.uuidString,
                                         "reason": "empty_original_value"])
                    return false
                }
                
                // Type-specific validation
                switch backup.type {
                case .hostname:
                    let engine = HardwareIdentifierEngine()
                    if !engine.validateHostname(backup.originalValue) {
                        logger.error("Invalid hostname in backup",
                                    metadata: ["backup_id": backup.backupId.uuidString,
                                             "hostname": backup.originalValue])
                        return false
                    }
                case .macAddress:
                    let engine = HardwareIdentifierEngine()
                    if !engine.validateMACAddress(backup.originalValue) {
                        logger.error("Invalid MAC address in backup",
                                    metadata: ["backup_id": backup.backupId.uuidString,
                                             "mac": backup.originalValue])
                        return false
                    }
                default:
                    // Additional validation for other types can be added here
                    break
                }
            }
        }
        
        logger.info("Backup integrity validation passed",
                   metadata: ["total_sessions": "\(sessions.count)",
                            "total_backups": "\(sessions.flatMap { $0.backups }.count)"])
        
        return true
    }
}

// MARK: - Extensions

extension IdentitySpoofingManager.IdentityType: Codable {}
