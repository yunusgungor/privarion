# PrivarionSharedModels

Shared data models for cross-component communication across all system extension components.

## Purpose

This module contains data structures that are shared between:
- PrivarionSystemExtension
- PrivarionNetworkExtension
- PrivarionVM
- PrivarionAgent
- PrivarionCore

## Contents

- Security event data models
- Network request/response models
- Configuration structures
- Error types
- Status enumerations

## Requirements

- macOS 13.0+
- Swift 5.9+

## Dependencies

- swift-log (for logging support)

## Usage

```swift
import PrivarionSharedModels

// Shared models will be available here
```

## Related Requirements

- Requirement 1.1: System Extension Installation and Management
- Requirements 12.1-12.9: Entitlements and Provisioning
