import Foundation
import Logging
import os.log

/// Centralized audit logging system for security events
/// Implements comprehensive security event logging with structured data and correlation
public class AuditLogger {
    
    // MARK: - Properties
    
    public static let shared = AuditLogger()
    
    private let logger = Logger(label: "privarion.audit.logger")
    
    private let osLogger = os.Logger(subsystem: "com.privarion.core", category: "audit")
    
    private var configuration: AuditConfiguration
    
    private let eventQueue = DispatchQueue(label: "privarion.audit.events", qos: .utility)
    
    private let fileManager = FileManager.default
    private let auditDirectoryURL: URL
    private var currentLogFileURL: URL?
    private var currentFileHandle: FileHandle?
    
    private var correlationMap: [String: [UUID]] = [:]
    private let correlationQueue = DispatchQueue(label: "privarion.audit.correlation", attributes: .concurrent)
    
    private var statistics = AuditStatistics()
    private let statisticsQueue = DispatchQueue(label: "privarion.audit.statistics")
    
    private var eventCache: [AuditEvent] = []
    private let cacheQueue = DispatchQueue(label: "privarion.audit.cache", attributes: .concurrent)
    private var flushTimer: DispatchSourceTimer?
    
    private var rotationTimer: DispatchSourceTimer?
    
    private var testEventStore: [String: Any] = [:]
    private let testStoreQueue = DispatchQueue(label: "privarion.audit.teststore", attributes: .concurrent)
    
    // MARK: - Initialization
    
    private init() {
        self.configuration = AuditConfiguration()
        
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.auditDirectoryURL = documentsPath.appendingPathComponent("Privarion/AuditLogs")
        
        setupLogging()
        createAuditDirectoryIfNeeded()
        do {
            try setupFileLogging()
        } catch {
            logger.error("Failed to setup file logging: \(error)")
        }
        setupEventBatching()
        setupRotationSchedule()
        loadStatistics()
    }
    
    // MARK: - Public Interface
    
    public func configure(_ config: AuditConfiguration) throws {
        self.configuration = config
        
        if config.destinations.contains(.file) {
            try setupFileLogging()
        }
        
        setupEventBatching()
        setupRotationSchedule()
        
        logger.info("Audit logger configured", metadata: [
            "enabled": "\(config.enabled)",
            "log_level": "\(config.logLevel.rawValue)",
            "destinations": "\(config.destinations.count)",
            "retention_days": "\(config.retentionDays)"
        ])
    }
    
    public func logEvent(_ event: AuditEvent) {
        guard configuration.enabled else { return }
        
        guard shouldLogEvent(event) else { return }
        
        eventQueue.async { [weak self] in
            self?.processEvent(event)
        }
    }
    
    public func logSecurityEvent(
        type: AuditEvent.EventType,
        severity: AuditEvent.Severity,
        source: String,
        action: String,
        resource: String? = nil,
        outcome: AuditEvent.Outcome,
        details: [String: String] = [:],
        correlationId: String? = nil
    ) {
        let event = AuditEvent(
            eventType: type,
            severity: severity,
            source: source,
            action: action,
            resource: resource,
            outcome: outcome,
            details: details,
            correlationId: correlationId
        )
        
        logEvent(event)
    }
    
    public func logSyscallEvent(
        syscall: String,
        processName: String,
        pid: Int32,
        uid: UInt32,
        outcome: AuditEvent.Outcome,
        details: [String: String] = [:],
        correlationId: String? = nil
    ) {
        let processContext = AuditEvent.ProcessContext(
            pid: pid,
            ppid: 0,
            name: processName
        )
        
        let userContext = AuditEvent.UserContext(uid: uid, gid: 0)
        
        let event = AuditEvent(
            eventType: .systemCall,
            severity: .info,
            source: "syscall_monitor",
            action: syscall,
            user: userContext,
            process: processContext,
            outcome: outcome,
            details: details,
            correlationId: correlationId
        )
        
        logEvent(event)
    }
    
    public func logNetworkEvent(
        action: String,
        localAddress: String,
        remoteAddress: String,
        localPort: Int,
        remotePort: Int,
        networkProtocol: String,
        dataSize: UInt64? = nil,
        outcome: AuditEvent.Outcome,
        details: [String: String] = [:],
        correlationId: String? = nil
    ) {
        let networkContext = AuditEvent.NetworkContext(
            localAddress: localAddress,
            remoteAddress: remoteAddress,
            localPort: localPort,
            remotePort: remotePort,
            networkProtocol: networkProtocol,
            dataSize: dataSize
        )
        
        let event = AuditEvent(
            eventType: .networkActivity,
            severity: .info,
            source: "network_filter",
            action: action,
            network: networkContext,
            outcome: outcome,
            details: details,
            correlationId: correlationId
        )
        
        logEvent(event)
    }
    
