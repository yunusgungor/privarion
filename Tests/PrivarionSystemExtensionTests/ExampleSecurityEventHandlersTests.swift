// PrivarionSystemExtensionTests - Example Security Event Handlers Tests
// Tests for example SecurityEventHandler implementations
// Requirements: 2.5, 20.1

import XCTest
import Logging
@testable import PrivarionSystemExtension
@testable import PrivarionSharedModels
@testable import PrivarionCore

final class ExampleSecurityEventHandlersTests: XCTestCase {
    
    // MARK: - Logging Handler Tests
    
    func testLoggingHandlerCanHandleAllEvents() {
        let handler = LoggingSecurityEventHandler()
        
        XCTAssertTrue(handler.canHandle(.processExecution))
        XCTAssertTrue(handler.canHandle(.fileAccess))
        XCTAssertTrue(handler.canHandle(.networkConnection))
        XCTAssertTrue(handler.canHandle(.dnsQuery))
    }
    
    func testLoggingHandlerAlwaysAllows() async {
        let handler = LoggingSecurityEventHandler()
        
        let processEvent = ProcessExecutionEvent(
            processID: 1234,
            executablePath: "/usr/bin/test",
            arguments: ["test", "arg"],
            environment: [:],
            parentProcessID: 1
        )
        
        let result = await handler.handleProcessExecution(processEvent)
        XCTAssertEqual(result, .allow)
    }
    
    // MARK: - Suspicious Path Blocker Tests
    
    func testSuspiciousPathBlockerCanHandleProcessExecution() {
        let handler = SuspiciousPathBlocker()
        
        XCTAssertTrue(handler.canHandle(.processExecution))
        XCTAssertFalse(handler.canHandle(.fileAccess))
        XCTAssertFalse(handler.canHandle(.networkConnection))
    }
    
    func testSuspiciousPathBlockerBlocksTmpExecutables() async {
        let handler = SuspiciousPathBlocker()
        
        let suspiciousEvent = ProcessExecutionEvent(
            processID: 1234,
            executablePath: "/tmp/malicious",
            arguments: [],
            environment: [:],
            parentProcessID: 1
        )
        
        let result = await handler.handleProcessExecution(suspiciousEvent)
        XCTAssertEqual(result, .deny)
    }
    
    func testSuspiciousPathBlockerAllowsNormalExecutables() async {
        let handler = SuspiciousPathBlocker()
        
        let normalEvent = ProcessExecutionEvent(
            processID: 1234,
            executablePath: "/usr/bin/ls",
            arguments: [],
            environment: [:],
            parentProcessID: 1
        )
        
        let result = await handler.handleProcessExecution(normalEvent)
        XCTAssertEqual(result, .allow)
    }
    
    func testSuspiciousPathBlockerCustomPaths() async {
        let handler = SuspiciousPathBlocker(suspiciousPaths: ["/custom/suspicious"])
        
        let suspiciousEvent = ProcessExecutionEvent(
            processID: 1234,
            executablePath: "/custom/suspicious/binary",
            arguments: [],
            environment: [:],
            parentProcessID: 1
        )
        
        let result = await handler.handleProcessExecution(suspiciousEvent)
        XCTAssertEqual(result, .deny)
    }
    
    // MARK: - Sensitive File Access Monitor Tests
    
    func testSensitiveFileAccessMonitorCanHandleFileAccess() {
        let handler = SensitiveFileAccessMonitor()
        
        XCTAssertFalse(handler.canHandle(.processExecution))
        XCTAssertTrue(handler.canHandle(.fileAccess))
        XCTAssertFalse(handler.canHandle(.networkConnection))
    }
    
    func testSensitiveFileAccessMonitorDetectsSshAccess() async {
        let handler = SensitiveFileAccessMonitor()
        
        let sshEvent = FileAccessEvent(
            processID: 1234,
            filePath: "/Users/test/.ssh/id_rsa",
            accessType: .read
        )
        
        let result = await handler.handleFileAccess(sshEvent)
        // Currently allows but logs - verify it doesn't crash
        XCTAssertEqual(result, .allow)
    }
    
    func testSensitiveFileAccessMonitorDetectsPasswordFiles() async {
        let handler = SensitiveFileAccessMonitor()
        
        let passwordEvent = FileAccessEvent(
            processID: 1234,
            filePath: "/Users/test/passwords.txt",
            accessType: .write
        )
        
        let result = await handler.handleFileAccess(passwordEvent)
        // Currently allows but logs - verify it doesn't crash
        XCTAssertEqual(result, .allow)
    }
    
    func testSensitiveFileAccessMonitorCustomPatterns() async {
        let handler = SensitiveFileAccessMonitor(sensitivePatterns: ["custom_secret"])
        
        let customEvent = FileAccessEvent(
            processID: 1234,
            filePath: "/Users/test/custom_secret.txt",
            accessType: .read
        )
        
        let result = await handler.handleFileAccess(customEvent)
        XCTAssertEqual(result, .allow)
    }
    
    // MARK: - Rate Limiting Handler Tests
    
    func testRateLimitingHandlerCanHandleProcessExecution() {
        let handler = RateLimitingHandler()
        
        XCTAssertTrue(handler.canHandle(.processExecution))
        XCTAssertFalse(handler.canHandle(.fileAccess))
        XCTAssertFalse(handler.canHandle(.networkConnection))
    }
    
