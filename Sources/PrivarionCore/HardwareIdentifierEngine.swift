import Foundation

/// Hardware identifier generation engine for identity spoofing
/// Generates realistic MAC addresses, hostnames, and other hardware identifiers
public class HardwareIdentifierEngine {
    
    // MARK: - Types
    
    public enum GenerationStrategy {
        case random
        case vendorBased(vendor: VendorProfile)
        case realistic
        case stealth
        case custom(pattern: String)
    }
    
    public struct VendorProfile {
        public let name: String
        public let organizationallyUniqueIdentifier: String
        public let deviceTypes: [String]
        
        public init(name: String, oui: String, deviceTypes: [String]) {
            self.name = name
            self.organizationallyUniqueIdentifier = oui
            self.deviceTypes = deviceTypes
        }
    }
    
    public enum IdentifierError: Error, LocalizedError {
        case invalidVendorProfile
        case generationFailed
        case invalidPattern
        
        public var errorDescription: String? {
            switch self {
            case .invalidVendorProfile:
                return "Invalid vendor profile provided"
            case .generationFailed:
                return "Failed to generate valid identifier"
            case .invalidPattern:
                return "Invalid pattern for custom generation"
            }
        }
    }
    
    // MARK: - Properties
    
    private let commonVendors: [VendorProfile]
    private let realisticHostnamePrefixes: [String]
    private let realisticHostnameSuffixes: [String]
    
    // MARK: - Initialization
    
    public init() {
        // Common MAC address vendor prefixes (OUI - Organizationally Unique Identifier)
        self.commonVendors = [
            VendorProfile(name: "Apple", oui: "AC:DE:48", deviceTypes: ["MacBook", "iMac", "Mac"]),
            VendorProfile(name: "Apple", oui: "F0:18:98", deviceTypes: ["MacBook", "iMac", "Mac"]),
            VendorProfile(name: "Apple", oui: "A4:83:E7", deviceTypes: ["MacBook", "iMac", "Mac"]),
            VendorProfile(name: "Intel", oui: "00:1B:21", deviceTypes: ["NUC", "Corporate"]),
            VendorProfile(name: "Intel", oui: "94:C6:91", deviceTypes: ["NUC", "Corporate"]),
            VendorProfile(name: "Dell", oui: "18:03:73", deviceTypes: ["Latitude", "OptiPlex"]),
            VendorProfile(name: "Dell", oui: "54:9F:35", deviceTypes: ["Latitude", "OptiPlex"]),
            VendorProfile(name: "HP", oui: "70:5A:0F", deviceTypes: ["EliteBook", "ProBook"]),
            VendorProfile(name: "Lenovo", oui: "54:EE:75", deviceTypes: ["ThinkPad", "ThinkCentre"]),
            VendorProfile(name: "ASUS", oui: "1C:87:2C", deviceTypes: ["ROG", "ZenBook"]),
            VendorProfile(name: "Realtek", oui: "52:54:00", deviceTypes: ["Generic", "Virtual"]),
            VendorProfile(name: "VMware", oui: "00:0C:29", deviceTypes: ["VM", "Virtual"])
        ]
        
        // Realistic hostname components
        self.realisticHostnamePrefixes = [
            "MacBook-Pro", "MacBook-Air", "iMac", "Mac-mini", "Mac-Pro",
            "Johns-MacBook", "Sarahs-iMac", "Office-Mac", "Dev-Machine",
            "laptop", "desktop", "workstation", "dev-box", "mac"
        ]
        
        self.realisticHostnameSuffixes = [
            "local", "lan", "home", "office", "work", "dev", "test", "prod"
        ]
    }
    
    // MARK: - Public Methods
    
    /// Generate MAC address based on strategy
    public func generateMACAddress(strategy: GenerationStrategy = .realistic) -> String {
        switch strategy {
        case .random:
            return generateRandomMAC()
            
        case .vendorBased(let vendor):
            return generateVendorBasedMAC(vendor: vendor)
            
        case .realistic:
            return generateRealisticMAC()
            
        case .stealth:
            return generateStealthMAC()
            
        case .custom(let pattern):
            return generateCustomMAC(pattern: pattern)
        }
    }
    
    /// Generate hostname based on strategy
    public func generateHostname(strategy: GenerationStrategy = .realistic) -> String {
        switch strategy {
        case .random:
            return generateRandomHostname()
            
        case .vendorBased(let vendor):
            return generateVendorBasedHostname(vendor: vendor)
            
        case .realistic:
            return generateRealisticHostname()
            
        case .stealth:
            return generateStealthHostname()
            
        case .custom(let pattern):
            return generateCustomHostname(pattern: pattern)
        }
    }
    
    /// Generate serial number based on strategy
    public func generateSerialNumber(strategy: GenerationStrategy = .realistic) -> String {
        switch strategy {
        case .realistic, .vendorBased:
            return generateAppleStyleSerialNumber()
        default:
            return generateRandomSerialNumber()
        }
    }
    
