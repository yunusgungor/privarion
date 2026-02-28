import Foundation

// MARK: - System Extension Configuration

/// System extension configuration for macOS system-level privacy protection
public struct SystemExtensionConfiguration: Codable, Equatable {
    /// Configuration schema version
    public let version: String
    
    /// Protection policies for applications
    public var policies: [ProtectionPolicy]
    
    /// Hardware profiles for VM isolation
    public var profiles: [HardwareProfile]
    
    /// Blocklist configuration
    public var blocklists: BlocklistConfiguration
    
    /// Network settings
    public var networkSettings: NetworkConfiguration
    
    /// Logging settings
    public var loggingSettings: LoggingConfiguration
    
    public init(
        version: String = "1.0.0",
        policies: [ProtectionPolicy] = [],
        profiles: [HardwareProfile] = [],
        blocklists: BlocklistConfiguration = BlocklistConfiguration(),
        networkSettings: NetworkConfiguration = NetworkConfiguration(),
        loggingSettings: LoggingConfiguration = LoggingConfiguration()
    ) {
        self.version = version
        self.policies = policies
        self.profiles = profiles
        self.blocklists = blocklists
        self.networkSettings = networkSettings
        self.loggingSettings = loggingSettings
    }
    
    /// Default configuration with sensible defaults
    public static func defaultConfiguration() -> SystemExtensionConfiguration {
        return SystemExtensionConfiguration(
            version: "1.0.0",
            policies: [ProtectionPolicy.defaultPolicy()],
            profiles: HardwareProfile.predefinedProfiles(),
            blocklists: BlocklistConfiguration.defaultBlocklist(),
            networkSettings: NetworkConfiguration(),
            loggingSettings: LoggingConfiguration()
        )
    }
}

// MARK: - Protection Policy

/// Protection policy for applications
public struct ProtectionPolicy: Codable, Equatable {
    /// Application identifier (bundle ID or path)
    public let identifier: String
    
    /// Protection level
    public var protectionLevel: ProtectionLevel
    
    /// Network filtering rules
    public var networkFiltering: NetworkFilteringRules
    
    /// DNS filtering rules
    public var dnsFiltering: DNSFilteringRules
    
    /// Hardware spoofing level
    public var hardwareSpoofing: HardwareSpoofingLevel
    
    /// Requires VM isolation
    public var requiresVMIsolation: Bool
    
    /// Parent policy for inheritance (optional)
    public var parentPolicy: String?
    
    public init(
        identifier: String,
        protectionLevel: ProtectionLevel = .standard,
        networkFiltering: NetworkFilteringRules = NetworkFilteringRules(),
        dnsFiltering: DNSFilteringRules = DNSFilteringRules(),
        hardwareSpoofing: HardwareSpoofingLevel = .none,
        requiresVMIsolation: Bool = false,
        parentPolicy: String? = nil
    ) {
        self.identifier = identifier
        self.protectionLevel = protectionLevel
        self.networkFiltering = networkFiltering
        self.dnsFiltering = dnsFiltering
        self.hardwareSpoofing = hardwareSpoofing
        self.requiresVMIsolation = requiresVMIsolation
        self.parentPolicy = parentPolicy
    }
    
    /// Default policy for unmatched applications
    public static func defaultPolicy() -> ProtectionPolicy {
        return ProtectionPolicy(
            identifier: "*",
            protectionLevel: .basic,
            networkFiltering: NetworkFilteringRules(
                action: .monitor,
                allowedDomains: [],
                blockedDomains: []
            ),
            dnsFiltering: DNSFilteringRules(
                action: .monitor,
                blockTracking: true,
                blockFingerprinting: false,
                customBlocklist: []
            ),
            hardwareSpoofing: .none,
            requiresVMIsolation: false
        )
    }
}

/// Protection level enumeration
public enum ProtectionLevel: String, Codable, CaseIterable, Equatable {
    case none
    case basic
    case standard
    case strict
    case paranoid
}

/// Network filtering rules
public struct NetworkFilteringRules: Codable, Equatable {
    /// Filter action
    public var action: FilterAction
    
    /// Allowed domains
    public var allowedDomains: [String]
    
    /// Blocked domains
    public var blockedDomains: [String]
    
    public init(
        action: FilterAction = .allow,
        allowedDomains: [String] = [],
        blockedDomains: [String] = []
    ) {
        self.action = action
        self.allowedDomains = allowedDomains
        self.blockedDomains = blockedDomains
    }
}

/// DNS filtering rules
public struct DNSFilteringRules: Codable, Equatable {
    /// Filter action
    public var action: FilterAction
    
