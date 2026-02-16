import XCTest
import Foundation
import Combine
@testable import PrivarionGUI
@testable import PrivarionCore

@MainActor
final class SandboxProfileViewModelTests: XCTestCase {
    
    private var viewModel: SandboxProfileViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = SandboxProfileViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testViewModelInitialization() {
        XCTAssertNotNil(viewModel, "ViewModel should initialize")
        XCTAssertNotNil(viewModel.profiles)
        XCTAssertNil(viewModel.selectedProfile)
    }
    
    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isActive)
        XCTAssertFalse(viewModel.showingError)
        XCTAssertFalse(viewModel.showingCreateProfile)
        XCTAssertFalse(viewModel.showingEditProfile)
        XCTAssertFalse(viewModel.showingDeleteConfirmation)
        XCTAssertNil(viewModel.profileToDelete)
    }
    
    func testNetworkAccessTypes() {
        let allCases = SandboxProfileViewModel.NetworkAccessType.allCases
        
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.blocked))
        XCTAssertTrue(allCases.contains(.restricted))
        XCTAssertTrue(allCases.contains(.unlimited))
    }
    
    func testNetworkAccessTypeRawValues() {
        XCTAssertEqual(SandboxProfileViewModel.NetworkAccessType.blocked.rawValue, "Blocked")
        XCTAssertEqual(SandboxProfileViewModel.NetworkAccessType.restricted.rawValue, "Restricted")
        XCTAssertEqual(SandboxProfileViewModel.NetworkAccessType.unlimited.rawValue, "Unlimited")
    }
    
    func testCreateNewProfile() {
        viewModel.createNewProfile()
        
        XCTAssertTrue(viewModel.showingCreateProfile)
        XCTAssertEqual(viewModel.editingName, "New Profile")
        XCTAssertEqual(viewModel.editingDescription, "")
        XCTAssertFalse(viewModel.editingStrictMode)
        XCTAssertEqual(viewModel.editingAllowedPaths, "")
        XCTAssertEqual(viewModel.editingBlockedPaths, "")
        XCTAssertEqual(viewModel.editingNetworkAccess, .restricted)
        XCTAssertEqual(viewModel.editingAllowedDomains, "")
        XCTAssertEqual(viewModel.editingMaxProcesses, 10)
        XCTAssertEqual(viewModel.editingMaxMemoryMB, 512)
        XCTAssertEqual(viewModel.editingMaxCPUPercent, 50.0)
        XCTAssertEqual(viewModel.editingMaxFileDescriptors, 256)
        XCTAssertEqual(viewModel.editingMaxOpenFiles, 128)
        XCTAssertEqual(viewModel.editingDiskQuotaMB, 1024)
        XCTAssertEqual(viewModel.editingTimeoutSeconds, 300)
    }
    
    func testConfirmDelete() {
        let testProfile = createTestProfile(name: "To Delete", description: "")
        
        viewModel.confirmDelete(testProfile)
        
        XCTAssertTrue(viewModel.showingDeleteConfirmation)
        XCTAssertNotNil(viewModel.profileToDelete)
        XCTAssertEqual(viewModel.profileToDelete?.name, "To Delete")
    }
    
    func testEditorStateAfterCreate() {
        viewModel.createNewProfile()
        
        XCTAssertEqual(viewModel.editingName, "New Profile")
        XCTAssertEqual(viewModel.editingNetworkAccess, .restricted)
        XCTAssertEqual(viewModel.editingMaxProcesses, 10)
        XCTAssertEqual(viewModel.editingMaxMemoryMB, 512)
        XCTAssertEqual(viewModel.editingMaxCPUPercent, 50.0)
    }
    
    private func createTestProfile(name: String, description: String) -> SandboxManager.SandboxProfile {
        return SandboxManager.SandboxProfile(
            name: name,
            description: description,
            strictMode: false,
            allowedPaths: [],
            blockedPaths: [],
            networkAccess: .restricted(allowedDomains: []),
            systemCallFilters: [],
            processGroupLimits: SandboxManager.SandboxProfile.ProcessGroupLimits(
                maxProcesses: 10,
                maxMemoryMB: 512,
                maxCPUPercent: 50.0,
                priorityLevel: 10
            ),
            resourceLimits: SandboxManager.SandboxProfile.ResourceLimits(
                maxFileDescriptors: 256,
                maxOpenFiles: 128,
                diskQuotaMB: 1024,
                executionTimeoutSeconds: 300
            )
        )
    }
}