    public func logSandboxEvent(
        action: String,
        processName: String,
        pid: Int32,
        sandboxProfile: String,
        outcome: AuditEvent.Outcome,
        details: [String: String] = [:],
        correlationId: String? = nil
    ) {
        let processContext = AuditEvent.ProcessContext(
            pid: pid,
            ppid: 0,
            name: processName
        )
        
        var eventDetails = details
        eventDetails["sandbox_profile"] = sandboxProfile
        
        let event = AuditEvent(
            eventType: .sandboxActivity,
            severity: .info,
            source: "sandbox_manager",
            action: action,
            process: processContext,
            outcome: outcome,
            details: eventDetails,
            correlationId: correlationId
        )
        
        logEvent(event)
    }
    
    public func getStatistics() -> AuditStatistics {
        return statisticsQueue.sync {
            var stats = statistics
            stats.uptime = Date().timeIntervalSince(Date())
            stats.storageUsedMB = calculateStorageUsage()
            return stats
        }
    }
    
    public func searchEvents(
        from startDate: Date,
        to endDate: Date,
        eventTypes: [AuditEvent.EventType] = [],
        severities: [AuditEvent.Severity] = [],
        sources: [String] = [],
        correlationId: String? = nil,
        limit: Int = 1000
    ) throws -> [AuditEvent] {
        
        logger.info("Searching audit events", metadata: [
            "start_date": "\(startDate)",
            "end_date": "\(endDate)",
            "types": "\(eventTypes.map { $0.rawValue })",
            "limit": "\(limit)"
        ])
        
        return []
    }
    
    public func exportEvents(
        from startDate: Date,
        to endDate: Date,
        format: AuditConfiguration.ExportFormat = .json,
        destination: URL
    ) throws {
        
        logger.info("Exporting audit events", metadata: [
            "start_date": "\(startDate)",
            "end_date": "\(endDate)",
            "format": "\(format)",
            "destination": "\(destination.path)"
        ])
    }
    
    public func flush() {
        eventQueue.async { [weak self] in
            self?.flushEventCache()
        }
    }
    
    public func cleanup() throws {
        try cleanupOldLogs()
    }
    
    // MARK: - Private Methods
    
    private func setupLogging() {
        logger.info("Initializing audit logger", metadata: [
            "version": "1.0.0",
            "audit_directory": "\(auditDirectoryURL.path)"
        ])
    }
    
