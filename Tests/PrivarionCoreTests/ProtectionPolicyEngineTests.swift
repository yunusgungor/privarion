import XCTest
@testable import PrivarionCore

final class ProtectionPolicyEngineTests: XCTestCase {
    var engine: ProtectionPolicyEngine!
    
    override func setUp() {
        super.setUp()
        engine = ProtectionPolicyEngine()
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    // MARK: - Policy Matching Tests
    
    func testPolicyMatchingWithExactBundleID() {
        // Given: A policy with a bundle ID
        let policy = ProtectionPolicy(
            identifier: "com.apple.Safari",
            protectionLevel: .strict
        )
        engine.addPolicy(policy)
        
        // When: Evaluating with matching bundle ID path
        let result = engine.evaluatePolicy(for: "/Applications/Safari.app/Contents/MacOS/Safari")
        
        // Then: Should return the matching policy
        XCTAssertEqual(result.identifier, "com.apple.Safari")
        XCTAssertEqual(result.protectionLevel, .strict)
    }
    
    func testPolicyMatchingWithPath() {
        // Given: A policy with a path
        let policy = ProtectionPolicy(
            identifier: "/usr/local/bin/myapp",
            protectionLevel: .paranoid
        )
        engine.addPolicy(policy)
        
        // When: Evaluating with exact path
        let result = engine.evaluatePolicy(for: "/usr/local/bin/myapp")
        
        // Then: Should return the matching policy
        XCTAssertEqual(result.identifier, "/usr/local/bin/myapp")
        XCTAssertEqual(result.protectionLevel, .paranoid)
    }
    
    func testMostSpecificPolicySelection() {
        // Given: Multiple policies with overlapping paths
        let generalPolicy = ProtectionPolicy(
            identifier: "/usr/local",
            protectionLevel: .basic
        )
        let specificPolicy = ProtectionPolicy(
            identifier: "/usr/local/bin",
            protectionLevel: .strict
        )
        engine.addPolicy(generalPolicy)
        engine.addPolicy(specificPolicy)
        
        // When: Evaluating with a path matching both
        let result = engine.evaluatePolicy(for: "/usr/local/bin/myapp")
        
        // Then: Should return the most specific policy
        XCTAssertEqual(result.identifier, "/usr/local/bin")
        XCTAssertEqual(result.protectionLevel, .strict)
    }
    
    func testDefaultPolicyFallback() {
        // Given: Engine with default policy only
        let defaultPolicy = ProtectionPolicy(
            identifier: "*",
            protectionLevel: .basic
        )
        engine = ProtectionPolicyEngine(defaultPolicy: defaultPolicy)
        
        // When: Evaluating with unmatched path
        let result = engine.evaluatePolicy(for: "/some/random/app")
        
        // Then: Should return default policy
        XCTAssertEqual(result.identifier, "*")
        XCTAssertEqual(result.protectionLevel, .basic)
    }
    
    // MARK: - Policy Inheritance Tests
    
    func testPolicyInheritance() {
        // Given: Parent and child policies
        let parentPolicy = ProtectionPolicy(
            identifier: "parent",
            protectionLevel: .standard,
            networkFiltering: NetworkFilteringRules(
                action: .block,
                allowedDomains: ["example.com"],
                blockedDomains: ["tracker.com"]
            )
        )
        let childPolicy = ProtectionPolicy(
            identifier: "child",
            protectionLevel: .strict,
            networkFiltering: NetworkFilteringRules(
                action: .block,
                allowedDomains: [],
                blockedDomains: []
            ),
            parentPolicy: "parent"
        )
        
        engine.addPolicy(parentPolicy)
        engine.addPolicy(childPolicy)
        
        // When: Evaluating child policy
        let result = engine.evaluatePolicy(for: "child")
        
        // Then: Should inherit parent's network rules
        XCTAssertEqual(result.protectionLevel, .strict)
        XCTAssertEqual(result.networkFiltering.allowedDomains, ["example.com"])
        XCTAssertEqual(result.networkFiltering.blockedDomains, ["tracker.com"])
    }
    
    func testMultiLevelInheritance() {
        // Given: Three-level inheritance chain
        let grandparentPolicy = ProtectionPolicy(
            identifier: "grandparent",
            protectionLevel: .basic,
            dnsFiltering: DNSFilteringRules(
                action: .allow,
                blockTracking: true,
                blockFingerprinting: false,
                customBlocklist: ["ads.com"]
            )
        )
        let parentPolicy = ProtectionPolicy(
            identifier: "parent",
            protectionLevel: .standard,
            dnsFiltering: DNSFilteringRules(
                action: .allow,
                blockTracking: true,  // Inherit from grandparent
                blockFingerprinting: false,
                customBlocklist: []  // Empty, should inherit from grandparent
            ),
            parentPolicy: "grandparent"
        )
        let childPolicy = ProtectionPolicy(
            identifier: "child",
            protectionLevel: .strict,
            dnsFiltering: DNSFilteringRules(
                action: .allow,
                blockTracking: true,  // Inherit from parent/grandparent
                blockFingerprinting: false,
                customBlocklist: []  // Empty, should inherit from grandparent
            ),
            parentPolicy: "parent"
        )
        
        engine.addPolicy(grandparentPolicy)
        engine.addPolicy(parentPolicy)
        engine.addPolicy(childPolicy)
        
        // When: Evaluating child policy
        let result = engine.evaluatePolicy(for: "child")
        
        // Then: Should inherit from grandparent through parent
        XCTAssertEqual(result.protectionLevel, .strict)
        XCTAssertTrue(result.dnsFiltering.blockTracking)
        XCTAssertEqual(result.dnsFiltering.customBlocklist, ["ads.com"])
    }
    
    // MARK: - Policy Management Tests
    
    func testAddPolicy() {
        // Given: A new policy
        let policy = ProtectionPolicy(
            identifier: "test.app",
            protectionLevel: .standard
        )
        
        // When: Adding the policy
        engine.addPolicy(policy)
        
        // Then: Policy should be retrievable
        let retrieved = engine.getPolicy(identifier: "test.app")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.identifier, "test.app")
    }
    
