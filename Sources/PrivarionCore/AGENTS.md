# PrivarionCore

Central privacy engine - 46 Swift files in flat structure.

## OVERVIEW

Core library handling all privacy protection logic: identity spoofing, network filtering, MAC addresses, permissions, security policies, syscalls, sandboxing.

## KEY FILES

| File | Purpose |
|------|---------|
| `IdentitySpoofingManager.swift` | Hardware ID spoofing |
| `MacAddressSpoofingManager.swift` | MAC address manipulation |
| `NetworkFilteringManager.swift` | Traffic filtering, blocklists |
| `SyscallHookManager.swift` | System call interception |
| `TCCPermissionEngine.swift` | macOS TCC permissions |
| `SandboxManager.swift` | Sandbox configuration |
| `SecurityProfileManager.swift` | Privacy profiles |
| `DNSProxyServer.swift` | DNS proxy implementation |

## CONVENTIONS

- Flat directory (no subdirs)
- All managers are `@unchecked Sendable`
- Use `DispatchQueue` for thread safety
- Custom error types via `PrivarionError`
- Async/await for I/O operations

## ANTI-PATTERNS

- DON'T use `try?` silently - handle errors explicitly
- DON'T use force unwrap in managers
- AVOID large functions - keep under 50 lines
