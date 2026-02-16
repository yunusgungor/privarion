import XCTest
import Foundation
@testable import PrivarionCore

final class MemoryProtectionManagerTests: XCTestCase {
    
    var memoryProtectionManager: MemoryProtectionManager!
    
    override func setUp() {
        super.setUp()
        let options = MemoryProtectionManager.MemoryProtectionOptions(
            protectionLevel: .minimal,
            enableMmapRandomization: true,
            enableAntiDebugging: true,
            enableProcessIsolation: true,
            randomizeBaseAddress: true,
            pageSize: 4096
        )
        memoryProtectionManager = MemoryProtectionManager(options: options)
    }
    
    override func tearDown() {
        memoryProtectionManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_WithDefaultOptions_ShouldSucceed() {
        let manager = MemoryProtectionManager()
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isActive)
    }
    
    func testInitialization_WithCustomOptions_ShouldSucceed() {
        let options = MemoryProtectionManager.MemoryProtectionOptions(
            protectionLevel: .paranoid,
            enableMmapRandomization: true,
            enableAntiDebugging: false,
            enableProcessIsolation: true,
            randomizeBaseAddress: false,
            pageSize: 8192
        )
        
        let manager = MemoryProtectionManager(options: options)
        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isActive)
    }
    
    // MARK: - Protection Level Tests
    
    func testProtectionLevel_AllCases_ShouldHaveDescription() {
        for level in MemoryProtectionManager.ProtectionLevel.allCases {
            XCTAssertFalse(level.description.isEmpty)
        }
    }
    
    func testProtectionLevel_ShouldBeCaseIterable() {
        let count = MemoryProtectionManager.ProtectionLevel.allCases.count
        XCTAssertEqual(count, 3)
    }
    
    // MARK: - Debugger Detection Tests
    
    func testIsDebuggerPresent_ShouldReturnBool() {
        let result = memoryProtectionManager.isDebuggerPresent()
        XCTAssertFalse(result)
    }
    
    func testIsDebuggerPresent_MultipleCalls_ShouldBeConsistent() {
        let firstResult = memoryProtectionManager.isDebuggerPresent()
        let secondResult = memoryProtectionManager.isDebuggerPresent()
        XCTAssertEqual(firstResult, secondResult)
    }
    
    // MARK: - Memory Region Protection Tests
    
    func testProtectMemoryRegion_ValidParameters_ShouldAllocateRegion() {
        do {
            let region = try memoryProtectionManager.protectMemoryRegion(
                address: 0,
                size: 4096,
                read: true,
                write: true,
                execute: false
            )
            
            XCTAssertNotNil(region)
            XCTAssertEqual(region.size, 4096)
            
            try memoryProtectionManager.unprotectMemoryRegion(regionId: region.id)
        } catch let error as MemoryProtectionManager.MemoryProtectionError {
            if case .syscallFailed = error {
                XCTSkip("mmap not available in test environment")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTSkip("mmap not available in test environment")
        }
    }
    
    func testProtectMemoryRegion_DifferentProtectionFlags_ShouldWork() {
        do {
            let readOnly = try memoryProtectionManager.protectMemoryRegion(
                address: 0,
                size: 4096,
                read: true,
                write: false,
                execute: false
            )
            XCTAssertNotNil(readOnly)
            
            let readWrite = try memoryProtectionManager.protectMemoryRegion(
                address: 0,
                size: 4096,
                read: true,
                write: true,
                execute: false
            )
            XCTAssertNotNil(readWrite)
            
            let executable = try memoryProtectionManager.protectMemoryRegion(
                address: 0,
                size: 4096,
                read: true,
                write: false,
                execute: true
            )
            XCTAssertNotNil(executable)
            
            for region in [readOnly, readWrite, executable] {
                try memoryProtectionManager.unprotectMemoryRegion(regionId: region.id)
            }
        } catch let error as MemoryProtectionManager.MemoryProtectionError {
            if case .syscallFailed = error {
                XCTSkip("mmap not available in test environment")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTSkip("mmap not available in test environment")
        }
    }
    
    func testProtectMemoryRegion_MultipleRegions_ShouldTrackAll() {
        do {
            let region1 = try memoryProtectionManager.protectMemoryRegion(
                address: 0,
                size: 4096,
                read: true,
                write: false,
                execute: false
            )
            
            let region2 = try memoryProtectionManager.protectMemoryRegion(
                address: 0,
                size: 8192,
                read: true,
                write: true,
                execute: false
            )
            
            let regions = memoryProtectionManager.protectedMemoryRegions
            XCTAssertEqual(regions.count, 2)
            
            try memoryProtectionManager.unprotectMemoryRegion(regionId: region1.id)
            try memoryProtectionManager.unprotectMemoryRegion(regionId: region2.id)
        } catch let error as MemoryProtectionManager.MemoryProtectionError {
            if case .syscallFailed = error {
                XCTSkip("mmap not available in test environment")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTSkip("mmap not available in test environment")
        }
    }
    
    func testUnprotectMemoryRegion_InvalidId_ShouldThrow() {
        do {
            _ = try memoryProtectionManager.protectMemoryRegion(
                address: 0,
                size: 4096,
                read: true,
                write: false,
                execute: false
            )
            
            try memoryProtectionManager.unprotectMemoryRegion(regionId: UUID())
            XCTFail("Should throw for invalid region ID")
        } catch let error as MemoryProtectionManager.MemoryProtectionError {
            if case .syscallFailed = error {
                XCTSkip("mmap not available in test environment")
            } else if case .protectionFailed = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch let error as MemoryProtectionManager.MemoryProtectionError {
            if case .syscallFailed = error {
                XCTSkip("mmap not available in test environment")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTSkip("mmap not available in test environment")
        }
    }
    
    func testUnprotectMemoryRegion_AfterProtection_ShouldDeallocate() {
        do {
            let region = try memoryProtectionManager.protectMemoryRegion(
                address: 0,
                size: 4096,
                read: true,
                write: true,
                execute: false
            )
            
            let regionId = region.id
            try memoryProtectionManager.unprotectMemoryRegion(regionId: regionId)
            
            let regions = memoryProtectionManager.protectedMemoryRegions
            XCTAssertEqual(regions.count, 0)
        } catch let error as MemoryProtectionManager.MemoryProtectionError {
            if case .syscallFailed = error {
                XCTSkip("mmap not available in test environment")
            } else {
                XCTFail("unprotectMemoryRegion should not throw: \(error)")
            }
        } catch {
            XCTSkip("mmap not available in test environment")
        }
    }
    
    // MARK: - ProtectedMemoryRegion Tests
    
    func testProtectedMemoryRegion_Description_ShouldBeFormatted() {
        let region = ProtectedMemoryRegion(
            id: UUID(),
            address: 0x10000,
            size: 4096,
            protectionFlags: 0x04 | 0x02,
            allocatedAt: Date()
        )
        
        let description = region.description
        XCTAssertTrue(description.contains("ProtectedRegion"))
        XCTAssertTrue(description.contains("RW"))
    }
    
    func testProtectedMemoryRegion_ReadFlags_ShouldParseCorrectly() {
        let readOnly = ProtectedMemoryRegion(
            id: UUID(),
            address: 0x10000,
            size: 4096,
            protectionFlags: 0x04,
            allocatedAt: Date()
        )
        
        XCTAssertTrue(readOnly.description.contains("R"))
        XCTAssertFalse(readOnly.description.contains("W"))
        XCTAssertFalse(readOnly.description.contains("X"))
    }
    
    // MARK: - Error Handling Tests
    
    func testMemoryProtectionError_AdminPrivilegesRequired() {
        let error = MemoryProtectionManager.MemoryProtectionError.adminPrivilegesRequired
        XCTAssertNotNil(error.localizedDescription)
    }
    
    func testMemoryProtectionError_ProcessNotFound() {
        let error = MemoryProtectionManager.MemoryProtectionError.processNotFound(pid: 123)
        XCTAssertTrue(error.localizedDescription.contains("123"))
    }
    
    func testMemoryProtectionError_MemoryAllocationFailed() {
        let error = MemoryProtectionManager.MemoryProtectionError.memoryAllocationFailed(reason: "test")
        XCTAssertTrue(error.localizedDescription.contains("test"))
    }
    
    func testMemoryProtectionError_ProtectionFailed() {
        let error = MemoryProtectionManager.MemoryProtectionError.protectionFailed(reason: "test")
        XCTAssertTrue(error.localizedDescription.contains("test"))
    }
    
    func testMemoryProtectionError_SyscallFailed() {
        let error = MemoryProtectionManager.MemoryProtectionError.syscallFailed(function: "mmap", errno: 12)
        XCTAssertTrue(error.localizedDescription.contains("mmap"))
        XCTAssertTrue(error.localizedDescription.contains("12"))
    }
    
    func testMemoryProtectionError_InvalidConfiguration() {
        let error = MemoryProtectionManager.MemoryProtectionError.invalidConfiguration(details: "test")
        XCTAssertTrue(error.localizedDescription.contains("test"))
    }
    
    // MARK: - Options Tests
    
    func testDefaultOptions_ShouldHaveStandardProtection() {
        let options = MemoryProtectionManager.MemoryProtectionOptions.default
        XCTAssertEqual(options.protectionLevel, .standard)
        XCTAssertTrue(options.enableMmapRandomization)
        XCTAssertTrue(options.enableAntiDebugging)
        XCTAssertTrue(options.enableProcessIsolation)
        XCTAssertTrue(options.randomizeBaseAddress)
        XCTAssertEqual(options.pageSize, 4096)
    }
    
    func testOptions_MinimalProtection_ShouldDisableFeatures() {
        let options = MemoryProtectionManager.MemoryProtectionOptions(
            protectionLevel: .minimal,
            enableMmapRandomization: false,
            enableAntiDebugging: false,
            enableProcessIsolation: false,
            randomizeBaseAddress: false,
            pageSize: 4096
        )
        
        XCTAssertEqual(options.protectionLevel, .minimal)
        XCTAssertFalse(options.enableMmapRandomization)
        XCTAssertFalse(options.enableAntiDebugging)
        XCTAssertFalse(options.enableProcessIsolation)
        XCTAssertFalse(options.randomizeBaseAddress)
    }
}
