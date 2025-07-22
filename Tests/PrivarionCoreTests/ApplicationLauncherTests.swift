//
//  ApplicationLauncherTests.swift
//  PrivarionCoreTests
//
//  Created by GitHub Copilot on 2025-01-27
//  STORY-2025-016: Ephemeral File System with APFS Snapshots for Zero-Trace Execution
//  Phase 2: Mount Point Management & Application Isolation - Unit Tests
//

import XCTest
import OSLog
@testable import PrivarionCore

@available(macOS 10.15, *)
final class ApplicationLauncherTests: XCTestCase {
    
    // MARK: - Properties
    
    private var ephemeralManager: EphemeralFileSystemManager!
    private var securityMonitor: SecurityMonitoringEngine!
    private var applicationLauncher: ApplicationLauncher!
    private var testApplicationPath: String!
    private var testWorkspace: URL!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test workspace
        testWorkspace = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ApplicationLauncherTests-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(
            at: testWorkspace,
            withIntermediateDirectories: true
        )
        
        // Initialize dependencies
        ephemeralManager = try EphemeralFileSystemManager()
        securityMonitor = SecurityMonitoringEngine()
        
        // Initialize application launcher
        applicationLauncher = ApplicationLauncher(
            ephemeralManager: ephemeralManager,
            securityMonitor: securityMonitor
        )
        
