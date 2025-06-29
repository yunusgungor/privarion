import Foundation
import Logging

/// Structured logging system for Privarion
public class PrivarionLogger {
    
    /// Shared logger instance
    public static let shared = PrivarionLogger()
    
    /// Internal logger
    private var logger: Logger
    
    /// Log file handler
    private var logFileHandler: LogFileHandler?
    
    /// Flag to prevent multiple bootstrap calls
    private static var isBootstrapped = false
    
    /// Check if running in test environment
    private static var isTestEnvironment: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
               ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
               ProcessInfo.processInfo.arguments.contains { $0.contains("xctest") }
    }
    
    /// Initialization
    private init() {
        // Initialize with default label
        self.logger = Logger(label: "privarion.system")
        
        // Setup log handlers only once and avoid in test environment
        if !Self.isBootstrapped && !Self.isTestEnvironment {
            setupLogHandlers()
            Self.isBootstrapped = true
        } else if Self.isTestEnvironment {
            // In test environment, use a simple console logger
            self.logger = Logger(label: "privarion.test")
        }
    }
    
    /// Setup log handlers based on configuration
    private func setupLogHandlers() {
        // Skip setup if already bootstrapped to avoid conflicts in tests
        if Self.isBootstrapped || Self.isTestEnvironment {
            return
        }
        
        let config = ConfigurationManager.shared.getCurrentConfiguration()
        
        // Setup file logging if possible, otherwise use console only
        setupFileLogging(config: config)
    }
    
    /// Setup file logging with rotation
    private func setupFileLogging(config: PrivarionConfig) {
        let logDirectory = expandPath(config.global.logDirectory)
        
        do {
            // Create log directory
            try FileManager.default.createDirectory(
                at: logDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            
            // Setup file handler
            logFileHandler = LogFileHandler(
                directory: logDirectory,
                maxFileSizeMB: config.global.maxLogSizeMB,
                rotationCount: config.global.logRotationCount
            )
            
            // Setup unified logging system with both console and file output
            LoggingSystem.bootstrap { label in
                var consoleHandler = StreamLogHandler.standardOutput(label: label)
                consoleHandler.logLevel = config.global.logLevel.swiftLogLevel
                
                return MultiplexLogHandler([
                    consoleHandler,
                    PrivarionFileLogHandler(
                        label: label,
                        fileHandler: self.logFileHandler!
                    )
                ])
            }
            
        } catch {
            // Fallback to console logging only
            LoggingSystem.bootstrap { label in
                var handler = StreamLogHandler.standardOutput(label: label)
                handler.logLevel = config.global.logLevel.swiftLogLevel
                return handler
            }
            
            // Create a temporary logger for error reporting
            let tempLogger = Logger(label: "privarion.logger")
            tempLogger.error("Failed to setup file logging", metadata: [
                "error": .string(error.localizedDescription),
                "directory": .string(logDirectory.path)
            ])
        }
    }
    
    /// Expand path with tilde
    private func expandPath(_ path: String) -> URL {
        if path.hasPrefix("~") {
            let expandedPath = NSString(string: path).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath)
        }
        return URL(fileURLWithPath: path)
    }
    
    /// Get logger for specific component
    public func logger(for component: String) -> Logger {
        return Logger(label: "privarion.\(component)")
    }
    
    /// Update log level
    public func updateLogLevel(_ level: LogLevel) {
        logger.logLevel = level.swiftLogLevel
    }
    
    /// Force log rotation
    public func rotateLog() {
        logFileHandler?.rotateLog()
    }
    
    /// Get log statistics
    public func getLogStatistics() -> LogStatistics {
        return LogStatistics(
            currentLogSize: logFileHandler?.getCurrentLogSize() ?? 0,
            totalLogFiles: logFileHandler?.getLogFileCount() ?? 0,
            lastRotationDate: logFileHandler?.getLastRotationDate()
        )
    }
}

/// Log statistics
public struct LogStatistics {
    public let currentLogSize: Int
    public let totalLogFiles: Int
    public let lastRotationDate: Date?
}

/// File log handler with rotation
private class LogFileHandler {
    private let directory: URL
    private let maxFileSizeBytes: Int
    private let rotationCount: Int
    private var currentLogFile: URL
    private var fileHandle: FileHandle?
    private let queue = DispatchQueue(label: "privarion.log.file", qos: .utility)
    
