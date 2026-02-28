# Privarion System Extensions Architecture

This document describes the system-level privacy protection architecture using macOS System Extensions, Network Extensions, and Virtualization Framework.

## Overview

Privarion has been enhanced with system-level protection capabilities that operate within macOS security boundaries (SIP-compliant) while providing comprehensive, system-wide privacy protection.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     User Interface Layer                     │
│  ┌──────────────────┐              ┌──────────────────┐     │
│  │  PrivarionGUI    │              │   PrivacyCtl     │     │
│  │   (SwiftUI)      │              │     (CLI)        │     │
│  └────────┬─────────┘              └────────┬─────────┘     │
└───────────┼──────────────────────────────────┼──────────────┘
            │                                  │
┌───────────┼──────────────────────────────────┼──────────────┐
│           │      Application Layer           │              │
│  ┌────────▼──────────────────────────────────▼─────────┐    │
│  │           Privarion Agent (Launch Agent)            │    │
│  │  - Lifecycle Management                             │    │
│  │  - Configuration Management                         │    │
│  │  - Permission Coordination                          │    │
│  └────┬──────────────┬──────────────┬──────────────┬──┘    │
└───────┼──────────────┼──────────────┼──────────────┼───────┘
        │              │              │              │
┌───────┼──────────────┼──────────────┼──────────────┼───────┐
│       │   System Extension Layer    │              │       │
│  ┌────▼────────┐ ┌──▼──────────┐ ┌─▼────────────┐ │       │
│  │  Endpoint   │ │   Network   │ │      VM      │ │       │
│  │  Security   │ │  Extension  │ │   Manager    │ │       │
│  │  Manager    │ │  Provider   │ │              │ │       │
│  └─────────────┘ └─────────────┘ └──────────────┘ │       │
└─────────────────────────────────────────────────────────────┘
            │              │              │
┌───────────┼──────────────┼──────────────┼───────────────────┐
│           │   macOS System Frameworks    │                   │
│  ┌────────▼────────┐ ┌──▼──────────┐ ┌──▼─────────────┐    │
│  │  EndpointSecurity│ │ NetworkExt  │ │ Virtualization │    │
│  │    Framework    │ │  Framework  │ │   Framework    │    │
│  └─────────────────┘ └─────────────┘ └────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## New Modules

### 1. PrivarionSharedModels
**Purpose**: Shared data models for cross-component communication

**Location**: `Sources/PrivarionSharedModels/`

**Contents**:
- Security event data models
- Network request/response models
- Configuration structures
- Error types
- Status enumerations

**Dependencies**: swift-log

### 2. PrivarionSystemExtension
**Purpose**: System Extension for system-level monitoring and protection

**Location**: `Sources/PrivarionSystemExtension/`

**Key Features**:
- System Extension lifecycle management
- Endpoint Security Framework integration
- Process execution monitoring
- File access monitoring
- Protection policy enforcement

**Entitlements**:
- `com.apple.developer.system-extension.install`
- `com.apple.developer.endpoint-security.client`
- `com.apple.security.files.user-selected.read-write`

**Dependencies**: PrivarionCore, PrivarionSharedModels, swift-log, swift-collections

### 3. PrivarionNetworkExtension
**Purpose**: Network Extension for packet filtering and DNS proxy

**Location**: `Sources/PrivarionNetworkExtension/`

**Key Features**:
- Packet Tunnel Provider for traffic interception
- Content Filter Provider for Safari/webview filtering
- DNS filtering and proxy
- Tracking domain blocking
- Telemetry prevention

**Entitlements**:
- `com.apple.developer.networking.networkextension` (packet-tunnel-provider, content-filter-provider, dns-proxy)

**Dependencies**: PrivarionCore, PrivarionSharedModels, swift-log, swift-nio

### 4. PrivarionVM
**Purpose**: VM Manager for hardware isolation

**Location**: `Sources/PrivarionVM/`

