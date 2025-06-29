import Foundation

/// Configuration profile for identity spoofing operations
public struct ConfigurationProfile {
    public let name: String
    public let version: String
    public let description: String
    public let macStrategy: HardwareIdentifierEngine.GenerationStrategy
    public let hostnameStrategy: HardwareIdentifierEngine.GenerationStrategy
    public let serialStrategy: HardwareIdentifierEngine.GenerationStrategy
    public let enabledTypes: Set<IdentitySpoofingManager.IdentityType>
    public let criticalTypes: Set<IdentitySpoofingManager.IdentityType>
    public let persistentChanges: Bool
    public let validationRequired: Bool
    public let rollbackOnFailure: Bool
    public let metadata: [String: String]
    
    public init(name: String,
                version: String = "1.0.0",
                description: String,
                macStrategy: HardwareIdentifierEngine.GenerationStrategy = .realistic,
                hostnameStrategy: HardwareIdentifierEngine.GenerationStrategy = .realistic,
                serialStrategy: HardwareIdentifierEngine.GenerationStrategy = .realistic,
                enabledTypes: Set<IdentitySpoofingManager.IdentityType> = Set(IdentitySpoofingManager.IdentityType.allCases),
                criticalTypes: Set<IdentitySpoofingManager.IdentityType> = [.macAddress, .hostname],
                persistentChanges: Bool = false,
                validationRequired: Bool = true,
                rollbackOnFailure: Bool = true,
                metadata: [String: String] = [:]) {
        self.name = name
        self.version = version
        self.description = description
        self.macStrategy = macStrategy
        self.hostnameStrategy = hostnameStrategy
        self.serialStrategy = serialStrategy
        self.enabledTypes = enabledTypes
        self.criticalTypes = criticalTypes
        self.persistentChanges = persistentChanges
        self.validationRequired = validationRequired
        self.rollbackOnFailure = rollbackOnFailure
        self.metadata = metadata
    }
    
    /// Check if identity type is enabled in this profile
    public func isEnabled(for type: IdentitySpoofingManager.IdentityType) -> Bool {
        return enabledTypes.contains(type)
    }
    
    /// Check if identity type is critical in this profile
    public func isCritical(for type: IdentitySpoofingManager.IdentityType) -> Bool {
        return criticalTypes.contains(type)
    }
}

/// Configuration profile manager for identity spoofing profiles
public class ConfigurationProfileManager {
    
    // MARK: - Types
    
    public enum ProfileError: Error, LocalizedError {
        case profileNotFound
        case invalidProfileFormat
        case profileAlreadyExists
        case profileSaveFailed
        case profileLoadFailed
        
        public var errorDescription: String? {
            switch self {
            case .profileNotFound:
                return "Configuration profile not found"
            case .invalidProfileFormat:
                return "Invalid configuration profile format"
            case .profileAlreadyExists:
                return "Configuration profile already exists"
            case .profileSaveFailed:
                return "Failed to save configuration profile"
            case .profileLoadFailed:
                return "Failed to load configuration profile"
            }
        }
    }
    
    // MARK: - Properties
    
    private let storageDirectory: URL
    private var profileCache: [String: ConfigurationProfile] = [:]
    private let defaultProfiles: [ConfigurationProfile]
    
    // MARK: - Initialization
    
    public init(storageDirectory: URL? = nil) {
        // Use default storage directory if not provided
        if let customDirectory = storageDirectory {
            self.storageDirectory = customDirectory
        } else {
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            self.storageDirectory = homeDirectory.appendingPathComponent(".privarion/profiles")
        }
        
        // Initialize default profiles
        self.defaultProfiles = Self.createDefaultProfiles()
        
        setupStorageDirectory()
        loadExistingProfiles()
        ensureDefaultProfiles()
    }
    
    // MARK: - Public Methods
    
    /// Load configuration profile by name
    public func loadProfile(name: String) throws -> ConfigurationProfile {
        if let cachedProfile = profileCache[name] {
            return cachedProfile
        }
        
        let profileFile = storageDirectory.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: profileFile.path) else {
            throw ProfileError.profileNotFound
        }
        
