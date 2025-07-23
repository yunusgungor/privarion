import Foundation
import os

/// Advanced temporary permission manager with automatic expiration and CLI integration
/// Extends PermissionPolicyEngine temporary permission capabilities
@available(macOS 12.0, *)
public actor TemporaryPermissionManager {
    
    // MARK: - Types
    
    /// Enhanced temporary permission grant with persistence support
    public struct TemporaryPermissionGrant: Sendable, Codable, Hashable {
        public let id: String
        public let bundleIdentifier: String
        public let serviceName: String
        public let grantedAt: Date
        public let expiresAt: Date
        public let grantedBy: String // CLI user, system, etc.
        public let reason: String
        public let autoRevoke: Bool
        public let notificationSent: Bool
        
        public var isExpired: Bool {
            Date() > expiresAt
        }
        
        public var remainingTime: TimeInterval {
            max(0, expiresAt.timeIntervalSinceNow)
        }
        
        public var isExpiringSoon: Bool {
            remainingTime < 300 // 5 minutes
        }
        
        init(id: String = UUID().uuidString, bundleIdentifier: String, serviceName: String, 
             duration: TimeInterval, grantedBy: String = "system", reason: String = "", 
             autoRevoke: Bool = true) {
            self.id = id
            self.bundleIdentifier = bundleIdentifier
            self.serviceName = serviceName
            self.grantedAt = Date()
            self.expiresAt = Date().addingTimeInterval(duration)
            self.grantedBy = grantedBy
            self.reason = reason
            self.autoRevoke = autoRevoke
            self.notificationSent = false
        }
    }
    
    /// Grant request for CLI integration
    public struct GrantRequest: Sendable {
        let bundleIdentifier: String
        let serviceName: String
        let duration: TimeInterval
        let reason: String
        let requestedBy: String
        
        public init(bundleIdentifier: String, serviceName: String, duration: TimeInterval, 
             reason: String = "", requestedBy: String = "cli") {
            self.bundleIdentifier = bundleIdentifier
            self.serviceName = serviceName
            self.duration = duration
            self.reason = reason
            self.requestedBy = requestedBy
        }
    }
    
        /// Grant operation result
    public enum GrantResult: Sendable {
        case granted(TemporaryPermissionGrant)
        case denied(reason: String)
        case alreadyExists(TemporaryPermissionGrant)
        case invalidRequest(reason: String)
    }
    
    /// Cleanup statistics
    public struct CleanupStats: Sendable {
        public let totalGrants: Int
        public let expiredCleaned: Int
        public let notificationsSent: Int
        public let cleanupDuration: TimeInterval
        public let timestamp: Date
        
        public var successRate: Double {
            guard totalGrants > 0 else { return 1.0 }
            return Double(totalGrants - expiredCleaned) / Double(totalGrants)
        }
    }
    
    // MARK: - Properties
    
    private var grants: [String: TemporaryPermissionGrant] = [:]
    private let logger: os.Logger
    private let persistenceURL: URL
    private let cleanupInterval: TimeInterval = 60 // 1 minute
    private let notificationThreshold: TimeInterval = 300 // 5 minutes
    private var cleanupTask: Task<Void, Never>?
    private var cleanupStats: [CleanupStats] = []
    
    // Performance and reliability targets
    private let maxConcurrentGrants = 100
    private let cleanupReliabilityTarget = 0.999 // 99.9%
    
    // MARK: - Initialization
    
    public init(persistenceDirectory: URL? = nil, logger: os.Logger = os.Logger(subsystem: "com.privarion.permissions", category: "TemporaryManager")) {
        self.logger = logger
        
        // Setup persistence
        let defaultDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Privarion")
        let persistenceDir = persistenceDirectory ?? defaultDir
        
        try? FileManager.default.createDirectory(at: persistenceDir, withIntermediateDirectories: true)
        self.persistenceURL = persistenceDir.appendingPathComponent("temporary_permissions.json")
        
        // Start background tasks
        Task {
            await loadPersistedGrants()
            await startBackgroundCleanup()
        }
    }
    
    deinit {
        cleanupTask?.cancel()
    }
    
    // MARK: - Public Interface
    
    /// Grant temporary permission
    public func grantPermission(_ request: GrantRequest) async throws -> GrantResult {
        // Validate request
        guard request.duration > 0 && request.duration <= 86400 else { // Max 24 hours
            return .invalidRequest(reason: "Duration must be between 1 second and 24 hours")
        }
        
        guard !request.bundleIdentifier.isEmpty && !request.serviceName.isEmpty else {
            return .invalidRequest(reason: "Bundle identifier and service name are required")
        }
        
        // Check if grant already exists
        let existingGrant = grants.values.first { grant in
            grant.bundleIdentifier == request.bundleIdentifier &&
            grant.serviceName == request.serviceName &&
            !grant.isExpired
        }
        
        if let existing = existingGrant {
            return .alreadyExists(existing)
        }
        
        // Check capacity
        guard grants.count < maxConcurrentGrants else {
            return .denied(reason: "Maximum concurrent grants exceeded")
        }
        
        // Create new grant
        let grant = TemporaryPermissionGrant(
            bundleIdentifier: request.bundleIdentifier,
            serviceName: request.serviceName,
            duration: request.duration,
            grantedBy: request.requestedBy,
            reason: request.reason
        )
        
        grants[grant.id] = grant
        await persistGrants()
        
        logger.info("Granted temporary permission: \(request.bundleIdentifier):\(request.serviceName) for \(request.duration)s")
        
        return .granted(grant)
    }
    
    /// Revoke temporary permission
    public func revokePermission(grantID: String) async -> Bool {
        guard let grant = grants.removeValue(forKey: grantID) else {
            return false
        }
        
        await persistGrants()
        logger.info("Revoked temporary permission: \(grant.bundleIdentifier):\(grant.serviceName)")
        
        return true
    }
    
    /// Revoke all temporary permissions for bundle
    public func revokeAllPermissions(bundleIdentifier: String) async -> Int {
        let toRevoke = grants.filter { _, grant in
            grant.bundleIdentifier == bundleIdentifier
        }
        
        for (id, _) in toRevoke {
            grants.removeValue(forKey: id)
        }
        
        await persistGrants()
        
        if !toRevoke.isEmpty {
            logger.info("Revoked \(toRevoke.count) temporary permissions for \(bundleIdentifier)")
        }
        
        return toRevoke.count
    }
    
    /// Get all active temporary grants
    public func getActiveGrants() async -> [TemporaryPermissionGrant] {
        return grants.values.filter { !$0.isExpired }
    }
    
    /// Get grants for specific bundle
    func getGrants(bundleIdentifier: String) async -> [TemporaryPermissionGrant] {
        return grants.values.filter { grant in
            grant.bundleIdentifier == bundleIdentifier && !grant.isExpired
        }
    }
    
    /// Get grant by ID
    public func getGrant(id: String) async -> TemporaryPermissionGrant? {
        guard let grant = grants[id], !grant.isExpired else {
            return nil
        }
        return grant
    }
    
    /// Check if permission is temporarily granted
    func hasActiveGrant(bundleIdentifier: String, serviceName: String) async -> TemporaryPermissionGrant? {
        return grants.values.first { grant in
            grant.bundleIdentifier == bundleIdentifier &&
            grant.serviceName == serviceName &&
            !grant.isExpired
        }
    }
    
    /// Force cleanup expired grants
    public func cleanupExpiredGrants() async -> CleanupStats {
        let startTime = Date()
        let totalBefore = grants.count
        let expiredGrants = grants.filter { _, grant in grant.isExpired }
        
        // Remove expired grants
        for (id, _) in expiredGrants {
            grants.removeValue(forKey: id)
        }
        
        // Send expiration notifications for grants expiring soon
        var notificationsSent = 0
        for (_, grant) in grants {
            if grant.isExpiringSoon && !grant.notificationSent {
                await sendExpirationNotification(grant)
                // Mark notification as sent (we'd need to update the grant)
                // Note: This would require making the struct mutable or using a different approach
                notificationsSent += 1
            }
        }
        
        await persistGrants()
        
        let cleanupDuration = Date().timeIntervalSince(startTime)
        let stats = CleanupStats(
            totalGrants: totalBefore,
            expiredCleaned: expiredGrants.count,
            notificationsSent: notificationsSent,
            cleanupDuration: cleanupDuration,
            timestamp: Date()
        )
        
        cleanupStats.append(stats)
        
        // Keep only last 100 cleanup stats
        if cleanupStats.count > 100 {
            cleanupStats.removeFirst()
        }
        
        if expiredGrants.count > 0 {
            logger.info("Cleanup completed: removed \(expiredGrants.count) expired grants in \(cleanupDuration)s")
        }
        
        return stats
    }
    
    /// Clear all grants - intended for testing purposes only
    internal func clearAllGrants() async {
        grants.removeAll()
        await persistGrants()
        logger.debug("All grants cleared for testing")
    }
    
    /// Get cleanup statistics
    public func getCleanupStats() async -> [CleanupStats] {
        return cleanupStats
    }
    
    /// Get overall reliability metrics
    public func getReliabilityMetrics() async -> (successRate: Double, averageCleanupTime: TimeInterval, totalGrants: Int) {
        guard !cleanupStats.isEmpty else {
            return (1.0, 0.0, grants.count)
        }
        
        let totalSuccessRate = cleanupStats.map(\.successRate).reduce(0, +) / Double(cleanupStats.count)
        let averageCleanupTime = cleanupStats.map(\.cleanupDuration).reduce(0, +) / Double(cleanupStats.count)
        
        return (totalSuccessRate, averageCleanupTime, grants.count)
    }
    
    // MARK: - CLI Integration Support
    
    /// List all grants (for CLI display)
    public func listGrantsForCLI() async -> String {
        let activeGrants = await getActiveGrants()
        
        guard !activeGrants.isEmpty else {
            return "No active temporary permissions found."
        }
        
        var output = "Active Temporary Permissions:\n"
        output += String(repeating: "=", count: 80) + "\n"
        
        // Create header with proper padding
        let headerBundle = "Bundle ID".padding(toLength: 20, withPad: " ", startingAt: 0)
        let headerService = "Service".padding(toLength: 25, withPad: " ", startingAt: 0)
        let headerRemaining = "Remaining".padding(toLength: 15, withPad: " ", startingAt: 0)
        let headerGrantedBy = "Granted By".padding(toLength: 20, withPad: " ", startingAt: 0)
        
        output += "\(headerBundle) \(headerService) \(headerRemaining) \(headerGrantedBy)\n"
        output += String(repeating: "-", count: 80) + "\n"
        
        for grant in activeGrants.sorted(by: { $0.expiresAt < $1.expiresAt }) {
            let bundleDisplay = String(grant.bundleIdentifier.prefix(18)) + (grant.bundleIdentifier.count > 18 ? ".." : "")
            let serviceDisplay = grant.serviceName.replacingOccurrences(of: "kTCCService", with: "")
            let remainingTime = formatDuration(grant.remainingTime)
            
            // Use padding functions instead of String.format for safety
            let paddedBundle = bundleDisplay.padding(toLength: 20, withPad: " ", startingAt: 0)
            let paddedService = serviceDisplay.padding(toLength: 25, withPad: " ", startingAt: 0)
            let paddedTime = remainingTime.padding(toLength: 15, withPad: " ", startingAt: 0)
            let paddedGrantedBy = grant.grantedBy.padding(toLength: 20, withPad: " ", startingAt: 0)
            
            output += "\(paddedBundle) \(paddedService) \(paddedTime) \(paddedGrantedBy)\n"
            
            if !grant.reason.isEmpty {
                output += "  Reason: \(grant.reason)\n"
            }
        }
        
        return output
    }
    
    /// Export grants to JSON (for CLI)
    public func exportGrantsToJSON() async throws -> String {
        let activeGrants = await getActiveGrants()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(activeGrants)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - Private Implementation
    
    private func startBackgroundCleanup() async {
        cleanupTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(cleanupInterval * 1_000_000_000))
                
                if !Task.isCancelled {
                    _ = await cleanupExpiredGrants()
                }
            }
        }
    }
    
    private func persistGrants() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(grants)
            try data.write(to: persistenceURL)
        } catch {
            logger.error("Failed to persist grants: \(error)")
        }
    }
    
    private func loadPersistedGrants() async {
        do {
            guard FileManager.default.fileExists(atPath: persistenceURL.path) else {
                return
            }
            
            let data = try Data(contentsOf: persistenceURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            grants = try decoder.decode([String: TemporaryPermissionGrant].self, from: data)
            
            // Clean up any expired grants that were persisted
            _ = await cleanupExpiredGrants()
            
            logger.info("Loaded \(self.grants.count) persisted temporary grants")
            
        } catch {
            logger.error("Failed to load persisted grants: \(error)")
        }
    }
    
    private func sendExpirationNotification(_ grant: TemporaryPermissionGrant) async {
        // In a real implementation, this would send notifications via notification center,
        // log to system log, or integrate with alerting systems
        logger.info("Permission expiring soon: \(grant.bundleIdentifier):\(grant.serviceName) expires in \(self.formatDuration(grant.remainingTime))")
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return String(format: "%.0fs", duration)
        } else if duration < 3600 {
            return String(format: "%.0fm", duration / 60)
        } else {
            return String(format: "%.1fh", duration / 3600)
        }
    }
}

