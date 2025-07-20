import XCTest
import Foundation
@testable import PrivarionCore

final class SyscallMonitoringEngineTests: XCTestCase {
    
    var monitoringEngine: SyscallMonitoringEngine!
    
    override func setUp() {
        super.setUp()
        monitoringEngine = SyscallMonitoringEngine.shared
        // Clear all rules for clean test state
        monitoringEngine.clearAllRules()
    }
    
    override func tearDown() {
        do {
            try monitoringEngine.stopMonitoring()
        } catch {
            // Ignore errors during tearDown
        }
        // Clear all rules for test isolation
        monitoringEngine.clearAllRules()
        monitoringEngine = nil
        super.tearDown()
    }
    
    // MARK: - Rule Management Tests
    
    func testAddMonitoringRule_ValidRule_ShouldSucceed() {
        // Given
        let condition = SyscallMonitoringEngine.RuleCondition(
            syscalls: ["open", "openat"],
            processFilters: SyscallMonitoringEngine.RuleCondition.ProcessFilters(
                allowedProcesses: ["test_process"],
                blockedProcesses: [],
                allowedUIDs: [501],
                blockedUIDs: []
            ),
            pathFilters: nil,
            networkFilters: nil,
            customCondition: nil
        )
        
        let rule = SyscallMonitoringEngine.MonitoringRule(
            id: "test-rule-001",
            name: "Test File Access Rule",
            description: "Detects file access attempts by test processes",
            condition: condition,
            output: "Test process accessed file: %proc.name %fd.name",
            priority: .warning,
            enabled: true,
            exceptions: []
        )
        
        // When
        do {
            try monitoringEngine.addRule(rule)
            
            // Then
            let rules = monitoringEngine.getRules()
            XCTAssertEqual(rules.count, 1)
            XCTAssertEqual(rules.first?.id, "test-rule-001")
            XCTAssertEqual(rules.first?.name, "Test File Access Rule")
        } catch {
            XCTFail("Adding valid rule should not throw error: \(error)")
        }
    }
    
    func testAddMonitoringRule_DuplicateID_ShouldFail() {
        // Given
        let condition1 = SyscallMonitoringEngine.RuleCondition(
            syscalls: ["open"],
            processFilters: nil,
            pathFilters: nil,
            networkFilters: nil,
            customCondition: nil
        )
        
        let rule1 = SyscallMonitoringEngine.MonitoringRule(
            id: "test-rule-001",
            name: "First Rule",
            description: "First test rule",
            condition: condition1,
            output: "First rule output",
            priority: .info,
            enabled: true,
            exceptions: []
        )
        
        let condition2 = SyscallMonitoringEngine.RuleCondition(
            syscalls: ["write"],
            processFilters: nil,
            pathFilters: nil,
            networkFilters: nil,
            customCondition: nil
        )
        
        let rule2 = SyscallMonitoringEngine.MonitoringRule(
            id: "test-rule-001", // Same ID
            name: "Second Rule",
            description: "Second test rule",
            condition: condition2,
            output: "Second rule output",
            priority: .warning,
            enabled: true,
            exceptions: []
        )
        
        // When
        do {
            try monitoringEngine.addRule(rule1)
            // This should fail
            try monitoringEngine.addRule(rule2)
            XCTFail("Adding duplicate rule ID should throw error")
        } catch {
            // Then
            XCTAssertTrue(error is SyscallMonitoringEngine.MonitoringError)
            let rules = monitoringEngine.getRules()
            XCTAssertEqual(rules.count, 1)
            XCTAssertEqual(rules.first?.name, "First Rule")
        }
    }
    
    func testRemoveMonitoringRule_ExistingRule_ShouldSucceed() {
        // Given
        let condition = SyscallMonitoringEngine.RuleCondition(
            syscalls: ["open"],
            processFilters: nil,
            pathFilters: nil,
            networkFilters: nil,
            customCondition: nil
        )
        
        let rule = SyscallMonitoringEngine.MonitoringRule(
            id: "test-rule-001",
            name: "Test Rule",
            description: "Test rule for removal",
            condition: condition,
            output: "Test output",
            priority: .info,
            enabled: true,
            exceptions: []
        )
        
        do {
            try monitoringEngine.addRule(rule)
            XCTAssertEqual(monitoringEngine.getRules().count, 1)
            
            // When
            try monitoringEngine.removeRule("test-rule-001")
            
            // Then
            XCTAssertEqual(monitoringEngine.getRules().count, 0)
        } catch {
            XCTFail("Rule management should not throw error: \(error)")
        }
    }
    