**Key Features**:
- Virtual machine creation with custom hardware identifiers
- Hardware profile management
- VM lifecycle management
- Resource allocation and monitoring
- Application installation in isolated VMs

**Entitlements**:
- `com.apple.security.virtualization`

**Dependencies**: PrivarionSharedModels, swift-log, Virtualization Framework

### 5. PrivarionAgent
**Purpose**: Background agent for persistent protection

**Location**: `Sources/PrivarionAgent/`

**Key Features**:
- Automatic startup at login (Launch Agent)
- Coordination of all protection components
- Permission management
- Configuration management
- Status monitoring
- Automatic restart on crash

**Entitlements**:
- Standard app sandbox entitlements

**Dependencies**: PrivarionCore, PrivarionSystemExtension, PrivarionNetworkExtension, PrivarionVM, PrivarionSharedModels, swift-log, swift-argument-parser

## Entitlements

All entitlement files are located in `Entitlements/`:

- `PrivarionSystemExtension.entitlements` - System Extension and Endpoint Security
- `PrivarionNetworkExtension.entitlements` - Network Extension capabilities
- `PrivarionVM.entitlements` - Virtualization Framework
- `PrivarionAgent.entitlements` - Background agent permissions

## Building

```bash
# Build all modules
swift build

# Build specific module
swift build --target PrivarionSystemExtension
swift build --target PrivarionNetworkExtension
swift build --target PrivarionVM
swift build --target PrivarionAgent

# Run tests
swift test
```

## Installation

### System Extension
```swift
let extension = PrivarionSystemExtension()
try await extension.installExtension()
try await extension.activateExtension()
```

### Launch Agent
```bash
# Install Launch Agent plist
cp com.privarion.agent.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.privarion.agent.plist
```

## Required Permissions

Users must grant the following permissions:

1. **System Extension Approval** - System dialog during installation
2. **Full Disk Access** - System Preferences → Security & Privacy → Privacy → Full Disk Access
3. **Network Extension Approval** - System dialog when starting network filtering

## Compatibility

- **macOS Version**: 13.0+ (Ventura or later)
- **Swift Version**: 5.9+
- **Architecture**: Apple Silicon and Intel

## Security Considerations

- All components operate within macOS security boundaries (SIP-compliant)
- No kernel modifications required
- Uses official Apple frameworks exclusively
- Suitable for App Store distribution with proper notarization
- Requires user approval for all privileged operations

## Performance

- **CPU Usage**: <5% average during normal operation
- **Memory Usage**: <200MB total across all components
- **Packet Processing**: <10ms latency for 95% of packets
- **DNS Queries**: <50ms for cached, <200ms for non-cached
- **Event Processing**: <100ms for 95% of security events

## Related Documentation

- [Requirements Document](.kiro/specs/macos-system-level-privacy-protection/requirements.md)
- [Design Document](.kiro/specs/macos-system-level-privacy-protection/design.md)
- [Implementation Tasks](.kiro/specs/macos-system-level-privacy-protection/tasks.md)

## Module READMEs

- [PrivarionSharedModels](Sources/PrivarionSharedModels/README.md)
- [PrivarionSystemExtension](Sources/PrivarionSystemExtension/README.md)
- [PrivarionNetworkExtension](Sources/PrivarionNetworkExtension/README.md)
- [PrivarionVM](Sources/PrivarionVM/README.md)
- [PrivarionAgent](Sources/PrivarionAgent/README.md)

## Implementation Status

This is the foundational structure for Task 1. Subsequent tasks will implement:
- Core data models and error handling (Task 2)
- Configuration management (Task 3)
- Protection policy engine (Task 4)
- System Extension Manager (Task 5)
- Endpoint Security integration (Task 6)
- Network filtering (Tasks 8-10)
- VM management (Tasks 13-14)
- And more...

See [tasks.md](.kiro/specs/macos-system-level-privacy-protection/tasks.md) for complete implementation plan.
