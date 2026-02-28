import Foundation

/// Protection policy engine for evaluating and applying protection policies to applications
public class ProtectionPolicyEngine {
    /// Policy database indexed by identifier
    private var policies: [String: ProtectionPolicy]
    
    /// Default policy for unmatched applications
    private let defaultPolicy: ProtectionPolicy
    
    /// Thread-safe access to policies
    private let queue = DispatchQueue(label: "com.privarion.policyengine", attributes: .concurrent)
    
    /// Initialize with default policy
    public init(defaultPolicy: ProtectionPolicy = .defaultPolicy()) {
        self.defaultPolicy = defaultPolicy
        self.policies = [:]
    }
    
    /// Evaluate policy for an executable path
    /// - Parameter executablePath: Path to the executable
    /// - Returns: The most specific matching policy or default policy
    public func evaluatePolicy(for executablePath: String) -> ProtectionPolicy {
        return queue.sync {
            // Try exact bundle ID match first (most specific)
            if let bundleID = extractBundleID(from: executablePath),
               let policy = policies[bundleID] {
                return resolveInheritance(policy)
            }
            
            // Try exact path match
            if let policy = policies[executablePath] {
                return resolveInheritance(policy)
            }
            
            // Try path prefix matching (find most specific)
            let matchingPolicies = policies.filter { identifier, _ in
                identifier != "*" && executablePath.hasPrefix(identifier)
            }.sorted { $0.key.count > $1.key.count }
            
            if let mostSpecific = matchingPolicies.first {
                return resolveInheritance(mostSpecific.value)
            }
            
            // Fall back to default policy
            return defaultPolicy
        }
    }
    
    /// Add a policy to the database
    /// - Parameter policy: The policy to add
    public func addPolicy(_ policy: ProtectionPolicy) {
        queue.async(flags: .barrier) {
            self.policies[policy.identifier] = policy
        }
    }
    
    /// Remove a policy from the database
    /// - Parameter identifier: The policy identifier to remove
    public func removePolicy(identifier: String) {
        queue.async(flags: .barrier) {
            self.policies.removeValue(forKey: identifier)
        }
    }
    
    /// Load policies from a URL
    /// - Parameter url: URL to the policies JSON file
    /// - Throws: Error if loading or parsing fails
    public func loadPolicies(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let loadedPolicies = try decoder.decode([ProtectionPolicy].self, from: data)
        
        queue.async(flags: .barrier) {
            for policy in loadedPolicies {
                self.policies[policy.identifier] = policy
            }
        }
    }
    
    /// Get all policies
    /// - Returns: Array of all policies
    public func getAllPolicies() -> [ProtectionPolicy] {
        return queue.sync {
            Array(policies.values)
        }
    }
    
    /// Get policy by identifier
    /// - Parameter identifier: The policy identifier
    /// - Returns: The policy if found, nil otherwise
    public func getPolicy(identifier: String) -> ProtectionPolicy? {
        return queue.sync {
            policies[identifier]
        }
    }
    
    /// Validate a policy before adding it
    /// - Parameter policy: The policy to validate
    /// - Throws: PolicyValidationError if validation fails
    public func validatePolicy(_ policy: ProtectionPolicy) throws {
        // Validate identifier is not empty
        guard !policy.identifier.isEmpty else {
            throw PolicyValidationError.emptyIdentifier
        }
        
        // Validate bundle ID format if it looks like a bundle ID (contains dot but not a path)
        if policy.identifier.contains(".") && !policy.identifier.hasPrefix("/") && policy.identifier != "*" {
            try validateBundleID(policy.identifier)
        }
        
        // Validate identifier doesn't contain invalid characters (spaces, etc.)
        if policy.identifier.contains(" ") {
            throw PolicyValidationError.invalidBundleIDFormat(policy.identifier)
        }
        
        // Validate domain patterns in network filtering rules
        for domain in policy.networkFiltering.allowedDomains {
            try validateDomainPattern(domain)
        }
        for domain in policy.networkFiltering.blockedDomains {
            try validateDomainPattern(domain)
        }
        
        // Validate domain patterns in DNS filtering rules
        for domain in policy.dnsFiltering.customBlocklist {
            try validateDomainPattern(domain)
        }
        
        // Validate policy consistency
        try validatePolicyConsistency(policy)
        
        // Validate parent policy exists if specified
        if let parentIdentifier = policy.parentPolicy {
            guard policies[parentIdentifier] != nil || parentIdentifier == "*" else {
                throw PolicyValidationError.parentPolicyNotFound(parentIdentifier)
            }
            
            // Check for circular inheritance
            try validateNoCircularInheritance(policy)
        }
    }
    
