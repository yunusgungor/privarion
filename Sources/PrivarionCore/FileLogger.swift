// PrivarionCore - FileLogger
// File logging infrastructure for DNS proxy and network components
// Requirements: 4.10, 17.3, 17.5

import Foundation
import Logging

/// File logger for writing DNS and network events to disk
/// Logs to /var/log/privarion/network-extension.log with fallback to user directory
@available(macOS 10.14, *)
internal class FileLogger {
    private let logFilePath: String
    private let fileManager = FileManager.default
    private let logQueue = DispatchQueue(label: "com.privarion.file-logger", qos: .utility)
    
    /// Initialize file logger with log file path
    /// - Parameter logFilePath: Path to the log file (default: /var/log/privarion/network-extension.log)
    init(logFilePath: String = "/var/log/privarion/network-extension.log") {
        self.logFilePath = logFilePath
        createLogDirectoryIfNeeded()
    }
    
    /// Create log directory if it doesn't exist
    /// Falls back to user's home directory if /var/log/privarion/ is not writable
    /// - Requirement: 17.10
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
    /// - Requirement: 17.3, 17.5
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
                    // If we can't write to /var/log/privarion/, try user's home directory (Requirement 17.10)
                    let fallbackPath = NSHomeDirectory() + "/Library/Logs/Privarion/network-extension.log"
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
    
    /// Log a DNS query event with structured information
    /// - Parameters:
    ///   - domain: The queried domain
    ///   - action: Action taken (blocked, allowed, faked)
    ///   - reason: Reason for the action
    ///   - processInfo: Optional process information
    ///   - queryType: DNS query type
    /// - Requirement: 4.10, 17.5
    func logDNSQuery(
        domain: String,
        action: String,
        reason: String,
        processInfo: String? = nil,
        queryType: UInt16? = nil
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let processString = processInfo.map { " process=\($0)" } ?? ""
        let typeString = queryType.map { " type=\($0)" } ?? ""
        let logMessage = "[\(timestamp)] DNS query: domain=\(domain) action=\(action) reason=\(reason)\(typeString)\(processString)"
        
        log(logMessage)
    }
    
    /// Log a network request event
    /// - Parameters:
    ///   - domain: The destination domain
    ///   - action: Action taken (blocked, allowed)
    ///   - reason: Reason for the action
    ///   - processInfo: Optional process information
    /// - Requirement: 17.5
    func logNetworkRequest(
        domain: String,
        action: String,
        reason: String,
        processInfo: String? = nil
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let processString = processInfo.map { " process=\($0)" } ?? ""
        let logMessage = "[\(timestamp)] Network request: domain=\(domain) action=\(action) reason=\(reason)\(processString)"
        
        log(logMessage)
    }
}
