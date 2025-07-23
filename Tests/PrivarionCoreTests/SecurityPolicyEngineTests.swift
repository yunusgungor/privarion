import XCTest
@testable import PrivarionCore

final class SecurityPolicyEngineTests: XCTestCase {
    
    var policyEngine: SecurityPolicyEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        // Initialize without default policies for clean testing
        policyEngine = SecurityPolicyEngine(loadDefaults: false)
    }
    
    override func tearDown() async throws {
        policyEngine = nil
        try await super.tearDown()
    }
    
    // MARK: - Policy Management Tests
    
    func testAddPolicy() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "test-policy",
            name: "Test Policy",
            description: "Test policy for unit testing",
            condition: .processName(matches: "test"),
            action: .log(level: .info),
            severity: .low
        )
        
        await policyEngine.addPolicy(policy)
        let policies = await policyEngine.getAllPolicies()
        
        XCTAssertTrue(policies.contains { $0.id == "test-policy" })
        XCTAssertEqual(policies.first { $0.id == "test-policy" }?.name, "Test Policy")
    }
    
    func testRemovePolicy() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "remove-test",
            name: "Remove Test",
            description: "Policy to be removed",
            condition: .processName(matches: "remove"),
            action: .log(level: .info),
            severity: .low
        )
        
        await policyEngine.addPolicy(policy)
        await policyEngine.removePolicy(id: "remove-test")
        let policies = await policyEngine.getAllPolicies()
        
        XCTAssertFalse(policies.contains { $0.id == "remove-test" })
    }
    
    func testEnableDisablePolicy() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "toggle-test",
            name: "Toggle Test",
            description: "Policy to test enable/disable",
            condition: .processName(matches: "toggle"),
            action: .log(level: .info),
            severity: .low
        )
        
        await policyEngine.addPolicy(policy)
        await policyEngine.setPolicy(id: "toggle-test", enabled: false)
        
        let policies = await policyEngine.getAllPolicies()
        let togglePolicy = policies.first { $0.id == "toggle-test" }
        
        XCTAssertNotNil(togglePolicy)
        XCTAssertFalse(togglePolicy!.enabled)
        
        await policyEngine.setPolicy(id: "toggle-test", enabled: true)
        let updatedPolicies = await policyEngine.getAllPolicies()
        let enabledPolicy = updatedPolicies.first { $0.id == "toggle-test" }
        
        XCTAssertTrue(enabledPolicy!.enabled)
    }
    
    // MARK: - Policy Evaluation Tests
    
    func testProcessNamePolicyEvaluation() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "process-name-test",
            name: "Process Name Test",
            description: "Test process name matching",
            condition: .processName(matches: "suspicious"),
            action: .alert(message: "Suspicious process detected"),
            severity: .high
        )
        
        await policyEngine.addPolicy(policy)
        
        let request = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "test-event-001",
            timestamp: Date(),
            processID: 1234,
            processName: "suspicious-app",
            processPath: "/usr/bin/suspicious-app",
            fileOperations: [],
            networkConnections: []
        )
        
        let result = try await policyEngine.evaluateEvent(request)
        
        XCTAssertTrue(result.triggered)
        XCTAssertEqual(result.matchedPolicies, ["process-name-test"])
        XCTAssertEqual(result.severity, .high)
        XCTAssertLessThan(result.evaluationTime, 0.05) // <50ms target
    }
    
    func testProcessPathPolicyEvaluation() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "process-path-test",
            name: "Process Path Test",
            description: "Test process path matching",
            condition: .processPath(startsWith: "/tmp/"),
            action: .isolate(processID: 0),
            severity: .critical
        )
        
        await policyEngine.addPolicy(policy)
        
        let request = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "test-event-002",
            timestamp: Date(),
            processID: 5678,
            processName: "malware",
            processPath: "/tmp/malware",
            fileOperations: [],
            networkConnections: []
        )
        
        let result = try await policyEngine.evaluateEvent(request)
        
        XCTAssertTrue(result.triggered)
        XCTAssertEqual(result.matchedPolicies, ["process-path-test"])
        XCTAssertEqual(result.severity, .critical)
    }
    
    func testFileAccessPolicyEvaluation() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "file-access-test",
            name: "File Access Test",
            description: "Test file access monitoring",
            condition: .fileAccess(path: "/etc/passwd", type: .read),
            action: .alert(message: "Sensitive file access"),
            severity: .medium
        )
        
        await policyEngine.addPolicy(policy)
        
        let fileOperation = SecurityPolicyEngine.PolicyEvaluationRequest.FileOperation(
            path: "/etc/passwd",
            operation: .read,
            timestamp: Date()
        )
        
        let request = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "test-event-003",
            timestamp: Date(),
            processID: 9999,
            processName: "cat",
            processPath: "/bin/cat",
            fileOperations: [fileOperation],
            networkConnections: []
        )
        
        let result = try await policyEngine.evaluateEvent(request)
        
        XCTAssertTrue(result.triggered)
        XCTAssertEqual(result.matchedPolicies, ["file-access-test"])
        XCTAssertEqual(result.severity, .medium)
    }
    
    func testNetworkConnectionPolicyEvaluation() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "network-test",
            name: "Network Connection Test",
            description: "Test network connection monitoring",
            condition: .networkConnection(host: "malicious.com", port: 443),
            action: .terminate(processID: 0),
            severity: .critical
        )
        
        await policyEngine.addPolicy(policy)
        
        let networkConnection = SecurityPolicyEngine.PolicyEvaluationRequest.NetworkConnection(
            host: "malicious.com",
            port: 443,
            networkProtocol: "HTTPS",
            timestamp: Date()
        )
        
        let request = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "test-event-004",
            timestamp: Date(),
            processID: 7777,
            processName: "curl",
            processPath: "/usr/bin/curl",
            fileOperations: [],
            networkConnections: [networkConnection]
        )
        
        let result = try await policyEngine.evaluateEvent(request)
        
        XCTAssertTrue(result.triggered)
        XCTAssertEqual(result.matchedPolicies, ["network-test"])
        XCTAssertEqual(result.severity, .critical)
    }
    
    // MARK: - Complex Condition Tests
    
    func testAndConditionEvaluation() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "and-condition-test",
            name: "AND Condition Test",
            description: "Test AND condition logic",
            condition: .and([
                .processName(matches: "test"),
                .processPath(startsWith: "/usr/bin/")
            ]),
            action: .log(level: .warning),
            severity: .medium
        )
        
        await policyEngine.addPolicy(policy)
        
        // Test case that should match both conditions
        let matchingRequest = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "and-test-match",
            timestamp: Date(),
            processID: 1111,
            processName: "test-app",
            processPath: "/usr/bin/test-app",
            fileOperations: [],
            networkConnections: []
        )
        
        let matchingResult = try await policyEngine.evaluateEvent(matchingRequest)
        XCTAssertTrue(matchingResult.triggered)
        
        // Test case that should not match (only one condition met)
        let nonMatchingRequest = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "and-test-no-match",
            timestamp: Date(),
            processID: 2222,
            processName: "other-app",
            processPath: "/usr/bin/other-app",
            fileOperations: [],
            networkConnections: []
        )
        
        let nonMatchingResult = try await policyEngine.evaluateEvent(nonMatchingRequest)
        XCTAssertFalse(nonMatchingResult.triggered)
    }
    
    func testOrConditionEvaluation() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "or-condition-test",
            name: "OR Condition Test",
            description: "Test OR condition logic",
            condition: .or([
                .processName(matches: "malware"),
                .processPath(startsWith: "/tmp/")
            ]),
            action: .isolate(processID: 0),
            severity: .high
        )
        
        await policyEngine.addPolicy(policy)
        
        // Test case that matches first condition
        let firstConditionRequest = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "or-test-first",
            timestamp: Date(),
            processID: 3333,
            processName: "malware-app",
            processPath: "/usr/bin/malware-app",
            fileOperations: [],
            networkConnections: []
        )
        
        let firstResult = try await policyEngine.evaluateEvent(firstConditionRequest)
        XCTAssertTrue(firstResult.triggered)
        
        // Test case that matches second condition
        let secondConditionRequest = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "or-test-second",
            timestamp: Date(),
            processID: 4444,
            processName: "legitimate-app",
            processPath: "/tmp/legitimate-app",
            fileOperations: [],
            networkConnections: []
        )
        
        let secondResult = try await policyEngine.evaluateEvent(secondConditionRequest)
        XCTAssertTrue(secondResult.triggered)
    }
    
    func testNotConditionEvaluation() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "not-condition-test",
            name: "NOT Condition Test",
            description: "Test NOT condition logic",
            condition: .not(.processName(matches: "malware")),
            action: .alert(message: "Untrusted process"),
            severity: .low
        )
        
        await policyEngine.addPolicy(policy)
        
        // Test case with secure process (should trigger - NOT contains malware)
        let secureRequest = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "not-test-secure",
            timestamp: Date(),
            processID: 5555,
            processName: "secure-app",
            processPath: "/usr/bin/secure-app",
            fileOperations: [],
            networkConnections: []
        )
        
        let secureResult = try await policyEngine.evaluateEvent(secureRequest)
        XCTAssertTrue(secureResult.triggered)
        
        // Test case with malware process (should not trigger - contains malware)
        let malwareRequest = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "not-test-malware",
            timestamp: Date(),
            processID: 6666,
            processName: "malware-scanner",
            processPath: "/usr/bin/malware-scanner",
            fileOperations: [],
            networkConnections: []
        )
        
        let malwareResult = try await policyEngine.evaluateEvent(malwareRequest)
        XCTAssertFalse(malwareResult.triggered)
    }
    
    // MARK: - Performance Tests
    
    func testEvaluationPerformance() async throws {
        // Add multiple policies to test performance under load
        for i in 1...100 {
            let policy = SecurityPolicyEngine.SecurityPolicy(
                id: "perf-test-\(i)",
                name: "Performance Test \(i)",
                description: "Policy for performance testing",
                condition: .processName(matches: "perf-test-\(i)"),
                action: .log(level: .info),
                severity: .low
            )
            await policyEngine.addPolicy(policy)
        }
        
        let request = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "performance-test",
            timestamp: Date(),
            processID: 8888,
            processName: "performance-app",
            processPath: "/usr/bin/performance-app",
            fileOperations: [],
            networkConnections: []
        )
        
        let startTime = Date()
        let result = try await policyEngine.evaluateEvent(request)
        let evaluationTime = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(evaluationTime, 0.05) // Must be <50ms
        XCTAssertLessThan(result.evaluationTime, 0.05) // Internal measurement should also be <50ms
    }
    
    func testConcurrentEvaluations() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "concurrent-test",
            name: "Concurrent Test",
            description: "Policy for concurrent testing",
            condition: .processName(matches: "concurrent"),
            action: .alert(message: "Concurrent process detected"),
            severity: .medium
        )
        
        await policyEngine.addPolicy(policy)
        
        // Create 20 concurrent evaluation requests (target: >10 simultaneous)
        let requests = (1...20).map { i in
            SecurityPolicyEngine.PolicyEvaluationRequest(
                eventID: "concurrent-test-\(i)",
                timestamp: Date(),
                processID: Int32(i),
                processName: "concurrent-app-\(i)",
                processPath: "/usr/bin/concurrent-app-\(i)",
                fileOperations: [],
                networkConnections: []
            )
        }
        
        let startTime = Date()
        
        // Execute all requests concurrently
        let results = try await withThrowingTaskGroup(of: SecurityPolicyEngine.PolicyEvaluationResult.self) { group in
            for request in requests {
                group.addTask {
                    try await self.policyEngine.evaluateEvent(request)
                }
            }
            
            var results: [SecurityPolicyEngine.PolicyEvaluationResult] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
        
        let totalTime = Date().timeIntervalSince(startTime)
        
        XCTAssertEqual(results.count, 20)
        XCTAssertLessThan(totalTime, 2.0) // All 20 evaluations should complete within 2 seconds
        
        // Verify each individual evaluation was fast
        for result in results {
            XCTAssertLessThan(result.evaluationTime, 0.05)
        }
    }
    
    // MARK: - Policy Validation Tests
    
    func testPolicyValidation() async throws {
        let validPolicy = SecurityPolicyEngine.SecurityPolicy(
            id: "valid-policy",
            name: "Valid Policy",
            description: "A properly structured policy",
            condition: .processName(matches: "test"),
            action: .log(level: .info),
            severity: .low
        )
        
        let validation = await policyEngine.validatePolicy(validPolicy)
        XCTAssertTrue(validation.valid)
        XCTAssertTrue(validation.issues.isEmpty)
        XCTAssertEqual(validation.complexity, 1)
    }
    
    func testPolicyValidationWithErrors() async throws {
        let invalidPolicy = SecurityPolicyEngine.SecurityPolicy(
            id: "invalid-policy",
            name: "", // Empty name should trigger validation error
            description: "", // Empty description should trigger validation error
            condition: .processName(matches: "test"),
            action: .log(level: .info),
            severity: .low
        )
        
        let validation = await policyEngine.validatePolicy(invalidPolicy)
        XCTAssertFalse(validation.valid)
        XCTAssertTrue(validation.issues.contains("Policy name cannot be empty"))
        XCTAssertTrue(validation.issues.contains("Policy description cannot be empty"))
    }
    
    func testComplexPolicyValidation() async throws {
        // Create a very complex policy that should trigger complexity warning
        let complexCondition = SecurityPolicyEngine.PolicyCondition.and([
            .or([.processName(matches: "a"), .processName(matches: "b")]),
            .or([.processName(matches: "c"), .processName(matches: "d")]),
            .and([
                .fileAccess(path: "/etc", type: .read),
                .fileAccess(path: "/var", type: .write),
                .networkConnection(host: "example.com", port: 443)
            ])
        ])
        
        let complexPolicy = SecurityPolicyEngine.SecurityPolicy(
            id: "complex-policy",
            name: "Complex Policy",
            description: "A very complex policy",
            condition: complexCondition,
            action: .log(level: .info),
            severity: .low
        )
        
        let validation = await policyEngine.validatePolicy(complexPolicy)
        XCTAssertGreaterThan(validation.complexity, 5)
    }
    
    // MARK: - Default Policies Tests
    
    func testDefaultPoliciesLoaded() async throws {
        // Create a separate engine with default policies for this test
        let defaultPolicyEngine = SecurityPolicyEngine(loadDefaults: true)
        
        // Wait a bit for async loading to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        let policies = await defaultPolicyEngine.getAllPolicies()
        
        // Should have default policies loaded
        XCTAssertGreaterThan(policies.count, 0)
        
        // Check for specific default policies
        XCTAssertTrue(policies.contains { $0.id == "suspicious-process-execution" })
        XCTAssertTrue(policies.contains { $0.id == "unauthorized-file-access" })
        XCTAssertTrue(policies.contains { $0.id == "suspicious-network-activity" })
    }
    
    func testDefaultPolicyTriggers() async throws {
        // Create a separate engine with default policies for this test
        let defaultPolicyEngine = SecurityPolicyEngine(loadDefaults: true)
        
        // Wait a bit for async loading to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Test suspicious process policy
        let suspiciousProcessRequest = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "default-test-001",
            timestamp: Date(),
            processID: 1234,
            processName: "nc", // Should trigger suspicious process policy
            processPath: "/usr/bin/nc",
            fileOperations: [],
            networkConnections: []
        )
        
        let suspiciousResult = try await defaultPolicyEngine.evaluateEvent(suspiciousProcessRequest)
        XCTAssertTrue(suspiciousResult.triggered)
        XCTAssertTrue(suspiciousResult.matchedPolicies.contains("suspicious-process-execution"))
        
        // Test unauthorized file access policy
        let fileAccessOperation = SecurityPolicyEngine.PolicyEvaluationRequest.FileOperation(
            path: "/etc/passwd",
            operation: .read,
            timestamp: Date()
        )
        
        let fileAccessRequest = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "default-test-002",
            timestamp: Date(),
            processID: 5678,
            processName: "cat",
            processPath: "/bin/cat",
            fileOperations: [fileAccessOperation],
            networkConnections: []
        )
        
        let fileResult = try await defaultPolicyEngine.evaluateEvent(fileAccessRequest)
        XCTAssertTrue(fileResult.triggered)
        XCTAssertTrue(fileResult.matchedPolicies.contains("unauthorized-file-access"))
    }
    
    // MARK: - Error Handling Tests
    
    func testNonExistentPolicyRemoval() async throws {
        // Removing non-existent policy should not crash
        await policyEngine.removePolicy(id: "non-existent-policy")
        
        // Should still be able to function normally
        let policies = await policyEngine.getAllPolicies()
        XCTAssertEqual(policies.count, 0) // Test engine doesn't load defaults
    }
    
    func testDisabledPolicyNotTriggered() async throws {
        let policy = SecurityPolicyEngine.SecurityPolicy(
            id: "disabled-test",
            name: "Disabled Test",
            description: "Policy to test disabled state",
            condition: .processName(matches: "disabled-test"),
            action: .alert(message: "Should not trigger"),
            severity: .high,
            enabled: false // Disabled policy
        )
        
        await policyEngine.addPolicy(policy)
        
        let request = SecurityPolicyEngine.PolicyEvaluationRequest(
            eventID: "disabled-test-001",
            timestamp: Date(),
            processID: 9999,
            processName: "disabled-test-app",
            processPath: "/usr/bin/disabled-test-app",
            fileOperations: [],
            networkConnections: []
        )
        
        let result = try await policyEngine.evaluateEvent(request)
        XCTAssertFalse(result.triggered)
        XCTAssertFalse(result.matchedPolicies.contains("disabled-test"))
    }
}