    func testRemovePolicy() {
        // Given: An existing policy
        let policy = ProtectionPolicy(
            identifier: "test.app",
            protectionLevel: .standard
        )
        engine.addPolicy(policy)
        
        // When: Removing the policy
        engine.removePolicy(identifier: "test.app")
        
        // Then: Policy should not be retrievable
        let retrieved = engine.getPolicy(identifier: "test.app")
        XCTAssertNil(retrieved)
    }
    
    func testLoadPoliciesFromFile() throws {
        // Given: A temporary JSON file with policies
        let policies = [
            ProtectionPolicy(identifier: "app1", protectionLevel: .basic),
            ProtectionPolicy(identifier: "app2", protectionLevel: .strict)
        ]
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(policies)
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-policies.json")
        try data.write(to: tempURL)
        
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        // When: Loading policies from file
        try engine.loadPolicies(from: tempURL)
        
        // Then: Policies should be loaded
        XCTAssertNotNil(engine.getPolicy(identifier: "app1"))
        XCTAssertNotNil(engine.getPolicy(identifier: "app2"))
    }
    
    // MARK: - Validation Tests
    
    func testValidatePolicyWithValidBundleID() throws {
        // Given: A policy with valid bundle ID
        let policy = ProtectionPolicy(
            identifier: "com.example.app",
            protectionLevel: .standard
        )
        
        // When/Then: Validation should succeed
        XCTAssertNoThrow(try engine.validatePolicy(policy))
    }
    
    func testValidatePolicyWithInvalidBundleID() {
        // Given: A policy with invalid bundle ID
        let policy = ProtectionPolicy(
            identifier: "invalid bundle id",
            protectionLevel: .standard
        )
        
        // When/Then: Validation should fail
        XCTAssertThrowsError(try engine.validatePolicy(policy)) { error in
            XCTAssertTrue(error is PolicyValidationError)
        }
    }
    
