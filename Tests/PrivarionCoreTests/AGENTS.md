# PrivarionCoreTests

Unit tests for core library - 32 test files.

## STRUCTURE

```
Tests/PrivarionCoreTests/
├── IdentitySpoofingManagerTests.swift
├── MacAddressSpoofingManagerTests.swift
├── NetworkFilteringManagerTests.swift
├── SecurityPolicyEngineTests.swift
├── AnomalyDetectionEngineTests.swift
└── ... (27 more)
```

## TESTING PATTERNS

- XCTest with `@testable import`
- Mock interactors for system dependencies
- Async testing with `async`/`await`
- Performance benchmarks via `PerformanceBenchmark.swift`

## KEY TEST FILES

| File | Tests |
|------|-------|
| `AnomalyDetectionEngineTests.swift` | 624 lines |
| `SecurityPolicyEngineTests.swift` | 592 lines |
| `SecurityProfileManagerTests.swift` | 559 lines |
| `AuditLoggerTests.swift` | 547 lines |

## CONVENTIONS

- Test naming: `test<Operation><ExpectedResult>`
- Uses `setUp()`/`tearDown()` lifecycle
- Mocks: MockSystemInteractor, MockModuleInteractor, MockProfileInteractor

## ANTI-PATTERNS

- Some tests disabled (TODO references)
- Performance test baselines may need updating
