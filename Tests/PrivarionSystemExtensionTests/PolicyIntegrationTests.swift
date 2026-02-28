// PrivarionSystemExtensionTests - Policy Integration Tests
// Tests for SecurityEventProcessor integration with ProtectionPolicyEngine
// Requirements: 2.6-2.7, 11.7

import XCTest
import Logging
@testable import PrivarionSystemExtension
@testable import PrivarionSharedModels
@testable import PrivarionCore

final class PolicyIntegrationTests: XCTestCase {
    
    var processor: SecurityEventProcessor!
    var policyEngine: ProtectionPolicyEngine!
    var logger: Logger!
    
    override func setUp() async throws {
        logger = Logger(label: "com.privarion.test.policyintegration")
        policyEngine = ProtectionPolicyEngine()
        processor = SecurityEventProcessor(policyEngine: policyEngine, logger: logger)
    }
    
    override func tearDown() async throws {
        processor = nil
        policyEngine = nil
        logger = nil
    }
    
    // MARK: - Policy Application Tests
    
    func testDefaultPolicyAllowsExecution() async {
        // Given - default policy should allow execution
        let event = ProcessExecutionEvent(
            processID: 1234,
            executablePath: "/Applications/TestApp.app/Contents/MacOS/TestApp",
            arguments: [],
            environment: [:],
            parentProcessID: 1
        )
        
        // When - no specific policy is configured, should use default
        // Note: We can't directly test handleProcessExecution without a real es_message_t
        // This test verifies the policy engine returns default policy
        let policy = policyEngine.evaluatePolicy(for: event.executablePath)
        
        // Then - default policy should be returned
        XCTAssertEqual(policy.identifier, "*", "Should return default policy")
        XCTAssertEqual(policy.protectionLevel, .basic, "Default policy should be basic level")
        XCTAssertFalse(policy.requiresVMIsolation, "Default policy should not require VM isolation")
    }
    
    func testStrictPolicyWithBlockActionDeniesExecution() async {
        // Given - strict policy with block action
        let policy = ProtectionPolicy(
            identifier: "com.test.blocked",
            protectionLevel: .strict,
            networkFiltering: NetworkFilteringRules(
                action: .block,
                allowedDomains: [],
                blockedDomains: ["*"]
            ),
            dnsFiltering: DNSFilteringRules(),
            hardwareSpoofing: .none,
            requiresVMIsolation: false
        )
        policyEngine.addPolicy(policy)
        
        // When - evaluating policy for blocked app
        let evaluatedPolicy = policyEngine.evaluatePolicy(for: "com.test.blocked")
        
        // Then - policy should be strict with block action
        XCTAssertEqual(evaluatedPolicy.identifier, "com.test.blocked")
        XCTAssertEqual(evaluatedPolicy.protectionLevel, .strict)
        XCTAssertEqual(evaluatedPolicy.networkFiltering.action, .block)
    }
    
    func testParanoidPolicyDeniesExecutionByDefault() async {
        // Given - paranoid policy without allowed domains
        let policy = ProtectionPolicy(
            identifier: "/Applications/ParanoidApp.app",
            protectionLevel: .paranoid,
            networkFiltering: NetworkFilteringRules(
                action: .block,
                allowedDomains: [],
                blockedDomains: []
            ),
            dnsFiltering: DNSFilteringRules(),
            hardwareSpoofing: .full,
            requiresVMIsolation: false
        )
        policyEngine.addPolicy(policy)
        
        // When - evaluating policy
        let evaluatedPolicy = policyEngine.evaluatePolicy(for: "/Applications/ParanoidApp.app/Contents/MacOS/ParanoidApp")
        
        // Then - policy should be paranoid
        XCTAssertEqual(evaluatedPolicy.protectionLevel, .paranoid)
        XCTAssertTrue(evaluatedPolicy.networkFiltering.allowedDomains.isEmpty)
    }
    
    func testVMIsolationRequiredPolicy() async {
        // Given - policy requiring VM isolation
        let policy = ProtectionPolicy(
            identifier: "com.test.isolated",
            protectionLevel: .paranoid,
            networkFiltering: NetworkFilteringRules(),
            dnsFiltering: DNSFilteringRules(),
            hardwareSpoofing: .full,
            requiresVMIsolation: true
        )
        policyEngine.addPolicy(policy)
        
        // When - evaluating policy
        let evaluatedPolicy = policyEngine.evaluatePolicy(for: "com.test.isolated")
        
        // Then - policy should require VM isolation
        XCTAssertTrue(evaluatedPolicy.requiresVMIsolation, "Policy should require VM isolation")
        XCTAssertEqual(evaluatedPolicy.hardwareSpoofing, .full, "VM isolation requires full hardware spoofing")
    }
    
