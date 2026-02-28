# PrivarionNetworkExtension

Network Extension for packet filtering, DNS proxy, and content filtering using macOS Network Extension Framework.

## Purpose

This module provides:
- Packet Tunnel Provider for system-wide network traffic interception
- Content Filter Provider for Safari and webview filtering
- DNS filtering and proxy
- Tracking domain blocking
- Telemetry prevention

## Architecture

```
PrivarionNetworkExtension/
├── NetworkExtension.swift         # Packet Tunnel & Content Filter Providers
├── DNSFilter/                     # DNS filtering (future)
├── PacketFilter/                  # Packet filtering (future)
├── TelemetryBlocker/              # Telemetry detection (future)
└── README.md
```

## Key Components

### PrivarionPacketTunnelProvider
NEPacketTunnelProvider subclass for packet-level filtering:
- `startTunnel(options:)` - Initialize packet tunnel
- `stopTunnel(with:)` - Cleanup tunnel
- Intercepts all network packets
- Applies filtering rules based on protection policies

### PrivarionContentFilterProvider
NEFilterDataProvider subclass for content filtering:
- `handleNewFlow(_:)` - Evaluate new network flows
- `handleInboundData(from:readBytesStartOffset:readBytes:)` - Inspect inbound data
- `handleOutboundData(from:readBytesStartOffset:readBytes:)` - Inspect outbound data
- Blocks tracking and fingerprinting scripts
- Prevents telemetry transmission

## Requirements

- macOS 13.0+
- Swift 5.9+
- Network Extension entitlements
- User approval for Network Extension

## Entitlements

See `Entitlements/PrivarionNetworkExtension.entitlements`:
- `com.apple.developer.networking.networkextension` with:
  - `packet-tunnel-provider`
  - `content-filter-provider`
  - `dns-proxy`

## Dependencies

- PrivarionCore (existing privacy engine)
- PrivarionSharedModels (shared data structures)
- swift-log (logging)
- swift-nio (async networking)

## Usage

```swift
import PrivarionNetworkExtension

// Packet Tunnel Provider is instantiated by the system
// Configuration is done through NEPacketTunnelProviderManager

let manager = NEPacketTunnelProviderManager()
manager.protocolConfiguration = NETunnelProviderProtocol()
// ... configure and save
```

## Performance Requirements

- Packet processing latency: <10ms for 95% of packets
- DNS query processing: <50ms for cached entries, <200ms for non-cached
- Minimal CPU usage: <5% average

## Related Requirements

- Requirement 3: Network Extension - Packet Tunnel Provider
- Requirement 4: DNS Filtering and Proxy
- Requirement 5: Content Filter Extension
- Requirement 10: Telemetry Blocking
- Requirements 12.3-12.4: Network Extension Entitlements
