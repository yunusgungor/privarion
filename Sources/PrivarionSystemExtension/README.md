# PrivarionSystemExtension

System Extension for system-level privacy protection using macOS System Extensions and Endpoint Security Framework.

## Purpose

This module provides:
- System Extension lifecycle management (installation, activation, deactivation)
- Endpoint Security Framework integration for system-wide monitoring
- Process execution monitoring
- File access monitoring
- Protection policy enforcement

## Architecture

```
PrivarionSystemExtension/
├── SystemExtension.swift          # Main extension entry point
├── EndpointSecurity/              # Endpoint Security Framework integration (future)
├── PolicyEngine/                  # Protection policy evaluation (future)
└── README.md
```

## Key Components

### PrivarionSystemExtension
Main class managing System Extension lifecycle:
- `installExtension()` - Install the system extension
- `activateExtension()` - Activate the extension
- `deactivateExtension()` - Deactivate the extension
- `checkStatus()` - Query current status

### ExtensionStatus
Enumeration of possible extension states:
- `notInstalled` - Extension not installed
- `installed` - Extension installed but not active
- `active` - Extension running
- `activating` - Extension activation in progress
- `deactivating` - Extension deactivation in progress
- `error(Error)` - Extension in error state

## Requirements

- macOS 13.0+
- Swift 5.9+
- System Extension entitlements
- Endpoint Security entitlements
- Full Disk Access permission

## Entitlements

See `Entitlements/PrivarionSystemExtension.entitlements`:
- `com.apple.developer.system-extension.install`
- `com.apple.developer.endpoint-security.client`
- `com.apple.security.files.user-selected.read-write`

## Dependencies

- PrivarionCore (existing privacy engine)
- PrivarionSharedModels (shared data structures)
- swift-log (logging)
- swift-collections (data structures)

## Usage

```swift
import PrivarionSystemExtension

let extension = PrivarionSystemExtension()

// Install and activate
try await extension.installExtension()
try await extension.activateExtension()

// Check status
let status = await extension.checkStatus()
```

## Related Requirements

- Requirement 1: System Extension Installation and Management
- Requirement 2: Endpoint Security Framework Integration
- Requirements 12.1-12.10: Entitlements and Provisioning
- Requirement 14: User Permission Management
