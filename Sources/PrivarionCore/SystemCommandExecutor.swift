import Foundation

/// Secure system command executor with logging and validation
/// Uses Swift Foundation Process for subprocess management
public class SystemCommandExecutor {
    
    // MARK: - Types
    
    public struct CommandResult {
        public let standardOutput: String?
        public let standardError: String?
        public let exitCode: Int32
        public let executionTime: TimeInterval
        
        public var isSuccess: Bool {
            return exitCode == 0
        }
    }
    
    public enum ExecutorError: Error, LocalizedError {
        case commandNotFound
        case executionTimeout
        case unauthorizedCommand
        case invalidArguments
        case processLaunchFailed
        
        public var errorDescription: String? {
            switch self {
            case .commandNotFound:
                return "Command not found in system PATH"
            case .executionTimeout:
                return "Command execution timed out"
            case .unauthorizedCommand:
                return "Command not authorized for execution"
            case .invalidArguments:
                return "Invalid command arguments provided"
            case .processLaunchFailed:
                return "Failed to launch process"
            }
        }
    }
    
    // MARK: - Properties
    
    private let logger: PrivarionLogger
    private let timeoutInterval: TimeInterval
    private let allowedCommands: Set<String>
    
    // MARK: - Initialization
    
    public init(logger: PrivarionLogger, timeoutInterval: TimeInterval = 30.0) {
        self.logger = logger
        self.timeoutInterval = timeoutInterval
        
        // Whitelist of allowed system commands for security
        self.allowedCommands = Set([
            "ifconfig", "scutil", "system_profiler", "diskutil",
            "id", "whoami", "uname", "sysctl", "networksetup",
            "sudo", "launchctl", "systemsetup", "pmset",
            "dscacheutil", "mdfind", "mdutil"
        ])
    }
    
    // MARK: - Public Methods
    
    /// Execute a system command with arguments
    /// Uses Swift Foundation Process for secure subprocess management
    @MainActor
    public func executeCommand(_ command: String, arguments: [String] = []) async throws -> CommandResult {
        let startTime = Date()
        
        // Validate command is allowed
        guard allowedCommands.contains(command) else {
            logger.error("Unauthorized command attempted: \(command)")
            throw ExecutorError.unauthorizedCommand
        }
        
        // Validate command exists
        let commandPath = try await findCommandPath(command)
        
        logger.debug("Executing command: \(command) \(arguments.joined(separator: " "))")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: commandPath)
        process.arguments = arguments
        
        // Setup pipes for output capture
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Launch process with timeout handling
        do {
            try process.run()
        } catch {
            logger.error("Failed to launch process: \(error)")
            throw ExecutorError.processLaunchFailed
        }
        
        // Wait for completion with timeout
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(timeoutInterval * 1_000_000_000))
            if process.isRunning {
                process.terminate()
                throw ExecutorError.executionTimeout
            }
        }
        
        // Wait for process completion
        let completionTask = Task {
            process.waitUntilExit()
        }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await timeoutTask.value }
            group.addTask { await completionTask.value }
            
            // Wait for first completion (either timeout or normal completion)
            try await group.next()
            group.cancelAll()
        }
        
        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        let standardOutput = outputData.isEmpty ? nil : String(data: outputData, encoding: .utf8)
        let standardError = errorData.isEmpty ? nil : String(data: errorData, encoding: .utf8)
        
        let executionTime = Date().timeIntervalSince(startTime)
        let result = CommandResult(
            standardOutput: standardOutput,
            standardError: standardError,
            exitCode: process.terminationStatus,
            executionTime: executionTime
        )
        
        // Log result
        if result.isSuccess {
            logger.debug("Command completed successfully in \(String(format: "%.3f", executionTime))s")
        } else {
            logger.warning("Command failed with exit code \(result.exitCode)")
            if let stderr = standardError {
                logger.warning("Error output: \(stderr)")
            }
        }
        
        return result
    }
    
    /// Execute command with elevated privileges (sudo)
    @MainActor
    public func executeElevatedCommand(_ command: String, arguments: [String] = []) async throws -> CommandResult {
        // Prepend sudo to the command
        var sudoArguments = [command]
        sudoArguments.append(contentsOf: arguments)
        
        return try await executeCommand("sudo", arguments: sudoArguments)
    }
    
    /// Execute multiple commands in sequence
    @MainActor
    public func executeCommandSequence(_ commands: [(command: String, arguments: [String])]) async throws -> [CommandResult] {
        var results: [CommandResult] = []
        
        for (command, arguments) in commands {
            let result = try await executeCommand(command, arguments: arguments)
            results.append(result)
            
            // Stop on first failure unless configured otherwise
            if !result.isSuccess {
                logger.warning("Command sequence stopped due to failure: \(command)")
                break
            }
        }
        
        return results
    }
    
    /// Check if a command is available in the system
    public func isCommandAvailable(_ command: String) async -> Bool {
        do {
            _ = try await findCommandPath(command)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func findCommandPath(_ command: String) async throws -> String {
        // Try common system paths
        let systemPaths = [
            "/usr/bin/\(command)",
            "/bin/\(command)",
            "/usr/sbin/\(command)",
            "/sbin/\(command)",
            "/usr/local/bin/\(command)"
        ]
        
        for path in systemPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Use 'which' command as fallback
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !path.isEmpty {
                        return path
                    }
                }
            }
        } catch {
            logger.debug("Failed to find command \(command) using 'which': \(error)")
        }
        
        throw ExecutorError.commandNotFound
    }
}

// MARK: - Extensions

extension SystemCommandExecutor {
    
    /// Convenience method for network-related commands
    @MainActor
    public func executeNetworkCommand(_ command: String, arguments: [String] = []) async throws -> CommandResult {
        let networkCommands = ["ifconfig", "networksetup", "scutil", "dscacheutil"]
        
        guard networkCommands.contains(command) else {
            throw ExecutorError.unauthorizedCommand
        }
        
        return try await executeCommand(command, arguments: arguments)
    }
    
    /// Convenience method for system information commands
    @MainActor
    public func executeSystemInfoCommand(_ command: String, arguments: [String] = []) async throws -> CommandResult {
        let systemInfoCommands = ["system_profiler", "diskutil", "sysctl", "uname"]
        
        guard systemInfoCommands.contains(command) else {
            throw ExecutorError.unauthorizedCommand
        }
        
        return try await executeCommand(command, arguments: arguments)
    }
}