    /// Block tracking domains
    public var blockTracking: Bool
    
    /// Block fingerprinting domains
    public var blockFingerprinting: Bool
    
    /// Custom blocklist
    public var customBlocklist: [String]
    
    public init(
        action: FilterAction = .allow,
        blockTracking: Bool = false,
        blockFingerprinting: Bool = false,
        customBlocklist: [String] = []
    ) {
        self.action = action
        self.blockTracking = blockTracking
        self.blockFingerprinting = blockFingerprinting
        self.customBlocklist = customBlocklist
    }
}

/// Filter action enumeration
public enum FilterAction: String, Codable, CaseIterable, Equatable {
    case allow
    case block
    case monitor
}

/// Hardware spoofing level
public enum HardwareSpoofingLevel: String, Codable, CaseIterable, Equatable {
    case none
    case basic  // software-level spoofing
    case full   // VM-based isolation
}

// MARK: - Hardware Profile

/// Hardware profile for VM configuration
public struct HardwareProfile: Codable, Equatable {
    /// Unique identifier
    public let id: UUID
    
    /// Profile name
    public let name: String
    
    /// Hardware model identifier
    public let hardwareModel: String
    
    /// Machine identifier (UUID string)
    public let machineIdentifier: String
    
    /// MAC address
    public let macAddress: String
    
    /// Serial number
    public let serialNumber: String
    
    /// Creation timestamp
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        hardwareModel: String,
        machineIdentifier: String,
        macAddress: String,
        serialNumber: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.hardwareModel = hardwareModel
        self.machineIdentifier = machineIdentifier
        self.macAddress = macAddress
        self.serialNumber = serialNumber
        self.createdAt = createdAt
    }
    
    /// Validate hardware profile identifiers
    public func validate() throws {
        // Validate MAC address format (XX:XX:XX:XX:XX:XX)
        let macRegex = "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"
        guard macAddress.range(of: macRegex, options: .regularExpression) != nil else {
            throw ConfigurationValidationError.invalidMACAddress(macAddress)
        }
        
        // Validate machine identifier is valid UUID
        guard UUID(uuidString: machineIdentifier) != nil else {
            throw ConfigurationValidationError.invalidMachineIdentifier(machineIdentifier)
        }
        
        // Validate hardware model is not empty
        guard !hardwareModel.isEmpty else {
            throw ConfigurationValidationError.emptyHardwareModel
        }
        
        // Validate serial number format (alphanumeric, 10-12 characters)
        let serialRegex = "^[A-Z0-9]{10,12}$"
        guard serialNumber.range(of: serialRegex, options: .regularExpression) != nil else {
            throw ConfigurationValidationError.invalidSerialNumber(serialNumber)
        }
    }
    
    /// Predefined hardware profiles
    public static func predefinedProfiles() -> [HardwareProfile] {
        return [
            HardwareProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                name: "MacBook Pro 2021",
                hardwareModel: "MacBookPro18,3",
                machineIdentifier: "00000000-0000-0000-0000-000000000101",
                macAddress: "02:00:00:00:00:01",
                serialNumber: "C02YX1ABMD6T",
                createdAt: Date(timeIntervalSince1970: 0)
            ),
            HardwareProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                name: "MacBook Air 2022",
                hardwareModel: "Mac14,2",
                machineIdentifier: "00000000-0000-0000-0000-000000000102",
                macAddress: "02:00:00:00:00:02",
                serialNumber: "C02ZX2BCNE6V",
                createdAt: Date(timeIntervalSince1970: 0)
            ),
            HardwareProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                name: "iMac 2021",
                hardwareModel: "iMac21,1",
                machineIdentifier: "00000000-0000-0000-0000-000000000103",
                macAddress: "02:00:00:00:00:03",
                serialNumber: "C02AA3CDPF7W",
                createdAt: Date(timeIntervalSince1970: 0)
            ),
            HardwareProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                name: "Mac Mini 2023",
                hardwareModel: "Mac14,3",
                machineIdentifier: "00000000-0000-0000-0000-000000000104",
                macAddress: "02:00:00:00:00:04",
                serialNumber: "C02BB4DEQG8X",
                createdAt: Date(timeIntervalSince1970: 0)
            ),
            HardwareProfile(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                name: "Mac Studio 2022",
                hardwareModel: "Mac13,1",
                machineIdentifier: "00000000-0000-0000-0000-000000000105",
                macAddress: "02:00:00:00:00:05",
                serialNumber: "C02CC5EFRH9Y",
                createdAt: Date(timeIntervalSince1970: 0)
            )
        ]
    }
}

