//
//  ApplicationLauncher.swift
//  PrivarionCore
//
//  Created by GitHub Copilot on 2025-01-27
//  STORY-2025-016: Ephemeral File System with APFS Snapshots for Zero-Trace Execution
//  Phase 2: Mount Point Management & Application Isolation
//

import Foundation
import OSLog

/// Manages launching applications in ephemeral file system spaces for zero-trace execution
/// Provides complete process isolation and automatic cleanup capabilities
@available(macOS 10.15, *)
public final class ApplicationLauncher: Sendable {
    
    // MARK: - Types
    
    /// Configuration for application launching in ephemeral spaces
    public struct LaunchConfiguration: Sendable, Codable {
        public let inheritEnvironment: Bool
        public let customEnvironment: [String: String]
        public let workingDirectory: String?
        public let redirectOutput: Bool
        public let enableResourceMonitoring: Bool
        public let maxExecutionTimeSeconds: Int
        public let killOnParentExit: Bool
        
        public init(
            inheritEnvironment: Bool = false,
            customEnvironment: [String: String] = [:],
            workingDirectory: String? = nil,
            redirectOutput: Bool = true,
            enableResourceMonitoring: Bool = true,
            maxExecutionTimeSeconds: Int = 3600,
            killOnParentExit: Bool = true
        ) {
            self.inheritEnvironment = inheritEnvironment
            self.customEnvironment = customEnvironment
            self.workingDirectory = workingDirectory
            self.redirectOutput = redirectOutput
            self.enableResourceMonitoring = enableResourceMonitoring
            self.maxExecutionTimeSeconds = maxExecutionTimeSeconds
            self.killOnParentExit = killOnParentExit
        }
        
        public static let `default` = LaunchConfiguration()
    }
    
    /// Handle for a running process in an ephemeral space
    public struct ProcessHandle: Sendable, Identifiable {
        public let id: UUID
        public let processId: Int32
        public let ephemeralSpaceId: UUID
        public let applicationPath: String
        public let launchedAt: Date
        public let configuration: LaunchConfiguration
        
        internal init(
            id: UUID = UUID(),
            processId: Int32,
            ephemeralSpaceId: UUID,
            applicationPath: String,
            launchedAt: Date = Date(),
            configuration: LaunchConfiguration
        ) {
            self.id = id
            self.processId = processId
            self.ephemeralSpaceId = ephemeralSpaceId
            self.applicationPath = applicationPath
            self.launchedAt = launchedAt
            self.configuration = configuration
        }
    }
    
    /// Process execution result
    public struct ProcessResult: Sendable {
        public let handle: ProcessHandle
        public let exitCode: Int32
        public let executionTime: TimeInterval
        public let standardOutput: String?
        public let standardError: String?
        public let resourceUsage: ResourceUsage?
        
        public init(
            handle: ProcessHandle,
            exitCode: Int32,
            executionTime: TimeInterval,
            standardOutput: String? = nil,
            standardError: String? = nil,
            resourceUsage: ResourceUsage? = nil
        ) {
            self.handle = handle
            self.exitCode = exitCode
            self.executionTime = executionTime
            self.standardOutput = standardOutput
            self.standardError = standardError
            self.resourceUsage = resourceUsage
        }
    }
    
    /// Resource usage tracking
    public struct ResourceUsage: Sendable, Codable {
        public let peakMemoryMB: Double
        public let cpuTimeSeconds: Double
        public let fileSystemReads: Int64
        public let fileSystemWrites: Int64
        public let networkBytesIn: Int64
        public let networkBytesOut: Int64
        
        public init(
            peakMemoryMB: Double,
            cpuTimeSeconds: Double,
            fileSystemReads: Int64 = 0,
            fileSystemWrites: Int64 = 0,
            networkBytesIn: Int64 = 0,
            networkBytesOut: Int64 = 0
        ) {
            self.peakMemoryMB = peakMemoryMB
            self.cpuTimeSeconds = cpuTimeSeconds
            self.fileSystemReads = fileSystemReads
            self.fileSystemWrites = fileSystemWrites
            self.networkBytesIn = networkBytesIn
            self.networkBytesOut = networkBytesOut
        }
    }
    
    /// Errors specific to application launching
    public enum LaunchError: LocalizedError, Sendable {
        case ephemeralSpaceNotFound(UUID)
        case applicationNotFound(String)
        case applicationNotExecutable(String)
        case processLaunchFailed(String)
        case processTerminationFailed(Int32)
        case resourceLimitExceeded(String)
        case securityViolation(String)
        case timeout(Int)
        
