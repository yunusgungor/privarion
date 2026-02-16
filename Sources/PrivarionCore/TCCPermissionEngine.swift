import Foundation
import SQLite3
import os

/// TCC (Transparency, Consent, and Control) Permission Engine
/// Provides read-access to macOS TCC database for permission monitoring and policy evaluation
/// Integrates with SecurityPolicyEngine for unified permission policy decisions
@available(macOS 12.0, *)
actor TCCPermissionEngine {
    
    // MARK: - Types
    
    /// TCC service types corresponding to macOS permission categories
    enum TCCService: String, CaseIterable, Sendable {
        case camera = "kTCCServiceCamera"
        case microphone = "kTCCServiceMicrophone"
        case location = "kTCCServiceLocationManager"
        case contacts = "kTCCServiceAddressBook"
        case calendar = "kTCCServiceCalendar"
        case reminders = "kTCCServiceReminders"
        case photos = "kTCCServicePhotos"
        case fullDiskAccess = "kTCCServiceSystemPolicyAllFiles"
        case accessibility = "kTCCServiceAccessibility"
        case screenRecording = "kTCCServiceScreenCapture"
        case inputMonitoring = "kTCCServiceListenEvent"
        case automation = "kTCCServiceAppleEvents"
        case fileProviderPresence = "kTCCServiceFileProviderPresence"
        case mediaLibrary = "kTCCServiceMediaLibrary"
        case speechRecognition = "kTCCServiceSpeechRecognition"
        case systemPolicyDesktopFolder = "kTCCServiceSystemPolicyDesktopFolder"
        case systemPolicyDocumentsFolder = "kTCCServiceSystemPolicyDocumentsFolder"
        case systemPolicyDownloadsFolder = "kTCCServiceSystemPolicyDownloadsFolder"
        case bluetoothAlways = "kTCCServiceBluetoothAlways"
        
        /// Human-readable name for the service
        var displayName: String {
            switch self {
            case .camera: return "Camera"
            case .microphone: return "Microphone"
            case .location: return "Location Services"
            case .contacts: return "Contacts"
            case .calendar: return "Calendar"
            case .reminders: return "Reminders"
            case .photos: return "Photos"
            case .fullDiskAccess: return "Full Disk Access"
            case .accessibility: return "Accessibility"
            case .screenRecording: return "Screen Recording"
            case .inputMonitoring: return "Input Monitoring"
            case .automation: return "Automation (Apple Events)"
            case .fileProviderPresence: return "File Provider Presence"
            case .mediaLibrary: return "Media Library"
            case .speechRecognition: return "Speech Recognition"
            case .systemPolicyDesktopFolder: return "Desktop Folder"
            case .systemPolicyDocumentsFolder: return "Documents Folder"
            case .systemPolicyDownloadsFolder: return "Downloads Folder"
            case .bluetoothAlways: return "Bluetooth"
            }
        }
        
        /// Sensitivity level for security policy evaluation
        var sensitivityLevel: SensitivityLevel {
            switch self {
            case .camera, .microphone, .location, .screenRecording, .inputMonitoring:
                return .critical
            case .fullDiskAccess, .accessibility, .automation:
                return .high
            case .contacts, .calendar, .reminders, .photos:
                return .medium
            case .fileProviderPresence, .mediaLibrary, .speechRecognition:
                return .medium
            case .systemPolicyDesktopFolder, .systemPolicyDocumentsFolder, .systemPolicyDownloadsFolder:
                return .low
            case .bluetoothAlways:
                return .low
            }
        }
    }
    
    /// TCC permission status as stored in TCC.db
    enum TCCPermissionStatus: Int, Sendable {
        case denied = 0
        case unknown = 1
        case allowed = 2
        case limited = 3
        
        var displayName: String {
            switch self {
            case .denied: return "Denied"
            case .unknown: return "Unknown"
            case .allowed: return "Allowed"
            case .limited: return "Limited"
            }
        }
        
        var isGranted: Bool {
            return self == .allowed || self == .limited
        }
    }
    
    /// Sensitivity level for permission evaluation
    enum SensitivityLevel: Int, Comparable, Sendable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        static func < (lhs: SensitivityLevel, rhs: SensitivityLevel) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Complete TCC permission record
    struct TCCPermission: Sendable {
        let service: TCCService
        let bundleId: String
        let status: TCCPermissionStatus
        let lastModified: Date
        let promptCount: Int
        let csreq: Data? // Code signing requirement blob
        let policyId: Int?
        let indirectObjectIdentifier: String?
        
        /// Whether this permission grants significant access
        var isSignificantAccess: Bool {
            return status.isGranted && service.sensitivityLevel >= .medium
        }
        
        /// Risk score based on service sensitivity and status
        var riskScore: Double {
            let baseScore = Double(service.sensitivityLevel.rawValue)
            let statusMultiplier: Double = status.isGranted ? 1.0 : 0.1
            return baseScore * statusMultiplier
        }
    }
    
    /// Permission change event for monitoring
    struct TCCPermissionChange: Sendable {
        let permission: TCCPermission
        let changeType: ChangeType
        let timestamp: Date
        
        enum ChangeType: String, Sendable, CustomStringConvertible {
            case granted
            case denied
            case revoked
            case modified
            
            var description: String { rawValue }
        }
    }
    
    /// TCC database access error
    enum TCCError: Error, Sendable {
        case databaseNotFound
        case accessDenied
        case invalidQuery
        case corruptedData
        case unknownService(String)
        case writeNotSupported
        case writeFailed(String)
        case snapshotCreationFailed
        
        var description: String {
            switch self {
            case .databaseNotFound:
                return "TCC database not found. Requires macOS 10.14 or later."
            case .accessDenied:
                return "Access denied to TCC database. Requires Full Disk Access privilege."
            case .invalidQuery:
                return "Invalid SQL query executed on TCC database."
            case .corruptedData:
                return "Corrupted or unexpected data format in TCC database."
            case .unknownService(let service):
                return "Unknown TCC service: \(service)"
            case .writeNotSupported:
                return "Write operations not supported. Requires elevated privileges."
            case .writeFailed(let reason):
                return "Failed to write to TCC database: \(reason)"
            case .snapshotCreationFailed:
                return "Failed to create TCC database snapshot for rollback"
            }
        }
    }
    
    // MARK: - Alert Types
    
    /// Alert severity levels for permission changes
    enum AlertSeverity: Int, Sendable, Comparable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        static func < (lhs: AlertSeverity, rhs: AlertSeverity) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Permission change alert for notifications
    struct PermissionAlert: Sendable {
        let id: String
        let change: TCCPermissionChange
        let severity: AlertSeverity
        let message: String
        let timestamp: Date
        let acknowledged: Bool
        
        init(change: TCCPermissionChange, severity: AlertSeverity, acknowledged: Bool = false) {
            self.id = UUID().uuidString
            self.change = change
            self.severity = severity
            self.timestamp = Date()
            self.acknowledged = acknowledged
            
            switch change.changeType {
            case .granted:
                self.message = "Permission GRANTED: \(change.permission.service.displayName) for \(change.permission.bundleId)"
            case .denied:
                self.message = "Permission DENIED: \(change.permission.service.displayName) for \(change.permission.bundleId)"
            case .revoked:
                self.message = "Permission REVOKED: \(change.permission.service.displayName) for \(change.permission.bundleId)"
            case .modified:
                self.message = "Permission MODIFIED: \(change.permission.service.displayName) for \(change.permission.bundleId) - \(change.permission.status.displayName)"
            }
        }
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.privarion.core", category: "TCCPermissionEngine")
    private let databasePath: String
    private var database: OpaquePointer?
    private var isConnected: Bool = false
    private var writeDatabase: OpaquePointer?
    private var isWriteConnected: Bool = false
    
    // Permission monitoring
    private var lastKnownPermissions: [String: TCCPermission] = [:]
    private var permissionChangeHandler: ((TCCPermissionChange) async -> Void)?
    private var monitoringTask: Task<Void, Never>?
    private var alerts: [PermissionAlert] = []
    private let maxAlerts = 100
    
    // Snapshot management for rollback
    private var snapshotPath: String?
    private let snapshotDirectory: String
    
    // Performance monitoring
    private var lastEnumerationTime: TimeInterval = 0
    private var enumerationCount: Int = 0
    
    // MARK: - Initialization
    
    init(databasePath: String = "/Library/Application Support/com.apple.TCC/TCC.db") {
        self.databasePath = databasePath
        
        let tempDir = NSTemporaryDirectory()
        self.snapshotDirectory = tempDir
    }
    
    deinit {
        if let db = database {
            sqlite3_close(db)
        }
    }
    
    // MARK: - Database Connection
    
    /// Connect to TCC database with read-only access
    /// Requires Full Disk Access privilege to succeed
    func connect() async throws {
        guard !isConnected else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Check if database file exists
        guard FileManager.default.fileExists(atPath: databasePath) else {
            logger.error("TCC database not found at path: \(self.databasePath)")
            throw TCCError.databaseNotFound
        }
        
        // Open database with read-only access
        let result = sqlite3_open_v2(
            databasePath,
            &database,
            SQLITE_OPEN_READONLY,
            nil
        )
        
        guard result == SQLITE_OK else {
            logger.error("Failed to open TCC database: \(String(cString: sqlite3_errmsg(self.database)))")
            throw TCCError.accessDenied
        }
        
        isConnected = true
        let connectionTime = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("Connected to TCC database in \(String(format: "%.2f", connectionTime * 1000))ms")
    }
    
    /// Disconnect from TCC database
    func disconnect() async {
        guard isConnected, let db = database else { return }
        
        sqlite3_close(db)
        database = nil
        isConnected = false
        logger.info("Disconnected from TCC database")
    }
    
    // MARK: - Write Support
    
    /// Connect to TCC database with read-write access
    /// Requires root privileges and SIP disabled or bypassed
    func connectForWriting() async throws {
        guard !isWriteConnected else { return }
        
        guard FileManager.default.fileExists(atPath: databasePath) else {
            logger.error("TCC database not found at path: \(self.databasePath)")
            throw TCCError.databaseNotFound
        }
        
        let result = sqlite3_open_v2(
            databasePath,
            &writeDatabase,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
            nil
        )
        
        guard result == SQLITE_OK else {
            logger.error("Failed to open TCC database for writing: \(String(cString: sqlite3_errmsg(self.writeDatabase)))")
            throw TCCError.writeFailed(String(cString: sqlite3_errmsg(self.writeDatabase)))
        }
        
        isWriteConnected = true
        logger.info("Connected to TCC database for writing")
    }
    
    /// Disconnect from write database
    func disconnectFromWriting() async {
        guard isWriteConnected, let db = writeDatabase else { return }
        
        sqlite3_close(db)
        writeDatabase = nil
        isWriteConnected = false
        logger.info("Disconnected from TCC write database")
    }
    
    /// Grant permission directly to TCC database
    func grantPermission(bundleId: String, service: TCCService, authValue: Int = 2) async throws {
        try await ensureWriteConnected()
        
        let query = """
            INSERT OR REPLACE INTO access (service, client, auth_value, last_modified, prompt_count, csreq, policy_id, indirect_object_identifier)
            VALUES (?, ?, ?, ?, 0, NULL, NULL, NULL)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(writeDatabase, query, -1, &statement, nil) == SQLITE_OK else {
            throw TCCError.writeFailed(String(cString: sqlite3_errmsg(writeDatabase)))
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, service.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, bundleId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(statement, 3, Int32(authValue))
        sqlite3_bind_int64(statement, 4, Int64(Date().timeIntervalSince1970))
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TCCError.writeFailed(String(cString: sqlite3_errmsg(writeDatabase)))
        }
        
        logger.info("Granted permission \(service.rawValue) to \(bundleId)")
    }
    
    /// Revoke permission from TCC database
    func revokePermission(bundleId: String, service: TCCService) async throws {
        try await ensureWriteConnected()
        
        let query = "DELETE FROM access WHERE service = ? AND client = ?"
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(writeDatabase, query, -1, &statement, nil) == SQLITE_OK else {
            throw TCCError.writeFailed(String(cString: sqlite3_errmsg(writeDatabase)))
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, service.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, bundleId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw TCCError.writeFailed(String(cString: sqlite3_errmsg(writeDatabase)))
        }
        
        logger.info("Revoked permission \(service.rawValue) from \(bundleId)")
    }
    
    /// Create snapshot for rollback capability
    func createSnapshot() async throws -> String {
        let snapshotName = "tcc_snapshot_\(Int(Date().timeIntervalSince1970)).db"
        let snapshotPath = (snapshotDirectory as NSString).appendingPathComponent(snapshotName)
        
        await disconnect()
        
        do {
            try FileManager.default.copyItem(atPath: databasePath, toPath: snapshotPath)
            self.snapshotPath = snapshotPath
            logger.info("Created TCC snapshot at \(snapshotPath)")
            try await connect()
            return snapshotPath
        } catch {
            try await connect()
            throw TCCError.snapshotCreationFailed
        }
    }
    
    /// Restore from snapshot
    func restoreFromSnapshot(_ path: String) async throws {
        await disconnect()
        await disconnectFromWriting()
        
        guard FileManager.default.fileExists(atPath: path) else {
            throw TCCError.snapshotCreationFailed
        }
        
        do {
            try FileManager.default.removeItem(atPath: databasePath)
            try FileManager.default.copyItem(atPath: path, toPath: databasePath)
            logger.info("Restored TCC database from snapshot")
            try await connect()
        } catch {
            try await connect()
            throw TCCError.writeFailed("Failed to restore snapshot: \(error.localizedDescription)")
        }
    }
    
    private func ensureWriteConnected() async throws {
        if !isWriteConnected {
            try await connectForWriting()
        }
    }
    
    // MARK: - Permission Enumeration
    
    /// Enumerate all TCC permissions in the database
    /// Performance target: <50ms for complete scan
    func enumeratePermissions() async throws -> [TCCPermission] {
        try await ensureConnected()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var permissions: [TCCPermission] = []
        
        let query = """
            SELECT service, client, auth_value, last_modified, prompt_count, 
                   csreq, policy_id, indirect_object_identifier
            FROM access
            ORDER BY service, client
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            logger.error("Failed to prepare TCC enumeration query")
            throw TCCError.invalidQuery
        }
        
        defer { sqlite3_finalize(statement) }
        
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let currentStatement = statement else {
                logger.warning("Statement is nil during iteration")
                continue
            }
            do {
                let permission = try parsePermissionRow(statement: currentStatement)
                permissions.append(permission)
            } catch {
                logger.warning("Failed to parse permission row: \(error)")
                continue
            }
        }
        
        let enumerationTime = CFAbsoluteTimeGetCurrent() - startTime
        lastEnumerationTime = enumerationTime
        enumerationCount += 1
        
        logger.info("Enumerated \(permissions.count) TCC permissions in \(String(format: "%.2f", enumerationTime * 1000))ms")
        
        // Performance validation
        if enumerationTime > 0.050 { // 50ms target
            logger.warning("TCC enumeration exceeded performance target: \(String(format: "%.2f", enumerationTime * 1000))ms > 50ms")
        }
        
        return permissions
    }
    
    /// Get permission status for specific application and service
    func getPermissionStatus(for bundleId: String, service: TCCService) async throws -> TCCPermissionStatus? {
        try await ensureConnected()
        
        let query = """
            SELECT auth_value FROM access 
            WHERE service = ? AND client = ?
            LIMIT 1
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
            throw TCCError.invalidQuery
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, service.rawValue, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(statement, 2, bundleId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        
        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil // No permission entry found
        }
        
        let authValue = sqlite3_column_int(statement, 0)
        return TCCPermissionStatus(rawValue: Int(authValue))
    }
    
    /// Get all permissions for a specific application
    func getPermissions(for bundleId: String) async throws -> [TCCPermission] {
        let allPermissions = try await enumeratePermissions()
        return allPermissions.filter { $0.bundleId == bundleId }
    }
    
    /// Get all permissions for a specific service type
    func getPermissions(for service: TCCService) async throws -> [TCCPermission] {
        let allPermissions = try await enumeratePermissions()
        return allPermissions.filter { $0.service == service }
    }
    
    // MARK: - Permission Analysis
    
    /// Analyze permission risk profile for an application
    func analyzePermissionRisk(for bundleId: String) async throws -> PermissionRiskProfile {
        let permissions = try await getPermissions(for: bundleId)
        
        let totalRiskScore = permissions.reduce(0) { $0 + $1.riskScore }
        let criticalPermissions = permissions.filter { $0.service.sensitivityLevel == .critical && $0.status.isGranted }
        let highPermissions = permissions.filter { $0.service.sensitivityLevel == .high && $0.status.isGranted }
        
        let riskLevel: PermissionRiskProfile.RiskLevel
        if !criticalPermissions.isEmpty {
            riskLevel = .critical
        } else if !highPermissions.isEmpty {
            riskLevel = .high
        } else if totalRiskScore > 5.0 {
            riskLevel = .medium
        } else {
            riskLevel = .low
        }
        
        return PermissionRiskProfile(
            bundleId: bundleId,
            totalRiskScore: totalRiskScore,
            riskLevel: riskLevel,
            criticalPermissions: criticalPermissions,
            highPermissions: highPermissions,
            allPermissions: permissions
        )
    }
    
    /// Permission risk profile for security evaluation
    struct PermissionRiskProfile: Sendable {
        let bundleId: String
        let totalRiskScore: Double
        let riskLevel: RiskLevel
        let criticalPermissions: [TCCPermission]
        let highPermissions: [TCCPermission]
        let allPermissions: [TCCPermission]
        
        enum RiskLevel: String, Sendable {
            case low = "low"
            case medium = "medium"
            case high = "high"
            case critical = "critical"
        }
    }
    
    // MARK: - Permission Monitoring & Alerts
    
    /// Start monitoring permission changes
    func startMonitoring(interval: TimeInterval = 5.0, handler: @escaping (TCCPermissionChange) async -> Void) async {
        permissionChangeHandler = handler
        
        monitoringTask = Task {
            while !Task.isCancelled {
                await checkForPermissionChanges()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
        
        logger.info("Started permission monitoring with \(interval)s interval")
    }
    
    /// Stop monitoring permission changes
    func stopMonitoring() async {
        monitoringTask?.cancel()
        monitoringTask = nil
        permissionChangeHandler = nil
        logger.info("Stopped permission monitoring")
    }
    
    /// Get generated alerts
    func getAlerts() async -> [PermissionAlert] {
        return alerts
    }
    
    /// Clear alerts
    func clearAlerts() async {
        alerts.removeAll()
    }
    
    /// Acknowledge an alert
    func acknowledgeAlert(id: String) async -> Bool {
        guard let index = alerts.firstIndex(where: { $0.id == id }) else {
            return false
        }
        
        let alert = alerts[index]
        let acknowledgedAlert = PermissionAlert(
            change: alert.change,
            severity: alert.severity
        )
        
        alerts[index] = acknowledgedAlert
        return true
    }
    
    private func checkForPermissionChanges() async {
        do {
            let currentPermissions = try await enumeratePermissions()
            let currentDict = Dictionary(uniqueKeysWithValues: currentPermissions.map { ($0.service.rawValue + $0.bundleId, $0) })
            
            for (key, current) in currentDict {
                if let last = lastKnownPermissions[key] {
                    if last.status != current.status {
                        let changeType: TCCPermissionChange.ChangeType
                        if current.status.isGranted {
                            changeType = .granted
                        } else if last.status.isGranted && !current.status.isGranted {
                            changeType = .revoked
                        } else {
                            changeType = .modified
                        }
                        
                        let change = TCCPermissionChange(
                            permission: current,
                            changeType: changeType,
                            timestamp: Date()
                        )
                        
                        let severity = determineAlertSeverity(for: change)
                        let alert = PermissionAlert(change: change, severity: severity)
                        
                        alerts.append(alert)
                        if alerts.count > maxAlerts {
                            alerts.removeFirst()
                        }
                        
                        if let handler = permissionChangeHandler {
                            await handler(change)
                        }
                        
                        logger.info("Permission change detected: \(change.changeType) for \(current.bundleId):\(current.service.rawValue)")
                    }
                }
            }
            
            lastKnownPermissions = currentDict
            
        } catch {
            logger.error("Failed to check permission changes: \(error.localizedDescription)")
        }
    }
    
    private func determineAlertSeverity(for change: TCCPermissionChange) -> AlertSeverity {
        switch change.changeType {
        case .granted:
            if change.permission.service.sensitivityLevel == .critical {
                return .critical
            } else if change.permission.service.sensitivityLevel == .high {
                return .high
            }
            return .medium
        case .denied, .revoked:
            return .low
        case .modified:
            return change.permission.service.sensitivityLevel == .critical ? .high : .medium
        }
    }
    
    // MARK: - Performance Metrics
    
    /// Get performance metrics for TCC operations
    func getPerformanceMetrics() async -> PerformanceMetrics {
        return PerformanceMetrics(
            lastEnumerationTime: lastEnumerationTime,
            averageEnumerationTime: lastEnumerationTime, // Will be improved with history tracking
            enumerationCount: enumerationCount,
            isConnected: isConnected
        )
    }
    
    struct PerformanceMetrics: Sendable {
        let lastEnumerationTime: TimeInterval
        let averageEnumerationTime: TimeInterval
        let enumerationCount: Int
        let isConnected: Bool
    }
    
    // MARK: - Private Helpers
    
    private func ensureConnected() async throws {
        if !isConnected {
            try await connect()
        }
    }
    
    private func parsePermissionRow(statement: OpaquePointer) throws -> TCCPermission {
        // Parse service
        guard let serviceString = sqlite3_column_text(statement, 0) else {
            throw TCCError.corruptedData
        }
        let serviceRawValue = String(cString: serviceString)
        guard let service = TCCService(rawValue: serviceRawValue) else {
            throw TCCError.unknownService(serviceRawValue)
        }
        
        // Parse bundle ID
        guard let bundleIdString = sqlite3_column_text(statement, 1) else {
            throw TCCError.corruptedData
        }
        let bundleId = String(cString: bundleIdString)
        
        // Parse auth value (permission status)
        let authValue = sqlite3_column_int(statement, 2)
        guard let status = TCCPermissionStatus(rawValue: Int(authValue)) else {
            throw TCCError.corruptedData
        }
        
        // Parse last modified timestamp
        let lastModifiedTimestamp = sqlite3_column_int64(statement, 3)
        let lastModified = Date(timeIntervalSince1970: TimeInterval(lastModifiedTimestamp))
        
        // Parse prompt count
        let promptCount = Int(sqlite3_column_int(statement, 4))
        
        // Parse optional fields
        let csreq: Data?
        if let csreqPointer = sqlite3_column_blob(statement, 5) {
            let csreqLength = sqlite3_column_bytes(statement, 5)
            csreq = Data(bytes: csreqPointer, count: Int(csreqLength))
        } else {
            csreq = nil
        }
        
        let policyId: Int?
        if sqlite3_column_type(statement, 6) != SQLITE_NULL {
            policyId = Int(sqlite3_column_int(statement, 6))
        } else {
            policyId = nil
        }
        
        let indirectObjectIdentifier: String?
        if let identifierString = sqlite3_column_text(statement, 7) {
            indirectObjectIdentifier = String(cString: identifierString)
        } else {
            indirectObjectIdentifier = nil
        }
        
        return TCCPermission(
            service: service,
            bundleId: bundleId,
            status: status,
            lastModified: lastModified,
            promptCount: promptCount,
            csreq: csreq,
            policyId: policyId,
            indirectObjectIdentifier: indirectObjectIdentifier
        )
    }
}
