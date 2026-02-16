# PrivarionCoreTests

Unit tests for core library - 32 test files.

## OVERVIEW

Comprehensive XCTest suite for PrivarionCore. Tests cover identity spoofing, network filtering, MAC addresses, security policies, anomaly detection, and more.

## STRUCTURE

Flat directory - 32 test files mirroring core structure.

## WHERE TO LOOK

| Component | Test File | Lines | Notes |
|-----------|-----------|-------|-------|
| Anomaly Detection | `AnomalyDetectionEngineTests.swift` | 624 | Complex ML-based tests |
| Security Policy | `SecurityPolicyEngineTests.swift` | 592 | Policy enforcement tests |
| Security Profiles | `SecurityProfileManagerTests.swift` | 559 | Profile CRUD tests |
| Audit Logging | `AuditLoggerTests.swift` | 547 | Logging system tests |
| MAC Addresses | `MacAddressSpoofingManagerTests.swift` | ~500 | MAC manipulation tests |
| Network Filter | `NetworkFilteringManagerTests.swift` | ~450 | Traffic filtering tests |
| Identity Spoof | `IdentitySpoofingManagerTests.swift` | ~400 | Hardware ID tests |
| Sandbox | `SandboxManagerTests.swift` | ~350 | Sandbox config tests |
| DNS Proxy | `DNSProxyServerTests.swift` | ~300 | DNS tests |
| TCC Permissions | `TCCPermissionEngineTests.swift` | ~300 | Permission tests |

## CONVENTIONS

- XCTest with `@testable import PrivarionCore`
- Naming: `test<Operation><ExpectedResult>`
- Use `setUp()` / `tearDown()` for lifecycle
- Mock interactors: `MockSystemInteractor`, `MockModuleInteractor`, `MockProfileInteractor`
- Async tests with `async` / `await`

## TESTING PATTERNS

```swift
func testOperationSuccess() async throws {
    // Given
    let manager = TestableManager()
    
    // When
    let result = try await manager.operation()
    
    // Then
    XCTAssertTrue(result)
}
```

## ANTI-PATTERNS

- Some tests have TODO comments (disabled)
- Performance baselines may need updating
- A few tests use force unwraps (should use XCTAssertNotNil)
