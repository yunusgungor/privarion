# PrivarionAgent

Background agent (Launch Agent) for persistent privacy protection.

## Purpose

This module provides:
- Automatic startup at login
- Coordination of all protection components
- Permission management
- Configuration management
- Status monitoring and reporting
- Automatic restart on crash

## Architecture

```
PrivarionAgent/
├── main.swift                     # Agent entry point and CLI
├── PermissionManager/             # Permission handling (future)
├── ConfigurationCoordinator/      # Configuration management (future)
└── README.md
```

## Key Components

### PrivarionAgent
Main agent class coordinating all components:
- `start()` - Initialize all protection components
- `stop()` - Gracefully shutdown all components
- `restart()` - Restart the agent
- `getStatus()` - Get comprehensive status

### AgentStatus
Status snapshot structure:
- `isRunning` - Agent running state
- `systemExtensionStatus` - System Extension status
- `endpointSecurityActive` - Endpoint Security state
- `networkExtensionActive` - Network Extension state
- `activeVMCount` - Number of running VMs
- `permissions` - Permission status map

### PermissionType
Required permission types:
- `systemExtension` - System Extension approval
- `fullDiskAccess` - Full Disk Access for monitoring
- `networkExtension` - Network Extension approval

### PermissionStatus
Permission states:
- `granted` - Permission granted
- `denied` - Permission denied
- `notDetermined` - Permission not yet requested

## Launch Agent Configuration

The agent is configured as a Launch Agent with:
- **Label**: `com.privarion.agent`
- **RunAtLoad**: `true` (automatic startup)
- **KeepAlive**: `true` (automatic restart on crash)
- **Logs**: `/var/log/privarion/agent.log`

Plist location: `~/Library/LaunchAgents/com.privarion.agent.plist`

## Requirements

- macOS 13.0+
- Swift 5.9+
- User approval for System Extension
- Full Disk Access permission
- Network Extension approval

## Entitlements

See `Entitlements/PrivarionAgent.entitlements`:
- `com.apple.security.app-sandbox`
- `com.apple.security.network.client`
- `com.apple.security.network.server`
- `com.apple.security.files.user-selected.read-write`

## Dependencies

- PrivarionCore (existing privacy engine)
- PrivarionSystemExtension (system extension management)
- PrivarionNetworkExtension (network filtering)
- PrivarionVM (VM management)
- PrivarionSharedModels (shared data structures)
- swift-log (logging)
- swift-argument-parser (CLI interface)

## Usage

### As Launch Agent (Automatic)

The agent starts automatically at login when installed:

```bash
# Install Launch Agent
cp com.privarion.agent.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.privarion.agent.plist

# Check status
launchctl list | grep privarion
```

### Manual Execution

```bash
# Run agent manually
swift run PrivarionAgent

# Or from built binary
./PrivarionAgent
```

### Programmatic Usage

```swift
import PrivarionAgent

let agent = PrivarionAgent()

// Start protection
try await agent.start()

// Get status
let status = await agent.getStatus()
print("System Extension: \(status.systemExtensionStatus)")
print("Endpoint Security: \(status.endpointSecurityActive)")
print("Network Extension: \(status.networkExtensionActive)")
print("Active VMs: \(status.activeVMCount)")

// Stop protection
try await agent.stop()
```

## Startup Sequence

1. Agent starts at login (Launch Agent)
2. Check all required permissions
3. Verify System Extension status
4. Initialize Endpoint Security Framework
5. Start Network Extension
6. Load configuration
7. Begin monitoring and protection

## Error Handling

- **Permission Denied**: Prompt user to grant permissions
- **Component Failure**: Continue with reduced functionality
- **Crash**: Automatic restart within 5 seconds (Launch Agent)
- **Configuration Error**: Use last known good configuration

## Logging

Logs are written to:
- **Standard Output**: `/var/log/privarion/agent.log`
- **Standard Error**: `/var/log/privarion/agent-error.log`

Log rotation: Daily with 7-day retention

## Related Requirements

- Requirement 6: Launch Agent for Persistent Protection
- Requirement 14: User Permission Management
- Requirement 17: Logging and Monitoring
- Requirement 19: Error Handling and Recovery
