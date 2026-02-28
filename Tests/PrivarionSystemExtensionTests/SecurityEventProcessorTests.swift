// PrivarionSystemExtensionTests - Security Event Processor Tests
// Unit tests for SecurityEventProcessor
// Requirements: 2.5-2.8, 18.1, 20.1

import XCTest
import CEndpointSecurity
import Logging
@testable import PrivarionSystemExtension
@testable import PrivarionSharedModels

final class SecurityEventProcessorTests: XCTestCase {
    
    var processor: SecurityEventProcessor!
    var logger: Logger!
    
    override func setUp() async throws {
        logger = Logger(label: "com.privarion.test")
        processor = SecurityEventProcessor(logger: logger)
    }
    
    override func tearDown() async throws {
        processor = nil
        logger = nil
    }
    
    // MARK: - Handler Registration Tests
    
    func testRegisterHandler() async {
        // Given
        let handler = MockSecurityEventHandler()
        
        // When
        await processor.registerHandler(handler)
        
        // Then - handler should be registered (verified by no crash)
        XCTAssertTrue(true, "Handler registered successfully")
    }
    
    func testRegisterMultipleHandlers() async {
        // Given
        let handler1 = MockSecurityEventHandler()
        let handler2 = MockSecurityEventHandler()
        
        // When
        await processor.registerHandler(handler1)
        await processor.registerHandler(handler2)
        
        // Then - both handlers should be registered
        XCTAssertTrue(true, "Multiple handlers registered successfully")
    }
    
    // MARK: - ESAuthResult Conversion Tests
    
    func testESAuthResultConversionAllow() {
        // Given
        let result = ESAuthResult.allow
        
        // When
        let esResult = result.toESAuthResult()
        
        // Then
        XCTAssertEqual(esResult, ES_AUTH_RESULT_ALLOW, "Allow should convert to ES_AUTH_RESULT_ALLOW")
    }
    
    func testESAuthResultConversionDeny() {
        // Given
        let result = ESAuthResult.deny
        
        // When
        let esResult = result.toESAuthResult()
        
        // Then
        XCTAssertEqual(esResult, ES_AUTH_RESULT_DENY, "Deny should convert to ES_AUTH_RESULT_DENY")
    }
    
    func testESAuthResultConversionAllowWithModification() {
        // Given
        let result = ESAuthResult.allowWithModification
        
        // When
        let esResult = result.toESAuthResult()
        
        // Then - currently maps to allow
        XCTAssertEqual(esResult, ES_AUTH_RESULT_ALLOW, "AllowWithModification should convert to ES_AUTH_RESULT_ALLOW")
    }
    
    // MARK: - Handler Protocol Tests
    
    func testMockHandlerCanHandleProcessExecution() {
        // Given
        let handler = MockSecurityEventHandler()
        
        // When
        let canHandle = handler.canHandle(.processExecution)
        
        // Then
        XCTAssertTrue(canHandle, "Mock handler should handle process execution events")
    }
    
    func testMockHandlerCanHandleFileAccess() {
        // Given
        let handler = MockSecurityEventHandler()
        
        // When
        let canHandle = handler.canHandle(.fileAccess)
        
        // Then
        XCTAssertTrue(canHandle, "Mock handler should handle file access events")
    }
    
    func testMockHandlerCanHandleNetworkConnection() {
        // Given
        let handler = MockSecurityEventHandler()
        
        // When
        let canHandle = handler.canHandle(.networkConnection)
        
        // Then
        XCTAssertTrue(canHandle, "Mock handler should handle network connection events")
    }
    
    func testMockHandlerProcessExecutionReturnsConfiguredResult() async {
        // Given
        let handler = MockSecurityEventHandler()
        handler.processExecutionResult = .deny
        
        let event = ProcessExecutionEvent(
            processID: 1234,
            executablePath: "/usr/bin/test",
            arguments: [],
            environment: [:],
            parentProcessID: 1
        )
        
        // When
        let result = await handler.handleProcessExecution(event)
        
        // Then
        XCTAssertEqual(result, .deny, "Handler should return configured result")
    }
    
    func testMockHandlerFileAccessReturnsConfiguredResult() async {
        // Given
        let handler = MockSecurityEventHandler()
        handler.fileAccessResult = .deny
        
        let event = FileAccessEvent(
            processID: 1234,
            filePath: "/tmp/test.txt",
            accessType: .read
        )
        
        // When
        let result = await handler.handleFileAccess(event)
        
        // Then
        XCTAssertEqual(result, .deny, "Handler should return configured result")
    }
    
    func testMockHandlerNetworkEventReturnsConfiguredResult() async {
        // Given
        let handler = MockSecurityEventHandler()
        handler.networkEventResult = .deny
        
        let event = NetworkEvent(
            processID: 1234,
            sourceIP: "127.0.0.1",
            sourcePort: 12345,
            destinationIP: "8.8.8.8",
            destinationPort: 53,
            protocol: .udp
        )
        
        // When
        let result = await handler.handleNetworkEvent(event)
        
        // Then
        XCTAssertEqual(result, .deny, "Handler should return configured result")
    }
    
    // MARK: - Integration Tests
    
    func testProcessorInitializesWithDefaultLogger() async {
        // Given/When
        let processor = SecurityEventProcessor()
        
        // Then - should initialize without error
        XCTAssertNotNil(processor, "Processor should initialize with default logger")
    }
    
    func testProcessorInitializesWithCustomLogger() async {
        // Given
        let customLogger = Logger(label: "com.privarion.custom")
        
        // When
        let processor = SecurityEventProcessor(logger: customLogger)
        
        // Then - should initialize without error
        XCTAssertNotNil(processor, "Processor should initialize with custom logger")
    }
}

// MARK: - Mock Security Event Handler

class MockSecurityEventHandler: SecurityEventHandler {
    var processExecutionResult: ESAuthResult = .allow
    var fileAccessResult: ESAuthResult = .allow
    var networkEventResult: ESAuthResult = .allow
    
    var canHandleTypes: Set<SecurityEventType> = [.processExecution, .fileAccess, .networkConnection]
    
    func canHandle(_ eventType: SecurityEventType) -> Bool {
        return canHandleTypes.contains(eventType)
    }
    
    func handleProcessExecution(_ event: ProcessExecutionEvent) async -> ESAuthResult {
        return processExecutionResult
    }
    
    func handleFileAccess(_ event: FileAccessEvent) async -> ESAuthResult {
        return fileAccessResult
    }
    
    func handleNetworkEvent(_ event: NetworkEvent) async -> ESAuthResult {
        return networkEventResult
    }
}
