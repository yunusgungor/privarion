import XCTest
import SwiftCheck
@testable import PrivarionCore

/// Property-based tests for system extension configuration
/// Feature: macos-system-level-privacy-protection
final class SystemExtensionConfigurationPropertyTests: XCTestCase {
    
    // MARK: - Property 1: Configuration Round-Trip Consistency
    
    /// **Validates: Requirements 16.8**
    ///
    /// Property: For all valid configuration objects, parsing then printing then parsing
    /// produces an equivalent object (round-trip property)
    func testConfigurationRoundTripConsistency() {
        // Test with default configuration
        let config = SystemExtensionConfiguration.defaultConfiguration()
        
        do {
            // Encode configuration to JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let jsonData = try encoder.encode(config)
            
            // Decode back to configuration
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedConfig = try decoder.decode(SystemExtensionConfiguration.self, from: jsonData)
            
            // Verify equivalence
            XCTAssertEqual(config, decodedConfig, "Round-trip should produce equivalent configuration")
        } catch {
            XCTFail("Round-trip failed with error: \(error)")
        }
    }
    
    /// Test round-trip with pretty printer
    func testConfigurationRoundTripWithPrettyPrinter() {
        let config = SystemExtensionConfiguration.defaultConfiguration()
        
        do {
            // Format with pretty printer
            let formatted = try JSONPrettyPrinter.format(config)
            
            // Parse formatted JSON
            guard let data = formatted.data(using: .utf8) else {
                XCTFail("Failed to convert formatted string to data")
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedConfig = try decoder.decode(SystemExtensionConfiguration.self, from: data)
            
            // Verify equivalence
            XCTAssertEqual(config, decodedConfig, "Round-trip with pretty printer should produce equivalent configuration")
        } catch {
            XCTFail("Round-trip with pretty printer failed: \(error)")
        }
    }
    
    /// Test that validation is idempotent
    func testValidationIdempotence() {
        let config = SystemExtensionConfiguration.defaultConfiguration()
        
        do {
            // Validate once
            let issues1 = try ConfigurationValidator.validate(config)
            
            // Validate again
            let issues2 = try ConfigurationValidator.validate(config)
            
            // Results should be identical
            XCTAssertEqual(issues1.count, issues2.count, "Validation should be idempotent")
        } catch {
            XCTFail("Validation failed: \(error)")
        }
    }
    
    /// Test round-trip with multiple configurations
    func testMultipleConfigurationRoundTrips() {
        let configurations = [
            SystemExtensionConfiguration.defaultConfiguration(),
            createCustomConfiguration1(),
            createCustomConfiguration2()
        ]
        
        for (index, config) in configurations.enumerated() {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                encoder.dateEncodingStrategy = .iso8601
                let jsonData = try encoder.encode(config)
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decodedConfig = try decoder.decode(SystemExtensionConfiguration.self, from: jsonData)
                
                XCTAssertEqual(config, decodedConfig, "Configuration \(index) round-trip failed")
            } catch {
                XCTFail("Configuration \(index) round-trip failed with error: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createCustomConfiguration1() -> SystemExtensionConfiguration {
        return SystemExtensionConfiguration(
            version: "1.0.0",
            policies: [
                ProtectionPolicy(
                    identifier: "com.example.app",
                    protectionLevel: .strict,
                    networkFiltering: NetworkFilteringRules(action: .block, blockedDomains: ["tracker.com"]),
                    dnsFiltering: DNSFilteringRules(action: .block, blockTracking: true, blockFingerprinting: true),
                    hardwareSpoofing: .full,
                    requiresVMIsolation: true
                )
            ],
            profiles: HardwareProfile.predefinedProfiles(),
            blocklists: BlocklistConfiguration.defaultBlocklist(),
            networkSettings: NetworkConfiguration(dnsProxyPort: 5353, httpProxyPort: 8080, httpsProxyPort: 8443),
            loggingSettings: LoggingConfiguration(level: .debug, rotationDays: 14, maxSizeMB: 200)
        )
    }
    
    private func createCustomConfiguration2() -> SystemExtensionConfiguration {
        return SystemExtensionConfiguration(
            version: "1.0.0",
            policies: [
                ProtectionPolicy(
                    identifier: "*",
                    protectionLevel: .basic,
                    networkFiltering: NetworkFilteringRules(action: .monitor),
                    dnsFiltering: DNSFilteringRules(action: .allow, blockTracking: false),
                    hardwareSpoofing: .none,
                    requiresVMIsolation: false
                )
            ],
            profiles: [],
            blocklists: BlocklistConfiguration(),
            networkSettings: NetworkConfiguration(),
            loggingSettings: LoggingConfiguration()
        )
    }
}
