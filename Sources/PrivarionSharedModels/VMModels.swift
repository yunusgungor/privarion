// PrivarionSharedModels - VM and Hardware Profile Data Models
// Data structures for virtual machine management and hardware isolation
// Requirements: 8.1-8.14, 9.1-9.11

import Foundation

/// Protocol for hardware profile validation
public protocol HardwareProfileProtocol {
    var hardwareModel: Data { get }
    var machineIdentifier: Data { get }
    var macAddress: String { get }
    var serialNumber: String { get }
    func validate() throws
}

/// Hardware profile for VM configuration
public struct HardwareProfile: Codable, HardwareProfileProtocol, Identifiable {
    public let id: UUID
    public let name: String
    public let hardwareModel: Data
    public let machineIdentifier: Data
    public let macAddress: String
    public let serialNumber: String
    public let createdAt: Date
    
    public init(
        id: UUID = UUID(),
        name: String,
        hardwareModel: Data,
        machineIdentifier: Data,
        macAddress: String,
        serialNumber: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.hardwareModel = hardwareModel
        self.machineIdentifier = machineIdentifier
        self.macAddress = macAddress
        self.serialNumber = serialNumber
        self.createdAt = createdAt
    }
    
    /// Validate hardware profile identifiers for realistic format
    public func validate() throws {
        // Validate MAC address format (XX:XX:XX:XX:XX:XX)
        let macPattern = "^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$"
        let macRegex = try NSRegularExpression(pattern: macPattern)
        let macRange = NSRange(macAddress.startIndex..., in: macAddress)
        guard macRegex.firstMatch(in: macAddress, range: macRange) != nil else {
            throw ConfigurationError.validationFailed(["Invalid MAC address format: \(macAddress)"])
        }
        
        // Validate serial number is not empty
        guard !serialNumber.isEmpty else {
            throw ConfigurationError.validationFailed(["Serial number cannot be empty"])
        }
        
        // Validate hardware model data is not empty
        guard !hardwareModel.isEmpty else {
            throw ConfigurationError.validationFailed(["Hardware model data cannot be empty"])
        }
        
        // Validate machine identifier data is not empty
        guard !machineIdentifier.isEmpty else {
            throw ConfigurationError.validationFailed(["Machine identifier data cannot be empty"])
        }
    }
}

/// VM snapshot structure for state management
public struct VMSnapshot: Codable, Identifiable {
    public let id: UUID
    public let vmID: UUID
    public let timestamp: Date
    public let name: String
    public let diskImagePath: URL
    public let memoryStatePath: URL
    
    public init(
        id: UUID = UUID(),
        vmID: UUID,
        timestamp: Date = Date(),
        name: String,
        diskImagePath: URL,
        memoryStatePath: URL
    ) {
        self.id = id
        self.vmID = vmID
        self.timestamp = timestamp
        self.name = name
        self.diskImagePath = diskImagePath
        self.memoryStatePath = memoryStatePath
    }
}

/// VM resource usage metrics
public struct VMResourceUsage: Codable {
    public let cpuUsage: Double // 0.0 to 1.0
    public let memoryUsage: UInt64 // bytes
    public let diskUsage: UInt64 // bytes
    public let networkBytesIn: UInt64
    public let networkBytesOut: UInt64
    public let timestamp: Date
    
    public init(
        cpuUsage: Double,
        memoryUsage: UInt64,
        diskUsage: UInt64,
        networkBytesIn: UInt64,
        networkBytesOut: UInt64,
        timestamp: Date = Date()
    ) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.diskUsage = diskUsage
        self.networkBytesIn = networkBytesIn
        self.networkBytesOut = networkBytesOut
        self.timestamp = timestamp
    }
    
    /// Format memory usage in human-readable format
    public var formattedMemoryUsage: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(memoryUsage))
    }
    
    /// Format disk usage in human-readable format
    public var formattedDiskUsage: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(diskUsage))
    }
    
    /// CPU usage as percentage
    public var cpuPercentage: Double {
        return cpuUsage * 100.0
    }
}
