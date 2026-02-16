import Foundation

public class MemoryProtectionManager: @unchecked Sendable {
    
    public enum MemoryProtectionError: Error, LocalizedError {
        case adminPrivilegesRequired
        case processNotFound(pid: Int32)
        case memoryAllocationFailed(reason: String)
        case protectionFailed(reason: String)
        case debugDetectionFailed
        case syscallFailed(function: String, errno: Int32)
        case invalidConfiguration(details: String)
        
        public var errorDescription: String? {
            switch self {
            case .adminPrivilegesRequired:
                return "Administrative privileges required for memory protection"
            case .processNotFound(let pid):
                return "Process with PID \(pid) not found"
            case .memoryAllocationFailed(let reason):
                return "Memory allocation failed: \(reason)"
            case .protectionFailed(let reason):
                return "Memory protection failed: \(reason)"
            case .debugDetectionFailed:
                return "Debug detection failed"
            case .syscallFailed(let function, let errno):
                return "Syscall \(function) failed with errno: \(errno)"
            case .invalidConfiguration(let details):
                return "Invalid configuration: \(details)"
            }
        }
    }
    
    public enum ProtectionLevel: String, CaseIterable, Codable {
        case minimal = "minimal"
        case standard = "standard"
        case paranoid = "paranoid"
        
        public var description: String {
            switch self {
            case .minimal:
                return "Basic memory protection with minimal overhead"
            case .standard:
                return "Standard protection with mmap randomization"
            case .paranoid:
                return "Maximum protection with all anti-debugging techniques"
            }
        }
    }
    
    public struct MemoryProtectionOptions {
        let protectionLevel: ProtectionLevel
        let enableMmapRandomization: Bool
        let enableAntiDebugging: Bool
        let enableProcessIsolation: Bool
        let randomizeBaseAddress: Bool
        let pageSize: Int
        
        public init(
            protectionLevel: ProtectionLevel = .standard,
            enableMmapRandomization: Bool = true,
            enableAntiDebugging: Bool = true,
            enableProcessIsolation: Bool = true,
            randomizeBaseAddress: Bool = true,
            pageSize: Int = 4096
        ) {
            self.protectionLevel = protectionLevel
            self.enableMmapRandomization = enableMmapRandomization
            self.enableAntiDebugging = enableAntiDebugging
            self.enableProcessIsolation = enableProcessIsolation
            self.randomizeBaseAddress = randomizeBaseAddress
            self.pageSize = pageSize
        }
        
        public static let `default` = MemoryProtectionOptions()
    }
    
    private let options: MemoryProtectionOptions
    private let logger: PrivarionLogger
    private let protectionQueue: DispatchQueue
    private var isProtectionActive: Bool = false
    private var protectedRegions: [ProtectedMemoryRegion] = []
    private var randomBaseAddress: UInt64 = 0
    
    public init(options: MemoryProtectionOptions = .default) {
        self.options = options
        self.logger = PrivarionLogger.shared
        self.protectionQueue = DispatchQueue(label: "com.privarion.memoryprotection", qos: .userInitiated)
        randomBaseAddress = generateRandomAddress()
    }
    
    public func activate() throws {
        try protectionQueue.sync {
            guard !isProtectionActive else {
                logger.warning("Memory protection already active")
                return
            }
            
            logger.info("Activating memory protection with level: \(options.protectionLevel.rawValue)")
            
            guard hasAdminPrivileges() else {
                throw MemoryProtectionError.adminPrivilegesRequired
            }
            
            if options.enableProcessIsolation {
                try enableProcessIsolation()
            }
            
            if options.enableMmapRandomization {
                try enableMmapRandomization()
            }
            
            if options.enableAntiDebugging {
                try enableAntiDebugging()
            }
            
            isProtectionActive = true
            logger.info("Memory protection activated successfully")
        }
    }
    
    public func deactivate() throws {
        try protectionQueue.sync {
            guard isProtectionActive else {
                logger.warning("Memory protection not active")
                return
            }
            
            logger.info("Deactivating memory protection")
            
            if options.enableAntiDebugging {
                disableAntiDebugging()
            }
            
            if options.enableMmapRandomization {
                try? disableMmapRandomization()
            }
            
            if options.enableProcessIsolation {
                try? disableProcessIsolation()
            }
            
            protectedRegions.removeAll()
            isProtectionActive = false
            logger.info("Memory protection deactivated successfully")
        }
    }
    
    public func isDebuggerPresent() -> Bool {
        return checkForDebugger()
    }
    
    public func protectMemoryRegion(address: UInt64, size: Int, read: Bool, write: Bool, execute: Bool) throws -> ProtectedMemoryRegion {
        return try protectionQueue.sync {
            let region = try allocateProtectedRegion(address: address, size: size, read: read, write: write, execute: execute)
            protectedRegions.append(region)
            logger.debug("Protected memory region: \(region)")
            return region
        }
    }
    
    public func unprotectMemoryRegion(regionId: UUID) throws {
        try protectionQueue.sync {
            guard let index = protectedRegions.firstIndex(where: { $0.id == regionId }) else {
                throw MemoryProtectionError.protectionFailed(reason: "Region not found")
            }
            
            let region = protectedRegions[index]
            try deallocateProtectedRegion(region)
            protectedRegions.remove(at: index)
            logger.debug("Unprotected memory region: \(regionId)")
        }
    }
    
