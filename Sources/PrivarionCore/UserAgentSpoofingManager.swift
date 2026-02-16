import Foundation

/// Manager for browser User-Agent spoofing operations
/// Provides randomized and configurable User-Agent strings to prevent browser fingerprinting
public class UserAgentSpoofingManager: @unchecked Sendable {
    
    // MARK: - Types
    
    public enum SpoofingError: Error, LocalizedError {
        case invalidUserAgent
        case spoofingNotEnabled
        case profileNotFound
        case configurationFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidUserAgent:
                return "Generated User-Agent string is invalid"
            case .spoofingNotEnabled:
                return "User-Agent spoofing is not enabled"
            case .profileNotFound:
                return "User-Agent profile not found"
            case .configurationFailed:
                return "Failed to configure User-Agent spoofing"
            }
        }
    }
    
    public enum UserAgentProfile: String, CaseIterable, Codable {
        case chromeMac = "chrome_mac"
        case chromeWindows = "chrome_windows"
        case chromeLinux = "chrome_linux"
        case safariMac = "safari_mac"
        case firefoxMac = "firefox_mac"
        case firefoxWindows = "firefox_windows"
        case edgeMac = "edge_mac"
        case edgeWindows = "edge_windows"
        case random = "random"
        
        public var displayName: String {
            switch self {
            case .chromeMac: return "Chrome (macOS)"
            case .chromeWindows: return "Chrome (Windows)"
            case .chromeLinux: return "Chrome (Linux)"
            case .safariMac: return "Safari (macOS)"
            case .firefoxMac: return "Firefox (macOS)"
            case .firefoxWindows: return "Firefox (Windows)"
            case .edgeMac: return "Edge (macOS)"
            case .edgeWindows: return "Edge (Windows)"
            case .random: return "Random"
            }
        }
    }
    
    public struct SpoofingOptions {
        public let profile: UserAgentProfile
        public let customUserAgent: String?
        public let randomize: Bool
        public let persistSession: Bool
        
        public init(profile: UserAgentProfile = .random,
                   customUserAgent: String? = nil,
                   randomize: Bool = true,
                   persistSession: Bool = false) {
            self.profile = profile
            self.customUserAgent = customUserAgent
            self.randomize = randomize
            self.persistSession = persistSession
        }
    }
    
    // MARK: - Properties
    
    private let logger: PrivarionLogger
    private var currentUserAgent: String?
    private var originalUserAgent: String?
    private let queue = DispatchQueue(label: "com.privarion.useragent.spoofing")
    
    // MARK: - User-Agent Database
    
    private let userAgentDatabase: [UserAgentProfile: [String]] = [
        .chromeMac: [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
        ],
        .chromeWindows: [
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36"
        ],
        .chromeLinux: [
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36"
        ],
        .safariMac: [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        ],
        .firefoxMac: [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:120.0) Gecko/20100101 Firefox/120.0",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:119.0) Gecko/20100101 Firefox/119.0"
        ],
        .firefoxWindows: [
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:120.0) Gecko/20100101 Firefox/120.0"
        ],
        .edgeMac: [
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0",
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0"
        ],
        .edgeWindows: [
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0",
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0"
        ]
    ]
    
    // MARK: - Initialization
    
    public init(logger: PrivarionLogger = PrivarionLogger.shared) {
        self.logger = logger
    }
    
    // MARK: - Public API
    
    /// Enable User-Agent spoofing with specified options
    public func enableSpoofing(options: SpoofingOptions) throws {
        logger.info("Enabling User-Agent spoofing with profile: \(options.profile.rawValue)")
        
        let userAgent: String
        
        // Use custom User-Agent if provided
        if let custom = options.customUserAgent {
            guard validateUserAgent(custom) else {
                throw SpoofingError.invalidUserAgent
            }
            userAgent = custom
        } else {
            // Generate based on profile
            userAgent = try generateUserAgent(for: options.profile, randomize: options.randomize)
        }
        
        // Store current for potential restoration
        queue.sync {
            self.currentUserAgent = userAgent
        }
        
        logger.info("User-Agent spoofing enabled: \(userAgent)")
    }
    
    /// Disable User-Agent spoofing and restore original
    public func disableSpoofing() throws {
        logger.info("Disabling User-Agent spoofing")
        
        queue.sync {
            self.currentUserAgent = nil
        }
        
        logger.info("User-Agent spoofing disabled")
    }
    
    /// Get current spoofed User-Agent string
    public func getCurrentUserAgent() -> String? {
        return queue.sync { currentUserAgent }
    }
    
    /// Generate a random User-Agent from available profiles
    public func generateRandomUserAgent() throws -> String {
        let profiles = UserAgentProfile.allCases.filter { $0 != .random }
        guard let randomProfile = profiles.randomElement() else {
            throw SpoofingError.configurationFailed
        }
        
        return try generateUserAgent(for: randomProfile, randomize: true)
    }
    
    /// Get available User-Agent profiles
    public func getAvailableProfiles() -> [UserAgentProfile] {
        return UserAgentProfile.allCases
    }
    
    /// Validate User-Agent string format
    public func validateUserAgent(_ userAgent: String) -> Bool {
        // Basic validation - User-Agent should contain Mozilla prefix
        guard userAgent.hasPrefix("Mozilla/") else {
            return false
        }
        
        // Should contain at least one browser identifier
        let browserIdentifiers = ["Chrome", "Safari", "Firefox", "Edge", "OPR", "Opera"]
        let hasBrowserIdentifier = browserIdentifiers.contains { userAgent.contains($0) }
        
        return hasBrowserIdentifier && userAgent.count >= 20
    }
    
    /// Parse User-Agent and extract browser info
    public func parseUserAgent(_ userAgent: String) -> (browser: String, platform: String, version: String)? {
        var browser = "Unknown"
        var platform = "Unknown"
        var version = "Unknown"
        
        // Detect browser
        if userAgent.contains("Chrome") && !userAgent.contains("Edg") {
            browser = "Chrome"
            if let match = userAgent.range(of: #"Chrome/(\d+)"#, options: .regularExpression) {
                let versionStr = String(userAgent[match])
                version = versionStr.replacingOccurrences(of: "Chrome/", with: "")
            }
        } else if userAgent.contains("Edg") {
            browser = "Edge"
            if let match = userAgent.range(of: #"Edg/(\d+)"#, options: .regularExpression) {
                let versionStr = String(userAgent[match])
                version = versionStr.replacingOccurrences(of: "Edg/", with: "")
            }
        } else if userAgent.contains("Firefox") {
            browser = "Firefox"
            if let match = userAgent.range(of: #"Firefox/(\d+)"#, options: .regularExpression) {
                let versionStr = String(userAgent[match])
                version = versionStr.replacingOccurrences(of: "Firefox/", with: "")
            }
        } else if userAgent.contains("Safari") && !userAgent.contains("Chrome") {
            browser = "Safari"
            if let match = userAgent.range(of: #"Version/(\d+)"#, options: .regularExpression) {
                let versionStr = String(userAgent[match])
                version = versionStr.replacingOccurrences(of: "Version/", with: "")
            }
        }
        
        // Detect platform
        if userAgent.contains("Mac OS X") {
            platform = "macOS"
            if let match = userAgent.range(of: #"Mac OS X (\d+[._]\d+)"#, options: .regularExpression) {
                let versionStr = String(userAgent[match])
                platform = versionStr.replacingOccurrences(of: "Mac OS X ", with: "")
            }
        } else if userAgent.contains("Windows") {
            platform = "Windows"
        } else if userAgent.contains("Linux") {
            platform = "Linux"
        }
        
        return (browser, platform, version)
    }
    
    // MARK: - Private Methods
    
    private func generateUserAgent(for profile: UserAgentProfile, randomize: Bool) throws -> String {
        // Handle random profile
        let actualProfile: UserAgentProfile
        if profile == .random {
            let profiles = UserAgentProfile.allCases.filter { $0 != .random }
            guard let random = profiles.randomElement() else {
                throw SpoofingError.configurationFailed
            }
            actualProfile = random
        } else {
            actualProfile = profile
        }
        
        // Get User-Agent strings for profile
        guard let uaStrings = userAgentDatabase[actualProfile] else {
            throw SpoofingError.profileNotFound
        }
        
        guard !uaStrings.isEmpty else {
            throw SpoofingError.configurationFailed
        }
        
        // Select User-Agent
        if randomize {
            guard let randomUA = uaStrings.randomElement() else {
                throw SpoofingError.configurationFailed
            }
            return randomUA
        } else {
            return uaStrings[0]
        }
    }
}

