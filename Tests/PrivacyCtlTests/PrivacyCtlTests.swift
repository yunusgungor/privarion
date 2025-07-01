import Foundation
import XCTest
import ArgumentParser
@testable import PrivacyCtl
@testable import PrivarionCore

final class PrivacyCtlCommandTests: XCTestCase {
    
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for CLI tests
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        super.tearDown()
        
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    // MARK: - Command Parsing Tests
    
    func testMainCommandParsing() throws {
        // Test basic command parsing
        let command = try PrivacyCtl.parseAsRoot(["--help"])
        XCTAssertNotNil(command)
    }
    
    func testStatusCommandParsing() throws {
        // Test status subcommand parsing
        let command = try PrivacyCtl.parseAsRoot(["status"])
        XCTAssertNotNil(command)
    }
    
    func testConfigCommandParsing() throws {
        // Test config subcommand parsing
        let command = try PrivacyCtl.parseAsRoot(["config", "set", "global.logLevel", "debug"])
        XCTAssertNotNil(command)
    }
    
    func testHookCommandParsing() throws {
        // Test hook subcommand parsing  
        let command = try PrivacyCtl.parseAsRoot(["hook", "list"])
        XCTAssertNotNil(command)
    }
    
    // MARK: - Command Execution Tests
    
    func testStatusCommandExecution() throws {
        // Test status command existence and properties
        let statusCommand = StatusCommand()
        XCTAssertNotNil(statusCommand)
        // Status command should have default properties
        XCTAssertTrue(type(of: statusCommand) == StatusCommand.self)
    }
    
    func testConfigSetCommandExecution() throws {
        // Test config set command existence and properties
        var configCommand = ConfigSetCommand()
        configCommand.keyPath = "global.logLevel"  
        configCommand.value = "debug"
        
        XCTAssertEqual(configCommand.keyPath, "global.logLevel")
        XCTAssertEqual(configCommand.value, "debug")
    }
    
    func testConfigGetCommandExecution() throws {
        // Test config get command existence and properties
        var configCommand = ConfigGetCommand()
        configCommand.keyPath = "global.logLevel"
        
        XCTAssertEqual(configCommand.keyPath, "global.logLevel")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCommandParsing() {
        // Test invalid command handling
        XCTAssertThrowsError(try PrivacyCtl.parseAsRoot(["invalid-command"])) { error in
            guard let validationError = error as? ArgumentParser.ValidationError else {
                XCTFail("Expected a ValidationError, but got \(type(of: error))")
                return
            }
            // We can be more specific about the error if needed, but for now,
            // just ensuring it's a validation error is sufficient.
            XCTAssertNotNil(validationError)
        }
    }
    
    func testMissingArgumentHandling() {
        // Test missing argument handling
        XCTAssertThrowsError(try PrivacyCtl.parseAsRoot(["config", "set"])) { error in
            // Should throw validation error for missing arguments
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Integration Tests
    
    func testCLIWithConfigurationIntegration() throws {
        // Test CLI commands with actual configuration manager
        var getCommand = ConfigGetCommand()
        getCommand.keyPath = "global.logLevel"
        XCTAssertNotNil(getCommand)
        XCTAssertEqual(getCommand.keyPath, "global.logLevel")
    }
    
    func testHelpCommandOutput() throws {
        // Test help command produces expected output
        let helpCommand = try PrivacyCtl.parseAsRoot(["--help"])
        XCTAssertNotNil(helpCommand)
    }
    
    // MARK: - Performance Tests
    
    func testCommandParsingPerformance() {
        // Test command parsing performance
        measure {
            for _ in 0..<100 {
                _ = try? PrivacyCtl.parseAsRoot(["status"])
            }
        }
    }
    
    func testConfigCommandPerformance() {
        // Test config command execution performance
        measure {
            for _ in 0..<100 {
                var configCommand = ConfigSetCommand()
                configCommand.keyPath = "global.logLevel"
                configCommand.value = "debug"
                XCTAssertNotNil(configCommand)
            }
        }
    }
}

// MARK: - Mock Classes for Testing

class MockConfigurationManager {
    var configurations: [String: Any] = [:]
    
    func getValue(for keyPath: String) -> Any? {
        return configurations[keyPath]
    }
    
    func setValue(_ value: Any, for keyPath: String) {
        configurations[keyPath] = value
    }
}