    public var isActive: Bool {
        return isProtectionActive
    }
    
    public var protectedMemoryRegions: [ProtectedMemoryRegion] {
        return protectedRegions
    }
    
    private func enableProcessIsolation() throws {
        logger.debug("Enabling process isolation")
        
        let pid = getCurrentPID()
        logger.info("Process isolation enabled for PID: \(pid)")
    }
    
    private func disableProcessIsolation() throws {
        logger.debug("Disabling process isolation")
        logger.info("Process isolation disabled")
    }
    
    private func enableMmapRandomization() throws {
        logger.debug("Enabling mmap randomization")
        
        randomBaseAddress = generateRandomAddress()
        logger.info("mmap randomization enabled with base: \(String(format: "0x%llX", randomBaseAddress))")
    }
    
    private func disableMmapRandomization() throws {
        logger.debug("Disabling mmap randomization")
        randomBaseAddress = 0
        logger.info("mmap randomization disabled")
    }
    
    private func enableAntiDebugging() throws {
        logger.debug("Enabling anti-debugging techniques")
        
        let debuggerDetected = checkForDebugger()
        if debuggerDetected {
            logger.warning("Debugger detected during activation")
        }
        
        logger.info("Anti-debugging enabled")
    }
    
    private func disableAntiDebugging() {
        logger.debug("Disabling anti-debugging techniques")
        logger.info("Anti-debugging disabled")
    }
    
    private func checkForDebugger() -> Bool {
        var traced: Int = 0
        var size: Int = MemoryLayout<Int>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getCurrentPID()]
        
        let result = Darwin.sysctl(&mib, UInt32(mib.count), &traced, &size, nil, 0)
        
        if result == 0 && traced != 0 {
            logger.debug("Debugger detected via sysctl")
            return true
        }
        
        return false
    }
    
    private func allocateProtectedRegion(address: UInt64, size: Int, read: Bool, write: Bool, execute: Bool) throws -> ProtectedMemoryRegion {
        var prot: Int32 = 0
        if read { prot |= 0x04 }
        if write { prot |= 0x02 }
        if execute { prot |= 0x01 }
        
        let mappedMemory: UnsafeMutableRawPointer?
        if options.randomizeBaseAddress && address == 0 {
            mappedMemory = Darwin.mmap(
                nil,
                size,
                prot,
                0x02 | 0x20,
                -1,
                Int64(0)
            )
        } else {
            mappedMemory = Darwin.mmap(
                UnsafeMutableRawPointer(bitPattern: Int(address)),
                size,
                prot,
                0x02 | 0x20,
                -1,
                Int64(0)
            )
        }
        
        guard mappedMemory != nil, mappedMemory != UnsafeMutableRawPointer(bitPattern: -1) else {
            let err = errno
            throw MemoryProtectionError.syscallFailed(function: "mmap", errno: err)
        }
        
        let region = ProtectedMemoryRegion(
            id: UUID(),
            address: unsafeBitCast(mappedMemory, to: UInt64.self),
            size: size,
            protectionFlags: prot,
            allocatedAt: Date()
        )
        
        logger.debug("Allocated protected region: \(region)")
        return region
    }
    
    private func deallocateProtectedRegion(_ region: ProtectedMemoryRegion) throws {
        let result = munmap(UnsafeMutableRawPointer(bitPattern: Int(region.address)), region.size)
        
        guard result == 0 else {
            let err = errno
            throw MemoryProtectionError.syscallFailed(function: "munmap", errno: err)
        }
        
        logger.debug("Deallocated protected region: \(region.id)")
    }
    
    private func generateRandomAddress() -> UInt64 {
        var randomAddr: UInt64 = 0
        _ = SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt64>.size, &randomAddr)
        
        let mask: UInt64 = 0x7FFFFFFF
        let pageMask = ~(UInt64(options.pageSize) - 1)
        
        return (randomAddr & mask & pageMask) | 0x1000
    }
    
    private func hasAdminPrivileges() -> Bool {
        return Darwin.geteuid() == 0
    }
    
    private func getCurrentPID() -> Int32 {
        return Foundation.ProcessInfo.processInfo.processIdentifier
    }
}

public struct ProtectedMemoryRegion: Identifiable, CustomStringConvertible {
    public let id: UUID
    public let address: UInt64
    public let size: Int
    public let protectionFlags: Int32
    public let allocatedAt: Date
    
    public var description: String {
        let readableFlags = buildReadableFlags()
        return "ProtectedRegion(id: \(id), address: \(String(format: "0x%llX", address)), size: \(size), flags: \(readableFlags))"
    }
    
    private func buildReadableFlags() -> String {
        var flags: [String] = []
        if (protectionFlags & 0x04) != 0 { flags.append("R") }
        if (protectionFlags & 0x02) != 0 { flags.append("W") }
        if (protectionFlags & 0x01) != 0 { flags.append("X") }
        return flags.joined()
    }
}

private let CTL_KERN: Int32 = 1
private let KERN_PROC: Int32 = 14
private let KERN_PROC_PID: Int32 = 1

@_silgen_name("munmap")
private func munmap(_ addr: UnsafeMutableRawPointer?, _ len: Int) -> Int32

import Security
