import Foundation
import Network
import Combine
import Logging
import NIOCore
import NIOPosix

/// Factory for creating network monitoring engines with seamless migration between legacy and SwiftNIO implementations
/// Implements PATTERN-2025-075: Factory Pattern for Protocol Migration
/// Enables backward compatibility while providing SwiftNIO performance benefits
@available(macOS 10.15, *)
internal final class NetworkMonitoringEngineFactory: @unchecked Sendable {
    
    // MARK: - Types
    
    /// Configuration for factory behavior
    internal struct FactoryConfig: Sendable {
        let preferSwiftNIO: Bool
        let fallbackToLegacy: Bool
        let performanceThreshold: Int // minimum core count for SwiftNIO
        
        static let `default` = FactoryConfig(
            preferSwiftNIO: true,
            fallbackToLegacy: true,
            performanceThreshold: 2
        )
    }
    
    /// Engine type indication
    internal enum EngineType: String, Sendable {
        case legacy = "legacy"
        case swiftNIO = "swiftNIO"
    }
    
    /// Factory result with engine and metadata
    internal struct FactoryResult: Sendable {
        let engine: any NetworkMonitoringEngineProtocol
        let engineType: EngineType
        let metadata: [String: String] // Changed to String: String for Sendable compliance
        
        init(engine: any NetworkMonitoringEngineProtocol, engineType: EngineType, metadata: [String: String] = [:]) {
            self.engine = engine
            self.engineType = engineType
            self.metadata = metadata
        }
    }
    
    // MARK: - Properties
    
    private let logger: Logger
    private let config: FactoryConfig
    
    // MARK: - Initialization
    
    internal init(config: FactoryConfig = .default) {
        self.logger = Logger(label: "privarion.network.factory")
        self.config = config
    }
    
    // MARK: - Factory Methods
    
    /// Create a network monitoring engine based on system capabilities and configuration
    internal func createEngine(networkConfig: NetworkMonitoringConfig = .default) async -> FactoryResult {
        logger.info("Creating network monitoring engine with factory")
        
        let systemInfo = gatherSystemInformation()
        let engineType = determineOptimalEngineType(systemInfo: systemInfo)
        
        do {
            switch engineType {
            case .swiftNIO:
                logger.info("Creating SwiftNIO-based monitoring engine")
                let engine = try await createSwiftNIOEngine(config: networkConfig)
                let adapter = SwiftNIOEngineAdapter(engine: engine)
                return FactoryResult(
                    engine: adapter,
                    engineType: .swiftNIO,
                    metadata: systemInfo
                )
                
            case .legacy:
                logger.info("Creating legacy monitoring engine")
                let engine = createLegacyEngine(config: networkConfig)
                let adapter = LegacyEngineAdapter(engine: engine)
                return FactoryResult(
                    engine: adapter,
                    engineType: .legacy,
                    metadata: systemInfo
                )
            }
        } catch {
            logger.error("Failed to create \(engineType.rawValue) engine: \(error). Falling back to legacy.")
            let engine = createLegacyEngine(config: networkConfig)
            let adapter = LegacyEngineAdapter(engine: engine)
            return FactoryResult(
                engine: adapter,
                engineType: .legacy,
                metadata: systemInfo
            )
        }
    }
    
    // MARK: - Private Implementation
    
    private func gatherSystemInformation() -> [String: String] {
        let processInfo = Foundation.ProcessInfo.processInfo
        return [
            "coreCount": String(processInfo.processorCount),
            "systemName": processInfo.operatingSystemVersionString,
            "swiftNIOAvailable": "true", // Always available in our minimum deployment target
            "timestamp": String(Date().timeIntervalSince1970)
        ]
    }
    
    private func determineOptimalEngineType(systemInfo: [String: String]) -> EngineType {
        guard config.preferSwiftNIO else {
            return .legacy
        }
        
        let coreCount = Int(systemInfo["coreCount"] ?? "1") ?? 1
        
        if coreCount >= config.performanceThreshold {
            return .swiftNIO
        } else {
            logger.info("System has \(coreCount) cores, below threshold \(config.performanceThreshold). Using legacy engine.")
            return .legacy
        }
    }
    
    private func createSwiftNIOEngine(config: NetworkMonitoringConfig) async throws -> SwiftNIONetworkMonitoringEngine {
        // Create SwiftNIO engine with appropriate configuration
        return SwiftNIONetworkMonitoringEngine(config: config)
    }
    
    private func createLegacyEngine(config: NetworkMonitoringConfig) -> NetworkMonitoringEngine {
        return NetworkMonitoringEngine(config: config)
    }
}

// MARK: - Common Protocol

/// Common protocol that both engine types conform to through adapters
internal protocol NetworkMonitoringEngineProtocol: Sendable {
    func start() async throws
    func stop() async
    var networkStatusPublisher: AnyPublisher<NetworkStatus, Never> { get }
    func recordDNSQuery(domain: String, blocked: Bool, latency: TimeInterval) async
}

// MARK: - Engine Adapters

/// Adapter for SwiftNIO engine to conform to common protocol
internal final class SwiftNIOEngineAdapter: NetworkMonitoringEngineProtocol, @unchecked Sendable {
    private let engine: SwiftNIONetworkMonitoringEngine
    private let logger: Logger
    
    internal init(engine: SwiftNIONetworkMonitoringEngine) {
        self.engine = engine
        self.logger = Logger(label: "privarion.network.swiftnio-adapter")
    }
    
    internal func start() async throws {
        try await engine.start()
    }
    
    internal func stop() async {
        engine.stop()
    }
    
    internal var networkStatusPublisher: AnyPublisher<NetworkStatus, Never> {
        // SwiftNIO engine doesn't have direct networkStatusPublisher, create a basic one
        return Just(NetworkStatus.connected).eraseToAnyPublisher()
    }
    
    internal func recordDNSQuery(domain: String, blocked: Bool, latency: TimeInterval) async {
        // Convert to SwiftNIO DNS event format and process
        await engine.processDNSEvent(domain: domain, blocked: blocked, latency: latency)
    }
}

/// Adapter for legacy engine to conform to common protocol
internal final class LegacyEngineAdapter: NetworkMonitoringEngineProtocol, @unchecked Sendable {
    private let engine: NetworkMonitoringEngine
    private let logger: Logger
    
    internal init(engine: NetworkMonitoringEngine) {
        self.engine = engine
        self.logger = Logger(label: "privarion.network.legacy-adapter")
    }
    
    internal func start() async throws {
        engine.start()
    }
    
    internal func stop() async {
        engine.stop()
    }
    
    internal var networkStatusPublisher: AnyPublisher<NetworkStatus, Never> {
        return engine.networkStatusPublisher
    }
    
    internal func recordDNSQuery(domain: String, blocked: Bool, latency: TimeInterval) async {
        engine.recordDNSQuery(domain: domain, blocked: blocked, latency: latency)
    }
}