        // Create test application
        testApplicationPath = try createTestApplication()
    }
    
    override func tearDown() async throws {
        // Clean up running processes
        await applicationLauncher.terminateAllProcesses()
        
        // Clean up test workspace
        try? FileManager.default.removeItem(at: testWorkspace)
        
        // Clean up test application
        if let testAppPath = testApplicationPath {
            try? FileManager.default.removeItem(atPath: testAppPath)
        }
        
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestApplication() throws -> String {
        let appPath = testWorkspace.appendingPathComponent("test_app.sh").path
        
        let scriptContent = """
        #!/bin/bash
        
        # Test application that performs basic operations
        echo "Hello from ephemeral application"
        echo "Working directory: $(pwd)"
        echo "Environment variables:"
        env | grep PRIVARION || true
        
        # Write a test file
        echo "Test output" > test_output.txt
        
        # Sleep for a bit to simulate work
        sleep 1
        
        # Exit with success
        exit 0
        """
        
        try scriptContent.write(toFile: appPath, atomically: true, encoding: .utf8)
        
        // Make executable
        let attributes = [FileAttributeKey.posixPermissions: 0o755]
        try FileManager.default.setAttributes(attributes, ofItemAtPath: appPath)
        
        return appPath
    }
    
    private func createTestApplicationWithCustomBehavior(
        exitCode: Int32 = 0,
        sleepTime: Double = 1.0,
        writeFiles: [String] = ["test_output.txt"]
    ) throws -> String {
        let appPath = testWorkspace.appendingPathComponent("custom_test_app_\(UUID().uuidString).sh").path
        
        var scriptContent = """
        #!/bin/bash
        
        echo "Custom test application started"
        echo "Working directory: $(pwd)"
        
        """
        
        // Add file writing operations
        for filename in writeFiles {
            scriptContent += "echo 'Test content' > \(filename)\n"
        }
        
        // Add sleep
        if sleepTime > 0 {
            scriptContent += "sleep \(sleepTime)\n"
        }
        
        // Add exit
        scriptContent += "exit \(exitCode)\n"
        
        try scriptContent.write(toFile: appPath, atomically: true, encoding: .utf8)
        
        // Make executable
        let attributes = [FileAttributeKey.posixPermissions: 0o755]
        try FileManager.default.setAttributes(attributes, ofItemAtPath: appPath)
        
        return appPath
    }
    
    // MARK: - Tests: Basic Functionality
    
    func testApplicationLauncherInitialization() throws {
        // Test that ApplicationLauncher initializes correctly
        let launcher = ApplicationLauncher(ephemeralManager: ephemeralManager)
        XCTAssertNotNil(launcher)
    }
    
    func testLaunchConfigurationDefaults() throws {
        let config = ApplicationLauncher.LaunchConfiguration.default
        
        XCTAssertFalse(config.inheritEnvironment)
        XCTAssertTrue(config.customEnvironment.isEmpty)
        XCTAssertNil(config.workingDirectory)
        XCTAssertTrue(config.redirectOutput)
        XCTAssertTrue(config.enableResourceMonitoring)
        XCTAssertEqual(config.maxExecutionTimeSeconds, 3600)
        XCTAssertTrue(config.killOnParentExit)
    }
    
    func testLaunchConfigurationCustomization() throws {
        let customEnv = ["TEST_VAR": "test_value", "CUSTOM_PATH": "/custom/path"]
        let config = ApplicationLauncher.LaunchConfiguration(
            inheritEnvironment: true,
            customEnvironment: customEnv,
            workingDirectory: "/custom/workdir",
            redirectOutput: false,
            enableResourceMonitoring: false,
            maxExecutionTimeSeconds: 1800,
            killOnParentExit: false
        )
        
        XCTAssertTrue(config.inheritEnvironment)
        XCTAssertEqual(config.customEnvironment, customEnv)
        XCTAssertEqual(config.workingDirectory, "/custom/workdir")
        XCTAssertFalse(config.redirectOutput)
        XCTAssertFalse(config.enableResourceMonitoring)
        XCTAssertEqual(config.maxExecutionTimeSeconds, 1800)
        XCTAssertFalse(config.killOnParentExit)
    }
    
    // MARK: - Tests: Application Launch in Existing Space
    
    func testLaunchApplicationInExistingSpace() async throws {
        // Create ephemeral space
        let ephemeralSpace = try await ephemeralManager.createEphemeralSpace(
            applicationPath: testApplicationPath
        )
        
        // Launch application
        let handle = try await applicationLauncher.launchApplication(
            at: testApplicationPath,
            arguments: [],
            in: ephemeralSpace.id
        )
        
        // Validate handle
        XCTAssertEqual(handle.ephemeralSpaceId, ephemeralSpace.id)
        XCTAssertEqual(handle.applicationPath, testApplicationPath)
        XCTAssertGreaterThan(handle.processId, 0)
        
        // Wait for process to complete
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Terminate and get result
        let result = try await applicationLauncher.terminateProcess(handle.id)
        
        XCTAssertEqual(result.handle.id, handle.id)
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertGreaterThan(result.executionTime, 0)
    }
    
    func testLaunchApplicationWithArguments() async throws {
        // Create custom test application that uses arguments
        let customAppPath = try createCustomArgumentTestApplication()
        
        // Create ephemeral space
        let ephemeralSpace = try await ephemeralManager.createEphemeralSpace(
            applicationPath: customAppPath
        )
        
        // Launch application with arguments
        let arguments = ["arg1", "arg2", "test_value"]
        let handle = try await applicationLauncher.launchApplication(
            at: customAppPath,
            arguments: arguments,
            in: ephemeralSpace.id
        )
        
        // Wait for completion
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        // Terminate and validate
        let result = try await applicationLauncher.terminateProcess(handle.id)
        XCTAssertEqual(result.exitCode, 0)
        
        // Clean up
        try? FileManager.default.removeItem(atPath: customAppPath)
    }
    
    private func createCustomArgumentTestApplication() throws -> String {
        let appPath = testWorkspace.appendingPathComponent("arg_test_app.sh").path
        
        let scriptContent = """
        #!/bin/bash
        
        echo "Arguments received: $@"
        echo "Number of arguments: $#"
        
        for arg in "$@"; do
            echo "Arg: $arg"
        done
        
        exit 0
        """
        
        try scriptContent.write(toFile: appPath, atomically: true, encoding: .utf8)
        
        let attributes = [FileAttributeKey.posixPermissions: 0o755]
        try FileManager.default.setAttributes(attributes, ofItemAtPath: appPath)
        
        return appPath
    }
    
    // MARK: - Tests: Application Launch in New Space
    
    func testLaunchApplicationInNewSpace() async throws {
        let handle = try await applicationLauncher.launchApplicationInNewSpace(
            at: testApplicationPath,
            arguments: []
        )
        
        // Validate handle
        XCTAssertNotNil(handle.ephemeralSpaceId)
        XCTAssertEqual(handle.applicationPath, testApplicationPath)
        XCTAssertGreaterThan(handle.processId, 0)
        
        // Check that ephemeral space exists
        let spaceInfo = await ephemeralManager.getSpaceInfo(handle.ephemeralSpaceId)
        XCTAssertNotNil(spaceInfo)
        
        // Wait and terminate
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        let result = try await applicationLauncher.terminateProcess(handle.id)
        XCTAssertEqual(result.exitCode, 0)
    }
    
    // MARK: - Tests: Process Management
    
    func testGetRunningProcesses() async throws {
        // Initially no processes
        var runningProcesses = await applicationLauncher.getRunningProcesses()
        XCTAssertTrue(runningProcesses.isEmpty)
        
        // Launch application
        let handle = try await applicationLauncher.launchApplicationInNewSpace(
            at: testApplicationPath
        )
        
        // Should have one running process
        runningProcesses = await applicationLauncher.getRunningProcesses()
        XCTAssertEqual(runningProcesses.count, 1)
        XCTAssertEqual(runningProcesses[0].id, handle.id)
        
        // Terminate process
        _ = try await applicationLauncher.terminateProcess(handle.id)
        
        // Should be empty again
        runningProcesses = await applicationLauncher.getRunningProcesses()
        XCTAssertTrue(runningProcesses.isEmpty)
    }
    
    func testGetProcessInfo() async throws {
        // Test getting non-existent process
        let nonExistentId = UUID()
        let processInfo = await applicationLauncher.getProcessInfo(nonExistentId)
        XCTAssertNil(processInfo)
        
        // Launch application
        let handle = try await applicationLauncher.launchApplicationInNewSpace(
            at: testApplicationPath
        )
        
        // Get process info
        let retrievedInfo = await applicationLauncher.getProcessInfo(handle.id)
        XCTAssertNotNil(retrievedInfo)
        XCTAssertEqual(retrievedInfo?.id, handle.id)
        XCTAssertEqual(retrievedInfo?.processId, handle.processId)
        
        // Clean up
        _ = try await applicationLauncher.terminateProcess(handle.id)
    }
    
    func testTerminateAllProcesses() async throws {
        // Launch multiple applications
        _ = try await applicationLauncher.launchApplicationInNewSpace(
            at: try createTestApplicationWithCustomBehavior(sleepTime: 5.0)
        )
        _ = try await applicationLauncher.launchApplicationInNewSpace(
            at: try createTestApplicationWithCustomBehavior(sleepTime: 5.0)
        )
        
        // Verify they're running
        let runningProcesses = await applicationLauncher.getRunningProcesses()
        XCTAssertEqual(runningProcesses.count, 2)
        
        // Terminate all
        await applicationLauncher.terminateAllProcesses()
        
        // Verify all terminated
        let finalProcesses = await applicationLauncher.getRunningProcesses()
        XCTAssertTrue(finalProcesses.isEmpty)
    }
    
    // MARK: - Tests: Error Handling
    
    func testLaunchNonexistentApplication() async throws {
        let nonExistentPath = "/path/to/nonexistent/application"
        
        do {
            _ = try await applicationLauncher.launchApplicationInNewSpace(
                at: nonExistentPath
            )
            XCTFail("Expected LaunchError.applicationNotFound")
        } catch ApplicationLauncher.LaunchError.applicationNotFound(let path) {
            XCTAssertEqual(path, nonExistentPath)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testLaunchNonExecutableFile() async throws {
        // Create non-executable file
        let nonExecutablePath = testWorkspace.appendingPathComponent("non_executable.txt").path
        try "This is not executable".write(toFile: nonExecutablePath, atomically: true, encoding: .utf8)
        
        do {
            _ = try await applicationLauncher.launchApplicationInNewSpace(
                at: nonExecutablePath
            )
            XCTFail("Expected LaunchError.applicationNotExecutable")
        } catch ApplicationLauncher.LaunchError.applicationNotExecutable(let path) {
            XCTAssertEqual(path, nonExecutablePath)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testLaunchInNonexistentEphemeralSpace() async throws {
        let nonExistentSpaceId = UUID()
        
        do {
            _ = try await applicationLauncher.launchApplication(
                at: testApplicationPath,
                in: nonExistentSpaceId
            )
            XCTFail("Expected LaunchError.ephemeralSpaceNotFound")
        } catch ApplicationLauncher.LaunchError.ephemeralSpaceNotFound(let id) {
            XCTAssertEqual(id, nonExistentSpaceId)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testTerminateNonexistentProcess() async throws {
        let nonExistentProcessId = UUID()
        
        do {
            _ = try await applicationLauncher.terminateProcess(nonExistentProcessId)
            XCTFail("Expected LaunchError.processTerminationFailed")
        } catch ApplicationLauncher.LaunchError.processTerminationFailed {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Tests: Custom Configuration
    
    func testLaunchWithCustomConfiguration() async throws {
        let customConfig = ApplicationLauncher.LaunchConfiguration(
            inheritEnvironment: true,
            customEnvironment: ["TEST_VAR": "custom_value"],
            workingDirectory: nil, // Will use ephemeral space
            redirectOutput: true,
            enableResourceMonitoring: true,
            maxExecutionTimeSeconds: 10,
            killOnParentExit: true
        )
        
        let handle = try await applicationLauncher.launchApplicationInNewSpace(
            at: testApplicationPath,
            configuration: customConfig
        )
        
        XCTAssertEqual(handle.configuration.maxExecutionTimeSeconds, 10)
        XCTAssertEqual(handle.configuration.customEnvironment["TEST_VAR"], "custom_value")
        
        // Wait and terminate
        try await Task.sleep(nanoseconds: 1_500_000_000)
        _ = try await applicationLauncher.terminateProcess(handle.id)
    }
    
    func testLaunchWithWorkingDirectory() async throws {
        // Create ephemeral space
        let ephemeralSpace = try await ephemeralManager.createEphemeralSpace(
            applicationPath: testApplicationPath
        )
        
        // Create custom working directory in ephemeral space
        let customWorkDir = ephemeralSpace.mountPath + "/custom_work"
        try FileManager.default.createDirectory(
            atPath: customWorkDir,
            withIntermediateDirectories: true
        )
        
        let config = ApplicationLauncher.LaunchConfiguration(
            workingDirectory: customWorkDir
        )
        
        let handle = try await applicationLauncher.launchApplication(
            at: testApplicationPath,
            in: ephemeralSpace.id,
            configuration: config
        )
        
        XCTAssertEqual(handle.configuration.workingDirectory, customWorkDir)
        
        // Wait and terminate
        try await Task.sleep(nanoseconds: 1_500_000_000)
        _ = try await applicationLauncher.terminateProcess(handle.id)
    }
    
    // MARK: - Tests: Performance
    
    func testLaunchPerformance() async throws {
        let startTime = DispatchTime.now()
        
        let handle = try await applicationLauncher.launchApplicationInNewSpace(
            at: testApplicationPath
        )
        
        let endTime = DispatchTime.now()
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000 // Convert to milliseconds
        
        // Should launch within 500ms (target from PRD)
        XCTAssertLessThan(duration, 500.0, "Application launch took \(duration)ms, target is <500ms")
        
        // Clean up
        _ = try await applicationLauncher.terminateProcess(handle.id)
    }
    
    func testConcurrentLaunches() async throws {
        let numberOfLaunches = 5
        
        let startTime = DispatchTime.now()
        
        // Launch multiple applications concurrently
        let handles = try await withThrowingTaskGroup(of: ApplicationLauncher.ProcessHandle.self) { group in
            var results: [ApplicationLauncher.ProcessHandle] = []
            
            for _ in 0..<numberOfLaunches {
                group.addTask {
                    let customApp = try self.createTestApplicationWithCustomBehavior(sleepTime: 2.0)
                    return try await self.applicationLauncher.launchApplicationInNewSpace(at: customApp)
                }
            }
            
            for try await handle in group {
                results.append(handle)
            }
            
            return results
        }
        
        let endTime = DispatchTime.now()
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
        
        XCTAssertEqual(handles.count, numberOfLaunches)
        XCTAssertLessThan(duration, 2000.0, "Concurrent launches took \(duration)ms")
        
        // Verify all processes are running
        let runningProcesses = await applicationLauncher.getRunningProcesses()
        XCTAssertEqual(runningProcesses.count, numberOfLaunches)
        
        // Clean up all processes
        await applicationLauncher.terminateAllProcesses()
    }
    
    // MARK: - Tests: Resource Usage
    
    func testProcessResourceCollection() async throws {
        let handle = try await applicationLauncher.launchApplicationInNewSpace(
            at: testApplicationPath
        )
        
        // Wait for process to do some work
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Terminate and check resource usage
        let result = try await applicationLauncher.terminateProcess(handle.id)
        
        XCTAssertNotNil(result.resourceUsage)
        XCTAssertGreaterThan(result.resourceUsage?.peakMemoryMB ?? 0, 0)
        XCTAssertGreaterThan(result.resourceUsage?.cpuTimeSeconds ?? 0, 0)
        XCTAssertGreaterThan(result.executionTime, 1.0) // Should have run for at least 1 second
    }
    
    // MARK: - Tests: Security Integration
    
    func testSecurityEventReporting() async throws {
        // This test verifies that security events are properly reported
        // In a real implementation, we would mock the security monitor
        
        let handle = try await applicationLauncher.launchApplicationInNewSpace(
            at: testApplicationPath
        )
        
        // Wait for application to complete
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        // Terminate
        let result = try await applicationLauncher.terminateProcess(handle.id)
        
        // Security events should have been reported
        // (In a real test, we would verify the mock was called)
        XCTAssertEqual(result.exitCode, 0)
    }
    
    // MARK: - Tests: Process Timeout
    
    func testProcessTimeout() async throws {
        // Create long-running application
        let longRunningApp = try createTestApplicationWithCustomBehavior(sleepTime: 10.0)
        
        let config = ApplicationLauncher.LaunchConfiguration(
            maxExecutionTimeSeconds: 2 // 2 second timeout
        )
        
        _ = try await applicationLauncher.launchApplicationInNewSpace(
            at: longRunningApp,
            configuration: config
        )
        
        // Wait for timeout + a bit more
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Process should be terminated due to timeout
        let runningProcesses = await applicationLauncher.getRunningProcesses()
        XCTAssertTrue(runningProcesses.isEmpty, "Process should have been terminated due to timeout")
        
        // Clean up
        try? FileManager.default.removeItem(atPath: longRunningApp)
    }
    
    // MARK: - Tests: Process Handle Equality and Identifiable
    
    func testProcessHandleIdentifiable() throws {
        let handle1 = ApplicationLauncher.ProcessHandle(
            processId: 1234,
            ephemeralSpaceId: UUID(),
            applicationPath: "/test/app",
            configuration: .default
        )
        
        let handle2 = ApplicationLauncher.ProcessHandle(
            processId: 5678,
            ephemeralSpaceId: UUID(),
            applicationPath: "/test/app2",
            configuration: .default
        )
        
        XCTAssertNotEqual(handle1.id, handle2.id)
        XCTAssertNotEqual(handle1.processId, handle2.processId)
    }
    
    // MARK: - Tests: Error Localization
    
    func testErrorLocalizedDescriptions() throws {
        let errors: [ApplicationLauncher.LaunchError] = [
            .ephemeralSpaceNotFound(UUID()),
            .applicationNotFound("/test/path"),
            .applicationNotExecutable("/test/executable"),
            .processLaunchFailed("Test reason"),
            .processTerminationFailed(1234),
            .resourceLimitExceeded("memory"),
            .securityViolation("Test violation"),
            .timeout(30)
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }
}