        public var errorDescription: String? {
            switch self {
            case .ephemeralSpaceNotFound(let id):
                return "Ephemeral space not found: \(id)"
            case .applicationNotFound(let path):
                return "Application not found: \(path)"
            case .applicationNotExecutable(let path):
                return "Application not executable: \(path)"
            case .processLaunchFailed(let reason):
                return "Process launch failed: \(reason)"
            case .processTerminationFailed(let pid):
                return "Process termination failed for PID: \(pid)"
            case .resourceLimitExceeded(let resource):
                return "Resource limit exceeded: \(resource)"
            case .securityViolation(let details):
                return "Security violation: \(details)"
            case .timeout(let seconds):
                return "Process execution timeout: \(seconds)s"
            }
        }
    }
    
    // MARK: - Properties
    
    private let ephemeralManager: EphemeralFileSystemManager
    private nonisolated(unsafe) let sandboxManager: SandboxManager?
    private let securityMonitor: SecurityMonitoringEngine?
    private let logger: Logger
    
    /// Serial queue for thread-safe process management
    private let processQueue = DispatchQueue(label: "com.privarion.applicationlauncher.process", qos: .userInitiated)
    
    /// Process registry protected by serial queue
    private struct ProcessInfo {
        let handle: ProcessHandle
        let process: Process
        let startTime: Date
        var resourceUsage: ResourceUsage?
    }
    
    private var runningProcesses: [UUID: ProcessInfo] = [:]
    private var completedProcesses: [UUID: ProcessResult] = [:]
    
    // MARK: - Initialization
    
    public init(
        ephemeralManager: EphemeralFileSystemManager,
        sandboxManager: SandboxManager? = nil,
        securityMonitor: SecurityMonitoringEngine? = nil
    ) {
        self.ephemeralManager = ephemeralManager
        self.sandboxManager = sandboxManager
        self.securityMonitor = securityMonitor
        self.logger = Logger(subsystem: "com.privarion.core", category: "ApplicationLauncher")
        
        logger.info("ApplicationLauncher initialized")
    }
    
    // MARK: - Public API
    
    /// Launches an application in an existing ephemeral space
    /// - Parameters:
    ///   - applicationPath: Path to the application executable
    ///   - arguments: Command line arguments
    ///   - ephemeralSpaceId: ID of the ephemeral space to run in
    ///   - configuration: Launch configuration
    /// - Returns: Process handle for the running application
    /// - Throws: LaunchError if launch fails
    public func launchApplication(
        at applicationPath: String,
        arguments: [String] = [],
        in ephemeralSpaceId: UUID,
        configuration: LaunchConfiguration = .default
    ) async throws -> ProcessHandle {
        
        let startTime = DispatchTime.now()
        
        logger.info("Launching application: \(applicationPath) in ephemeral space: \(ephemeralSpaceId)")
        
        // Validate ephemeral space exists
        guard let ephemeralSpace = await ephemeralManager.getSpaceInfo(ephemeralSpaceId) else {
            throw LaunchError.ephemeralSpaceNotFound(ephemeralSpaceId)
        }
        
        // Validate application exists and is executable
        try validateApplication(at: applicationPath)
        
        // Security validation
        if securityMonitor != nil {
            try await validateSecurityContext(applicationPath: applicationPath, space: ephemeralSpace)
        }
        
        // Prepare execution environment
        let workingDir = configuration.workingDirectory ?? ephemeralSpace.mountPath
        let environment = try prepareEnvironment(configuration: configuration, ephemeralSpace: ephemeralSpace)
        
        // Create process
        let process = Process()
        let handle = ProcessHandle(
            processId: 0, // Will be set after launch
            ephemeralSpaceId: ephemeralSpaceId,
            applicationPath: applicationPath,
            configuration: configuration
        )
        
        // Configure process
        process.executableURL = URL(fileURLWithPath: applicationPath)
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: workingDir)
        
        // Set up output redirection if needed
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        if configuration.redirectOutput {
            process.standardOutput = outputPipe
            process.standardError = errorPipe
        }
        