    /// Validate generated MAC address
    public func validateMACAddress(_ mac: String) -> Bool {
        let macRegex = #"^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$"#
        return mac.range(of: macRegex, options: .regularExpression) != nil
    }
    
    /// Validate generated hostname
    public func validateHostname(_ hostname: String) -> Bool {
        let hostnameRegex = #"^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?$"#
        return hostname.range(of: hostnameRegex, options: .regularExpression) != nil
    }
    
    // MARK: - MAC Address Generation
    
    private func generateRandomMAC() -> String {
        var bytes = [UInt8]()
        for _ in 0..<6 {
            bytes.append(UInt8.random(in: 0...255))
        }
        
        // Ensure local bit is set and multicast bit is not set for valid unicast address
        bytes[0] = (bytes[0] | 0x02) & 0xFE
        
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
    
    private func generateVendorBasedMAC(vendor: VendorProfile) -> String {
        let ouiComponents = vendor.organizationallyUniqueIdentifier.components(separatedBy: ":")
        guard ouiComponents.count == 3 else {
            return generateRandomMAC()
        }
        
        var bytes = [UInt8]()
        
        // Add vendor OUI
        for component in ouiComponents {
            if let byte = UInt8(component, radix: 16) {
                bytes.append(byte)
            } else {
                return generateRandomMAC()
            }
        }
        
        // Add random device-specific bytes
        for _ in 0..<3 {
            bytes.append(UInt8.random(in: 0...255))
        }
        
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
    
    private func generateRealisticMAC() -> String {
        let randomVendor = commonVendors.randomElement()!
        return generateVendorBasedMAC(vendor: randomVendor)
    }
    
    private func generateStealthMAC() -> String {
        // Use commonly seen vendor prefixes for stealth
        let stealthVendors = commonVendors.filter { vendor in
            ["Apple", "Intel", "Dell", "HP"].contains(vendor.name)
        }
        
        let randomVendor = stealthVendors.randomElement() ?? commonVendors[0]
        return generateVendorBasedMAC(vendor: randomVendor)
    }
    
    private func generateCustomMAC(pattern: String) -> String {
        let patternComponents = pattern.components(separatedBy: ":")
        let requiredComponents = 6
        
        guard !patternComponents.isEmpty, patternComponents.count <= requiredComponents else {
            return generateRealisticMAC() // Invalid pattern
        }

        var bytes = patternComponents.compactMap { UInt8($0, radix: 16) }

        // Fill remaining bytes with random values
        while bytes.count < requiredComponents {
            bytes.append(UInt8.random(in: 0...255))
        }

        let result = bytes.map { String(format: "%02X", $0) }.joined(separator: ":")

        // Validate the result
        if validateMACAddress(result) {
            return result
        } else {
            return generateRealisticMAC()
        }
    }
    
    // MARK: - Hostname Generation
    
    private func generateRandomHostname() -> String {
        let randomString = (0..<8).map { _ in
            String("abcdefghijklmnopqrstuvwxyz0123456789".randomElement()!)
        }.joined()
        
        return "host-\(randomString)"
    }
    
    private func generateVendorBasedHostname(vendor: VendorProfile) -> String {
        let deviceType = vendor.deviceTypes.randomElement() ?? "Device"
        let identifier = String(Int.random(in: 1000...9999))
        
        return "\(deviceType)-\(identifier)"
    }
    
    private func generateRealisticHostname() -> String {
        let prefix = realisticHostnamePrefixes.randomElement()!
        let separator = ["-", ""].randomElement()!
        let number = Int.random(in: 1...9999)
        let suffix = realisticHostnameSuffixes.randomElement() ?? ""
        
        // Add more variations
        let formatOptions = [
            "\(prefix)\(separator)\(number)",
            "\(prefix)",
            "\(prefix)\(separator)\(suffix)",
            "\(prefix)\(number)"
        ]
        
        return formatOptions.randomElement()!
    }
    
    private func generateStealthHostname() -> String {
        // Generate hostname that looks like default system names
        let commonPatterns = [
            "MacBook-Pro",
            "MacBook-Air", 
            "iMac",
            "Mac-mini"
        ]
        
        let pattern = commonPatterns.randomElement()!
        
        if Bool.random() {
            return pattern
        } else {
            let number = Int.random(in: 1...20)
            return "\(pattern)-\(number)"
        }
    }
    
    private func generateCustomHostname(pattern: String) -> String {
        // Pattern example: "host-###" where # = random digit
        var result = pattern
        
        while result.contains("#") {
            let digit = String(Int.random(in: 0...9))
            if let range = result.range(of: "#") {
                result.replaceSubrange(range, with: digit)
            }
        }
        
        // Validate the result
        if validateHostname(result) {
            return result
        } else {
            return generateRealisticHostname()
        }
    }
    
    // MARK: - Serial Number Generation
    
    private func generateAppleStyleSerialNumber() -> String {
        // Apple serial number format: PPYWWSSSCCC
        // PP = Production Plant, Y = Year, WW = Week, SSS = Unique identifier, CCC = Model
        
        let plants = ["C02", "F4H", "G8W", "C17", "H25", "J0G"]
        let plant = plants.randomElement()!
        
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearCode = String(currentYear % 10)
        
        let weekCode = String(format: "%02d", Int.random(in: 1...52))
        
        let uniqueID = (0..<3).map { _ in
            String("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!)
        }.joined()
        
        let modelCode = (0..<3).map { _ in
            String("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!)
        }.joined()
        
        return "\(plant)\(yearCode)\(weekCode)\(uniqueID)\(modelCode)"
    }
    
    private func generateRandomSerialNumber() -> String {
        return (0..<12).map { _ in
            String("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".randomElement()!)
        }.joined()
    }
    
    // MARK: - Utility Methods
    
    /// Get available vendor profiles
    public func getAvailableVendors() -> [VendorProfile] {
        return commonVendors
    }
    
    /// Get vendor profile by name
    public func getVendorProfile(name: String) -> VendorProfile? {
        return commonVendors.first { $0.name.lowercased() == name.lowercased() }
    }
    
    /// Generate multiple MAC addresses for different interfaces
    public func generateMultipleMACs(count: Int, strategy: GenerationStrategy = .realistic) -> [String] {
        var macs = Set<String>()
        
        while macs.count < count {
            let mac = generateMACAddress(strategy: strategy)
            macs.insert(mac)
        }
        
        return Array(macs)
    }
    
    // MARK: - System Information Methods (for CLI)
    
    /// Get current system hostname
    public func getCurrentHostname() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        process.arguments = ["--get", "ComputerName"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        } catch {
            return "unknown"
        }
    }
    
    /// Get current system serial number
    public func getSystemSerial() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPHardwareDataType"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Parse serial number from system_profiler output
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("Serial Number") {
                    let components = line.components(separatedBy: ":")
                    if components.count > 1 {
                        return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            return "unknown"
        } catch {
            return "unknown"
        }
    }
    
    /// Get network interface information
    public struct NetworkInterface {
        public let name: String
        public let macAddress: String
        
        public init(name: String, macAddress: String) {
            self.name = name
            self.macAddress = macAddress
        }
    }
    
    /// Get current network interfaces with MAC addresses
    public func getNetworkInterfaces() -> [NetworkInterface] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process.arguments = ["-a"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return parseNetworkInterfaces(from: output)
        } catch {
            return []
        }
    }
    
    /// Get disk information
    public struct DiskInfo {
        public let device: String
        public let uuid: String
        public let mountPoint: String
        
        public init(device: String, uuid: String, mountPoint: String) {
            self.device = device
            self.uuid = uuid
            self.mountPoint = mountPoint
        }
    }
    
    /// Get current disk information
    public func getDiskInfo() -> [DiskInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["list", "-plist"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            _ = pipe.fileHandleForReading.readDataToEndOfFile()
            
            // For simplicity, just get the root disk UUID
            let rootProcess = Process()
            rootProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            rootProcess.arguments = ["info", "/"]
            
            let rootPipe = Pipe()
            rootProcess.standardOutput = rootPipe
            
            try rootProcess.run()
            rootProcess.waitUntilExit()
            
            let rootData = rootPipe.fileHandleForReading.readDataToEndOfFile()
            let rootOutput = String(data: rootData, encoding: .utf8) ?? ""
            
            let uuid = parseUUIDFromDiskutil(rootOutput)
            return [DiskInfo(device: "disk1", uuid: uuid, mountPoint: "/")]
            
        } catch {
            return []
        }
    }
    
    // MARK: - Private Parsing Helpers
    
    private func parseNetworkInterfaces(from output: String) -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        let lines = output.components(separatedBy: .newlines)
        
        var currentInterface: String?
        
        for line in lines {
            // Interface name line (starts at beginning of line)
            if !line.starts(with: "\t") && line.contains(":") {
                let components = line.components(separatedBy: ":")
                currentInterface = components.first?.trimmingCharacters(in: .whitespaces)
            }
            
            // MAC address line (indented with tabs)
            if line.contains("ether") && line.contains(":") {
                let components = line.components(separatedBy: .whitespaces)
                for (index, component) in components.enumerated() {
                    if component == "ether" && index + 1 < components.count {
                        let macAddress = components[index + 1]
                        if let interfaceName = currentInterface, interfaceName != "lo0" {
                            interfaces.append(NetworkInterface(name: interfaceName, macAddress: macAddress))
                        }
                        break
                    }
                }
            }
        }
        
        return interfaces
    }
    
    private func parseUUIDFromDiskutil(_ output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Volume UUID") || line.contains("Disk / Partition UUID") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return "unknown"
    }
}