        do {
            let data = try Data(contentsOf: profileFile)
            let codableProfile = try JSONDecoder().decode(ConfigurationProfileCodable.self, from: data)
            let profile = codableProfile.toConfigurationProfile()
            
            profileCache[name] = profile
            return profile
        } catch {
            throw ProfileError.profileLoadFailed
        }
    }
    
    /// Save configuration profile
    public func saveProfile(_ profile: ConfigurationProfile, overwrite: Bool = false) throws {
        let profileFile = storageDirectory.appendingPathComponent("\(profile.name).json")
        
        if !overwrite && FileManager.default.fileExists(atPath: profileFile.path) {
            throw ProfileError.profileAlreadyExists
        }
        
        do {
            let codableProfile = ConfigurationProfileCodable(from: profile)
            let data = try JSONEncoder().encode(codableProfile)
            try data.write(to: profileFile)
            
            profileCache[profile.name] = profile
        } catch {
            throw ProfileError.profileSaveFailed
        }
    }
    
    /// List all available profiles
    public func listProfiles() -> [String] {
        return Array(profileCache.keys).sorted()
    }
    
    /// Delete a profile
    public func deleteProfile(name: String) throws {
        let profileFile = storageDirectory.appendingPathComponent("\(name).json")
        
        if FileManager.default.fileExists(atPath: profileFile.path) {
            try FileManager.default.removeItem(at: profileFile)
        }
        
        profileCache.removeValue(forKey: name)
    }
    
    /// Get profile details
    public func getProfileDetails(name: String) throws -> ConfigurationProfile {
        return try loadProfile(name: name)
    }
    
    /// Validate profile configuration
    public func validateProfile(_ profile: ConfigurationProfile) -> [String] {
        var issues: [String] = []
        
        // Check profile name
        if profile.name.isEmpty {
            issues.append("Profile name cannot be empty")
        }
        
        // Check enabled types
        if profile.enabledTypes.isEmpty {
            issues.append("At least one identity type must be enabled")
        }
        
        // Check critical types are subset of enabled types
        if !profile.criticalTypes.isSubset(of: profile.enabledTypes) {
            issues.append("Critical types must be subset of enabled types")
        }
        
        // Additional validation can be added here
        
        return issues
    }
    
    // MARK: - Private Methods
    
    private func setupStorageDirectory() {
        do {
            try FileManager.default.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            // Handle error silently for now
        }
    }
    
    private func loadExistingProfiles() {
        do {
            let profileFiles = try FileManager.default.contentsOfDirectory(at: storageDirectory,
                                                                          includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
            
            for file in profileFiles {
                do {
                    let data = try Data(contentsOf: file)
                    let codableProfile = try JSONDecoder().decode(ConfigurationProfileCodable.self, from: data)
                    let profile = codableProfile.toConfigurationProfile()
                    profileCache[profile.name] = profile
                } catch {
                    // Skip corrupted profiles
                }
            }
        } catch {
            // Handle error silently for now
        }
    }
    
    private func ensureDefaultProfiles() {
        for profile in defaultProfiles {
            if profileCache[profile.name] == nil {
                try? saveProfile(profile, overwrite: false)
            }
        }
    }
    
    // MARK: - Default Profiles
    
    private static func createDefaultProfiles() -> [ConfigurationProfile] {
        return [
            // Default profile with realistic settings
            ConfigurationProfile(
                name: "default",
                description: "Default identity spoofing profile with realistic identifiers",
                macStrategy: .realistic,
                hostnameStrategy: .realistic,
                serialStrategy: .realistic,
                enabledTypes: [.macAddress, .hostname],
                criticalTypes: [.macAddress, .hostname],
                persistentChanges: false,
                validationRequired: true,
                rollbackOnFailure: true,
                metadata: [
                    "author": "Privarion",
                    "category": "default",
                    "risk_level": "low"
                ]
            ),
            
            // Stealth profile for maximum anonymity
            ConfigurationProfile(
                name: "stealth",
                description: "High stealth profile with common vendor identifiers",
                macStrategy: .stealth,
                hostnameStrategy: .stealth,
                serialStrategy: .realistic,
                enabledTypes: Set(IdentitySpoofingManager.IdentityType.allCases),
                criticalTypes: [.macAddress, .hostname, .serialNumber],
                persistentChanges: false,
                validationRequired: true,
                rollbackOnFailure: true,
                metadata: [
                    "author": "Privarion",
                    "category": "stealth",
                    "risk_level": "medium"
                ]
            ),
            
            // Random profile for maximum obfuscation
            ConfigurationProfile(
                name: "random",
                description: "Random identity generation for maximum obfuscation",
                macStrategy: .random,
                hostnameStrategy: .random,
                serialStrategy: .random,
                enabledTypes: Set(IdentitySpoofingManager.IdentityType.allCases),
                criticalTypes: [.macAddress, .hostname],
                persistentChanges: false,
                validationRequired: true,
                rollbackOnFailure: true,
                metadata: [
                    "author": "Privarion",
                    "category": "random",
                    "risk_level": "high"
                ]
            ),
            
            // Apple-specific profile
            ConfigurationProfile(
                name: "apple",
                description: "Apple-specific identity profile using Apple vendor identifiers",
                macStrategy: .vendorBased(vendor: HardwareIdentifierEngine.VendorProfile(
                    name: "Apple", 
                    oui: "AC:DE:48", 
                    deviceTypes: ["MacBook", "iMac"]
                )),
                hostnameStrategy: .custom(pattern: "MacBook-Pro-###"),
                serialStrategy: .realistic,
                enabledTypes: [.macAddress, .hostname, .serialNumber],
                criticalTypes: [.macAddress, .hostname],
                persistentChanges: false,
                validationRequired: true,
                rollbackOnFailure: true,
                metadata: [
                    "author": "Privarion",
                    "category": "vendor",
                    "vendor": "Apple",
                    "risk_level": "low"
                ]
            ),
            
            // Testing profile with validation disabled
            ConfigurationProfile(
                name: "testing",
                description: "Testing profile with relaxed validation for development",
                macStrategy: .realistic,
                hostnameStrategy: .realistic,
                serialStrategy: .realistic,
                enabledTypes: [.macAddress, .hostname],
                criticalTypes: [],
                persistentChanges: false,
                validationRequired: false,
                rollbackOnFailure: true,
                metadata: [
                    "author": "Privarion",
                    "category": "testing",
                    "risk_level": "low"
                ]
            )
        ]
    }
}

