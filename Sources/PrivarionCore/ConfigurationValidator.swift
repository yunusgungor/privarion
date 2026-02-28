import Foundation

/// Configuration validator for system extension configuration
public class ConfigurationValidator {
    
    /// Validate JSON schema before parsing
    public static func validateJSONSchema(_ data: Data) throws {
        // First, check if it's valid JSON
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
            throw ConfigurationValidationError.invalidJSONSchema("Invalid JSON format")
        }
        
        // Check if it's a dictionary
        guard let dict = jsonObject as? [String: Any] else {
            throw ConfigurationValidationError.invalidJSONSchema("Root element must be a JSON object")
        }
        
        // Validate required top-level keys
        let requiredKeys = ["version", "policies", "profiles", "blocklists", "networkSettings", "loggingSettings"]
        for key in requiredKeys {
            guard dict[key] != nil else {
                throw ConfigurationValidationError.invalidJSONSchema("Missing required key: \(key)")
            }
        }
        
        // Validate version is a string
        guard dict["version"] is String else {
            throw ConfigurationValidationError.invalidJSONSchema("'version' must be a string")
        }
        
        // Validate policies is an array
        guard dict["policies"] is [[String: Any]] else {
            throw ConfigurationValidationError.invalidJSONSchema("'policies' must be an array")
        }
        
        // Validate profiles is an array
        guard dict["profiles"] is [[String: Any]] else {
            throw ConfigurationValidationError.invalidJSONSchema("'profiles' must be an array")
        }
        
        // Validate blocklists is an object
        guard dict["blocklists"] is [String: Any] else {
            throw ConfigurationValidationError.invalidJSONSchema("'blocklists' must be an object")
        }
        
        // Validate networkSettings is an object
        guard dict["networkSettings"] is [String: Any] else {
            throw ConfigurationValidationError.invalidJSONSchema("'networkSettings' must be an object")
        }
        