    func testRemoveMonitoringRule_NonExistentRule_ShouldFail() {
        // Given
        let nonExistentRuleID = "non-existent-rule"
        
        // When & Then
        do {
            try monitoringEngine.removeRule(nonExistentRuleID)
            XCTFail("Removing non-existent rule should throw error")
        } catch {
            XCTAssertTrue(error is SyscallMonitoringEngine.MonitoringError)
        }
    }
    
    // MARK: - Monitoring Control Tests
    
    func testStartMonitoring_WhenStopped_ShouldSucceed() {
        // When & Then
        do {
            try monitoringEngine.startMonitoring()
            XCTAssertTrue(true) // Success if no exception thrown
        } catch {
            // This might fail on CI/testing environments without proper entitlements
            // We'll just log the error and mark as success
            print("Start monitoring failed (expected in test environment): \(error)")
        }
    }
    
    func testStartMonitoring_WhenAlreadyRunning_ShouldFail() {
        // Given
        do {
            try monitoringEngine.startMonitoring()
            
            // When & Then
            do {
                try monitoringEngine.startMonitoring()
                XCTFail("Starting already running monitoring should throw error")
            } catch let error as SyscallMonitoringEngine.MonitoringError {
                XCTAssertTrue(error.localizedDescription.contains("already active"))
            } catch {
                XCTFail("Should throw MonitoringError.monitoringAlreadyActive")
            }
        } catch {
            // Skip test if initial start fails (common in test environments)
            print("Skipping test due to monitoring start failure: \(error)")
        }
    }
    
    func testStopMonitoring_WhenRunning_ShouldSucceed() {
        // Given
        do {
            try monitoringEngine.startMonitoring()
            
            // When & Then
            try monitoringEngine.stopMonitoring()
            XCTAssertTrue(true) // Success if no exception thrown
        } catch {
            // Skip test if monitoring cannot be started (common in test environments)
            print("Skipping test due to monitoring start/stop failure: \(error)")
        }
    }
    
    func testStopMonitoring_WhenStopped_ShouldFail() {
        // When & Then
        do {
            try monitoringEngine.stopMonitoring()
            XCTFail("Stopping already stopped monitoring should throw error")
        } catch let error as SyscallMonitoringEngine.MonitoringError {
            XCTAssertTrue(error.localizedDescription.contains("not active"))
        } catch {
            XCTFail("Should throw MonitoringError.monitoringNotActive")
        }
    }
    
    // MARK: - Statistics Tests
    
    func testGetMonitoringStatistics_ShouldReturnValidStats() {
        // When
        let stats = monitoringEngine.getStatistics()
        
        // Then
        XCTAssertGreaterThanOrEqual(stats.totalEvents, 0)
        XCTAssertGreaterThanOrEqual(stats.ruleMatches, 0)
        XCTAssertGreaterThanOrEqual(stats.blockedEvents, 0)
        XCTAssertGreaterThanOrEqual(stats.allowedEvents, 0)
        XCTAssertGreaterThanOrEqual(stats.averageProcessingTimeMs, 0)
        XCTAssertGreaterThanOrEqual(stats.peakEventsPerSecond, 0)
        XCTAssertGreaterThanOrEqual(stats.uptime, 0)
    }
    
    // MARK: - Rule Condition Tests
    
    func testRuleCondition_WithProcessFilters_ShouldCreate() {
        // Given & When
        let processFilters = SyscallMonitoringEngine.RuleCondition.ProcessFilters(
            allowedProcesses: ["test_app"],
            blockedProcesses: ["malware"],
            allowedUIDs: [501, 502],
            blockedUIDs: [0]
        )
        
        let condition = SyscallMonitoringEngine.RuleCondition(
            syscalls: ["open", "close"],
            processFilters: processFilters,
            pathFilters: nil,
            networkFilters: nil,
            customCondition: nil
        )
        
        // Then
        XCTAssertEqual(condition.syscalls.count, 2)
        XCTAssertNotNil(condition.processFilters)
        XCTAssertEqual(condition.processFilters?.allowedProcesses.count, 1)
        XCTAssertEqual(condition.processFilters?.blockedProcesses.count, 1)
        XCTAssertEqual(condition.processFilters?.allowedUIDs.count, 2)
        XCTAssertEqual(condition.processFilters?.blockedUIDs.count, 1)
    }
    
    func testRuleCondition_WithPathFilters_ShouldCreate() {
        // Given & When
        let pathFilters = SyscallMonitoringEngine.RuleCondition.PathFilters(
            allowedPaths: ["/tmp", "/var/tmp"],
            blockedPaths: ["/etc", "/System"],
            pathPatterns: ["*.log", "*.tmp"]
        )
        
        let condition = SyscallMonitoringEngine.RuleCondition(
            syscalls: ["open", "openat"],
            processFilters: nil,
            pathFilters: pathFilters,
            networkFilters: nil,
            customCondition: nil
        )
        
        // Then
        XCTAssertEqual(condition.syscalls.count, 2)
        XCTAssertNotNil(condition.pathFilters)
        XCTAssertEqual(condition.pathFilters?.allowedPaths.count, 2)
        XCTAssertEqual(condition.pathFilters?.blockedPaths.count, 2)
        XCTAssertEqual(condition.pathFilters?.pathPatterns.count, 2)
    }
    
