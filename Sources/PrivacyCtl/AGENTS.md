# PrivacyCtl

CLI tool using Swift ArgumentParser.

## OVERVIEW

121KB main.swift with all 14 commands inline. Commands subdirectory for some subcommands.

## ENTRY POINT

- `Sources/PrivacyCtl/main.swift` (3053 lines)

## COMMAND STRUCTURE

```
PrivacyCtl (root)
├── start, stop, status
├── config (list/get/set/reset)
├── profile (list/switch/create/delete)
├── logs, inject, hook
├── identity, mac-address
├── network (NetworkCommands.swift)
├── analytics (AnalyticsCommands.swift)
└── permission (PermissionCommands.swift)
```

## FILES

| File | Lines | Purpose |
|------|-------|---------|
| `main.swift` | 3053 | All commands inline |
| `Commands/MacAddressCommands.swift` | 774 | MAC operations |
| `Commands/NetworkCommands.swift` | 708 | Network filtering |
| `Commands/PermissionCommands.swift` | 445 | Permission mgmt |
| `Commands/AnalyticsCommands.swift` | 552 | Analytics |

## CONVENTIONS

- Uses Swift ArgumentParser (`AsyncParsableCommand`)
- All commands in single file (non-standard)
- Async commands via `async throws`

## ANTI-PATTERNS

- Large monolithic main.swift (consider splitting)
- No command modularity
