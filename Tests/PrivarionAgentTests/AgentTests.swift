// PrivarionAgentTests
// Unit tests for Privarion Agent module

import XCTest
@testable import PrivarionAgent

final class AgentTests: XCTestCase {
    
    func testAgentInitialization() {
        // Test that PrivarionAgent can be initialized
        let agent = PrivarionAgent()
        XCTAssertNotNil(agent)
    }
    
    func testAgentStatusInitialization() {
        // Test that AgentStatus can be created
        let status = AgentStatus(
            isRunning: false,
            systemExtensionStatus: .notInstalled,
            endpointSecurityActive: false,
            networkExtensionActive: false,
            activeVMCount: 0,
            permissions: [:]
        )
        
        XCTAssertFalse(status.isRunning)
        XCTAssertFalse(status.endpointSecurityActive)
        XCTAssertFalse(status.networkExtensionActive)
        XCTAssertEqual(status.activeVMCount, 0)
    }
    
    func testPermissionTypeEnum() {
        // Test that PermissionType enum cases exist
        let types: [PermissionType] = [
            .systemExtension,
            .fullDiskAccess,
            .networkExtension
        ]
        
        XCTAssertEqual(types.count, 3)
    }
    
    func testPermissionStatusEnum() {
        // Test that PermissionStatus enum cases exist
        let statuses: [PermissionStatus] = [
            .granted,
            .denied,
            .notDetermined
        ]
        
        XCTAssertEqual(statuses.count, 3)
    }
    
    // Additional tests will be added in subsequent tasks
}