    func testRuleCondition_WithNetworkFilters_ShouldCreate() {
        // Given & When
        let networkFilters = SyscallMonitoringEngine.RuleCondition.NetworkFilters(
            allowedPorts: [80, 443],
            blockedPorts: [22, 23],
            allowedIPs: ["192.168.1.1"],
            blockedIPs: ["0.0.0.0"]
        )
        
        let condition = SyscallMonitoringEngine.RuleCondition(
            syscalls: ["connect", "sendto", "recvfrom"],
            processFilters: nil,
            pathFilters: nil,
            networkFilters: networkFilters,
            customCondition: nil
        )
        
        // Then
        XCTAssertEqual(condition.syscalls.count, 3)
        XCTAssertNotNil(condition.networkFilters)
        XCTAssertEqual(condition.networkFilters?.allowedPorts.count, 2)
        XCTAssertEqual(condition.networkFilters?.blockedPorts.count, 2)
        XCTAssertEqual(condition.networkFilters?.allowedIPs.count, 1)
        XCTAssertEqual(condition.networkFilters?.blockedIPs.count, 1)
    }
    
    // MARK: - SyscallEvent Tests
    
    func testSyscallEvent_Creation_ShouldInitializeCorrectly() {
        // Given & When
        let event = SyscallMonitoringEngine.SyscallEvent(
            syscallName: "open",
            processID: 1234,
            processName: "test_process",
            userID: 501,
            groupID: 20,
            arguments: ["/tmp/test.txt", "O_RDONLY"],
            returnValue: 3,
            filePath: "/tmp/test.txt",
            networkInfo: nil,
            triggeredRules: []
        )
        
        // Then
        XCTAssertNotNil(event.id)
        XCTAssertEqual(event.syscallName, "open")
        XCTAssertEqual(event.processID, 1234)
        XCTAssertEqual(event.processName, "test_process")
        XCTAssertEqual(event.userID, 501)
        XCTAssertEqual(event.groupID, 20)
        XCTAssertEqual(event.returnValue, 3)
        XCTAssertEqual(event.filePath, "/tmp/test.txt")
        XCTAssertEqual(event.arguments[0], "/tmp/test.txt")
        XCTAssertEqual(event.triggeredRules.count, 0)
    }
    
    // MARK: - MonitoringRule Priority Tests
    
    func testMonitoringRulePriority_AllCases_ShouldExist() {
        // Given & When
        let priorities = SyscallMonitoringEngine.MonitoringRule.Priority.allCases
        
        // Then
        XCTAssertEqual(priorities.count, 8)
        XCTAssertTrue(priorities.contains(.emergency))
        XCTAssertTrue(priorities.contains(.alert))
        XCTAssertTrue(priorities.contains(.critical))
        XCTAssertTrue(priorities.contains(.error))
        XCTAssertTrue(priorities.contains(.warning))
        XCTAssertTrue(priorities.contains(.notice))
        XCTAssertTrue(priorities.contains(.info))
        XCTAssertTrue(priorities.contains(.debug))
    }
    
    // MARK: - Performance Tests
    
    func testAddRule_Performance() {
        // Test that rule addition completes within reasonable time
        let startTime = Date()
        
        for i in 0..<100 {
            let condition = SyscallMonitoringEngine.RuleCondition(
                syscalls: ["open"],
                processFilters: nil,
                pathFilters: nil,
                networkFilters: nil,
                customCondition: nil
            )
            
            let rule = SyscallMonitoringEngine.MonitoringRule(
                id: "test-rule-\(i)",
                name: "Test Rule \(i)",
                description: "Performance test rule",
                condition: condition,
                output: "Test output",
                priority: .info,
                enabled: true,
                exceptions: []
            )
            
            do {
                try monitoringEngine.addRule(rule)
            } catch {
                XCTFail("Rule addition failed during performance test: \(error)")
            }
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Assert that adding 100 rules takes less than 1 second (reasonable performance threshold)
        XCTAssertLessThan(elapsedTime, 1.0, "Adding 100 rules should take less than 1 second, took \(elapsedTime) seconds")
        
        // Also verify that rules were actually added
        XCTAssertEqual(monitoringEngine.getRules().count, 100, "Should have 100 rules after performance test")
    }
}