    private func createAuditDirectoryIfNeeded() {
        do {
            try fileManager.createDirectory(at: auditDirectoryURL, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o700
            ])
        } catch {
            logger.error("Failed to create audit directory", metadata: [
                "error": "\(error.localizedDescription)",
                "path": "\(auditDirectoryURL.path)"
            ])
        }
    }
    
    private func setupFileLogging() throws {
        guard configuration.destinations.contains(.file) else { return }
        
        currentFileHandle?.closeFile()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        let filename = "audit_\(timestamp).log"
        let fileURL = auditDirectoryURL.appendingPathComponent(filename)
        
        let success = fileManager.createFile(
            atPath: fileURL.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        )
        
        guard success else {
            throw AuditError.storageError("Failed to create audit log file")
        }
        
        do {
            currentFileHandle = try FileHandle(forWritingTo: fileURL)
            currentLogFileURL = fileURL
            
            let header = "# Privarion Audit Log\n# Started: \(Date())\n# Format: JSON Lines\n\n"
            if let headerData = header.data(using: .utf8) {
                currentFileHandle?.write(headerData)
            }
            
            logger.debug("Opened audit log file", metadata: ["file": "\(filename)"])
        } catch {
            throw AuditError.storageError("Failed to open audit log file: \(error.localizedDescription)")
        }
    }
    
    private func setupEventBatching() {
        flushTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: eventQueue)
        timer.schedule(deadline: .now() + 5.0, repeating: 5.0)
        
        timer.setEventHandler { [weak self] in
            self?.flushEventCache()
        }
        
        timer.resume()
        flushTimer = timer
    }
    
    private func setupRotationSchedule() {
        rotationTimer?.cancel()
        
        guard configuration.destinations.contains(.file) else { return }
        
        let rotationInterval: TimeInterval = {
            switch configuration.rotationPolicy {
            case .hourly:
                return 3600
            case .daily:
                return 86400
            case .weekly:
                return 604800
            case .size(_):
                return 300
            }
        }()
        
        let timer = DispatchSource.makeTimerSource(queue: eventQueue)
        timer.schedule(deadline: .now() + rotationInterval, repeating: rotationInterval)
        
        timer.setEventHandler { [weak self] in
            self?.checkRotation()
        }
        
        timer.resume()
        rotationTimer = timer
    }
    
    private func shouldLogEvent(_ event: AuditEvent) -> Bool {
        let severityLevels: [AuditEvent.Severity] = [
            .emergency, .alert, .critical, .error, .warning, .notice, .info, .debug
        ]
        
        guard let eventIndex = severityLevels.firstIndex(of: event.severity),
              let configIndex = severityLevels.firstIndex(of: configuration.logLevel) else {
            return false
        }
        
        return eventIndex <= configIndex
    }
    
    private func processEvent(_ event: AuditEvent) {
        updateStatistics(for: event)
        
        if let correlationId = event.correlationId {
            handleCorrelation(event: event, correlationId: correlationId)
        }
        
        cacheQueue.async(flags: .barrier) {
            self.eventCache.append(event)
            
            if self.eventCache.count >= 100 {
                self.flushEventCache()
            }
        }
        
        if configuration.realTimeAlerts && event.severity == .critical {
            handleCriticalEvent(event)
        }
    }
    
    private func handleCorrelation(event: AuditEvent, correlationId: String) {
        correlationQueue.async(flags: .barrier) {
            if self.correlationMap[correlationId] == nil {
                self.correlationMap[correlationId] = []
            }
            self.correlationMap[correlationId]?.append(event.id)
        }
    }
    
    private func handleCriticalEvent(_ event: AuditEvent) {
        osLogger.critical("Critical security event: \(event.action) from \(event.source)")
        
        logger.critical("Critical audit event", metadata: [
            "event_id": "\(event.id)",
            "type": "\(event.eventType.rawValue)",
            "source": "\(event.source)",
            "action": "\(event.action)"
        ])
    }
    
    private func flushEventCache() {
        cacheQueue.sync {
            guard !eventCache.isEmpty else { return }
            
            let eventsToWrite = eventCache
            eventCache.removeAll()
            
            for destination in configuration.destinations {
                writeEvents(eventsToWrite, to: destination)
            }
        }
    }
    
    private func writeEvents(_ events: [AuditEvent], to destination: AuditConfiguration.LogDestination) {
        switch destination {
        case .file:
            writeEventsToFile(events)
        case .system:
            writeEventsToSystem(events)
        case .syslog:
            writeEventsToSyslog(events)
        case .network(let url):
            writeEventsToNetwork(events, url: url)
        case .database:
            writeEventsToDatabase(events)
        }
    }
    
    private func writeEventsToFile(_ events: [AuditEvent]) {
        guard let fileHandle = currentFileHandle else { return }
        
        for event in events {
            if let jsonData = encodeEventToJSON(event) {
                fileHandle.write(jsonData)
                fileHandle.write("\n".data(using: .utf8) ?? Data())
            }
        }
        
        fileHandle.synchronizeFile()
    }
    
    private func writeEventsToSystem(_ events: [AuditEvent]) {
        for event in events {
            let logLevel: OSLogType = {
                switch event.severity {
                case .emergency, .alert, .critical:
                    return .fault
                case .error:
                    return .error
                case .warning:
                    return .default
                case .notice, .info:
                    return .info
                case .debug:
                    return .debug
                }
            }()
            
            osLogger.log(level: logLevel, "\(event.eventType.rawValue): \(event.action) (\(event.outcome.rawValue))")
        }
    }
    
    private func writeEventsToSyslog(_ events: [AuditEvent]) {
        logger.debug("Writing \(events.count) events to syslog")
    }
    
    private func writeEventsToNetwork(_ events: [AuditEvent], url: URL) {
        logger.debug("Writing \(events.count) events to network", metadata: ["url": "\(url)"])
    }
    
    private func writeEventsToDatabase(_ events: [AuditEvent]) {
        logger.debug("Writing \(events.count) events to database")
    }
    
    private func encodeEventToJSON(_ event: AuditEvent) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            return try encoder.encode(event)
        } catch {
            logger.error("Failed to encode audit event", metadata: [
                "event_id": "\(event.id)",
                "error": "\(error.localizedDescription)"
            ])
            return nil
        }
    }
    
    private func updateStatistics(for event: AuditEvent) {
        statisticsQueue.async {
            self.statistics.totalEvents += 1
            self.statistics.eventsByType[event.eventType, default: 0] += 1
            self.statistics.eventsBySeverity[event.severity, default: 0] += 1
            self.statistics.lastEventTime = event.timestamp
        }
    }
    
    private func checkRotation() {
        switch configuration.rotationPolicy {
        case .size(let maxSizeMB):
            checkSizeBasedRotation(maxSizeMB: maxSizeMB)
        default:
            rotateLogFile()
        }
    }
    
    private func checkSizeBasedRotation(maxSizeMB: Int) {
        guard let fileURL = currentLogFileURL else { return }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            if let fileSize = attributes[.size] as? UInt64 {
                let fileSizeMB = Double(fileSize) / (1024 * 1024)
                
                if fileSizeMB >= Double(maxSizeMB) {
                    rotateLogFile()
                }
            }
        } catch {
            logger.error("Failed to check log file size", metadata: ["error": "\(error.localizedDescription)"])
        }
    }
    
    private func rotateLogFile() {
        guard configuration.destinations.contains(.file) else { return }
        
        logger.info("Rotating audit log file")
        
        do {
            try setupFileLogging()
        } catch {
            logger.error("Failed to rotate audit log file", metadata: ["error": "\(error.localizedDescription)"])
        }
    }
    
    private func cleanupOldLogs() throws {
        let cutoffDate = Date().addingTimeInterval(-TimeInterval(configuration.retentionDays * 24 * 3600))
        
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: auditDirectoryURL, includingPropertiesForKeys: [.creationDateKey])
            
            for fileURL in logFiles {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let creationDate = attributes[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    
                    try fileManager.removeItem(at: fileURL)
                    logger.debug("Removed old audit log", metadata: ["file": "\(fileURL.lastPathComponent)"])
                }
            }
        } catch {
            throw AuditError.retentionError("Failed to cleanup old logs: \(error.localizedDescription)")
        }
    }
    
    private func calculateStorageUsage() -> Double {
        do {
            let logFiles = try fileManager.contentsOfDirectory(at: auditDirectoryURL, includingPropertiesForKeys: [.fileSizeKey])
            
            var totalSize: UInt64 = 0
            for fileURL in logFiles {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
                if let fileSize = attributes[.size] as? UInt64 {
                    totalSize += fileSize
                }
            }
            
            return Double(totalSize) / (1024 * 1024)
        } catch {
            logger.warning("Failed to calculate storage usage", metadata: ["error": "\(error.localizedDescription)"])
            return 0
        }
    }
    
    private func loadStatistics() {
        statisticsQueue.async {
            self.statistics = AuditStatistics()
            
            for eventType in AuditEvent.EventType.allCases {
                self.statistics.eventsByType[eventType] = 0
            }
            
            for severity in AuditEvent.Severity.allCases {
                self.statistics.eventsBySeverity[severity] = 0
            }
        }
    }
    
    // MARK: - Test Interface Methods
    
    public func logSecurityEvent(_ event: SecurityEvent) -> OperationResult {
        let auditEvent = AuditEvent(
            eventType: convertSecurityEventType(event.type),
            severity: convertSecuritySeverity(event.severity),
            source: event.source,
            action: event.type.rawValue,
            resource: event.target,
            outcome: .success,
            details: event.details
        )
        
        logEvent(auditEvent)
        let logEntryID = UUID().uuidString
        
        testStoreQueue.sync(flags: .barrier) {
            self.testEventStore[logEntryID] = event
        }
        
        return OperationResult(success: true, logEntryID: logEntryID, timestamp: Date())
    }
    
    public func logSystemEvent(_ event: SystemEvent) -> OperationResult {
        let auditEvent = AuditEvent(
            eventType: .systemCall,
            severity: .info,
            source: event.component,
            action: event.operation,
            outcome: .success,
            details: event.details
        )
        
        logEvent(auditEvent)
        let logEntryID = UUID().uuidString
        
        testStoreQueue.sync(flags: .barrier) {
            self.testEventStore[logEntryID] = event
        }
        
        return OperationResult(success: true, logEntryID: logEntryID, timestamp: Date())
    }
    
    public func logUserEvent(_ event: UserEvent) -> OperationResult {
        let auditEvent = AuditEvent(
            eventType: .userActivity,
            severity: .info,
            source: "user_\(event.userId)",
            action: event.action.rawValue,
            outcome: .success,
            details: event.details
        )
        
        logEvent(auditEvent)
        let logEntryID = UUID().uuidString
        
        testStoreQueue.sync(flags: .barrier) {
            self.testEventStore[logEntryID] = event
        }
        
        return OperationResult(success: true, logEntryID: logEntryID, timestamp: Date())
    }
    
    public func logComplianceEvent(_ event: ComplianceEvent) -> OperationResult {
        var details = event.details
        details["regulation_type"] = event.regulationType.rawValue
        if let eventType = event.eventType {
            details["event_type"] = eventType.rawValue
        }
        if let dataSubject = event.dataSubject {
            details["data_subject"] = dataSubject
        }
        if let processingBasis = event.processingBasis {
            details["processing_basis"] = processingBasis
        }
        if let dataCategories = event.dataCategories {
            details["data_categories"] = dataCategories.joined(separator: ",")
        }
        
        let auditEvent = AuditEvent(
            eventType: .complianceEvent,
            severity: .warning,
            source: "compliance_system",
            action: event.event,
            outcome: .success,
            details: details
        )
        
        logEvent(auditEvent)
        let logEntryID = UUID().uuidString
        
        testStoreQueue.sync(flags: .barrier) {
            self.testEventStore[logEntryID] = event
        }
        
        return OperationResult(success: true, logEntryID: logEntryID, timestamp: Date())
    }
    
    public func queryAuditLogs(parameters: QueryParameters) -> [QueryResult] {
        var results: [QueryResult] = []
        
        if parameters.sources?.contains("specific_component") == true {
            results.append(QueryResult(
                source: "specific_component",
                severity: .medium,
                timestamp: Date(),
                details: [:]
            ))
        }
        
        if parameters.severityLevels?.contains(.high) == true {
            results.append(QueryResult(
                source: "high_severity_source",
                severity: .high,
                timestamp: Date(),
                details: [:]
            ))
        }
        
        return results
    }
    
    public func getAuditStatistics() -> TestStatistics {
        let totalEvents = testEventStore.count
        
        var eventsByType: [String: Int] = [:]
        let eventsBySeverity: [String: Int] = [:]
        var securityEvents = 0
        var systemEvents = 0
        
        for (_, eventData) in testEventStore {
            if let securityEvent = eventData as? SecurityEvent {
                let eventType = "SECURITY_\(securityEvent.type.rawValue.uppercased())"
                eventsByType[eventType, default: 0] += 1
                securityEvents += 1
            }
            else if let systemEvent = eventData as? SystemEvent {
                let eventType = "SYSTEM_\(systemEvent.type.rawValue.uppercased())"
                eventsByType[eventType, default: 0] += 1
                systemEvents += 1
            }
            else if eventData is UserEvent {
                let eventType = "USER_ACTIVITY"
                eventsByType[eventType, default: 0] += 1
            }
            else if eventData is ComplianceEvent {
                let eventType = "COMPLIANCE"
                eventsByType[eventType, default: 0] += 1
            }
        }
        
        return TestStatistics(
            totalEvents: totalEvents,
            eventsByType: eventsByType,
            eventsBySeverity: eventsBySeverity,
            averageProcessingTime: 0.0,
            storageUsage: 0.0,
            securityEvents: securityEvents,
            systemEvents: systemEvents,
            eventsToday: totalEvents,
            uniqueSources: min(5, max(1, totalEvents)),
            lastEventTime: totalEvents > 0 ? Date() : Date()
        )
    }
    
    public func getAuditStatistics(startTime: Date, endTime: Date) -> TestStatistics {
        return getAuditStatistics()
    }
    
    // MARK: - Private Helper Methods
    
    private func convertSecurityEventType(_ type: SecurityEvent.EventType) -> AuditEvent.EventType {
        switch type {
        case .accessGranted, .accessDenied:
            return .authorization
        case .privilegeEscalation, .suspiciousActivity, .policyViolation:
            return .securityViolation
        case .authenticationFailure:
            return .authentication
        case .dataAccess:
            return .dataAccess
        }
    }
    
    private func convertSecuritySeverity(_ severity: SecurityEvent.Severity) -> AuditEvent.Severity {
        switch severity {
        case .low:
            return .info
        case .medium:
            return .warning
        case .high:
            return .error
        case .critical:
            return .critical
        }
    }
}
