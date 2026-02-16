//
//  EphemeralFileSystemManager.swift
//  PrivarionCore
//
//  Created by GitHub Copilot on 2025-01-27
//  STORY-2025-016: Ephemeral File System with APFS Snapshots for Zero-Trace Execution
//  Phase 1: APFS Snapshot Core Implementation
//

import Foundation
import OSLog

/// Manager for creating and managing ephemeral file systems using APFS snapshots
/// Provides zero-trace application execution capabilities by ensuring complete cleanup
@available(macOS 10.15, *)
public final class EphemeralFileSystemManager: Sendable {
    
    // MARK: - Types
    
    /// Configuration for ephemeral file system creation
    public struct Configuration: Sendable, Codable {
        public let basePath: String
        public let maxEphemeralSpaces: Int
        public let cleanupTimeoutSeconds: Int
        public let enableSecurityMonitoring: Bool
        public let isTestMode: Bool
        
        public init(
            basePath: String = "/tmp/privarion/ephemeral",
            maxEphemeralSpaces: Int = 50,
            cleanupTimeoutSeconds: Int = 300,
            enableSecurityMonitoring: Bool = true,
            isTestMode: Bool = false
        ) {
            self.basePath = basePath
            self.maxEphemeralSpaces = maxEphemeralSpaces
            self.cleanupTimeoutSeconds = cleanupTimeoutSeconds
            self.enableSecurityMonitoring = enableSecurityMonitoring
            self.isTestMode = isTestMode
        }
        
        public static let `default` = Configuration()
    }
    
    /// Ephemeral space identifier and metadata
    public struct EphemeralSpace: Sendable, Codable, Identifiable {
        public let id: UUID
        public let snapshotName: String
        public let mountPath: String
        public let createdAt: Date
        public let processId: Int32?
        public let applicationPath: String?
        
        internal init(
            id: UUID,
            snapshotName: String,
            mountPath: String,
            createdAt: Date = Date(),
            processId: Int32? = nil,
            applicationPath: String? = nil
        ) {
            self.id = id
            self.snapshotName = snapshotName
            self.mountPath = mountPath
            self.createdAt = createdAt
            self.processId = processId
            self.applicationPath = applicationPath
        }
    }
    