// MARK: - CLI Command Support

/// CLI-specific temporary permission operations
@available(macOS 12.0, *)
extension TemporaryPermissionManager {
    
    /// Parse duration string from CLI (e.g., "30m", "2h", "300s", "1h30m")
    public static func parseDuration(_ durationString: String) -> TimeInterval? {
        let trimmed = durationString.trimmingCharacters(in: .whitespaces).lowercased()
        
        // Handle empty string
        guard !trimmed.isEmpty else { return nil }
        
        // Handle pure number format - reject it unless it has a unit
        if Double(trimmed) != nil && !trimmed.contains(where: { $0.isLetter }) {
            return nil
        }
        
        var totalSeconds: TimeInterval = 0
        var currentNumber = ""
        
        for char in trimmed {
            if char.isNumber || char == "." {
                currentNumber.append(char)
            } else if char.isLetter {
                guard let value = Double(currentNumber), value >= 0 else { return nil }
                
                switch char {
                case "s":
                    totalSeconds += value
                case "m":
                    totalSeconds += value * 60
                case "h":
                    totalSeconds += value * 3600
                case "d":
                    totalSeconds += value * 86400
                default:
                    return nil // Unknown unit
                }
                currentNumber = ""
            } else {
                return nil // Invalid character
            }
        }
        
        // If there are leftover numbers without unit, it's invalid
        if !currentNumber.isEmpty {
            return nil
        }
        
        // Reject negative durations or zero durations
        return totalSeconds > 0 ? totalSeconds : nil
    }
    