// MARK: - Codable Support

private struct ConfigurationProfileCodable: Codable {
    let name: String
    let version: String
    let description: String
    let macStrategy: String
    let hostnameStrategy: String
    let serialStrategy: String
    let enabledTypes: [String]
    let criticalTypes: [String]
    let persistentChanges: Bool
    let validationRequired: Bool
    let rollbackOnFailure: Bool
    let metadata: [String: String]
    
    init(from profile: ConfigurationProfile) {
        self.name = profile.name
        self.version = profile.version
        self.description = profile.description
        self.enabledTypes = profile.enabledTypes.map { $0.rawValue }
        self.criticalTypes = profile.criticalTypes.map { $0.rawValue }
        self.persistentChanges = profile.persistentChanges
        self.validationRequired = profile.validationRequired
        self.rollbackOnFailure = profile.rollbackOnFailure
        self.metadata = profile.metadata
        self.macStrategy = ConfigurationProfileCodable.encodeStrategy(profile.macStrategy)
        self.hostnameStrategy = ConfigurationProfileCodable.encodeStrategy(profile.hostnameStrategy)
        self.serialStrategy = ConfigurationProfileCodable.encodeStrategy(profile.serialStrategy)
    }
    
    func toConfigurationProfile() -> ConfigurationProfile {
        return ConfigurationProfile(
            name: name,
            version: version,
            description: description,
            macStrategy: ConfigurationProfileCodable.decodeStrategy(macStrategy),
            hostnameStrategy: ConfigurationProfileCodable.decodeStrategy(hostnameStrategy),
            serialStrategy: ConfigurationProfileCodable.decodeStrategy(serialStrategy),
            enabledTypes: Set(enabledTypes.compactMap { IdentitySpoofingManager.IdentityType(rawValue: $0) }),
            criticalTypes: Set(criticalTypes.compactMap { IdentitySpoofingManager.IdentityType(rawValue: $0) }),
            persistentChanges: persistentChanges,
            validationRequired: validationRequired,
            rollbackOnFailure: rollbackOnFailure,
            metadata: metadata
        )
    }
    
    private static func encodeStrategy(_ strategy: HardwareIdentifierEngine.GenerationStrategy) -> String {
        switch strategy {
        case .random:
            return "random"
        case .realistic:
            return "realistic"
        case .stealth:
            return "stealth"
        case .vendorBased(let vendor):
            return "vendor:\(vendor.name):\(vendor.organizationallyUniqueIdentifier)"
        case .custom(let pattern):
            return "custom:\(pattern)"
        }
    }
    
    private static func decodeStrategy(_ encoded: String) -> HardwareIdentifierEngine.GenerationStrategy {
        if encoded == "random" {
            return .random
        } else if encoded == "realistic" {
            return .realistic
        } else if encoded == "stealth" {
            return .stealth
        } else if encoded.hasPrefix("vendor:") {
            let components = encoded.components(separatedBy: ":")
            if components.count >= 3 {
                let vendor = HardwareIdentifierEngine.VendorProfile(
                    name: components[1],
                    oui: components[2],
                    deviceTypes: []
                )
                return .vendorBased(vendor: vendor)
            }
        } else if encoded.hasPrefix("custom:") {
            let pattern = String(encoded.dropFirst(7))
            return .custom(pattern: pattern)
        }
        
        return .realistic // Default fallback
    }
}
