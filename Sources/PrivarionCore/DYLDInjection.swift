// DYLD Injection Manager for Privarion Hook System
// Manages DYLD_INSERT_LIBRARIES injection for target applications

import Foundation
import os.log

/// DYLD Injection result codes
public enum DYLDInjectionResult {
    case success
    case sipEnabled
    case targetNotFound
    case permissionDenied
    case injectionFailed
    case targetAlreadyRunning
    case hookLibraryNotFound
}

/// DYLD Injection Manager
/// Handles injection of Privarion hook library into target applications
public class DYLDInjectionManager {
    
    private let logger = Logger(subsystem: "com.privarion.core", category: "DYLDInjection")
    private let configuration: ConfigurationManager
    
    /// Path to the Privarion hook dynamic library
    private var hookLibraryPath: String {
        // Use configurable path from configuration, with secure fallback
        if let configPath = configuration.hookLibraryPath,
           FileManager.default.fileExists(atPath: configPath) {
            return configPath
        }
        
        // Secure fallback: Check bundle resources first
        if let bundlePath = Bundle.main.path(forResource: "libprivarion_hook", ofType: "dylib") {
            return bundlePath
        }
        
        // Last resort: system library path (validate existence)
        let systemPath = "/usr/local/lib/libprivarion_hook.dylib"
        guard FileManager.default.fileExists(atPath: systemPath) else {
            logger.error("Hook library not found at any expected location")
            return ""
        }
        return systemPath
    }
    
    public init(configuration: ConfigurationManager) {
        self.configuration = configuration
    }
    
    /// Check if System Integrity Protection (SIP) is enabled
    /// SIP prevents DYLD injection into system applications
    public func checkSIPStatus() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/csrutil"
        task.arguments = ["status"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            logger.debug("SIP status check output: \(output)")
            
            // SIP is disabled if output contains "disabled"
            return !output.lowercased().contains("disabled")
        } catch {
            logger.error("Failed to check SIP status: \(error.localizedDescription)")
            // Assume SIP is enabled if we can't determine status
            return true
        }
    }
    
    /// Verify hook library exists and is accessible
    private func validateHookLibrary() -> Bool {
        let fileManager = FileManager.default
        
        // Check if library file exists
        guard fileManager.fileExists(atPath: self.hookLibraryPath) else {
            logger.error("Hook library not found at path: \(self.hookLibraryPath)")
            return false
        }
        
        // Check if library is readable
        guard fileManager.isReadableFile(atPath: self.hookLibraryPath) else {
            logger.error("Hook library is not readable: \(self.hookLibraryPath)")
            return false
        }
        
        logger.debug("Hook library validated at: \(self.hookLibraryPath)")
        return true
    }
    
    /// Launch target application with DYLD injection
    /// - Parameters:
    ///   - applicationPath: Path to the target application
    ///   - arguments: Arguments to pass to the application
    ///   - environment: Additional environment variables
    /// - Returns: DYLDInjectionResult indicating success or failure reason
    public func launchWithInjection(
        applicationPath: String,
        arguments: [String] = [],
        environment: [String: String] = [:]
    ) -> DYLDInjectionResult {
        
        logger.info("Attempting DYLD injection for application: \(applicationPath)")
        
        // Pre-flight checks
        if checkSIPStatus() {
            logger.warning("SIP is enabled - injection may fail for system applications")
            // Don't block injection, but warn user
        }
        
        guard validateHookLibrary() else {
            return .hookLibraryNotFound
        }
        
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: applicationPath) else {
            logger.error("Target application not found: \(applicationPath)")
            return .targetNotFound
        }
        
        // Check if target is already running (optional check)
        if isApplicationRunning(applicationPath) {
            logger.warning("Target application is already running: \(applicationPath)")
            // Continue with injection anyway
        }
        
        // Setup environment for injection
        var injectionEnvironment = environment
        
        // Add DYLD_INSERT_LIBRARIES
        if let existingLibraries = injectionEnvironment["DYLD_INSERT_LIBRARIES"] {
            injectionEnvironment["DYLD_INSERT_LIBRARIES"] = "\(existingLibraries):\(hookLibraryPath)"
        } else {
            injectionEnvironment["DYLD_INSERT_LIBRARIES"] = hookLibraryPath
        }
        
        // Enable debug logging if configured (check log level)
        let currentConfig = configuration.getCurrentConfiguration()
        if currentConfig.global.logLevel == .debug {
            injectionEnvironment["PRIVARION_DEBUG"] = "1"
        }
        
        // Launch the application
        do {
            let result = try launchApplicationWithEnvironment(
                applicationPath: applicationPath,
                arguments: arguments,
                environment: injectionEnvironment
            )
            
            if result {
                logger.info("Successfully launched application with DYLD injection: \(applicationPath)")
                return .success
            } else {
                logger.error("Failed to launch application with injection: \(applicationPath)")
                return .injectionFailed
            }
            
        } catch {
            logger.error("Exception during application launch: \(error.localizedDescription)")
            return .injectionFailed
        }
    }
    
    /// Launch application with custom environment
    private func launchApplicationWithEnvironment(
        applicationPath: String,
        arguments: [String],
        environment: [String: String]
    ) throws -> Bool {
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: applicationPath)
        task.arguments = arguments
        
        // Merge with current environment
        var processEnvironment = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            processEnvironment[key] = value
        }
        task.environment = processEnvironment
        
        logger.debug("Launching with environment: DYLD_INSERT_LIBRARIES=\(environment["DYLD_INSERT_LIBRARIES"] ?? "none")")
        
        try task.run()
        
        // Don't wait for completion as the application should run independently
        // task.waitUntilExit()
        
        return task.isRunning
    }
    
    /// Check if an application is currently running
    private func isApplicationRunning(_ applicationPath: String) -> Bool {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-ax"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let applicationName = URL(fileURLWithPath: applicationPath).lastPathComponent
            return output.contains(applicationName)
            
        } catch {
            logger.error("Failed to check running applications: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Create DYLD injection command for manual execution
    /// Useful for debugging and testing
    public func generateInjectionCommand(
        applicationPath: String,
        arguments: [String] = []
    ) -> String {
        
        guard validateHookLibrary() else {
            return "# Error: Hook library not found at \(hookLibraryPath)"
        }
        
        var command = "DYLD_INSERT_LIBRARIES=\(hookLibraryPath) "
        
        if configuration.getCurrentConfiguration().global.logLevel == .debug {
            command += "PRIVARION_DEBUG=1 "
        }
        
        command += "\"\(applicationPath)\""
        
        if !arguments.isEmpty {
            command += " " + arguments.map { "\"\($0)\"" }.joined(separator: " ")
        }
        
        return command
    }
    
    /// Get information about injection capability
    public func getInjectionInfo() -> [String: Any] {
        return [
            "hook_library_path": hookLibraryPath,
            "hook_library_exists": validateHookLibrary(),
            "sip_enabled": checkSIPStatus(),
            "injection_supported": true // macOS always supports DYLD injection
        ]
    }
}

/// Extension for result descriptions
extension DYLDInjectionResult {
    public var description: String {
        switch self {
        case .success:
            return "DYLD injection successful"
        case .sipEnabled:
            return "System Integrity Protection (SIP) may prevent injection"
        case .targetNotFound:
            return "Target application not found"
        case .permissionDenied:
            return "Permission denied for injection"
        case .injectionFailed:
            return "DYLD injection failed"
        case .targetAlreadyRunning:
            return "Target application is already running"
        case .hookLibraryNotFound:
            return "Privarion hook library not found"
        }
    }
}