    init(directory: URL, maxFileSizeMB: Int, rotationCount: Int) {
        self.directory = directory
        self.maxFileSizeBytes = maxFileSizeMB * 1024 * 1024
        self.rotationCount = rotationCount
        self.currentLogFile = directory.appendingPathComponent("privarion.log")
        
        openCurrentLogFile()
    }
    
    deinit {
        fileHandle?.closeFile()
    }
    
    func writeLog(_ data: Data) {
        queue.async { [weak self] in
            self?.performWrite(data)
        }
    }
    
    private func performWrite(_ data: Data) {
        // Check if rotation is needed
        if shouldRotate() {
            rotateLog()
        }
        
        // Write to current log file
        fileHandle?.write(data)
    }
    
    private func shouldRotate() -> Bool {
        guard let fileHandle = fileHandle else { return false }
        
        do {
            let currentSize = try fileHandle.seekToEnd()
            return currentSize >= maxFileSizeBytes
        } catch {
            return false
        }
    }
    
    func rotateLog() {
        // Close current file
        fileHandle?.closeFile()
        
        // Rotate existing files
        for i in (1..<rotationCount).reversed() {
            let currentFile = directory.appendingPathComponent("privarion.log.\(i)")
            let nextFile = directory.appendingPathComponent("privarion.log.\(i + 1)")
            
            if FileManager.default.fileExists(atPath: currentFile.path) {
                try? FileManager.default.moveItem(at: currentFile, to: nextFile)
            }
        }
        
        // Move current log to .1
        let firstRotatedFile = directory.appendingPathComponent("privarion.log.1")
        if FileManager.default.fileExists(atPath: currentLogFile.path) {
            try? FileManager.default.moveItem(at: currentLogFile, to: firstRotatedFile)
        }
        
        // Remove oldest file if exists
        let oldestFile = directory.appendingPathComponent("privarion.log.\(rotationCount)")
        if FileManager.default.fileExists(atPath: oldestFile.path) {
            try? FileManager.default.removeItem(at: oldestFile)
        }
        
        // Open new current log file
        openCurrentLogFile()
    }
    
    private func openCurrentLogFile() {
        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: currentLogFile.path) {
            FileManager.default.createFile(atPath: currentLogFile.path, contents: nil, attributes: [
                .posixPermissions: 0o600
            ])
        }
        
        fileHandle = FileHandle(forWritingAtPath: currentLogFile.path)
        fileHandle?.seekToEndOfFile()
    }
    
    func getCurrentLogSize() -> Int {
        guard let fileHandle = fileHandle else { return 0 }
        
        do {
            let currentPosition = fileHandle.offsetInFile
            let size = try fileHandle.seekToEnd()
            fileHandle.seek(toFileOffset: currentPosition)
            return Int(size)
        } catch {
            return 0
        }
    }
    
    func getLogFileCount() -> Int {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            return files.filter { $0.lastPathComponent.hasPrefix("privarion.log") }.count
        } catch {
            return 0
        }
    }
    
    func getLastRotationDate() -> Date? {
        let rotatedFile = directory.appendingPathComponent("privarion.log.1")
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: rotatedFile.path)
            return attributes[.creationDate] as? Date
        } catch {
            return nil
        }
    }
}

/// Custom file log handler for swift-log
private struct PrivarionFileLogHandler: LogHandler {
    private let label: String
    private let fileHandler: LogFileHandler
    
    public var logLevel: Logger.Level = .info
    public var metadata: Logger.Metadata = [:]
    
    init(label: String, fileHandler: LogFileHandler) {
        self.label = label
        self.fileHandler = fileHandler
    }
    
    public subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
    
    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        let combinedMetadata = self.metadata.merging(metadata ?? [:]) { _, new in new }
        
        let logEntry: [String: Any] = [
            "timestamp": timestamp,
            "level": level.rawValue,
            "message": message.description,
            "source": source,
            "metadata": combinedMetadata.mapValues { $0.description }
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: logEntry, options: [])
            var dataWithNewline = jsonData
            dataWithNewline.append("\n".data(using: .utf8)!)
            
            fileHandler.writeLog(dataWithNewline)
        } catch {
            // Fallback to simple string format
            let simpleLog = "[\(timestamp)] \(level.rawValue.uppercased()): \(message)\n"
            if let data = simpleLog.data(using: .utf8) {
                fileHandler.writeLog(data)
            }
        }
    }
}