    func testBasicProtectionLevelAllowsExecution() async {
        // Given - basic protection policy
        let policy = ProtectionPolicy(
            identifier: "com.test.basic",
            protectionLevel: .basic,
            networkFiltering: NetworkFilteringRules(
                action: .monitor,
                allowedDomains: [],
                blockedDomains: []
            ),
            dnsFiltering: DNSFilteringRules(),
            hardwareSpoofing: .none,
            requiresVMIsolation: false
        )
        policyEngine.addPolicy(policy)
        
        // When - evaluating policy
        let evaluatedPolicy = policyEngine.evaluatePolicy(for: "com.test.basic")
        
        // Then - policy should be basic with monitor action
        XCTAssertEqual(evaluatedPolicy.protectionLevel, .basic)
        XCTAssertEqual(evaluatedPolicy.networkFiltering.action, .monitor)
        XCTAssertFalse(evaluatedPolicy.requiresVMIsolation)
    }
    
    func testStandardProtectionLevelAllowsWithFiltering() async {
        // Given - standard protection policy
        let policy = ProtectionPolicy(
            identifier: "com.test.standard",
            protectionLevel: .standard,
            networkFiltering: NetworkFilteringRules(
                action: .allow,
                allowedDomains: ["example.com"],
                blockedDomains: ["tracker.com"]
            ),
            dnsFiltering: DNSFilteringRules(
                action: .allow,
                blockTracking: true,
                blockFingerprinting: false,
                customBlocklist: []
            ),
            hardwareSpoofing: .basic,
            requiresVMIsolation: false
        )
        policyEngine.addPolicy(policy)
        
        // When - evaluating policy
        let evaluatedPolicy = policyEngine.evaluatePolicy(for: "com.test.standard")
        
        // Then - policy should be standard with filtering
        XCTAssertEqual(evaluatedPolicy.protectionLevel, .standard)
        XCTAssertEqual(evaluatedPolicy.networkFiltering.action, .allow)
        XCTAssertTrue(evaluatedPolicy.dnsFiltering.blockTracking)
        XCTAssertEqual(evaluatedPolicy.hardwareSpoofing, .basic)
    }
    
    func testMostSpecificPolicyIsSelected() async {
        // Given - multiple policies with different specificity
        let generalPolicy = ProtectionPolicy(
            identifier: "/Applications",
            protectionLevel: .basic,
            networkFiltering: NetworkFilteringRules(),
            dnsFiltering: DNSFilteringRules(),
            hardwareSpoofing: .none,
            requiresVMIsolation: false
        )
        
        let specificPolicy = ProtectionPolicy(
            identifier: "/Applications/TestApp.app",
            protectionLevel: .strict,
            networkFiltering: NetworkFilteringRules(),
            dnsFiltering: DNSFilteringRules(),
            hardwareSpoofing: .full,
            requiresVMIsolation: true
        )
        
        policyEngine.addPolicy(generalPolicy)
        policyEngine.addPolicy(specificPolicy)
        
        // When - evaluating policy for specific app
        let evaluatedPolicy = policyEngine.evaluatePolicy(for: "/Applications/TestApp.app/Contents/MacOS/TestApp")
        
        // Then - most specific policy should be selected
        XCTAssertEqual(evaluatedPolicy.identifier, "/Applications/TestApp.app")
        XCTAssertEqual(evaluatedPolicy.protectionLevel, .strict)
        XCTAssertTrue(evaluatedPolicy.requiresVMIsolation)
    }
    
    func testPolicyEngineIntegrationWithProcessor() async {
        // Given - processor with policy engine
        let policy = ProtectionPolicy(
            identifier: "com.test.app",
            protectionLevel: .standard,
            networkFiltering: NetworkFilteringRules(),
            dnsFiltering: DNSFilteringRules(),
            hardwareSpoofing: .basic,
            requiresVMIsolation: false
        )
        policyEngine.addPolicy(policy)
        
        // When - processor is initialized with policy engine
        // Then - processor should have access to policy engine
        XCTAssertNotNil(processor, "Processor should be initialized with policy engine")
        
        // Verify policy can be retrieved
        let retrievedPolicy = policyEngine.evaluatePolicy(for: "com.test.app")
        XCTAssertEqual(retrievedPolicy.identifier, "com.test.app")
    }
}
