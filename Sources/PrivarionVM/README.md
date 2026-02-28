# PrivarionVM

VM Manager for hardware isolation using macOS Virtualization Framework.

## Purpose

This module provides:
- Virtual machine creation with custom hardware identifiers
- Hardware profile management
- VM lifecycle management (start, stop, snapshot, restore)
- Resource allocation and monitoring
- Application installation in isolated VMs

## Architecture

```
PrivarionVM/
├── VMManager.swift                # Main VM management
├── VMConfigurationBuilder/        # VM configuration (future)
├── VMResourceManager/             # Resource management (future)
├── HardwareProfileManager/        # Hardware profiles (future)
└── README.md
```

## Key Components

### VMManager
Main class for VM lifecycle management:
- `createVM(with:)` - Create VM with hardware profile
- `startVM(_:)` - Start a virtual machine
- `stopVM(_:)` - Stop a virtual machine
- `installApplication(_:in:)` - Install app in VM
- `snapshot(_:)` - Create VM snapshot
- `restore(_:)` - Restore from snapshot

### HardwareProfile
Configuration for VM hardware identifiers:
- `id` - Unique profile identifier
- `name` - Profile name
- `hardwareModel` - Custom hardware model data
- `machineIdentifier` - Custom machine ID
- `macAddress` - Custom MAC address
- `serialNumber` - Custom serial number
- `validate()` - Validate identifier formats

### VMSnapshot
VM state snapshot for backup/restore:
- `id` - Snapshot identifier
- `vmID` - Associated VM identifier
- `diskImagePath` - Path to disk image
- `memoryStatePath` - Path to memory state

### VMResourceUsage
Resource consumption metrics:
- `cpuUsage` - CPU usage (0.0 to 1.0)
- `memoryUsage` - Memory usage in bytes
- `diskUsage` - Disk usage in bytes
- `networkBytesIn/Out` - Network traffic

## Requirements

- macOS 13.0+
- Swift 5.9+
- Virtualization Framework entitlements
- Sufficient system resources (CPU, memory, disk)

## Entitlements

See `Entitlements/PrivarionVM.entitlements`:
- `com.apple.security.virtualization`
- `com.apple.security.files.user-selected.read-write`

## Dependencies

- PrivarionSharedModels (shared data structures)
- swift-log (logging)
- Virtualization Framework (macOS system framework)

## Usage

```swift
import PrivarionVM

let vmManager = VMManager()

// Create hardware profile
let profile = HardwareProfile(
    name: "MacBook Pro 2021",
    hardwareModel: customModelData,
    machineIdentifier: customMachineID,
    macAddress: "02:00:00:00:00:01",
    serialNumber: "C02ABC123DEF"
)

// Create and start VM
let vm = try await vmManager.createVM(with: profile)
try await vmManager.startVM(vm.id)

// Install application
try await vmManager.installApplication(appURL, in: vm.id)
```

## Resource Limits

- CPU: Maximum 50% of host CPU cores
- Memory: Maximum 50% of host memory
- Disk: Configurable per VM (default 50GB)

## Performance Requirements

- VM creation: <30 seconds
- VM startup: <60 seconds
- Resource monitoring: Real-time with <1 second latency

## Related Requirements

- Requirement 8: Virtualization Framework for Hardware Isolation
- Requirement 9: Hardware Profile Management
- Requirement 12.5: Virtualization Entitlements
- Requirements 18.6-18.7: Resource Management