    // MARK: - Private Methods
    
    /// Validate bundle ID format
    private func validateBundleID(_ bundleID: String) throws {
        // Bundle ID should be reverse domain notation (e.g., com.example.app)
        let components = bundleID.components(separatedBy: ".")
        guard components.count >= 2 else {
            throw PolicyValidationError.invalidBundleIDFormat(bundleID)
        }
        
        // Each component should be alphanumeric with hyphens allowed
        let validPattern = "^[a-zA-Z0-9-]+$"
        for component in components {
            guard component.range(of: validPattern, options: .regularExpression) != nil else {
                throw PolicyValidationError.invalidBundleIDFormat(bundleID)
            }
        }
    }
    
    /// Validate domain pattern
    private func validateDomainPattern(_ domain: String) throws {
        guard !domain.isEmpty else {
            throw PolicyValidationError.emptyDomainPattern
        }
        
        // Allow wildcard patterns like *.example.com
        let pattern = domain.replacingOccurrences(of: "*", with: "")
        
        // Remove leading dot if present
        let cleanPattern = pattern.hasPrefix(".") ? String(pattern.dropFirst()) : pattern
        
        // Validate domain format (alphanumeric, dots, hyphens)
        let domainRegex = "^[a-zA-Z0-9.-]+$"
        guard cleanPattern.range(of: domainRegex, options: .regularExpression) != nil else {
            throw PolicyValidationError.invalidDomainPattern(domain)
        }
    }
    
    /// Validate policy consistency
    private func validatePolicyConsistency(_ policy: ProtectionPolicy) throws {
        // If VM isolation is required, hardware spoofing should be full
        if policy.requiresVMIsolation && policy.hardwareSpoofing != .full {
            throw PolicyValidationError.inconsistentRules(
                "VM isolation requires full hardware spoofing level"
            )
        }
        
        // If protection level is paranoid, should have strict settings
        if policy.protectionLevel == .paranoid {
            if policy.networkFiltering.action == .allow && policy.networkFiltering.blockedDomains.isEmpty {
                throw PolicyValidationError.inconsistentRules(
                    "Paranoid protection level should have network filtering enabled"
                )
            }
        }
        
        // Cannot have same domain in both allowed and blocked lists
        let allowedSet = Set(policy.networkFiltering.allowedDomains)
        let blockedSet = Set(policy.networkFiltering.blockedDomains)
        let intersection = allowedSet.intersection(blockedSet)
        
        if !intersection.isEmpty {
            throw PolicyValidationError.inconsistentRules(
                "Domains cannot be in both allowed and blocked lists: \(intersection.joined(separator: ", "))"
            )
        }
    }
    
    /// Validate no circular inheritance
    private func validateNoCircularInheritance(_ policy: ProtectionPolicy) throws {
        var visited = Set<String>()
        visited.insert(policy.identifier) // Add the starting policy to visited
        var current = policy
        
        while let parentIdentifier = current.parentPolicy {
            // Check if we've seen this identifier before (circular reference)
            if visited.contains(parentIdentifier) {
                throw PolicyValidationError.circularInheritance(policy.identifier)
            }
            
            visited.insert(parentIdentifier)
            
            // Get parent policy
            guard let parent = policies[parentIdentifier] else {
                break
            }
            
            current = parent
        }
    }
    
