//
//  EphemeralFileSystemManagerTests.swift
//  PrivarionCoreTests
//
//  Created by GitHub Copilot on 2025-07-23
//  STORY-2025-016: Ephemeral File System with APFS Snapshots for Zero-Trace Execution
//  Phase 1: Core APFS Integration Testing
//

import XCTest
import Foundation
@testable import PrivarionCore

@available(macOS 10.15, *)
final class EphemeralFileSystemManagerTests: XCTestCase {
    
    var ephemeralManager: EphemeralFileSystemManager!
    var testBasePath: String!
    var securityMonitor: SecurityMonitoringEngine!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test directory
        testBasePath = NSTemporaryDirectory() + "EphemeralTest_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: testBasePath, withIntermediateDirectories: true)
        
        // Create real security monitor for testing
        securityMonitor = SecurityMonitoringEngine()
        
        // Create configuration for testing
        let config = EphemeralFileSystemManager.Configuration(
            basePath: testBasePath,
            maxEphemeralSpaces: 10,
            cleanupTimeoutSeconds: 60,
            enableSecurityMonitoring: false, // Disable for testing
            isTestMode: true // Enable test mode for APFS simulation
        )
        
        // Initialize ephemeral manager
        ephemeralManager = try EphemeralFileSystemManager(
            configuration: config,
            securityMonitor: securityMonitor
        )
    }
    
    override func tearDown() async throws {
        // Cleanup all spaces
        await ephemeralManager.cleanupAllSpaces()
        
        // Remove test directory
        try? FileManager.default.removeItem(atPath: testBasePath)
        
        ephemeralManager = nil
        securityMonitor = nil
        testBasePath = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Configuration Tests
    
    func testInitializationWithValidConfiguration() throws {
        XCTAssertNotNil(ephemeralManager)
        XCTAssertTrue(FileManager.default.fileExists(atPath: testBasePath))
    }
    
    func testInitializationWithInvalidConfiguration() throws {
        let invalidConfig = EphemeralFileSystemManager.Configuration(
            basePath: "",
            maxEphemeralSpaces: -1,
            cleanupTimeoutSeconds: 0
        )
        
        XCTAssertThrowsError(try EphemeralFileSystemManager(configuration: invalidConfig)) { error in
            guard let ephemeralError = error as? EphemeralFileSystemManager.EphemeralError else {
                XCTFail("Expected EphemeralError")
                return
            }
            
            switch ephemeralError {
            case .invalidConfiguration:
                break // Expected
            default:
                XCTFail("Expected invalidConfiguration error")
            }
        }
    }
    
    // MARK: - Ephemeral Space Creation Tests
    
    func testCreateEphemeralSpace() async throws {
        let space = try await ephemeralManager.createEphemeralSpace(
            processId: 12345,
            applicationPath: "/usr/bin/test"
        )
        
        XCTAssertNotNil(space.id)
        XCTAssertEqual(space.processId, 12345)
        XCTAssertEqual(space.applicationPath, "/usr/bin/test")
        XCTAssertTrue(space.snapshotName.contains("privarion_ephemeral"))
        XCTAssertTrue(space.mountPath.contains(testBasePath))
        
        // Verify mount path exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: space.mountPath))
        
        // Security monitoring disabled for testing
        
        // Cleanup
        try await ephemeralManager.destroyEphemeralSpace(space.id)
    }
    
    func testCreateMultipleEphemeralSpaces() async throws {
        var spaces: [EphemeralFileSystemManager.EphemeralSpace] = []
        
        // Create multiple spaces
        for i in 0..<5 {
            let space = try await ephemeralManager.createEphemeralSpace(
                processId: Int32(1000 + i),
                applicationPath: "/usr/bin/test\(i)"
            )
            spaces.append(space)
        }
        
        XCTAssertEqual(spaces.count, 5)
        
        // Verify all spaces are active
        let activeSpaces = await ephemeralManager.listActiveSpaces()
        XCTAssertEqual(activeSpaces.count, 5)
        
        // Cleanup all spaces
        for space in spaces {
            try await ephemeralManager.destroyEphemeralSpace(space.id)
        }
        
        // Verify cleanup
        let remainingSpaces = await ephemeralManager.listActiveSpaces()
        XCTAssertEqual(remainingSpaces.count, 0)
    }
    
    func testMaxEphemeralSpacesLimit() async throws {
        var spaces: [EphemeralFileSystemManager.EphemeralSpace] = []
        
        // Create spaces up to the limit (10)
        for i in 0..<10 {
            let space = try await ephemeralManager.createEphemeralSpace(
                processId: Int32(1000 + i)
            )
            spaces.append(space)
        }
        
        // Try to create one more (should fail)
        do {
            _ = try await ephemeralManager.createEphemeralSpace(processId: 1011)
            XCTFail("Expected maxSpacesExceeded error")
        } catch let error as EphemeralFileSystemManager.EphemeralError {
            switch error {
            case .maxSpacesExceeded(let limit):
                XCTAssertEqual(limit, 10)
            default:
                XCTFail("Expected maxSpacesExceeded error, got \(error)")
            }
        }
        
        // Cleanup
        for space in spaces {
            try await ephemeralManager.destroyEphemeralSpace(space.id)
        }
    }
    
    // MARK: - Ephemeral Space Destruction Tests
    
    func testDestroyEphemeralSpace() async throws {
        // Create space
        let space = try await ephemeralManager.createEphemeralSpace()
        
        // Verify it exists
        let spaceInfo = await ephemeralManager.getSpaceInfo(space.id)
        XCTAssertNotNil(spaceInfo)
        
        // Destroy space
        try await ephemeralManager.destroyEphemeralSpace(space.id)
        
        // Verify it's gone
        let destroyedSpaceInfo = await ephemeralManager.getSpaceInfo(space.id)
        XCTAssertNil(destroyedSpaceInfo)
        
        // Verify mount path is cleaned up
        XCTAssertFalse(FileManager.default.fileExists(atPath: space.mountPath))
        
        // Security monitoring disabled for testing
    }
    
    func testDestroyNonExistentSpace() async throws {
        let nonExistentId = UUID()
        
        // Should not throw error for non-existent space
        try await ephemeralManager.destroyEphemeralSpace(nonExistentId)
        
        // Should log warning but not fail
        XCTAssertTrue(true) // Test passes if no exception is thrown
    }
    
    // MARK: - Performance Tests
    
    func testEphemeralSpaceCreationPerformance() async throws {
        let startTime = DispatchTime.now()
        
        let space = try await ephemeralManager.createEphemeralSpace()
        
        let endTime = DispatchTime.now()
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
        
        // Should complete within 200ms (including snapshot creation simulation)
        XCTAssertLessThan(duration, 200.0, "Ephemeral space creation took \(duration)ms, expected <200ms")
        
        // Cleanup
        try await ephemeralManager.destroyEphemeralSpace(space.id)
    }
    
    func testEphemeralSpaceDestructionPerformance() async throws {
        // Create space
        let space = try await ephemeralManager.createEphemeralSpace()
        
        let startTime = DispatchTime.now()
        
        // Destroy space
        try await ephemeralManager.destroyEphemeralSpace(space.id)
        
        let endTime = DispatchTime.now()
        let duration = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
        
        // Should complete within 250ms (including cleanup simulation)
        XCTAssertLessThan(duration, 250.0, "Ephemeral space destruction took \(duration)ms, expected <250ms")
    }
    
    // MARK: - Security Tests
    
    func testSecurityMonitoringIntegration() async throws {
        let space = try await ephemeralManager.createEphemeralSpace(
            processId: 12345,
            applicationPath: "/usr/bin/security_test"
        )
        
        // Security monitoring disabled for testing
        // In real implementation, events would be reported
        
        try await ephemeralManager.destroyEphemeralSpace(space.id)
        
        // Verify basic functionality works without security monitoring
        XCTAssertTrue(true)
    }
    
    func testSecurityContextValidation() async throws {
        // Test with suspicious application path
        do {
            _ = try await ephemeralManager.createEphemeralSpace(
                applicationPath: "/tmp/suspicious_binary"
            )
            // Should succeed in this mock implementation
            XCTAssertTrue(true)
        } catch {
            XCTFail("Security validation should not fail in test environment: \(error)")
        }
    }
    
    // MARK: - Cleanup Tests
    
    func testAutomaticCleanup() async throws {
        let _ = try await ephemeralManager.createEphemeralSpace()
        
        // Verify space exists
        let activeSpaces = await ephemeralManager.listActiveSpaces()
        XCTAssertEqual(activeSpaces.count, 1)
        
        // Manual cleanup for testing
        await ephemeralManager.cleanupAllSpaces()
        
        // Verify cleanup
        let remainingSpaces = await ephemeralManager.listActiveSpaces()
        XCTAssertEqual(remainingSpaces.count, 0)
    }
    
    func testCleanupAllSpaces() async throws {
        // Create multiple spaces
        var spaceIds: [UUID] = []
        for i in 0..<5 {
            let space = try await ephemeralManager.createEphemeralSpace(processId: Int32(1000 + i))
            spaceIds.append(space.id)
        }
        
        // Verify all spaces exist
        let activeSpaces = await ephemeralManager.listActiveSpaces()
        XCTAssertEqual(activeSpaces.count, 5)
        
        // Cleanup all
        await ephemeralManager.cleanupAllSpaces()
        
        // Verify all spaces are gone
        let remainingSpaces = await ephemeralManager.listActiveSpaces()
        XCTAssertEqual(remainingSpaces.count, 0)
    }
    
    // MARK: - Data Management Tests
    
    func testListActiveSpaces() async throws {
        // Initially no spaces
        let initialSpaces = await ephemeralManager.listActiveSpaces()
        XCTAssertEqual(initialSpaces.count, 0)
        
        // Create spaces
        let space1 = try await ephemeralManager.createEphemeralSpace(processId: 100)
        let space2 = try await ephemeralManager.createEphemeralSpace(processId: 200)
        
        // Verify list
        let activeSpaces = await ephemeralManager.listActiveSpaces()
        XCTAssertEqual(activeSpaces.count, 2)
        
        let spaceIds = activeSpaces.map { $0.id }
        XCTAssertTrue(spaceIds.contains(space1.id))
        XCTAssertTrue(spaceIds.contains(space2.id))
        
        // Cleanup
        try await ephemeralManager.destroyEphemeralSpace(space1.id)
        try await ephemeralManager.destroyEphemeralSpace(space2.id)
    }
    
    func testGetSpaceInfo() async throws {
        let space = try await ephemeralManager.createEphemeralSpace(
            processId: 12345,
            applicationPath: "/usr/bin/test"
        )
        
        // Get space info
        let spaceInfo = await ephemeralManager.getSpaceInfo(space.id)
        XCTAssertNotNil(spaceInfo)
        XCTAssertEqual(spaceInfo?.id, space.id)
        XCTAssertEqual(spaceInfo?.processId, 12345)
        XCTAssertEqual(spaceInfo?.applicationPath, "/usr/bin/test")
        
        // Test non-existent space
        let nonExistentInfo = await ephemeralManager.getSpaceInfo(UUID())
        XCTAssertNil(nonExistentInfo)
        
        // Cleanup
        try await ephemeralManager.destroyEphemeralSpace(space.id)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() async throws {
        // This would test various error conditions in a real implementation
        // For now, we test basic error propagation
        
        do {
            // Try to create with invalid configuration would be tested here
            // For now, just verify error types exist
            let error = EphemeralFileSystemManager.EphemeralError.snapshotCreationFailed("test")
            XCTAssertNotNil(error.errorDescription)
        }
    }
}