    /// Errors that can occur during ephemeral file system operations
    public enum EphemeralError: LocalizedError, Sendable {
        case snapshotCreationFailed(String)
        case snapshotDeletionFailed(String)
        case mountOperationFailed(String)
        case unmountOperationFailed(String)
        case maxSpacesExceeded(Int)
        case invalidConfiguration(String)
        case systemError(Int32, String)
        case securityViolation(String)
        case snapshotNotFound(String)
        case restoreFailed(String)
        case scheduleFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .snapshotCreationFailed(let details):
                return "Failed to create APFS snapshot: \(details)"
            case .snapshotDeletionFailed(let details):
                return "Failed to delete APFS snapshot: \(details)"
            case .mountOperationFailed(let details):
                return "Failed to mount ephemeral space: \(details)"
            case .unmountOperationFailed(let details):
                return "Failed to unmount ephemeral space: \(details)"
            case .maxSpacesExceeded(let limit):
                return "Maximum ephemeral spaces exceeded: \(limit)"
            case .invalidConfiguration(let reason):
                return "Invalid configuration: \(reason)"
            case .systemError(let code, let message):
                return "System error \(code): \(message)"
            case .securityViolation(let details):
                return "Security violation detected: \(details)"
            case .snapshotNotFound(let name):
                return "Snapshot not found: \(name)"
            case .restoreFailed(let details):
                return "Failed to restore snapshot: \(details)"
            case .scheduleFailed(let details):
                return "Failed to schedule snapshot: \(details)"
            }
        }
    }
    
    // MARK: - Snapshot Strategy Types
    
    /// Snapshot strategy for different use cases
    public enum SnapshotStrategy: String, Sendable, Codable, CaseIterable {
        case preExecution = "pre_execution"
        case postExecution = "post_execution"
        case incremental = "incremental"
        case scheduled = "scheduled"
        
        public var displayName: String {
            switch self {
            case .preExecution:
                return "Pre-Execution Snapshot"
            case .postExecution:
                return "Post-Execution Snapshot"
            case .incremental:
                return "Incremental Snapshot"
            case .scheduled:
                return "Scheduled Snapshot"
            }
        }
        
        public var description: String {
            switch self {
            case .preExecution:
                return "Captures system state before application execution"
            case .postExecution:
                return "Restores system state after application execution"
            case .incremental:
                return "Captures only changed files since last snapshot"
            case .scheduled:
                return "Automatically captures snapshots at specified intervals"
            }
        }
    }
    
    /// Snapshot metadata for tracking and restoration
    public struct SnapshotMetadata: Sendable, Codable, Identifiable {
        public let id: UUID
        public let strategy: SnapshotStrategy
        public let snapshotName: String
        public let createdAt: Date
        public let parentSnapshotId: UUID?
        public let changedFiles: [String]
        public let totalFiles: Int
        public let sizeBytes: UInt64
        public let applicationPath: String?
        public let processId: Int32?
        
        public init(
            id: UUID = UUID(),
            strategy: SnapshotStrategy,
            snapshotName: String,
            createdAt: Date = Date(),
            parentSnapshotId: UUID? = nil,
            changedFiles: [String] = [],
            totalFiles: Int = 0,
            sizeBytes: UInt64 = 0,
            applicationPath: String? = nil,
            processId: Int32? = nil
        ) {
            self.id = id
            self.strategy = strategy
            self.snapshotName = snapshotName
            self.createdAt = createdAt
            self.parentSnapshotId = parentSnapshotId
            self.changedFiles = changedFiles
            self.totalFiles = totalFiles
            self.sizeBytes = sizeBytes
            self.applicationPath = applicationPath
            self.processId = processId
        }
    }
    
    /// Schedule configuration for automatic snapshots
    public struct SnapshotSchedule: Sendable, Codable {
        public let intervalSeconds: TimeInterval
        public let maxSnapshots: Int
        public let retentionDays: Int
        public let enabledStrategies: Set<SnapshotStrategy>
        
        public init(
            intervalSeconds: TimeInterval = 3600,
            maxSnapshots: Int = 10,
            retentionDays: Int = 7,
            enabledStrategies: Set<SnapshotStrategy> = Set(SnapshotStrategy.allCases)
        ) {
            self.intervalSeconds = intervalSeconds
            self.maxSnapshots = maxSnapshots
            self.retentionDays = retentionDays
            self.enabledStrategies = enabledStrategies
        }
        
        public static let `default` = SnapshotSchedule()
    }
    
    /// Application execution context for pre/post snapshot management
    public struct ExecutionContext: Sendable {
        public let applicationPath: String
        public let arguments: [String]
        public let environment: [String: String]
        public let processId: Int32
        public let workingDirectory: String
        public let preSnapshotId: UUID?
        public let startTime: Date
        
        public init(
            applicationPath: String,
            arguments: [String] = [],
            environment: [String: String] = [:],
            processId: Int32,
            workingDirectory: String = "/",
            preSnapshotId: UUID? = nil,
            startTime: Date = Date()
        ) {
            self.applicationPath = applicationPath
            self.arguments = arguments
            self.environment = environment
            self.processId = processId
            self.workingDirectory = workingDirectory
            self.preSnapshotId = preSnapshotId
            self.startTime = startTime
        }
    }
    
    /// Actor for thread-safe management of ephemeral spaces
    private actor SpaceRegistry {
        private var activeSpaces: [UUID: EphemeralSpace] = [:]
        private var cleanupTimers: [UUID: Timer] = [:]
        private let maxSpaces: Int
        
        init(maxSpaces: Int) {
            self.maxSpaces = maxSpaces
        }
        
        func registerSpace(_ space: EphemeralSpace) throws {
            guard activeSpaces.count < maxSpaces else {
                throw EphemeralError.maxSpacesExceeded(maxSpaces)
            }
            activeSpaces[space.id] = space
        }
        
        func unregisterSpace(_ id: UUID) {
            activeSpaces.removeValue(forKey: id)
            cleanupTimers[id]?.invalidate()
            cleanupTimers.removeValue(forKey: id)
        }
        
        func getSpace(_ id: UUID) -> EphemeralSpace? {
            return activeSpaces[id]
        }
        
        func getAllSpaces() -> [EphemeralSpace] {
            return Array(activeSpaces.values)
        }
        
        func setCleanupTimer(_ id: UUID, timer: Timer) {
            cleanupTimers[id] = timer
        }
    }
    
    /// Actor for thread-safe management of snapshots
    private actor SnapshotRegistry {
        private var snapshots: [UUID: SnapshotMetadata] = [:]
        private var executionContexts: [UUID: ExecutionContext] = [:]
        private var scheduledTimers: [UUID: Timer] = [:]
        private var lastIncrementalSnapshot: UUID?
        private var schedule: SnapshotSchedule?
        
        func registerSnapshot(_ metadata: SnapshotMetadata) {
            snapshots[metadata.id] = metadata
            if metadata.strategy == .incremental {
                lastIncrementalSnapshot = metadata.id
            }
        }
        
        func getSnapshot(_ id: UUID) -> SnapshotMetadata? {
            return snapshots[id]
        }
        
        func getAllSnapshots() -> [SnapshotMetadata] {
            return Array(snapshots.values).sorted { $0.createdAt > $1.createdAt }
        }
        
        func getSnapshotsByStrategy(_ strategy: SnapshotStrategy) -> [SnapshotMetadata] {
            return snapshots.values.filter { $0.strategy == strategy }.sorted { $0.createdAt > $1.createdAt }
        }
        
        func deleteSnapshot(_ id: UUID) {
            snapshots.removeValue(forKey: id)
        }
        
        func getLastIncrementalSnapshot() -> UUID? {
            return lastIncrementalSnapshot
        }
        
        func registerExecutionContext(_ context: ExecutionContext, forId id: UUID) {
            executionContexts[id] = context
        }
        
        func getExecutionContext(forId id: UUID) -> ExecutionContext? {
            return executionContexts[id]
        }
        
        func removeExecutionContext(forId id: UUID) {
            executionContexts.removeValue(forKey: id)
        }
        
        func setSchedule(_ schedule: SnapshotSchedule) {
            self.schedule = schedule
        }
        
        func getSchedule() -> SnapshotSchedule? {
            return schedule
        }
        
        func setScheduledTimer(_ id: UUID, timer: Timer) {
            scheduledTimers[id] = timer
        }
        
        func cancelScheduledTimer(_ id: UUID) {
            scheduledTimers[id]?.invalidate()
            scheduledTimers.removeValue(forKey: id)
        }
        
        func cleanupOldSnapshots(olderThanDays days: Int) {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let oldSnapshots = snapshots.filter { $0.value.createdAt < cutoffDate }
            for (id, _) in oldSnapshots {
                snapshots.removeValue(forKey: id)
            }
        }
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private let logger: Logger
    private let securityMonitor: SecurityMonitoringEngine?
    private let spaceRegistry: SpaceRegistry
    private let snapshotRegistry: SnapshotRegistry
    
    // MARK: - Initialization
    
    public init(
        configuration: Configuration = .default,
        securityMonitor: SecurityMonitoringEngine? = nil
    ) throws {
        self.snapshotRegistry = SnapshotRegistry()
        self.configuration = configuration
        self.logger = Logger(subsystem: "com.privarion.core", category: "EphemeralFileSystem")
        self.securityMonitor = securityMonitor
        self.spaceRegistry = SpaceRegistry(maxSpaces: configuration.maxEphemeralSpaces)
        
        try validateConfiguration(configuration)
        try createBaseDirectory()
        
        logger.info("EphemeralFileSystemManager initialized with base path: \(configuration.basePath)")
    }
    
    // MARK: - Public API
    
    /// Creates a new ephemeral file system space using APFS snapshots
    /// - Parameters:
    ///   - processId: Optional process ID for lifecycle management
    ///   - applicationPath: Optional application path for security monitoring
    /// - Returns: EphemeralSpace identifier and metadata
    /// - Throws: EphemeralError if creation fails
    public func createEphemeralSpace(
        processId: Int32? = nil,
        applicationPath: String? = nil
    ) async throws -> EphemeralSpace {
        
        let startTime = DispatchTime.now()
        let spaceId = UUID()
        let snapshotName = "privarion_ephemeral_\(spaceId.uuidString.replacingOccurrences(of: "-", with: "_"))"
        let mountPath = "\(configuration.basePath)/\(spaceId.uuidString)"
        
        logger.info("Creating ephemeral space: \(spaceId) with snapshot: \(snapshotName)")
        
        do {
            // Security check
            if let _ = securityMonitor, configuration.enableSecurityMonitoring {
                try await validateSecurityContext(processId: processId, applicationPath: applicationPath)
            }
            
            // Create APFS snapshot
            try await createAPFSSnapshot(name: snapshotName)
            
            // Create mount directory
            try createDirectory(at: mountPath)
            
            // Mount the snapshot (simplified for macOS implementation)
            try await mountSnapshot(snapshotName: snapshotName, mountPath: mountPath)
            
            // Create ephemeral space object
            let space = EphemeralSpace(
                id: spaceId,
                snapshotName: snapshotName,
                mountPath: mountPath,
                processId: processId,
                applicationPath: applicationPath
            )
            
            // Register space
            try await spaceRegistry.registerSpace(space)
            
            // Set up automatic cleanup timer
            await scheduleCleanup(for: space)
            
            // Log performance metrics
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            logger.info("Ephemeral space created successfully in \(String(format: "%.2f", durationMs))ms")
            
            // Report to security monitoring
            if let monitor = securityMonitor, configuration.enableSecurityMonitoring {
                await monitor.reportEphemeralEvent(.ephemeralSpaceCreated(space.id, durationMs))
            }
            
            return space
            
        } catch {
            logger.error("Failed to create ephemeral space: \(error.localizedDescription)")
            
            // Cleanup on failure
            await cleanupFailedSpace(snapshotName: snapshotName, mountPath: mountPath)
            
            throw error
        }
    }
    
    /// Destroys an ephemeral file system space and cleans up all traces
    /// - Parameter spaceId: The ephemeral space identifier
    /// - Throws: EphemeralError if cleanup fails
    public func destroyEphemeralSpace(_ spaceId: UUID) async throws {
        
        let startTime = DispatchTime.now()
        
        guard let space = await spaceRegistry.getSpace(spaceId) else {
            logger.warning("Attempted to destroy non-existent ephemeral space: \(spaceId)")
            return
        }
        
        logger.info("Destroying ephemeral space: \(spaceId)")
        
        do {
            // Unmount the snapshot
            try await unmountSnapshot(mountPath: space.mountPath)
            
            // Remove mount directory
            try removeDirectory(at: space.mountPath)
            
            // Delete APFS snapshot
            try await deleteAPFSSnapshot(name: space.snapshotName)
            
            // Unregister space
            await spaceRegistry.unregisterSpace(spaceId)
            
            // Log performance metrics
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            logger.info("Ephemeral space destroyed successfully in \(String(format: "%.2f", durationMs))ms")
            
            // Report to security monitoring
            if let monitor = securityMonitor, configuration.enableSecurityMonitoring {
                await monitor.reportEphemeralEvent(.ephemeralSpaceDestroyed(spaceId, durationMs))
            }
            
        } catch {
            logger.error("Failed to destroy ephemeral space \(spaceId): \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Lists all active ephemeral spaces
    /// - Returns: Array of active ephemeral spaces
    public func listActiveSpaces() async -> [EphemeralSpace] {
        return await spaceRegistry.getAllSpaces()
    }
    
    /// Gets information about a specific ephemeral space
    /// - Parameter spaceId: The ephemeral space identifier
    /// - Returns: EphemeralSpace if found, nil otherwise
    public func getSpaceInfo(_ spaceId: UUID) async -> EphemeralSpace? {
        return await spaceRegistry.getSpace(spaceId)
    }
    
    /// Cleanup all ephemeral spaces (emergency cleanup)
    public func cleanupAllSpaces() async {
        let spaces = await spaceRegistry.getAllSpaces()
        
        logger.warning("Emergency cleanup initiated for \(spaces.count) ephemeral spaces")
        
        await withTaskGroup(of: Void.self) { group in
            for space in spaces {
                group.addTask {
                    do {
                        try await self.destroyEphemeralSpace(space.id)
                    } catch {
                        self.logger.error("Failed to cleanup space \(space.id): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func validateConfiguration(_ config: Configuration) throws {
        if config.basePath.isEmpty {
            throw EphemeralError.invalidConfiguration("Base path cannot be empty")
        }
        
        if config.maxEphemeralSpaces <= 0 {
            throw EphemeralError.invalidConfiguration("Max ephemeral spaces must be positive")
        }
        
        if config.cleanupTimeoutSeconds <= 0 {
            throw EphemeralError.invalidConfiguration("Cleanup timeout must be positive")
        }
    }
    
    private func createBaseDirectory() throws {
        let baseURL = URL(fileURLWithPath: configuration.basePath)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
    
    private func createDirectory(at path: String) throws {
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    }
    
    private func removeDirectory(at path: String) throws {
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
    }
    
    private func validateSecurityContext(processId: Int32?, applicationPath: String?) async throws {
        // Security validation logic would go here
        // For now, just log the validation attempt
        logger.debug("Validating security context for process: \(processId?.description ?? "unknown")")
    }
    
    private func createAPFSSnapshot(name: String) async throws {
        logger.debug("Creating APFS snapshot: \(name)")
        
        let startTime = DispatchTime.now()
        
        // In test mode, simulate snapshot creation without real APFS operations
        if configuration.isTestMode {
            logger.debug("Test mode: Simulating APFS snapshot creation")
            
            // Simulate some work
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            // Verify snapshot creation performance (<100ms target)
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            logger.debug("Simulated APFS snapshot '\(name)' created in \(String(format: "%.2f", durationMs))ms")
            return
        }
        
        // Real APFS snapshot creation using tmutil (Time Machine snapshots)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["localsnapshot"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            guard process.terminationStatus == 0 else {
                throw EphemeralError.snapshotCreationFailed("tmutil failed with status \(process.terminationStatus): \(output)")
            }
            
            // Verify snapshot creation performance (<100ms target)
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            if durationMs > 100 {
                logger.warning("APFS snapshot creation exceeded performance target: \(String(format: "%.2f", durationMs))ms")
            }
            
            logger.info("APFS snapshot \(name) created successfully in \(String(format: "%.2f", durationMs))ms")
            
        } catch {
            logger.error("Failed to create APFS snapshot \(name): \(error.localizedDescription)")
            throw EphemeralError.snapshotCreationFailed(error.localizedDescription)
        }
    }
    
    private func deleteAPFSSnapshot(name: String) async throws {
        logger.debug("Deleting APFS snapshot: \(name)")
        
        let startTime = DispatchTime.now()
        
        // In test mode, simulate snapshot deletion without real APFS operations
        if configuration.isTestMode {
            logger.debug("Test mode: Simulating APFS snapshot deletion")
            
            // Simulate some work
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            
            // Verify cleanup performance (<200ms target)
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            logger.debug("Simulated APFS snapshot '\(name)' deleted in \(String(format: "%.2f", durationMs))ms")
            return
        }
        
        // Real APFS snapshot deletion using diskutil
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["apfs", "deleteSnapshot", "/", "-name", name]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            guard process.terminationStatus == 0 else {
                throw EphemeralError.snapshotDeletionFailed("diskutil failed with status \(process.terminationStatus): \(output)")
            }
            
            // Verify cleanup performance (<200ms target)
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            if durationMs > 200 {
                logger.warning("APFS snapshot deletion exceeded performance target: \(String(format: "%.2f", durationMs))ms")
            }
            
            logger.info("APFS snapshot \(name) deleted successfully in \(String(format: "%.2f", durationMs))ms")
            
        } catch {
            logger.error("Failed to delete APFS snapshot \(name): \(error.localizedDescription)")
            throw EphemeralError.snapshotDeletionFailed(error.localizedDescription)
        }
    }
    
    private func mountSnapshot(snapshotName: String, mountPath: String) async throws {
        logger.debug("Mounting snapshot \(snapshotName) at \(mountPath)")
        
        let startTime = DispatchTime.now()
        
        // Create mount point directory
        try FileManager.default.createDirectory(atPath: mountPath, withIntermediateDirectories: true)
        
        // In test mode, simulate mounting without real APFS operations
        if configuration.isTestMode {
            logger.debug("Test mode: Simulating APFS snapshot mount")
            
            // Simulate some work
            try await Task.sleep(nanoseconds: 5_000_000) // 5ms
            
            // Verify mount performance (<50ms target)
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            logger.debug("Simulated APFS snapshot '\(snapshotName)' mounted at \(mountPath) in \(String(format: "%.2f", durationMs))ms")
            return
        }
        
        // Mount APFS snapshot using mount_apfs
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/mount_apfs")
        process.arguments = ["-s", snapshotName, "/", mountPath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            guard process.terminationStatus == 0 else {
                throw EphemeralError.mountOperationFailed("mount_apfs failed with status \(process.terminationStatus): \(output)")
            }
            
            // Verify mount performance (<50ms target)
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            if durationMs > 50 {
                logger.warning("APFS snapshot mount exceeded performance target: \(String(format: "%.2f", durationMs))ms")
            }
            
            logger.info("APFS snapshot \(snapshotName) mounted at \(mountPath) in \(String(format: "%.2f", durationMs))ms")
            
        } catch {
            logger.error("Failed to mount APFS snapshot \(snapshotName): \(error.localizedDescription)")
            
            // Cleanup mount directory on failure
            do {
                try FileManager.default.removeItem(atPath: mountPath)
            } catch {
                logger.warning("Failed to cleanup mount directory: \(error.localizedDescription)")
            }
            
            throw EphemeralError.mountOperationFailed(error.localizedDescription)
        }
    }
    
    private func unmountSnapshot(mountPath: String) async throws {
        logger.debug("Unmounting snapshot at \(mountPath)")
        
        let startTime = DispatchTime.now()
        
        // Test mode: Skip actual unmount operation
        if configuration.isTestMode {
            logger.debug("Test mode: Simulating snapshot unmount at \(mountPath)")
            
            // Simulate unmount delay
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            // Clean up directory if it exists
            if FileManager.default.fileExists(atPath: mountPath) {
                do {
                    try FileManager.default.removeItem(atPath: mountPath)
                } catch {
                    logger.warning("Failed to cleanup test directory: \(error.localizedDescription)")
                }
            }
            
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            logger.info("Test mode: APFS snapshot unmounted from \(mountPath) in \(String(format: "%.2f", durationMs))ms")
            return
        }
        
        // Production mode: Use umount to unmount the snapshot
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/umount")
        process.arguments = [mountPath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            guard process.terminationStatus == 0 else {
                throw EphemeralError.unmountOperationFailed("umount failed with status \(process.terminationStatus): \(output)")
            }
            
            // Verify unmount performance
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            logger.info("APFS snapshot unmounted from \(mountPath) in \(String(format: "%.2f", durationMs))ms")
            
        } catch {
            logger.error("Failed to unmount APFS snapshot at \(mountPath): \(error.localizedDescription)")
            throw EphemeralError.unmountOperationFailed(error.localizedDescription)
        }
    }
    
    private func scheduleCleanup(for space: EphemeralSpace) async {
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(configuration.cleanupTimeoutSeconds), repeats: false) { _ in
            Task {
                do {
                    try await self.destroyEphemeralSpace(space.id)
                } catch {
                    self.logger.warning("Failed to cleanup ephemeral space: \(error.localizedDescription)")
                }
            }
        }
        
        await spaceRegistry.setCleanupTimer(space.id, timer: timer)
    }
    
    private func cleanupFailedSpace(snapshotName: String, mountPath: String) async {
        do {
            if FileManager.default.fileExists(atPath: mountPath) {
                try FileManager.default.removeItem(atPath: mountPath)
            }
            
            let snapshotPath = "\(configuration.basePath)/snapshots/\(snapshotName)"
            if FileManager.default.fileExists(atPath: snapshotPath) {
                try FileManager.default.removeItem(atPath: snapshotPath)
            }
        } catch {
            logger.error("Failed to cleanup failed space: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Pre-Execution Snapshot
    
    /// Creates a pre-execution snapshot before running an application
    public func createPreExecutionSnapshot(
        for applicationPath: String,
        processId: Int32
    ) async throws -> SnapshotMetadata {
        
        let snapshotId = UUID()
        let snapshotName = "privarion_pre_\(snapshotId.uuidString.replacingOccurrences(of: "-", with: "_"))"
        
        logger.info("Creating pre-execution snapshot for: \(applicationPath)")
        
        try await createAPFSSnapshot(name: snapshotName)
        
        let metadata = SnapshotMetadata(
            id: snapshotId,
            strategy: .preExecution,
            snapshotName: snapshotName,
            applicationPath: applicationPath,
            processId: processId
        )
        
        await snapshotRegistry.registerSnapshot(metadata)
        
        logger.info("Pre-execution snapshot created: \(snapshotId)")
        return metadata
    }
    
    // MARK: - Post-Execution Snapshot & Restore
    
    /// Restores system state from a pre-execution snapshot after application completes
    public func restoreFromPreExecution(
        snapshotId: UUID,
        killProcess: Bool = true
    ) async throws {
        
        guard let snapshot = await snapshotRegistry.getSnapshot(snapshotId) else {
            throw EphemeralError.snapshotNotFound(snapshotId.uuidString)
        }
        
        logger.info("Restoring from pre-execution snapshot: \(snapshotId)")
        
        if killProcess, let processId = snapshot.processId {
            try await terminateProcess(processId)
        }
        
        try await restoreAPFSSnapshot(name: snapshot.snapshotName)
        
        await snapshotRegistry.deleteSnapshot(snapshotId)
        
        logger.info("Restored from pre-execution snapshot: \(snapshotId)")
    }
    
    /// Creates a post-execution snapshot after application completes
    public func createPostExecutionSnapshot(
        preSnapshotId: UUID,
        applicationPath: String,
        processId: Int32
    ) async throws -> SnapshotMetadata {
        
        let preSnapshot = await snapshotRegistry.getSnapshot(preSnapshotId)
        
        let snapshotId = UUID()
        let snapshotName = "privarion_post_\(snapshotId.uuidString.replacingOccurrences(of: "-", with: "_"))"
        
        logger.info("Creating post-execution snapshot for: \(applicationPath)")
        
        let changedFiles = try await detectChangedFiles(since: preSnapshot?.snapshotName)
        
        try await createAPFSSnapshot(name: snapshotName)
        
        let metadata = SnapshotMetadata(
            id: snapshotId,
            strategy: .postExecution,
            snapshotName: snapshotName,
            parentSnapshotId: preSnapshotId,
            changedFiles: changedFiles,
            applicationPath: applicationPath,
            processId: processId
        )
        
        await snapshotRegistry.registerSnapshot(metadata)
        
        logger.info("Post-execution snapshot created: \(snapshotId) with \(changedFiles.count) changed files")
        return metadata
    }
    
    // MARK: - Incremental Snapshot Support
    
    /// Creates an incremental snapshot capturing only changed files
    public func createIncrementalSnapshot(
        targetPath: String? = nil,
        applicationPath: String? = nil
    ) async throws -> SnapshotMetadata {
        
        let snapshotId = UUID()
        let snapshotName = "privarion_incr_\(snapshotId.uuidString.replacingOccurrences(of: "-", with: "_"))"
        
        logger.info("Creating incremental snapshot")
        
        let lastSnapshotId = await snapshotRegistry.getLastIncrementalSnapshot()
        let lastSnapshotName: String? = await snapshotRegistry.getSnapshot(lastSnapshotId ?? UUID())?.snapshotName
        
        let changedFiles = try await detectChangedFiles(since: lastSnapshotName, targetPath: targetPath)
        
        try await createAPFSSnapshot(name: snapshotName)
        
        let totalFiles = try await countFiles(in: targetPath ?? "/")
        let sizeBytes = try await calculateSnapshotSize(changedFiles)
        
        let metadata = SnapshotMetadata(
            id: snapshotId,
            strategy: .incremental,
            snapshotName: snapshotName,
            parentSnapshotId: lastSnapshotId,
            changedFiles: changedFiles,
            totalFiles: totalFiles,
            sizeBytes: sizeBytes,
            applicationPath: applicationPath
        )
        
        await snapshotRegistry.registerSnapshot(metadata)
        
        logger.info("Incremental snapshot created: \(snapshotId) with \(changedFiles.count) changed files")
        return metadata
    }
    
    // MARK: - Scheduled Snapshot Support
    
    /// Configures and starts scheduled automatic snapshots
    public func startScheduledSnapshots(
        schedule: SnapshotSchedule,
        targetPath: String? = nil,
        applicationPath: String? = nil
    ) async throws {
        
        logger.info("Starting scheduled snapshots with interval: \(schedule.intervalSeconds)s")
        
        await snapshotRegistry.setSchedule(schedule)
        
        let timerId = UUID()
        
        let timer = Timer.scheduledTimer(withTimeInterval: schedule.intervalSeconds, repeats: true) { [weak self] _ in
            Task {
                await self?.performScheduledSnapshot(
                    schedule: schedule,
                    targetPath: targetPath,
                    applicationPath: applicationPath
                )
            }
        }
        
        await snapshotRegistry.setScheduledTimer(timerId, timer: timer)
        
        await snapshotRegistry.cleanupOldSnapshots(olderThanDays: schedule.retentionDays)
        
        logger.info("Scheduled snapshots started")
    }
    
    /// Stops scheduled automatic snapshots
    public func stopScheduledSnapshots() async {
        logger.info("Stopping scheduled snapshots")
        
        let snapshots = await snapshotRegistry.getAllSnapshots()
        let scheduledSnapshots = snapshots.filter { $0.strategy == .scheduled }
        
        for snapshot in scheduledSnapshots {
            await snapshotRegistry.deleteSnapshot(snapshot.id)
        }
        
        logger.info("Scheduled snapshots stopped")
    }
    
    /// Lists all snapshots
    public func listSnapshots() async -> [SnapshotMetadata] {
        return await snapshotRegistry.getAllSnapshots()
    }
    
    /// Lists snapshots by strategy
    public func listSnapshots(strategy: SnapshotStrategy) async -> [SnapshotMetadata] {
        return await snapshotRegistry.getSnapshotsByStrategy(strategy)
    }
    
    /// Gets a specific snapshot by ID
    public func getSnapshot(_ id: UUID) async -> SnapshotMetadata? {
        return await snapshotRegistry.getSnapshot(id)
    }
    
    /// Deletes a snapshot
    public func deleteSnapshot(_ id: UUID) async throws {
        guard let snapshot = await snapshotRegistry.getSnapshot(id) else {
            throw EphemeralError.snapshotNotFound(id.uuidString)
        }
        
        try await deleteAPFSSnapshot(name: snapshot.snapshotName)
        await snapshotRegistry.deleteSnapshot(id)
        
        logger.info("Deleted snapshot: \(id)")
    }
    
    // MARK: - Private Helper Methods
    
    private func performScheduledSnapshot(
        schedule: SnapshotSchedule,
        targetPath: String?,
        applicationPath: String?
    ) async {
        
        guard schedule.enabledStrategies.contains(.scheduled) else {
            return
        }
        
        do {
            let snapshotId = UUID()
            let snapshotName = "privarion_sched_\(snapshotId.uuidString.replacingOccurrences(of: "-", with: "_"))"
            
            logger.info("Performing scheduled snapshot: \(snapshotId)")
            
            try await createAPFSSnapshot(name: snapshotName)
            
            let metadata = SnapshotMetadata(
                id: snapshotId,
                strategy: .scheduled,
                snapshotName: snapshotName,
                applicationPath: applicationPath
            )
            
            await snapshotRegistry.registerSnapshot(metadata)
            
            await enforceSnapshotLimit(maxSnapshots: schedule.maxSnapshots)
            
            logger.info("Scheduled snapshot completed: \(snapshotId)")
            
        } catch {
            logger.error("Scheduled snapshot failed: \(error.localizedDescription)")
        }
    }
    
    private func enforceSnapshotLimit(maxSnapshots: Int) async {
        let snapshots = await snapshotRegistry.getAllSnapshots()
        
        if snapshots.count > maxSnapshots {
            let sortedSnapshots = snapshots.sorted { $0.createdAt < $1.createdAt }
            let toDelete = sortedSnapshots.prefix(snapshots.count - maxSnapshots)
            
            for snapshot in toDelete {
                do {
                    try await deleteAPFSSnapshot(name: snapshot.snapshotName)
                    await snapshotRegistry.deleteSnapshot(snapshot.id)
                    logger.info("Deleted old snapshot due to limit: \(snapshot.id)")
                } catch {
                    logger.warning("Failed to delete old snapshot: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func terminateProcess(_ processId: Int32) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/kill")
        process.arguments = ["-9", String(processId)]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            logger.info("Terminated process: \(processId)")
        } catch {
            logger.warning("Failed to terminate process: \(error.localizedDescription)")
        }
    }
    
    private func restoreAPFSSnapshot(name: String) async throws {
        logger.info("Restoring APFS snapshot: \(name)")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["apfs", "restore", name, "/", "-force"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            guard process.terminationStatus == 0 else {
                throw EphemeralError.restoreFailed("diskutil failed: \(output)")
            }
            
            logger.info("Restored APFS snapshot: \(name)")
        } catch let error as EphemeralError {
            throw error
        } catch {
            throw EphemeralError.restoreFailed(error.localizedDescription)
        }
    }
    
    private func detectChangedFiles(since snapshotName: String?, targetPath: String? = nil) async throws -> [String] {
        if configuration.isTestMode {
            return ["test_file_1.txt", "test_file_2.txt"]
        }
        
        guard snapshotName != nil else {
            return []
        }
        
        let path = targetPath ?? "/"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["listlocalsnapshots", path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let lines = output.components(separatedBy: .newlines)
            return lines.filter { !$0.isEmpty }.prefix(100).map { String($0) }
        } catch {
            logger.warning("Failed to detect changed files: \(error.localizedDescription)")
            return []
        }
    }
    
    private func countFiles(in path: String) async throws -> Int {
        if configuration.isTestMode {
            return 100
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        process.arguments = [path, "-type", "f"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return output.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
    }
    
    private func calculateSnapshotSize(_ files: [String]) async throws -> UInt64 {
        if configuration.isTestMode {
            return UInt64(files.count * 4096)
        }
        
        var totalSize: UInt64 = 0
        
        for file in files {
            let url = URL(fileURLWithPath: file)
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let size = attributes[.size] as? UInt64 {
                    totalSize += size
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
}

// MARK: - SecurityMonitoringEngine Integration

extension SecurityMonitoringEngine {
    /// Security events specific to ephemeral file system operations
    public enum EphemeralEvent: Sendable {
        case ephemeralSpaceCreated(UUID, Double)
        case ephemeralSpaceDestroyed(UUID, Double)
        case suspiciousEphemeralActivity(UUID, String)
        case ephemeralSpaceQuotaExceeded(Int)
    }
    
    /// Reports ephemeral file system security events
    /// - Parameter event: The ephemeral security event to report
    public func reportEphemeralEvent(_ event: EphemeralEvent) async {
        let securityEvent: SecurityEvent
        
        switch event {
        case .ephemeralSpaceCreated(let id, let duration):
            securityEvent = SecurityEvent(
                eventType: .suspiciousTraffic, // We'll need to add ephemeral event types
                severity: .low,
                description: "Ephemeral space created: \(id.uuidString)",
                evidence: ["id": id.uuidString, "duration_ms": String(duration)],
                confidence: 1.0,
                mitigationSuggestion: "Monitor ephemeral space usage"
            )
        case .ephemeralSpaceDestroyed(let id, let duration):
            securityEvent = SecurityEvent(
                eventType: .suspiciousTraffic,
                severity: .low,
                description: "Ephemeral space destroyed: \(id.uuidString)",
                evidence: ["id": id.uuidString, "duration_ms": String(duration)],
                confidence: 1.0,
                mitigationSuggestion: "Normal cleanup operation"
            )
        case .suspiciousEphemeralActivity(let id, let details):
            securityEvent = SecurityEvent(
                eventType: .threatDetected,
                severity: .high,
                description: "Suspicious ephemeral activity: \(details)",
                evidence: ["ephemeral_space": id.uuidString, "details": details],
                confidence: 0.8,
                mitigationSuggestion: "Investigate ephemeral space usage patterns"
            )
        case .ephemeralSpaceQuotaExceeded(let count):
            securityEvent = SecurityEvent(
                eventType: .anomalousConnection,
                severity: .medium,
                description: "Ephemeral space quota exceeded: \(count)",
                evidence: ["quota_count": String(count)],
                confidence: 1.0,
                mitigationSuggestion: "Review ephemeral space limits and usage"
            )
        }
        
        // Use the existing private method to add the event
        reportSecurityEvent(securityEvent)
    }
}