    func testRateLimitingHandlerAllowsNormalRate() async {
        let handler = RateLimitingHandler(maxExecutionsPerSecond: 10)
        
        // Execute 5 times (below limit)
        for i in 0..<5 {
            let event = ProcessExecutionEvent(
                processID: 1000 + Int32(i),
                executablePath: "/usr/bin/test",
                arguments: [],
                environment: [:],
                parentProcessID: 1
            )
            
            let result = await handler.handleProcessExecution(event)
            XCTAssertEqual(result, .allow)
        }
    }
    
    func testRateLimitingHandlerBlocksExcessiveRate() async {
        let handler = RateLimitingHandler(maxExecutionsPerSecond: 5)
        
        // Execute 10 times (above limit of 5)
        var allowCount = 0
        var denyCount = 0
        
        for i in 0..<10 {
            let event = ProcessExecutionEvent(
                processID: 1000 + Int32(i),
                executablePath: "/usr/bin/test",
                arguments: [],
                environment: [:],
                parentProcessID: 1
            )
            
            let result = await handler.handleProcessExecution(event)
            if result == .allow {
                allowCount += 1
            } else {
                denyCount += 1
            }
        }
        
        // Should allow first 5, deny the rest
        XCTAssertEqual(allowCount, 5)
        XCTAssertEqual(denyCount, 5)
    }
    
    func testRateLimitingHandlerTracksPerParentProcess() async {
        let handler = RateLimitingHandler(maxExecutionsPerSecond: 5)
        
        // Execute from two different parent processes
        for parentPID in [1, 2] {
            for i in 0..<5 {
                let event = ProcessExecutionEvent(
                    processID: 1000 + Int32(i),
                    executablePath: "/usr/bin/test",
                    arguments: [],
                    environment: [:],
                    parentProcessID: Int32(parentPID)
                )
                
                let result = await handler.handleProcessExecution(event)
                // Both parents should be allowed since they're tracked separately
                XCTAssertEqual(result, .allow)
            }
        }
    }
    
    // MARK: - Composite Handler Tests
    
    func testCompositeHandlerCanHandleIfAnyChildCanHandle() {
        let loggingHandler = LoggingSecurityEventHandler()
        let pathBlocker = SuspiciousPathBlocker()
        
        let composite = CompositeSecurityEventHandler(handlers: [loggingHandler, pathBlocker])
        
        // Should be able to handle process execution (both can)
        XCTAssertTrue(composite.canHandle(.processExecution))
        
        // Should be able to handle file access (logging can)
        XCTAssertTrue(composite.canHandle(.fileAccess))
    }
    
    func testCompositeHandlerDeniesIfAnyChildDenies() async {
        let loggingHandler = LoggingSecurityEventHandler()
        let pathBlocker = SuspiciousPathBlocker()
        
        let composite = CompositeSecurityEventHandler(handlers: [loggingHandler, pathBlocker])
        
        let suspiciousEvent = ProcessExecutionEvent(
            processID: 1234,
            executablePath: "/tmp/malicious",
            arguments: [],
            environment: [:],
            parentProcessID: 1
        )
        
        let result = await composite.handleProcessExecution(suspiciousEvent)
        // Path blocker should deny
        XCTAssertEqual(result, .deny)
    }
    
    func testCompositeHandlerAllowsIfAllChildrenAllow() async {
        let loggingHandler = LoggingSecurityEventHandler()
        let pathBlocker = SuspiciousPathBlocker()
        
        let composite = CompositeSecurityEventHandler(handlers: [loggingHandler, pathBlocker])
        
        let normalEvent = ProcessExecutionEvent(
            processID: 1234,
            executablePath: "/usr/bin/ls",
            arguments: [],
            environment: [:],
            parentProcessID: 1
        )
        
        let result = await composite.handleProcessExecution(normalEvent)
        // Both should allow
        XCTAssertEqual(result, .allow)
    }
    
    func testCompositeHandlerExecutesHandlersInOrder() async {
        // Create multiple handlers
        let handler1 = SuspiciousPathBlocker(suspiciousPaths: ["/path1"])
        let handler2 = SuspiciousPathBlocker(suspiciousPaths: ["/path2"])
        
        let composite = CompositeSecurityEventHandler(handlers: [handler1, handler2])
        
        // Test with path1 - should be denied by first handler
        let event1 = ProcessExecutionEvent(
            processID: 1234,
            executablePath: "/path1/binary",
            arguments: [],
            environment: [:],
            parentProcessID: 1
        )
        
        let result1 = await composite.handleProcessExecution(event1)
        XCTAssertEqual(result1, .deny)
        
        // Test with path2 - should be denied by second handler
        let event2 = ProcessExecutionEvent(
            processID: 1234,
            executablePath: "/path2/binary",
            arguments: [],
            environment: [:],
            parentProcessID: 1
        )
        
        let result2 = await composite.handleProcessExecution(event2)
        XCTAssertEqual(result2, .deny)
    }
    
    // MARK: - Integration Tests
    
    func testHandlerRegistrationWithProcessor() async throws {
        // Create a mock policy engine
        let policyEngine = ProtectionPolicyEngine()
        
        // Create processor
        let processor = SecurityEventProcessor(policyEngine: policyEngine)
        
        // Register handlers
        let loggingHandler = LoggingSecurityEventHandler()
        let pathBlocker = SuspiciousPathBlocker()
        
        await processor.registerHandler(loggingHandler)
        await processor.registerHandler(pathBlocker)
        
        // Verify handlers are registered (this is implicit - no crash means success)
        // In a real scenario, we'd process events through the processor
    }
}