    /// Format grant result for CLI display
    public func formatGrantResultForCLI(_ result: GrantResult) async -> String {
        switch result {
        case .granted(let grant):
            return """
            ✅ Temporary permission granted successfully
            Grant ID: \(grant.id)
            Bundle: \(grant.bundleIdentifier)
            Service: \(grant.serviceName.replacingOccurrences(of: "kTCCService", with: ""))
            Duration: \(formatDuration(grant.remainingTime))
            Expires: \(DateFormatter.localizedString(from: grant.expiresAt, dateStyle: .medium, timeStyle: .medium))
            """
            
        case .denied(let reason):
            return "❌ Permission denied: \(reason)"
            
        case .alreadyExists(let grant):
            return """
            ⚠️  Permission already exists
            Grant ID: \(grant.id)
            Remaining time: \(formatDuration(grant.remainingTime))
            """
            
        case .invalidRequest(let reason):
            return "❌ Invalid request: \(reason)"
        }
    }
}

// MARK: - Supporting Types

/// Error types for temporary permission management
enum TemporaryPermissionError: Error, LocalizedError {
    case persistenceFailure(String)
    case invalidDuration(String)
    case grantNotFound(String)
    case capacityExceeded
    case invalidBundleIdentifier(String)
    case invalidServiceName(String)
    
    var errorDescription: String? {
        switch self {
        case .persistenceFailure(let detail):
            return "Failed to persist temporary permissions: \(detail)"
        case .invalidDuration(let detail):
            return "Invalid duration: \(detail)"
        case .grantNotFound(let id):
            return "Grant not found: \(id)"
        case .capacityExceeded:
            return "Maximum number of temporary grants exceeded"
        case .invalidBundleIdentifier(let bundleId):
            return "Invalid bundle identifier: \(bundleId)"
        case .invalidServiceName(let service):
            return "Invalid service name: \(service)"
        }
    }
}