// MARK: - Blocklist Configuration

/// Blocklist configuration for tracking and fingerprinting domains
public struct BlocklistConfiguration: Codable, Equatable {
    /// Tracking domains
    public var trackingDomains: [String]
    
    /// Fingerprinting domains
    public var fingerprintingDomains: [String]
    
    /// Telemetry endpoints
    public var telemetryEndpoints: [String]
    
    /// Custom blocklist
    public var customBlocklist: [String]
    
    public init(
        trackingDomains: [String] = [],
        fingerprintingDomains: [String] = [],
        telemetryEndpoints: [String] = [],
        customBlocklist: [String] = []
    ) {
        self.trackingDomains = trackingDomains
        self.fingerprintingDomains = fingerprintingDomains
        self.telemetryEndpoints = telemetryEndpoints
        self.customBlocklist = customBlocklist
    }
    
    /// Default blocklist with common tracking domains
    public static func defaultBlocklist() -> BlocklistConfiguration {
        return BlocklistConfiguration(
            trackingDomains: [
                "google-analytics.com",
                "doubleclick.net",
                "facebook.com",
                "analytics.twitter.com"
            ],
            fingerprintingDomains: [
                "fingerprint.com",
                "fingerprintjs.com"
            ],
            telemetryEndpoints: [
                "telemetry.mozilla.org",
                "vortex.data.microsoft.com"
            ],
            customBlocklist: []
        )
    }
}

// MARK: - Network Configuration

/// Network configuration for proxies and DNS
public struct NetworkConfiguration: Codable, Equatable {
    /// DNS proxy port
    public var dnsProxyPort: Int
    
    /// HTTP proxy port
    public var httpProxyPort: Int
    
    /// HTTPS proxy port
    public var httpsProxyPort: Int
    
    /// Upstream DNS servers
    public var upstreamDNS: [String]
    
    /// Enable DNS over HTTPS
    public var enableDoH: Bool
    
    public init(
        dnsProxyPort: Int = 53,
        httpProxyPort: Int = 8080,
        httpsProxyPort: Int = 8443,
        upstreamDNS: [String] = ["8.8.8.8", "1.1.1.1"],
        enableDoH: Bool = false
    ) {
        self.dnsProxyPort = dnsProxyPort
        self.httpProxyPort = httpProxyPort
        self.httpsProxyPort = httpsProxyPort
        self.upstreamDNS = upstreamDNS
        self.enableDoH = enableDoH
    }
}

// MARK: - Logging Configuration

/// Logging configuration for system extension
public struct LoggingConfiguration: Codable, Equatable {
    /// Log level
    public var level: SystemLogLevel
    
    /// Log rotation period in days
    public var rotationDays: Int
    
    /// Maximum log file size in MB
    public var maxSizeMB: Int
    
    /// Sanitize personally identifiable information
    public var sanitizePII: Bool
    
    public init(
        level: SystemLogLevel = .info,
        rotationDays: Int = 7,
        maxSizeMB: Int = 100,
        sanitizePII: Bool = true
    ) {
        self.level = level
        self.rotationDays = rotationDays
        self.maxSizeMB = maxSizeMB
        self.sanitizePII = sanitizePII
    }
}

/// System log level (separate from existing LogLevel to avoid conflicts)
public enum SystemLogLevel: String, Codable, CaseIterable, Equatable {
    case debug
    case info
    case warning
    case error
    case critical
}

// MARK: - Validation Errors

/// Validation errors for configuration
public enum ConfigurationValidationError: Error, LocalizedError {
    case invalidMACAddress(String)
    case invalidMachineIdentifier(String)
    case emptyHardwareModel
    case invalidSerialNumber(String)
    case invalidJSONSchema(String)
    case inconsistentPolicyRules(String)
    case invalidHardwareProfileIdentifier(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidMACAddress(let address):
            return "Invalid MAC address format: \(address). Expected format: XX:XX:XX:XX:XX:XX"
        case .invalidMachineIdentifier(let identifier):
            return "Invalid machine identifier: \(identifier). Expected valid UUID format"
        case .emptyHardwareModel:
            return "Hardware model cannot be empty"
        case .invalidSerialNumber(let serial):
            return "Invalid serial number format: \(serial). Expected 10-12 alphanumeric characters"
        case .invalidJSONSchema(let message):
            return "Invalid JSON schema: \(message)"
        case .inconsistentPolicyRules(let message):
            return "Inconsistent policy rules: \(message)"
        case .invalidHardwareProfileIdentifier(let message):
            return "Invalid hardware profile identifier: \(message)"
        }
    }
}