    func testValidatePolicyWithEmptyIdentifier() {
        // Given: A policy with empty identifier
        let policy = ProtectionPolicy(
            identifier: "",
            protectionLevel: .standard
        )
        
        // When/Then: Validation should fail
        XCTAssertThrowsError(try engine.validatePolicy(policy)) { error in
            guard case PolicyValidationError.emptyIdentifier = error else {
                XCTFail("Expected emptyIdentifier error")
                return
            }
        }
    }
    
    func testValidatePolicyWithInvalidDomainPattern() {
        // Given: A policy with invalid domain pattern
        let policy = ProtectionPolicy(
            identifier: "test.app",
            protectionLevel: .standard,
            networkFiltering: NetworkFilteringRules(
                action: .block,
                allowedDomains: [],
                blockedDomains: ["invalid domain!"]
            )
        )
        
        // When/Then: Validation should fail
        XCTAssertThrowsError(try engine.validatePolicy(policy)) { error in
            XCTAssertTrue(error is PolicyValidationError)
        }
    }
    
    func testValidatePolicyWithInconsistentRules() {
        // Given: A policy with VM isolation but not full hardware spoofing
        let policy = ProtectionPolicy(
            identifier: "test.app",
            protectionLevel: .standard,
            hardwareSpoofing: .basic,
            requiresVMIsolation: true
        )
        
        // When/Then: Validation should fail
        XCTAssertThrowsError(try engine.validatePolicy(policy)) { error in
            guard case PolicyValidationError.inconsistentRules = error else {
                XCTFail("Expected inconsistentRules error")
                return
            }
        }
    }
    
    func testValidatePolicyWithConflictingDomains() {
        // Given: A policy with same domain in allowed and blocked lists
        let policy = ProtectionPolicy(
            identifier: "test.app",
            protectionLevel: .standard,
            networkFiltering: NetworkFilteringRules(
                action: .block,
                allowedDomains: ["example.com"],
                blockedDomains: ["example.com"]
            )
        )
        
        // When/Then: Validation should fail
        XCTAssertThrowsError(try engine.validatePolicy(policy)) { error in
            guard case PolicyValidationError.inconsistentRules = error else {
                XCTFail("Expected inconsistentRules error")
                return
            }
        }
    }
    
    func testValidatePolicyWithMissingParent() {
        // Given: A policy with non-existent parent
        let policy = ProtectionPolicy(
            identifier: "child",
            protectionLevel: .standard,
            parentPolicy: "nonexistent"
        )
        
        // When/Then: Validation should fail
        XCTAssertThrowsError(try engine.validatePolicy(policy)) { error in
            guard case PolicyValidationError.parentPolicyNotFound = error else {
                XCTFail("Expected parentPolicyNotFound error")
                return
            }
        }
    }
    
    func testValidatePolicyWithCircularInheritance() {
        // Given: Policies with circular inheritance
        let policy1 = ProtectionPolicy(
            identifier: "policy1",
            protectionLevel: .standard,
            parentPolicy: "policy2"
        )
        let policy2 = ProtectionPolicy(
            identifier: "policy2",
            protectionLevel: .standard,
            parentPolicy: "policy1"
        )
        
        engine.addPolicy(policy1)
        engine.addPolicy(policy2)
        
        // When/Then: Validation should fail
        XCTAssertThrowsError(try engine.validatePolicy(policy1)) { error in
            guard case PolicyValidationError.circularInheritance = error else {
                XCTFail("Expected circularInheritance error")
                return
            }
        }
    }
    
    func testValidatePolicyWithValidWildcardDomain() throws {
        // Given: A policy with wildcard domain pattern
        let policy = ProtectionPolicy(
            identifier: "test.app",
            protectionLevel: .standard,
            networkFiltering: NetworkFilteringRules(
                action: .block,
                allowedDomains: [],
                blockedDomains: ["*.tracker.com"]
            )
        )
        
        // When/Then: Validation should succeed
        XCTAssertNoThrow(try engine.validatePolicy(policy))
    }
}
