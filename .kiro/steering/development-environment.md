---
inclusion: fileMatch
fileMatchPattern: 'Package.swift'
---

# Development Environment Setup

## Requirements
- macOS 13.0 (Ventura) or later
- Xcode 15.0+
- Swift 5.9+
- Command Line Tools: `xcode-select --install`

## Build Commands

### Development Build
```bash
swift build
```

### Release Build
```bash
swift build -c release
```

### Testing
```bash
swift test
swift test --enable-code-coverage
```

### Running CLI
```bash
swift run privacyctl --help
```

### Running GUI
```bash
swift run PrivarionGUI
```

## Environment Variables
- `PRIVARION_DEBUG=1` - Enable debug logging
- `PRIVARION_CONFIG_PATH` - Custom config directory
- `PRIVARION_LOG_LEVEL` - Trace, debug, info, warn, error

## Code Signing (for distribution)
- Configure signing identity in Xcode
- Enable Hardened Runtime
- Configure entitlements for:
  - `com.apple.security.network.client` - Network access
  - `com.apple.security.network.server` - DNS proxy
  - `com.apple.security.temporary-exception.mach-lookup.global-name` - System communication

## Dependencies
Managed via Swift Package Manager. Dependencies are automatically resolved on first build.

## Xcode Integration
```bash
# Generate Xcode project
swift package generate-xcodeproj

# Or open directly
open Package.swift
```

Select appropriate scheme:
- `PrivacyCtl` - CLI tool development
- `PrivarionGUI` - GUI application development
- `PrivarionCore` - Library development
