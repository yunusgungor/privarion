# PrivacyCtl

CLI tool using Swift ArgumentParser.

## OVERVIEW

Terminal-based privacy management. 14 commands in single 3053-line main.swift.

## ENTRY POINT

- `Sources/PrivacyCtl/main.swift` (3053 lines) - All commands inline
- `PrivarionGUIApp.swift` - @main for GUI (separate target)

## COMMAND STRUCTURE

```
PrivacyCtl (root) - AsyncParsableCommand
├── start, stop, status           # System control
├── config (list/get/set/reset)   # Configuration
├── profile (list/switch/create/delete)  # Profile management
├── logs                          # Log viewing
├── inject                        # DYLD injection
├── hook                          # Syscall hooks
├── identity                      # Identity spoofing
├── mac-address                   # MAC operations
├── network                       # Network filtering
├── analytics                     # System analytics
└── permission                    # TCC permissions
```

## FILES

| File | Lines | Purpose |
|------|-------|---------|
| `main.swift` | 3053 | All 14 commands inline - anti-pattern |
| `Commands/MacAddressCommands.swift` | 774 | MAC address subcommands |
| `Commands/NetworkCommands.swift` | 708 | Network filtering subcommands |
| `Commands/PermissionCommands.swift` | 445 | Permission subcommands |
| `Commands/AnalyticsCommands.swift` | 552 | Analytics subcommands |

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| System control | `main.swift` | start, stop, status commands |
| Configuration | `main.swift` | config list/get/set/reset |
| Profiles | `main.swift` | profile management |
| MAC addresses | `Commands/MacAddressCommands.swift` | 774 lines |
| Network | `Commands/NetworkCommands.swift` | 708 lines |
| Permissions | `Commands/PermissionCommands.swift` | 445 lines |
| Analytics | `Commands/AnalyticsCommands.swift` | 552 lines |

## CONVENTIONS

- Swift ArgumentParser (`AsyncParsableCommand`)
- Async commands via `async throws`
- Commands in single file (non-standard)

## ANTI-PATTERNS

- **Monolithic**: 3053-line main.swift violates single responsibility
- **No modularity**: All commands in one file
- **Silent errors**: Multiple `try?` without handling (44+ instances in codebase)
- **Force unwraps**: 26 instances, many in critical paths
