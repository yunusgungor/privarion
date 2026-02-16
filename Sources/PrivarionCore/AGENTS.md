# PrivarionCore

Central privacy engine - 46 Swift files handling privacy protection.

## OVERVIEW

Core library for identity spoofing, network filtering, MAC addresses, permissions, security policies, syscalls, sandboxing.

## STRUCTURE

Flat directory - all 46 files in single folder.

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Hardware ID spoofing | `IdentitySpoofingManager.swift` | UUID, serial number manipulation |
| MAC addresses | `MacAddressSpoofingManager.swift` | Network interface spoofing |
| Network filtering | `NetworkFilteringManager.swift` | Traffic filtering, blocklists |
| DNS proxy | `DNSProxyServer.swift` | SwiftNIO-based DNS proxy |
| Syscall hooks | `SyscallHookManager.swift` | C interop for system calls |
| TCC permissions | `TCCPermissionEngine.swift` | macOS permission management |
| Sandbox | `SandboxManager.swift` | Sandbox configuration |
| Security profiles | `SecurityProfileManager.swift` | Privacy profile logic |
| Threat detection | `ThreatDetectionManager.swift` | 701 lines |
| Anomaly detection | `AnomalyDetectionEngine.swift` | 1616 lines |
| Audit logging | `AuditLogger.swift` | 1659 lines |

## CONVENTIONS

- Flat structure (no subdirectories)
- Managers use `@unchecked Sendable`
- `DispatchQueue` for thread safety
- `PrivarionError` enum for errors
- Async/await for I/O

## ANTI-PATTERNS

- **90 instances** of `try?` without error handling - AVOID adding more
- DON'T force unwrap (`!`)
- AVOID functions >50 lines

## LARGE FILES (Review Needed)

| File | Lines | Issue |
|------|-------|-------|
| `AuditLogger.swift` | 1659 | Too large |
| `AnomalyDetectionEngine.swift` | 1616 | Too large |
| `SecurityProfileManager.swift` | 1181 | Too large |
