import Foundation
import Network

/// Manager for network interface operations and system command abstraction
/// Provides safe wrappers for network interface enumeration and modification
public class NetworkInterfaceManager {
    
    private let commandExecutor: SystemCommandExecutor
    private let logger: PrivarionLogger
    
    public init(commandExecutor: SystemCommandExecutor? = nil, logger: PrivarionLogger? = nil) {
        self.commandExecutor = commandExecutor ?? SystemCommandExecutor(logger: PrivarionLogger.shared)
        self.logger = logger ?? PrivarionLogger.shared
    }
    
    /// Enumerates all available network interfaces
    public func enumerateInterfaces() async throws -> [NetworkInterface] {
        logger.debug("Enumerating network interfaces")
        
        let command = "ifconfig"
        let args = ["-a"]
        
        do {
            let result = try await commandExecutor.executeCommand(command, arguments: args)
            if !result.isSuccess {
                throw NetworkError.commandExecutionFailed(command, result.standardError ?? "Unknown error")
            }
            let output = result.standardOutput ?? ""
            return try parseIfconfigOutput(output)
        } catch {
            logger.error("Failed to enumerate network interfaces: \(error)")
            throw error
        }
    }
    
    /// Gets a specific network interface by name
    public func getInterface(name: String) async throws -> NetworkInterface? {
        let interfaces = try await enumerateInterfaces()
        return interfaces.first { $0.name == name }
    }
    
    /// Changes the MAC address of a network interface
    public func changeMACAddress(interface: String, newMAC: String) async throws {
        logger.info("Changing MAC address for interface \(interface) to \(newMAC)")
        
        // First try networksetup (macOS native)
        do {
            try await changeUsingNetworksetup(interface: interface, newMAC: newMAC)
        } catch {
            logger.warning("networksetup failed, falling back to ifconfig: \(error)")
            // Fallback to ifconfig
            try await changeUsingIfconfig(interface: interface, newMAC: newMAC)
        }
    }
    
    /// Tests network connectivity for an interface
    public func testConnectivity(interface: String) async throws -> Bool {
        logger.debug("Testing connectivity for interface \(interface)")
        
        // Simple ping test to gateway or known host
        let command = "ping"
        let args = ["-c", "1", "-W", "2000", "-I", interface, "8.8.8.8"]
        
        do {
            let result = try await commandExecutor.executeCommand(command, arguments: args)
            return result.isSuccess
        } catch {
            logger.debug("Connectivity test failed for interface \(interface): \(error)")
            return false
        }
    }
    
    // MARK: - Private Implementation
    
