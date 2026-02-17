import Foundation
import Network
import Logging

public class BandwidthThrottler {
    
    public static let shared = BandwidthThrottler()
    
    private let logger = Logger(label: "privarion.bandwidth.throttler")
    
    private var config: BandwidthThrottleConfig
    private var isRunning = false
    private let queue = DispatchQueue(label: "privarion.bandwidth.throttler", qos: .userInitiated)
    
    private var activeConnections: [UUID: ThrottledConnection] = [:]
    private var perAppBuckets: [String: TokenBucket] = [:]
    
    private var uploadTokens: Int64 = 0
    private var downloadTokens: Int64 = 0
    private let tokenUpdateInterval: TimeInterval = 0.1
    
    private var tokenTimer: DispatchSourceTimer?
    
    private init() {
        self.config = ConfigurationManager.shared.getCurrentConfiguration().modules.networkFilter.bandwidthThrottle
    }
    
    public func updateConfig(_ newConfig: BandwidthThrottleConfig) {
        self.config = newConfig
        
        if isRunning {
            applyNewLimits()
        }
    }
    
    public func start() throws {
        guard !isRunning else {
            logger.warning("Bandwidth throttler is already running")
            return
        }
        
        guard config.enabled else {
            logger.info("Bandwidth throttling is disabled in configuration")
            return
        }
        
        logger.info("Starting bandwidth throttler (upload: \(config.uploadLimitKBps) KB/s, download: \(config.downloadLimitKBps) KB/s)")
        
        startTokenGeneration()
        
        isRunning = true
        logger.info("Bandwidth throttler started successfully")
    }
    
    public func stop() {
        guard isRunning else { return }
        
        logger.info("Stopping bandwidth throttler...")
        
        tokenTimer?.cancel()
        tokenTimer = nil
        
        activeConnections.removeAll()
        perAppBuckets.removeAll()
        
        isRunning = false
        logger.info("Bandwidth throttler stopped")
    }
    
    public var running: Bool {
        return isRunning
    }
    
    public func resetForTesting() {
        if isRunning {
            stop()
        }
        config = BandwidthThrottleConfig()
        isRunning = false
        activeConnections.removeAll()
        perAppBuckets.removeAll()
    }
    
    // Test helper to check config state
    func getConfigForTesting() -> BandwidthThrottleConfig {
        return config
    }
    
    public func getCurrentStats() -> BandwidthStats {
        let active = activeConnections.count
        let uploadRate = calculateCurrentUploadRate()
        let downloadRate = calculateCurrentDownloadRate()
        
        return BandwidthStats(
            activeConnections: active,
            uploadRateBps: uploadRate,
            downloadRateBps: downloadRate,
            uploadLimitBps: Int64(config.uploadLimitKBps * 1024),
            downloadLimitBps: Int64(config.downloadLimitKBps * 1024)
        )
    }
    
    public func shouldThrottleConnection(for applicationId: String?) -> Bool {
        guard isRunning else { return false }
        
        if let appId = applicationId {
            if config.throttleBlocklist.contains(appId) {
                return true
            }
        }
        
        let hasLimits = config.uploadLimitKBps > 0 || config.downloadLimitKBps > 0
        
        if config.enabled && hasLimits {
            return true
        }
        
        if hasLimits {
            return true
        }
        
        return false
    }
    
    public func registerConnection(_ connectionId: UUID, applicationId: String?) {
        guard shouldThrottleConnection(for: applicationId) else { return }
        
        queue.sync(flags: .barrier) {
            let bucket = TokenBucket(
                capacity: Int64(max(self.config.uploadLimitKBps, self.config.downloadLimitKBps) * 1024),
                refillRate: Int64(max(self.config.uploadLimitKBps, self.config.downloadLimitKBps) * 1024) / 10
            )
            
            self.activeConnections[connectionId] = ThrottledConnection(
                id: connectionId,
                applicationId: applicationId,
                bucket: bucket,
                bytesUploaded: 0,
                bytesDownloaded: 0
            )
        }
    }
    
    public func unregisterConnection(_ connectionId: UUID) {
        queue.sync(flags: .barrier) {
            self.activeConnections.removeValue(forKey: connectionId)
        }
    }
    
