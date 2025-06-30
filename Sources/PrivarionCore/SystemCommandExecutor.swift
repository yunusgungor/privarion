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
        // NOTE: Removed sudo and launchctl due to security risks (privilege escalation)
        self.allowedCommands = Set([
            "ifconfig", "scutil", "system_profiler", "diskutil",
            "id", "whoami", "uname", "sysctl", "networksetup",
            "systemsetup", "pmset", "dscacheutil", "mdfind", "mdutil"
        ])
    }
    
    // MARK: - Public Methods
    
    /// Execute a system command with arguments
    /// Uses Swift Foundation Process for secure subprocess management
    public func executeCommand(_ command: String, arguments: [String] = []) async throws -> CommandResult {
        let startTime = Date()
        
        // Validate command is allowed
        guard allowedCommands.contains(command) else {
            logger.error("Unauthorized command attempted: \(command)")
            throw ExecutorError.unauthorizedCommand
        }
        
        // Validate and sanitize arguments to prevent command injection
        let sanitizedArguments = try validateAndSanitizeArguments(arguments)
        
        // Validate command exists
        let commandPath = try await findCommandPath(command)
        
        logger.debug("Executing command: \(command) \(sanitizedArguments.joined(separator: " "))")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: commandPath)
        process.arguments = sanitizedArguments
        
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
        
        // Wait for completion with timeout using Task cancellation
        let result = try await withThrowingTaskGroup(of: CommandResult.self) { group in
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.timeoutInterval * 1_000_000_000))
                throw ExecutorError.executionTimeout
            }
            
            // Add process execution task
            group.addTask {
                return try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        process.waitUntilExit()
                        
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
                        
                        continuation.resume(returning: result)
                    }
                }
            }
            
            // Wait for first completion and cancel others
            let result = try await group.next()!
            group.cancelAll()
            
            // Terminate process if it's still running
            if process.isRunning {
                process.terminate()
            }
            
            return result
        }
        
        // Log result
        if result.isSuccess {
            logger.debug("Command completed successfully in \(String(format: "%.3f", result.executionTime))s")
        } else {
            logger.warning("Command failed with exit code \(result.exitCode)")
            if let stderr = result.standardError {
                logger.warning("Error output: \(stderr)")
            }
        }
        
        return result
    }
    
    /// Execute command with elevated privileges (DISABLED FOR SECURITY)
    public func executeElevatedCommand(_ command: String, arguments: [String] = []) async throws -> CommandResult {
        logger.error("Elevated command execution disabled for security reasons: \(command)")
        throw ExecutorError.unauthorizedCommand
    }
    
    /// Execute multiple commands in sequence
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
    
    /// Find the full path of a command
    private func findCommandPath(_ command: String) async throws -> String {
        // Try common system paths first - this is much faster than using 'which'
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
        
        // If not found in standard paths, use PATH environment variable
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let paths = pathEnv.components(separatedBy: ":")
            for pathDir in paths {
                let fullPath = "\(pathDir)/\(command)"
                if FileManager.default.isExecutableFile(atPath: fullPath) {
                    return fullPath
                }
            }
        }
        
        throw ExecutorError.commandNotFound
    }
    
    /// Validate and sanitize command arguments to prevent injection attacks
    private func validateAndSanitizeArguments(_ arguments: [String]) throws -> [String] {
        let dangerousChars = CharacterSet(charactersIn: ";|&$`()<>\"'\\")
        let maxArgumentLength = 1024
        
        return try arguments.map { arg in
            // Check for dangerous characters
            if arg.rangeOfCharacter(from: dangerousChars) != nil {
                logger.error("Dangerous characters detected in argument: \(arg)")
                throw ExecutorError.invalidArguments
            }
            
            // Check argument length
            if arg.count > maxArgumentLength {
                logger.error("Argument too long: \(arg.count) characters")
                throw ExecutorError.invalidArguments
            }
            
            // Remove any null bytes
            let sanitized = arg.replacingOccurrences(of: "\0", with: "")
            
            return sanitized
        }
    }
}

// MARK: - Extensions

extension SystemCommandExecutor {
    
    /// Convenience method for network-related commands
    public func executeNetworkCommand(_ command: String, arguments: [String] = []) async throws -> CommandResult {
        let networkCommands = ["ifconfig", "networksetup", "scutil", "dscacheutil"]
        
        guard networkCommands.contains(command) else {
            throw ExecutorError.unauthorizedCommand
        }
        
        return try await executeCommand(command, arguments: arguments)
    }
    
    /// Convenience method for system information commands
    public func executeSystemInfoCommand(_ command: String, arguments: [String] = []) async throws -> CommandResult {
        let systemInfoCommands = ["system_profiler", "diskutil", "sysctl", "uname"]
        
        guard systemInfoCommands.contains(command) else {
            throw ExecutorError.unauthorizedCommand
        }
        
        return try await executeCommand(command, arguments: arguments)
    }
}
