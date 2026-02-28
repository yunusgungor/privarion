// PrivarionSystemExtension - SystemExtensionLifecycleLogger
// Logs system extension lifecycle events to /var/log/privarion/system-extension.log
// Requirements: 1.8, 17.1

import Foundation
import Logging

/// Logs system extension lifecycle events to the designated log file
/// Implements the SystemExtensionLifecycle protocol to capture all lifecycle events
public class SystemExtensionLifecycleLogger: SystemExtensionLifecycle {
    private let logger: Logger
    private let fileLogger: FileLogger
    
    /// Initialize the lifecycle logger
    /// - Parameter extensionIdentifier: The identifier of the system extension
    public init(extensionIdentifier: String = "com.privarion.system-extension") {
        self.logger = Logger(label: "com.privarion.system-extension.lifecycle")
        self.fileLogger = FileLogger(logFilePath: "/var/log/privarion/system-extension.log")
    }
    
    /// Log willActivate event
    public func willActivate() async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let message = "[\(timestamp)] System Extension lifecycle: willActivate - Extension is preparing to activate"
        
        logger.info("System Extension lifecycle: willActivate")
        fileLogger.log(message)
    }
    
    /// Log didActivate event
    public func didActivate() async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let message = "[\(timestamp)] System Extension lifecycle: didActivate - Extension has successfully activated"
        
        logger.info("System Extension lifecycle: didActivate")
        fileLogger.log(message)
    }
    
    /// Log willDeactivate event
    public func willDeactivate() async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let message = "[\(timestamp)] System Extension lifecycle: willDeactivate - Extension is preparing to deactivate"
        
        logger.info("System Extension lifecycle: willDeactivate")
        fileLogger.log(message)
    }
    
    /// Log didDeactivate event
    public func didDeactivate() async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let message = "[\(timestamp)] System Extension lifecycle: didDeactivate - Extension has successfully deactivated"
        
        logger.info("System Extension lifecycle: didDeactivate")
        fileLogger.log(message)
    }
    
    /// Log didFailWithError event
    /// - Parameter error: The error that occurred
    public func didFailWithError(_ error: Error) async {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let errorDescription = error.localizedDescription
        let message = "[\(timestamp)] System Extension lifecycle: didFailWithError - Error: \(errorDescription)"
        
        logger.error("System Extension lifecycle: didFailWithError", metadata: [
            "error": .string(errorDescription)
        ])
        fileLogger.log(message)
    }
}

/// File logger for writing lifecycle events to disk
internal class FileLogger {
    private let logFilePath: String
    private let fileManager = FileManager.default
    private let logQueue = DispatchQueue(label: "com.privarion.system-extension.file-logger", qos: .utility)
    
    /// Initialize file logger with log file path
    /// - Parameter logFilePath: Path to the log file
    init(logFilePath: String) {
        self.logFilePath = logFilePath
        createLogDirectoryIfNeeded()
    }
    
    /// Create log directory if it doesn't exist
    private func createLogDirectoryIfNeeded() {
        let logDirectory = URL(fileURLWithPath: logFilePath).deletingLastPathComponent()
        
        guard !fileManager.fileExists(atPath: logDirectory.path) else {
            return
        }
        
        do {
            try fileManager.createDirectory(
                at: logDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            // If we can't create /var/log/privarion/, fall back to user's home directory
            print("Warning: Could not create log directory at \(logDirectory.path): \(error.localizedDescription)")
        }
    }
    
    /// Log a message to the file
    /// - Parameter message: The message to log
    func log(_ message: String) {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            
            let messageWithNewline = message + "\n"
            
            guard let data = messageWithNewline.data(using: .utf8) else {
                return
            }
            
            // Check if file exists
            if self.fileManager.fileExists(atPath: self.logFilePath) {
                // Append to existing file
                if let fileHandle = FileHandle(forWritingAtPath: self.logFilePath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // Create new file
                do {
                    try data.write(to: URL(fileURLWithPath: self.logFilePath), options: .atomic)
                } catch {
                    // If we can't write to /var/log/privarion/, try user's home directory
                    let fallbackPath = NSHomeDirectory() + "/Library/Logs/Privarion/system-extension.log"
                    let fallbackDirectory = URL(fileURLWithPath: fallbackPath).deletingLastPathComponent()
                    
                    try? self.fileManager.createDirectory(
                        at: fallbackDirectory,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                    
                    try? data.write(to: URL(fileURLWithPath: fallbackPath), options: .atomic)
                }
            }
        }
    }
    
    /// Create a log handler for the swift-log framework
    /// - Parameter label: The logger label
    /// - Returns: A log handler that writes to the file
    func makeHandler(label: String) -> LogHandler {
        return FileLogHandler(label: label, fileLogger: self)
    }
}

/// Log handler that writes to file
internal struct FileLogHandler: LogHandler {
    private let label: String
    private let fileLogger: FileLogger
    
    var logLevel: Logger.Level = .info
    var metadata: Logger.Metadata = [:]
    
    init(label: String, fileLogger: FileLogger) {
        self.label = label
        self.fileLogger = fileLogger
    }
    
    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let levelString = level.rawValue.uppercased()
        let metadataString = metadata?.isEmpty == false ? " \(metadata!)" : ""
        let logMessage = "[\(timestamp)] [\(levelString)] [\(label)] \(message)\(metadataString)"
        
        fileLogger.log(logMessage)
    }
    
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
}

/// Multiplexes log output to multiple handlers
internal struct MultiplexLogHandler: LogHandler {
    private var handlers: [LogHandler]
    
    var logLevel: Logger.Level {
        get { handlers.first?.logLevel ?? .info }
        set {
            for i in handlers.indices {
                handlers[i].logLevel = newValue
            }
        }
    }
    
    var metadata: Logger.Metadata {
        get { handlers.first?.metadata ?? [:] }
        set {
            for i in handlers.indices {
                handlers[i].metadata = newValue
            }
        }
    }
    
    init(_ handlers: [LogHandler]) {
        self.handlers = handlers
    }
    
    func log(level: Logger.Level,
             message: Logger.Message,
             metadata: Logger.Metadata?,
             source: String,
             file: String,
             function: String,
             line: UInt) {
        for handler in handlers {
            let mutableHandler = handler
            mutableHandler.log(
                level: level,
                message: message,
                metadata: metadata,
                source: source,
                file: file,
                function: function,
                line: line
            )
        }
    }
    
    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { handlers.first?[metadataKey: key] }
        set {
            for i in handlers.indices {
                handlers[i][metadataKey: key] = newValue
            }
        }
    }
}