    public func throttleUpload(_ connectionId: UUID, dataSize: Int) -> Bool {
        guard isRunning, var connection = activeConnections[connectionId] else {
            return false
        }
        
        let tokensNeeded = Int64(dataSize)
        
        if connection.bucket.take(tokensNeeded) {
            connection.bytesUploaded += dataSize
            activeConnections[connectionId] = connection
            return true
        }
        
        return false
    }
    
    public func throttleDownload(_ connectionId: UUID, dataSize: Int) -> Bool {
        guard isRunning, var connection = activeConnections[connectionId] else {
            return false
        }
        
        let tokensNeeded = Int64(dataSize)
        
        if connection.bucket.take(tokensNeeded) {
            connection.bytesDownloaded += dataSize
            activeConnections[connectionId] = connection
            return true
        }
        
        return false
    }
    
    private func startTokenGeneration() {
        let tokensPerInterval = Int64(max(config.uploadLimitKBps, config.downloadLimitKBps) * 1024) / 10
        
        tokenTimer = DispatchSource.makeTimerSource(queue: queue)
        tokenTimer?.schedule(deadline: .now(), repeating: tokenUpdateInterval)
        
        tokenTimer?.setEventHandler { [weak self] in
            self?.refillTokens()
        }
        
        tokenTimer?.resume()
    }
    
    private func refillTokens() {
        let tokensToAdd = Int64(max(config.uploadLimitKBps, config.downloadLimitKBps) * 1024) / 10
        
        uploadTokens += tokensToAdd
        downloadTokens += tokensToAdd
        
        let maxUploadTokens = Int64(config.uploadLimitKBps * 1024 * 10)
        let maxDownloadTokens = Int64(config.downloadLimitKBps * 1024 * 10)
        
        if config.uploadLimitKBps > 0 {
            uploadTokens = min(uploadTokens, maxUploadTokens)
        }
        
        if config.downloadLimitKBps > 0 {
            downloadTokens = min(downloadTokens, maxDownloadTokens)
        }
        
        for (connectionId, var connection) in activeConnections {
            connection.bucket.refill(amount: tokensToAdd)
            activeConnections[connectionId] = connection
        }
    }
    
    private func applyNewLimits() {
        logger.info("Applying new bandwidth limits")
        
        for (connectionId, var connection) in activeConnections {
            connection.bucket = TokenBucket(
                capacity: Int64(max(config.uploadLimitKBps, config.downloadLimitKBps) * 1024),
                refillRate: Int64(max(config.uploadLimitKBps, config.downloadLimitKBps) * 1024) / 10
            )
            activeConnections[connectionId] = connection
        }
    }
    
    private func calculateCurrentUploadRate() -> Int64 {
        return 0
    }
    
    private func calculateCurrentDownloadRate() -> Int64 {
        return 0
    }
}

private struct ThrottledConnection {
    let id: UUID
    let applicationId: String?
    var bucket: TokenBucket
    var bytesUploaded: Int
    var bytesDownloaded: Int
}

private class TokenBucket {
    private var tokens: Int64
    private let capacity: Int64
    private let refillRate: Int64
    
    init(capacity: Int64, refillRate: Int64) {
        self.capacity = capacity
        self.refillRate = refillRate
        self.tokens = capacity
    }
    
    func take(_ amount: Int64) -> Bool {
        if tokens >= amount {
            tokens -= amount
            return true
        }
        return false
    }
    
    func refill(amount: Int64) {
        tokens = min(tokens + amount, capacity)
    }
}

public struct BandwidthStats {
    public let activeConnections: Int
    public let uploadRateBps: Int64
    public let downloadRateBps: Int64
    public let uploadLimitBps: Int64
    public let downloadLimitBps: Int64
    
    public var uploadUtilization: Double {
        guard uploadLimitBps > 0 else { return 0 }
        return Double(uploadRateBps) / Double(uploadLimitBps)
    }
    
    public var downloadUtilization: Double {
        guard downloadLimitBps > 0 else { return 0 }
        return Double(downloadRateBps) / Double(downloadLimitBps)
    }
}

extension BandwidthThrottler: @unchecked Sendable {}