    private func changeUsingNetworksetup(interface: String, newMAC: String) async throws {
        // First, get the network service name for this interface
        let serviceName = try await getNetworkServiceName(for: interface)
        
        let command = "networksetup"
        let args = ["-setMACAddress", serviceName, newMAC]
        
        do {
            let result = try await commandExecutor.executeCommand(command, arguments: args)
            if !result.isSuccess {
                throw NetworkError.macChangeUsingNetworksetupFailed(interface, 
                    NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: result.standardError ?? "Unknown error"]))
            }
            logger.debug("Successfully changed MAC using networksetup")
        } catch {
            throw NetworkError.macChangeUsingNetworksetupFailed(interface, error)
        }
    }
    
    private func changeUsingIfconfig(interface: String, newMAC: String) async throws {
        let command = "ifconfig"
        let args = [interface, "ether", newMAC]
        
        do {
            let result = try await commandExecutor.executeCommand(command, arguments: args)
            if !result.isSuccess {
                throw NetworkError.macChangeUsingIfconfigFailed(interface,
                    NSError(domain: "NetworkError", code: -1, userInfo: [NSLocalizedDescriptionKey: result.standardError ?? "Unknown error"]))
            }
            logger.debug("Successfully changed MAC using ifconfig")
        } catch {
            throw NetworkError.macChangeUsingIfconfigFailed(interface, error)
        }
    }
    
    private func getNetworkServiceName(for interface: String) async throws -> String {
        let command = "networksetup"
        let args = ["-listnetworkserviceorder"]
        
        let result = try await commandExecutor.executeCommand(command, arguments: args)
        if !result.isSuccess {
            throw NetworkError.serviceNameNotFound(interface)
        }
        
        let output = result.standardOutput ?? ""
        
        // Parse the output to find the service name for the interface
        let lines = output.components(separatedBy: CharacterSet.newlines)
        var currentService: String?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
            
            // Look for service name lines (start with (1), (2), etc.)
            if trimmed.hasPrefix("(") && trimmed.contains(")") {
                let serviceLine = trimmed
                if let range = serviceLine.range(of: ") ") {
                    currentService = String(serviceLine[range.upperBound...])
                }
            }
            
            // Look for device lines that match our interface
            if trimmed.hasPrefix("(Device: ") && trimmed.contains(interface) {
                guard let service = currentService else {
                    throw NetworkError.serviceNameNotFound(interface)
                }
                return service
            }
        }
        
        throw NetworkError.serviceNameNotFound(interface)
    }
    
    private func parseIfconfigOutput(_ output: String) throws -> [NetworkInterface] {
        var interfaces: [NetworkInterface] = []
        let lines = output.components(separatedBy: CharacterSet.newlines)
        
        var currentInterface: NetworkInterface?
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
            
            // New interface line (doesn't start with whitespace/tab)
            if !line.hasPrefix("\t") && !line.hasPrefix(" ") && !trimmed.isEmpty {
                // Save previous interface if exists
                if let interface = currentInterface {
                    interfaces.append(interface)
                }
                
                // Parse new interface
                currentInterface = try parseInterfaceLine(trimmed)
            } else if var interface = currentInterface {
                // Parse additional interface properties
                if trimmed.contains("ether ") {
                    interface.macAddress = extractMACAddress(from: trimmed)
                } else if trimmed.contains("status: ") {
                    interface.isActive = trimmed.contains("status: active")
                } else if trimmed.contains("inet ") {
                    if interface.ipAddresses == nil {
                        interface.ipAddresses = []
                    }
                    if let ip = extractIPAddress(from: trimmed) {
                        interface.ipAddresses?.append(ip)
                    }
                }
                currentInterface = interface
            }
        }
        
        // Add the last interface
        if let interface = currentInterface {
            interfaces.append(interface)
        }
        
        return interfaces
    }
    
    private func parseInterfaceLine(_ line: String) throws -> NetworkInterface {
        // Parse lines like "en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500"
        let components = line.components(separatedBy: ":")
        guard !components.isEmpty else {
            throw NetworkError.interfaceParsingFailed(line)
        }
        
        let name = components[0].trimmingCharacters(in: CharacterSet.whitespaces)
        let flagsAndMtu = components.dropFirst().joined(separator: ":").trimmingCharacters(in: CharacterSet.whitespaces)
        
        // Determine interface type
        let type = determineInterfaceType(name: name)
        
        // Parse flags to determine if interface is eligible for spoofing
        let isEligible = isEligibleForSpoofing(name: name, type: type, flags: flagsAndMtu)
        
        return NetworkInterface(
            name: name,
            macAddress: "", // Will be filled in later when parsing ether line
            type: type,
            isActive: false, // Will be updated when parsing status line
            isEligibleForSpoofing: isEligible,
            ipAddresses: nil
        )
    }
    
    private func determineInterfaceType(name: String) -> NetworkInterfaceType {
        switch true {
        case name.hasPrefix("en"):
            return .ethernet
        case name.hasPrefix("wlan") || name.hasPrefix("wifi"):
            return .wifi
        case name.hasPrefix("lo"):
            return .loopback
        case name.hasPrefix("bridge"):
            return .bridge
        case name.hasPrefix("utun") || name.hasPrefix("tun"):
            return .vpn
        case name.hasPrefix("awdl"):
            return .other
        default:
            return .other
        }
    }
    
    private func isEligibleForSpoofing(name: String, type: NetworkInterfaceType, flags: String) -> Bool {
        // Don't allow spoofing of certain interface types
        switch type {
        case .loopback, .vpn:
            return false
        default:
            break
        }
        
        // Don't allow spoofing of certain named interfaces
        let excludedInterfaces = ["lo0", "awdl0", "llw0"]
        if excludedInterfaces.contains(name) {
            return false
        }
        
        return true
    }
    
    private func extractMACAddress(from line: String) -> String {
        // Parse lines like "	ether a8:20:66:xx:xx:xx"
        let components = line.components(separatedBy: CharacterSet.whitespaces)
        guard let etherIndex = components.firstIndex(of: "ether"),
              etherIndex + 1 < components.count else {
            return ""
        }
        
        return components[etherIndex + 1]
    }
    
    private func extractIPAddress(from line: String) -> String? {
        // Parse lines like "	inet 192.168.1.100 netmask 0xffffff00 broadcast 192.168.1.255"
        let components = line.components(separatedBy: CharacterSet.whitespaces)
        guard let inetIndex = components.firstIndex(of: "inet"),
              inetIndex + 1 < components.count else {
            return nil
        }
        
        return components[inetIndex + 1]
    }
}

// MARK: - Supporting Types

/// Represents a network interface
public struct NetworkInterface: Codable {
    public let name: String
    public var macAddress: String
    public let type: NetworkInterfaceType
    public var isActive: Bool
    public let isEligibleForSpoofing: Bool
    public var ipAddresses: [String]?
    
    public init(
        name: String,
        macAddress: String,
        type: NetworkInterfaceType,
        isActive: Bool,
        isEligibleForSpoofing: Bool,
        ipAddresses: [String]? = nil
    ) {
        self.name = name
        self.macAddress = macAddress
        self.type = type
        self.isActive = isActive
        self.isEligibleForSpoofing = isEligibleForSpoofing
        self.ipAddresses = ipAddresses
    }
}

/// Network interface types
public enum NetworkInterfaceType: String, CaseIterable, Codable {
    case ethernet = "ethernet"
    case wifi = "wifi"
    case loopback = "loopback"
    case bridge = "bridge"
    case vpn = "vpn"
    case other = "other"
}

/// Network-specific errors
public enum NetworkError: Error, LocalizedError {
    case macChangeUsingNetworksetupFailed(String, Error)
    case macChangeUsingIfconfigFailed(String, Error)
    case serviceNameNotFound(String)
    case interfaceParsingFailed(String)
    case commandExecutionFailed(String, String)
    
    public var errorDescription: String? {
        switch self {
        case .macChangeUsingNetworksetupFailed(let interface, let error):
            return "Failed to change MAC address using networksetup for interface \(interface): \(error.localizedDescription)"
        case .macChangeUsingIfconfigFailed(let interface, let error):
            return "Failed to change MAC address using ifconfig for interface \(interface): \(error.localizedDescription)"
        case .serviceNameNotFound(let interface):
            return "Could not find network service name for interface \(interface)"
        case .interfaceParsingFailed(let line):
            return "Failed to parse interface line: \(line)"
        case .commandExecutionFailed(let command, let error):
            return "Command '\(command)' failed: \(error)"
        }
    }
}
