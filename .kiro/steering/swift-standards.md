---
inclusion: fileMatch
fileMatchPattern: 'Package.swift|*.swift'
---

# Swift Development Standards

## SwiftUI Standards (GUI)

### View Structure
```swift
// Preferred: Clear separation
struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationStack {
            content
        }
    }
    
    // MARK: - Private
    
    @ViewBuilder
    private var content: some View {
        // Implementation
    }
}
```

### ViewModel Guidelines
- Use `@Observable` (iOS 17+) or `@StateObject` for view state
- Keep business logic in separate managers/services
- Use `@MainActor` for UI-bound operations
- Expose only necessary state to views

### SwiftUI Best Practices
- Use `@ViewBuilder` for conditional content
- Prefer value types (structs) over reference types
- Use `Equatable` conformance for optimal redraws
- Implement proper accessibility labels

## Core Library Standards

### Manager Pattern
```swift
public final class IdentitySpoofingManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.privarion.identity", qos: .userInitiated)
    
    public func enable() async throws {
        // Implementation
    }
}
```

### Error Handling
- Use custom error types conforming to `Error` and `LocalizedError`
- Provide meaningful error messages
- Log errors with context

### Concurrency
- Prefer Swift Concurrency (async/await, actors) over callbacks
- Use `Task` for background operations
- Mark classes as `@unchecked Sendable` when thread-safe

## CLI Standards

### Argument Parser Usage
```swift
import ArgumentParser

struct SpoofCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Enable identity spoofing",
        discussion: "Spoofs hardware identifiers to prevent fingerprinting"
    )
    
    @Flag(name: .shortAndLong, help: "Spoof all identifiers")
    var all: Bool
    
    func run() async throws {
        // Implementation
    }
}
```

### Output Formatting
- Use `consoleIO` for structured output
- Support `--json` flag for machine-readable output
- Use ANSI colors sparingly (respect `--no-color` flag)

## Testing Standards

### Unit Tests
```swift
@testable import PrivarionCore

final class IdentitySpoofingManagerTests: XCTestCase {
    func testEnableSpoofing() async throws {
        let manager = IdentitySpoofingManager()
        try await manager.enable()
        XCTAssertTrue(manager.isEnabled)
    }
}
```

### Mocking
- Use protocols for dependency injection
- Create `MockXxx` classes for testing
- Avoid testing private implementation details

## Performance Considerations

### Memory Management
- Use `[weak self]` in closures
- Prefer value types in SwiftUI views
- Properly cancel Tasks when views disappear

### Lazy Operations
- Use `LazyVStack` for long lists
- Defer heavy computations
- Cache expensive operations