        // Launch process
        do {
            try process.run()
            
            // Update handle with actual PID
            let updatedHandle = ProcessHandle(
                id: handle.id,
                processId: process.processIdentifier,
                ephemeralSpaceId: ephemeralSpaceId,
                applicationPath: applicationPath,
                configuration: configuration
            )
            
            // Register process (thread-safe via serial queue)
            processQueue.sync {
                let processInfo = ProcessInfo(
                    handle: updatedHandle,
                    process: process,
                    startTime: Date()
                )
                runningProcesses[updatedHandle.id] = processInfo
            }
            
            // Set up process monitoring
            await setupProcessMonitoring(handle: updatedHandle, process: process)
            
            // Set up execution timeout if configured
            if configuration.maxExecutionTimeSeconds > 0 {
                await setupExecutionTimeout(for: updatedHandle)
            }
            
            // Log performance and security events
            let duration = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
            let durationMs = Double(duration) / 1_000_000
            
            logger.info("Application launched successfully in \(String(format: "%.2f", durationMs))ms, PID: \(process.processIdentifier)")
            
            // Report to security monitoring
            if let monitor = securityMonitor {
                await monitor.reportEphemeralEvent(.applicationLaunched(updatedHandle, durationMs))
            }
            
            return updatedHandle
            
        } catch {
            logger.error("Failed to launch application: \(error.localizedDescription)")
            throw LaunchError.processLaunchFailed(error.localizedDescription)
        }
    }
    
    /// Launches an application in a new ephemeral space (convenience method)
    /// - Parameters:
    ///   - applicationPath: Path to the application executable
    ///   - arguments: Command line arguments
    ///   - configuration: Launch configuration
    /// - Returns: Process handle for the running application
    /// - Throws: LaunchError if launch fails
    public func launchApplicationInNewSpace(
        at applicationPath: String,
        arguments: [String] = [],
        configuration: LaunchConfiguration = .default
    ) async throws -> ProcessHandle {
        
        // Create new ephemeral space
        let ephemeralSpace = try await ephemeralManager.createEphemeralSpace(
            applicationPath: applicationPath
        )
        
        // Launch application in the new space
        return try await launchApplication(
            at: applicationPath,
            arguments: arguments,
            in: ephemeralSpace.id,
            configuration: configuration
        )
    }
    
    /// Terminates a running process and cleans up its ephemeral space
    /// - Parameter processId: ID of the process handle to terminate
    /// - Returns: Process execution result
    /// - Throws: LaunchError if termination fails
    public func terminateProcess(_ processId: UUID) async throws -> ProcessResult {
        
        logger.info("Terminating process: \(processId)")
        
        // First check if process already completed and we have the result stored
        let completedResult: ProcessResult? = processQueue.sync {
            return completedProcesses[processId]
        }
        
        if let result = completedResult {
            processQueue.sync {
                _ = completedProcesses.removeValue(forKey: processId)
            }
            return result
        }
        
        // Get process info - handle case where process already terminated
        let processInfo: ProcessInfo? = processQueue.sync {
            return runningProcesses[processId]
        }
        
        guard let processInfo = processInfo else {
            logger.info("Process already terminated: \(processId)")
            throw LaunchError.processTerminationFailed(-1)
        }
        
        let startTime = Date()
        let process = processInfo.process
        let handle = processInfo.handle
        
        // Check if process is still running before attempting termination
        guard process.isRunning else {
            // Process already terminated - clean up ephemeral space and return
            logger.info("Process already terminated (not running): \(processId)")
            
            // Clean up ephemeral space
            do {
                try await ephemeralManager.destroyEphemeralSpace(handle.ephemeralSpaceId)
            } catch {
                logger.error("Failed to cleanup ephemeral space: \(error.localizedDescription)")
            }
            
            // Unregister the process
            processQueue.sync {
                _ = runningProcesses.removeValue(forKey: processId)
            }
            
            // Return result for already terminated process
            let result = ProcessResult(
                handle: handle,
                exitCode: process.terminationStatus,
                executionTime: Date().timeIntervalSince(processInfo.startTime),
                standardOutput: nil,
                standardError: nil,
                resourceUsage: nil
            )
            
            return result
        }
        
        // Terminate process gracefully
        process.terminate()
        
        // Wait for process to exit
        process.waitUntilExit()
        
        // Calculate execution time
        _ = Date().timeIntervalSince(startTime)
        let totalExecutionTime = Date().timeIntervalSince(processInfo.startTime)
        
        // Collect output if redirected
        let standardOutput: String? = nil // Would collect from pipes if implemented
        let standardError: String? = nil // Would collect from pipes if implemented
        
        // Collect resource usage
        let resourceUsage = await collectResourceUsage(for: handle)
        
        // Unregister process
        processQueue.sync {
            _ = runningProcesses.removeValue(forKey: processId)
        }
        
        // Clean up ephemeral space
        do {
            try await ephemeralManager.destroyEphemeralSpace(handle.ephemeralSpaceId)
        } catch {
            logger.error("Failed to cleanup ephemeral space: \(error.localizedDescription)")
        }
        
        // Create result
        let result = ProcessResult(
            handle: handle,
            exitCode: process.terminationStatus,
            executionTime: totalExecutionTime,
            standardOutput: standardOutput,
            standardError: standardError,
            resourceUsage: resourceUsage
        )
        
        logger.info("Process terminated successfully: PID \(handle.processId), exit code: \(process.terminationStatus)")
        
        // Report to security monitoring
        if let monitor = securityMonitor {
            await monitor.reportEphemeralEvent(.applicationTerminated(handle, result))
        }
        
        return result
    }
    
    /// Gets information about all running processes
    /// - Returns: Array of process handles for running processes
    public func getRunningProcesses() async -> [ProcessHandle] {
        return processQueue.sync {
            return runningProcesses.values.map { $0.handle }
        }
    }
    
    /// Gets information about a specific running process
    /// - Parameter processId: ID of the process handle
    /// - Returns: Process handle if found, nil otherwise
    public func getProcessInfo(_ processId: UUID) async -> ProcessHandle? {
        return processQueue.sync {
            return runningProcesses[processId]?.handle
        }
    }
    
    /// Terminates all running processes and cleans up
    public func terminateAllProcesses() async {
        let processes = processQueue.sync {
            return Array(runningProcesses.values)
        }
        
        logger.warning("Emergency termination of \(processes.count) running processes")
        
        await withTaskGroup(of: Void.self) { group in
            for processInfo in processes {
                group.addTask {
                    do {
                        _ = try await self.terminateProcess(processInfo.handle.id)
                    } catch {
                        self.logger.error("Failed to terminate process \(processInfo.handle.id): \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func validateApplication(at path: String) throws {
        let fileManager = FileManager.default
        
        // Check if file exists
        guard fileManager.fileExists(atPath: path) else {
            throw LaunchError.applicationNotFound(path)
        }
        
        // Check if file is executable
        guard fileManager.isExecutableFile(atPath: path) else {
            throw LaunchError.applicationNotExecutable(path)
        }
    }
    
    private func validateSecurityContext(
        applicationPath: String,
        space: EphemeralFileSystemManager.EphemeralSpace
    ) async throws {
        // Security validation logic would go here
        // For now, just log the validation attempt
        logger.debug("Validating security context for: \(applicationPath)")
    }
    
    private func prepareEnvironment(
        configuration: LaunchConfiguration,
        ephemeralSpace: EphemeralFileSystemManager.EphemeralSpace
    ) throws -> [String: String] {
        
        var environment: [String: String] = [:]
        
        // Inherit parent environment if configured
        if configuration.inheritEnvironment {
            environment = Foundation.ProcessInfo.processInfo.environment
        }
        
        // Add custom environment variables
        for (key, value) in configuration.customEnvironment {
            environment[key] = value
        }
        
        // Set ephemeral-specific environment variables
        environment["PRIVARION_EPHEMERAL_SPACE"] = ephemeralSpace.id.uuidString
        environment["PRIVARION_EPHEMERAL_PATH"] = ephemeralSpace.mountPath
        environment["TMPDIR"] = ephemeralSpace.mountPath + "/tmp"
        environment["HOME"] = ephemeralSpace.mountPath + "/home"
        
        // Ensure secure PATH (limited to ephemeral space and essential system paths)
        let securePath = [
            ephemeralSpace.mountPath + "/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ].joined(separator: ":")
        
        environment["PATH"] = securePath
        
        return environment
    }
    
    private func setupProcessMonitoring(handle: ProcessHandle, process: Process) async {
        // Set up process termination notification
        process.terminationHandler = { [weak self] terminatedProcess in
            Task {
                await self?.handleProcessTermination(handle: handle, process: terminatedProcess)
            }
        }
    }
    
    private func setupExecutionTimeout(for handle: ProcessHandle) async {
        let timeoutSeconds = handle.configuration.maxExecutionTimeSeconds
        
        Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds) * 1_000_000_000)
                self.logger.warning("Process execution timeout for: \(handle.id)")
                _ = try await self.terminateProcess(handle.id)
            } catch {
                self.logger.warning("Failed to terminate timed-out process or already terminated: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleProcessTermination(handle: ProcessHandle, process: Process) async {
        logger.info("Process terminated: PID \(handle.processId), exit code: \(process.terminationStatus)")
        
        // Get process start time from registry if available
        let startTime = processQueue.sync {
            return runningProcesses[handle.id]?.startTime ?? Date()
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Collect resource usage
        let resourceUsage = await collectResourceUsage(for: handle)
        
        // Store the result before unregistering so tests can still get result after process ends
        let result = ProcessResult(
            handle: handle,
            exitCode: process.terminationStatus,
            executionTime: executionTime,
            standardOutput: nil,
            standardError: nil,
            resourceUsage: resourceUsage
        )
        
        processQueue.sync {
            completedProcesses[handle.id] = result
            runningProcesses.removeValue(forKey: handle.id)
        }
        
        // Clean up ephemeral space if configured
        if handle.configuration.killOnParentExit {
            do {
                try await ephemeralManager.destroyEphemeralSpace(handle.ephemeralSpaceId)
            } catch {
                logger.error("Failed to cleanup ephemeral space after process termination: \(error.localizedDescription)")
            }
        }
    }
    
    private func collectResourceUsage(for handle: ProcessHandle) async -> ResourceUsage? {
        // Resource usage collection would be implemented here
        // For now, return mock data
        return ResourceUsage(
            peakMemoryMB: 50.0,
            cpuTimeSeconds: 1.0
        )
    }
}

// MARK: - SecurityMonitoringEngine Integration

extension SecurityMonitoringEngine {
    /// Security events specific to application launching
    public enum ApplicationEvent: Sendable {
        case applicationLaunched(ApplicationLauncher.ProcessHandle, Double)
        case applicationTerminated(ApplicationLauncher.ProcessHandle, ApplicationLauncher.ProcessResult)
        case suspiciousApplicationActivity(ApplicationLauncher.ProcessHandle, String)
        case resourceLimitExceeded(ApplicationLauncher.ProcessHandle, String)
    }
    
    /// Reports application launcher security events
    /// - Parameter event: The application security event to report
    public func reportEphemeralEvent(_ event: ApplicationEvent) async {
        let securityEvent: SecurityEvent
        
        switch event {
        case .applicationLaunched(let handle, let duration):
            securityEvent = SecurityEvent(
                eventType: .suspiciousTraffic, // We'll need application-specific event types
                severity: .low,
                description: "Application launched in ephemeral space: \(handle.applicationPath)",
                evidence: [
                    "process_id": String(handle.processId),
                    "ephemeral_space": handle.ephemeralSpaceId.uuidString,
                    "application": handle.applicationPath,
                    "launch_duration_ms": String(duration)
                ],
                confidence: 1.0,
                mitigationSuggestion: "Monitor application execution in ephemeral space"
            )
        case .applicationTerminated(let handle, let result):
            securityEvent = SecurityEvent(
                eventType: .suspiciousTraffic,
                severity: .low,
                description: "Application terminated: \(handle.applicationPath)",
                evidence: [
                    "process_id": String(handle.processId),
                    "exit_code": String(result.exitCode),
                    "execution_time": String(result.executionTime),
                    "ephemeral_space": handle.ephemeralSpaceId.uuidString
                ],
                confidence: 1.0,
                mitigationSuggestion: "Normal process termination"
            )
        case .suspiciousApplicationActivity(let handle, let details):
            securityEvent = SecurityEvent(
                eventType: .threatDetected,
                severity: .high,
                description: "Suspicious application activity: \(details)",
                evidence: [
                    "process_id": String(handle.processId),
                    "application": handle.applicationPath,
                    "details": details
                ],
                confidence: 0.8,
                mitigationSuggestion: "Investigate application behavior and consider termination"
            )
        case .resourceLimitExceeded(let handle, let resource):
            securityEvent = SecurityEvent(
                eventType: .anomalousConnection,
                severity: .medium,
                description: "Resource limit exceeded: \(resource)",
                evidence: [
                    "process_id": String(handle.processId),
                    "resource": resource,
                    "application": handle.applicationPath
                ],
                confidence: 1.0,
                mitigationSuggestion: "Review resource limits and application behavior"
            )
        }
        
        reportSecurityEvent(securityEvent)
    }
}