// MARK: - User-Agent Injection Script Generation

extension UserAgentSpoofingManager {
    
    /// Generate JavaScript code for User-Agent spoofing (browser extension content script)
    public func generateSpoofingScript() -> String {
        guard let userAgent = getCurrentUserAgent() else {
            logger.warning("No User-Agent set, generating random")
            let ua = (try? generateRandomUserAgent()) ?? userAgentDatabase[.chromeMac]?.first ?? ""
            return generateScriptForUserAgent(ua)
        }
        return generateScriptForUserAgent(userAgent)
    }
    
    private func generateScriptForUserAgent(_ userAgent: String) -> String {
        let escapedUA = userAgent.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        
        return """
        (function() {
            // Override Navigator.userAgent
            Object.defineProperty(navigator, 'userAgent', {
                get: function() {
                    return '\(escapedUA)';
                },
                configurable: true
            });
            
            // Override Navigator.appVersion
            Object.defineProperty(navigator, 'appVersion', {
                get: function() {
                    return '\(escapedUA)';
                },
                configurable: true
            });
            
            // Override Navigator.platform
            Object.defineProperty(navigator, 'platform', {
                get: function() {
                    return 'MacIntel';
                },
                configurable: true
            });
            
            // Override Navigator.hardwareConcurrency
            Object.defineProperty(navigator, 'hardwareConcurrency', {
                get: function() {
                    return 8;
                },
                configurable: true
            });
            
            // Override Navigator.deviceMemory (if available)
            if (navigator.deviceMemory !== undefined) {
                Object.defineProperty(navigator, 'deviceMemory', {
                    get: function() {
                        return 8;
                    },
                    configurable: true
                });
            }
            
            console.log('[Privarion] User-Agent spoofing enabled');
        })();
        """
    }
}