        // Validate loggingSettings is an object
        guard dict["loggingSettings"] is [String: Any] else {
            throw ConfigurationValidationError.invalidJSONSchema("'loggingSettings' must be an object")
        }
    }
    
    /// Validate complete configuration
    public static func validate(_ config: SystemExtensionConfiguration) throws -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate version
        if config.version.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                field: "version",
                message: "Version cannot be empty"
            ))
        }
        
        // Validate policies
        for (index, policy) in config.policies.enumerated() {
            let policyIssues = validatePolicy(policy, index: index)
            issues.append(contentsOf: policyIssues)
        }
        
        // Check for duplicate policy identifiers
        let identifiers = config.policies.map { $0.identifier }
        let duplicates = identifiers.filter { identifier in
            identifiers.filter { $0 == identifier }.count > 1
        }
        if !duplicates.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                field: "policies",
                message: "Duplicate policy identifiers found: \(Set(duplicates).joined(separator: ", "))"
            ))
        }
        
        // Validate hardware profiles
        for (index, profile) in config.profiles.enumerated() {
            let profileIssues = validateHardwareProfile(profile, index: index)
            issues.append(contentsOf: profileIssues)
        }
        
        // Check for duplicate profile IDs
        let profileIds = config.profiles.map { $0.id }
        let duplicateIds = profileIds.filter { id in
            profileIds.filter { $0 == id }.count > 1
        }
        if !duplicateIds.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                field: "profiles",
                message: "Duplicate profile IDs found"
            ))
        }
        
        // Validate blocklists
        let blocklistIssues = validateBlocklist(config.blocklists)
        issues.append(contentsOf: blocklistIssues)
        
        // Validate network settings
        let networkIssues = validateNetworkSettings(config.networkSettings)
        issues.append(contentsOf: networkIssues)
        
        // Validate logging settings
        let loggingIssues = validateLoggingSettings(config.loggingSettings)
        issues.append(contentsOf: loggingIssues)
        
        // If there are any errors, throw
        let errors = issues.filter { $0.severity == .error }
        if !errors.isEmpty {
            let errorMessages = errors.map { "\($0.field): \($0.message)" }
            throw ConfigurationValidationError.inconsistentPolicyRules(errorMessages.joined(separator: "; "))
        }
        
        return issues
    }
    
    /// Validate policy
    private static func validatePolicy(_ policy: ProtectionPolicy, index: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let fieldPrefix = "policies[\(index)]"
        
        // Validate identifier
        if policy.identifier.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                field: "\(fieldPrefix).identifier",
                message: "Policy identifier cannot be empty"
            ))
        }
        
        // Validate network filtering consistency
        if policy.networkFiltering.action == .block {
            if policy.networkFiltering.blockedDomains.isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    field: "\(fieldPrefix).networkFiltering",
                    message: "Block action specified but no domains are blocked"
                ))
            }
        }
        
        // Validate DNS filtering consistency
        if policy.dnsFiltering.action == .block {
            if !policy.dnsFiltering.blockTracking &&
               !policy.dnsFiltering.blockFingerprinting &&
               policy.dnsFiltering.customBlocklist.isEmpty {
                issues.append(ValidationIssue(
                    severity: .warning,
                    field: "\(fieldPrefix).dnsFiltering",
                    message: "Block action specified but no DNS filtering rules enabled"
                ))
            }
        }
        
        // Validate VM isolation consistency
        if policy.requiresVMIsolation && policy.hardwareSpoofing != .full {
            issues.append(ValidationIssue(
                severity: .warning,
                field: "\(fieldPrefix).hardwareSpoofing",
                message: "VM isolation required but hardware spoofing not set to 'full'"
            ))
        }
        
        // Validate parent policy reference
        if let parentPolicy = policy.parentPolicy {
            if parentPolicy.isEmpty {
                issues.append(ValidationIssue(
                    severity: .error,
                    field: "\(fieldPrefix).parentPolicy",
                    message: "Parent policy reference cannot be empty"
                ))
            }
        }
        
        return issues
    }
    
    /// Validate hardware profile
    private static func validateHardwareProfile(_ profile: HardwareProfile, index: Int) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        let fieldPrefix = "profiles[\(index)]"
        
        // Validate using profile's validate method
        do {
            try profile.validate()
        } catch let error as ConfigurationValidationError {
            issues.append(ValidationIssue(
                severity: .error,
                field: fieldPrefix,
                message: error.localizedDescription
            ))
        } catch {
            issues.append(ValidationIssue(
                severity: .error,
                field: fieldPrefix,
                message: error.localizedDescription
            ))
        }
        
        // Validate name is not empty
        if profile.name.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                field: "\(fieldPrefix).name",
                message: "Profile name cannot be empty"
            ))
        }
        
        return issues
    }
    
    /// Validate blocklist configuration
    private static func validateBlocklist(_ blocklist: BlocklistConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate domain formats in tracking domains
        for domain in blocklist.trackingDomains {
            if !isValidDomain(domain) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    field: "blocklists.trackingDomains",
                    message: "Invalid domain format: \(domain)"
                ))
            }
        }
        
        // Validate domain formats in fingerprinting domains
        for domain in blocklist.fingerprintingDomains {
            if !isValidDomain(domain) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    field: "blocklists.fingerprintingDomains",
                    message: "Invalid domain format: \(domain)"
                ))
            }
        }
        
        // Validate domain formats in telemetry endpoints
        for endpoint in blocklist.telemetryEndpoints {
            if !isValidDomain(endpoint) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    field: "blocklists.telemetryEndpoints",
                    message: "Invalid endpoint format: \(endpoint)"
                ))
            }
        }
        
        return issues
    }
    
    /// Validate network settings
    private static func validateNetworkSettings(_ settings: NetworkConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate DNS proxy port
        if !isValidPort(settings.dnsProxyPort) {
            issues.append(ValidationIssue(
                severity: .error,
                field: "networkSettings.dnsProxyPort",
                message: "Invalid DNS proxy port: \(settings.dnsProxyPort). Must be between 1 and 65535"
            ))
        }
        
        // Validate HTTP proxy port
        if !isValidPort(settings.httpProxyPort) {
            issues.append(ValidationIssue(
                severity: .error,
                field: "networkSettings.httpProxyPort",
                message: "Invalid HTTP proxy port: \(settings.httpProxyPort). Must be between 1 and 65535"
            ))
        }
        
        // Validate HTTPS proxy port
        if !isValidPort(settings.httpsProxyPort) {
            issues.append(ValidationIssue(
                severity: .error,
                field: "networkSettings.httpsProxyPort",
                message: "Invalid HTTPS proxy port: \(settings.httpsProxyPort). Must be between 1 and 65535"
            ))
        }
        
        // Validate upstream DNS servers
        if settings.upstreamDNS.isEmpty {
            issues.append(ValidationIssue(
                severity: .error,
                field: "networkSettings.upstreamDNS",
                message: "At least one upstream DNS server must be specified"
            ))
        }
        
        // Validate DNS server formats
        for server in settings.upstreamDNS {
            if !isValidIPAddress(server) && !isValidDomain(server) {
                issues.append(ValidationIssue(
                    severity: .warning,
                    field: "networkSettings.upstreamDNS",
                    message: "Invalid DNS server format: \(server)"
                ))
            }
        }
        
        return issues
    }
    
    /// Validate logging settings
    private static func validateLoggingSettings(_ settings: LoggingConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        
        // Validate rotation days
        if settings.rotationDays <= 0 {
            issues.append(ValidationIssue(
                severity: .error,
                field: "loggingSettings.rotationDays",
                message: "Rotation days must be positive, got: \(settings.rotationDays)"
            ))
        }
        
        // Validate max size
        if settings.maxSizeMB <= 0 {
            issues.append(ValidationIssue(
                severity: .error,
                field: "loggingSettings.maxSizeMB",
                message: "Maximum log size must be positive, got: \(settings.maxSizeMB)"
            ))
        }
        
        // Warn if max size is very large
        if settings.maxSizeMB > 1000 {
            issues.append(ValidationIssue(
                severity: .warning,
                field: "loggingSettings.maxSizeMB",
                message: "Maximum log size is very large: \(settings.maxSizeMB)MB"
            ))
        }
        
        return issues
    }
    
    // MARK: - Helper Methods
    
    /// Check if port number is valid
    private static func isValidPort(_ port: Int) -> Bool {
        return port > 0 && port <= 65535
    }
    
    /// Check if domain format is valid
    private static func isValidDomain(_ domain: String) -> Bool {
        // Simple domain validation (allows wildcards)
        let domainRegex = "^(\\*\\.)?[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
        return domain.range(of: domainRegex, options: .regularExpression) != nil
    }
    
    /// Check if IP address format is valid
    private static func isValidIPAddress(_ ip: String) -> Bool {
        // Simple IPv4 validation
        let ipv4Regex = "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
        if ip.range(of: ipv4Regex, options: .regularExpression) != nil {
            return true
        }
        
        // Simple IPv6 validation (basic check)
        let ipv6Regex = "^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$"
        return ip.range(of: ipv6Regex, options: .regularExpression) != nil
    }
}

// MARK: - Validation Issue

/// Validation issue with severity
public struct ValidationIssue {
    /// Issue severity
    public let severity: ValidationSeverity
    
    /// Field that has the issue
    public let field: String
    
    /// Issue message
    public let message: String
    
    public init(severity: ValidationSeverity, field: String, message: String) {
        self.severity = severity
        self.field = field
        self.message = message
    }
}

/// Validation severity
public enum ValidationSeverity {
    case error
    case warning
    case info
}