    /// Extract bundle ID from executable path
    /// - Parameter path: Executable path
    /// - Returns: Bundle ID if found
    private func extractBundleID(from path: String) -> String? {
        // Check if path is in an app bundle
        guard path.contains(".app/") else {
            return nil
        }
        
        // Extract app bundle path
        let components = path.components(separatedBy: ".app/")
        guard let appPath = components.first else {
            return nil
        }
        
        let bundlePath = appPath + ".app"
        let infoPlistPath = bundlePath + "/Contents/Info.plist"
        
        // Try to read bundle ID from Info.plist
        guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: infoPlistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String else {
            return nil
        }
        
        return bundleID
    }
    
    /// Resolve policy inheritance
    /// - Parameter policy: The policy to resolve
    /// - Returns: Policy with inherited values applied
    private func resolveInheritance(_ policy: ProtectionPolicy) -> ProtectionPolicy {
        guard let parentIdentifier = policy.parentPolicy,
              let parentPolicy = policies[parentIdentifier] else {
            return policy
        }
        
        // Recursively resolve parent inheritance
        let resolvedParent = resolveInheritance(parentPolicy)
        
        // Create merged policy (child overrides parent)
        return ProtectionPolicy(
            identifier: policy.identifier,
            protectionLevel: policy.protectionLevel,
            networkFiltering: mergeNetworkRules(child: policy.networkFiltering, parent: resolvedParent.networkFiltering),
            dnsFiltering: mergeDNSRules(child: policy.dnsFiltering, parent: resolvedParent.dnsFiltering),
            hardwareSpoofing: policy.hardwareSpoofing,
            requiresVMIsolation: policy.requiresVMIsolation,
            parentPolicy: policy.parentPolicy
        )
    }
    
    /// Merge network filtering rules (child overrides parent)
    private func mergeNetworkRules(child: NetworkFilteringRules, parent: NetworkFilteringRules) -> NetworkFilteringRules {
        return NetworkFilteringRules(
            action: child.action,
            allowedDomains: child.allowedDomains.isEmpty ? parent.allowedDomains : child.allowedDomains,
            blockedDomains: child.blockedDomains.isEmpty ? parent.blockedDomains : child.blockedDomains
        )
    }
    
    /// Merge DNS filtering rules (child overrides parent)
    private func mergeDNSRules(child: DNSFilteringRules, parent: DNSFilteringRules) -> DNSFilteringRules {
        // If child has non-empty customBlocklist, use it; otherwise inherit from parent
        let customBlocklist = child.customBlocklist.isEmpty ? parent.customBlocklist : child.customBlocklist
        
        return DNSFilteringRules(
            action: child.action,
            blockTracking: child.blockTracking,
            blockFingerprinting: child.blockFingerprinting,
            customBlocklist: customBlocklist
        )
    }
}


// MARK: - Policy Validation Errors

/// Errors that can occur during policy validation
public enum PolicyValidationError: Error, LocalizedError {
    case emptyIdentifier
    case invalidBundleIDFormat(String)
    case emptyDomainPattern
    case invalidDomainPattern(String)
    case inconsistentRules(String)
    case parentPolicyNotFound(String)
    case circularInheritance(String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyIdentifier:
            return "Policy identifier cannot be empty"
        case .invalidBundleIDFormat(let bundleID):
            return "Invalid bundle ID format: \(bundleID). Expected reverse domain notation (e.g., com.example.app)"
        case .emptyDomainPattern:
            return "Domain pattern cannot be empty"
        case .invalidDomainPattern(let domain):
            return "Invalid domain pattern: \(domain). Expected alphanumeric characters, dots, hyphens, and optional wildcards"
        case .inconsistentRules(let message):
            return "Inconsistent policy rules: \(message)"
        case .parentPolicyNotFound(let identifier):
            return "Parent policy not found: \(identifier)"
        case .circularInheritance(let identifier):
            return "Circular inheritance detected for policy: \(identifier)"
        }
    }
}
