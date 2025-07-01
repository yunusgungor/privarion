# PATTERN-2025-032: Multi-Layer Error Handling in CLI Applications

## Context
When building CLI applications that integrate with domain-specific core libraries, error handling becomes complex as multiple error types need to be unified into a coherent user experience while maintaining technical accuracy.

## Problem
- Domain errors from core business logic need to be translated to user-friendly CLI messages
- CLI framework errors (argument parsing, validation) need consistent handling
- Technical stack traces should be hidden from end users while preserving debugging information
- Exit codes and status propagation need standardization across command hierarchy

## Solution

### Error Type Hierarchy
```swift
// Domain-specific errors from core
public enum DomainError: Error {
    case businessLogicError(String)
    case resourceNotFound(String)
    case operationFailed(String)
}

// CLI-specific errors for user interactions
enum CLIError: Error {
    case invalidInput(String)
    case missingConfiguration
    case operationCancelled
}

// Unified error handling protocol
protocol UserPresentableError {
    var userMessage: String { get }
    var exitCode: Int32 { get }
    var shouldShowDetails: Bool { get }
}
```

### Error Bridge Implementation
```swift
extension DomainError: UserPresentableError {
    var userMessage: String {
        switch self {
        case .businessLogicError(let message):
            return "Operation failed: \(message)"
        case .resourceNotFound(let resource):
            return "Resource not found: \(resource)"
        case .operationFailed(let operation):
            return "Failed to \(operation)"
        }
    }
    
    var exitCode: Int32 {
        switch self {
        case .businessLogicError: return 1
        case .resourceNotFound: return 2
        case .operationFailed: return 3
        }
    }
    
    var shouldShowDetails: Bool { return false }
}
```

### Unified Error Handler
```swift
func handleError(_ error: Error) -> Never {
    if let presentableError = error as? UserPresentableError {
        print("Error: \(presentableError.userMessage)")
        if presentableError.shouldShowDetails {
            print("Details: \(error)")
        }
        Foundation.exit(presentableError.exitCode)
    } else {
        print("Unexpected error: \(error.localizedDescription)")
        Foundation.exit(99)
    }
}
```

## Implementation Details

### Command-Level Error Handling
- Wrap async operations in do-catch blocks
- Convert domain errors to CLI-appropriate messages
- Maintain error context through command hierarchy
- Provide verbose mode for debugging

### Exit Code Standardization
- 0: Success
- 1-10: Business logic errors
- 11-20: Input validation errors
- 21-30: System/resource errors
- 99: Unexpected errors

### Logging Integration
- Log technical details for debugging
- Present simplified messages to users
- Support verbose flag for enhanced error information

## Benefits
- Consistent error experience across CLI commands
- Clear separation between technical and user-facing errors
- Maintainable error handling architecture
- Enhanced debugging capabilities while protecting user experience

## Trade-offs
- Additional abstraction layer complexity
- Need for comprehensive error mapping
- Potential for error information loss in translation

## When to Use
- CLI applications with complex domain logic
- Multi-layer architectures with different error types
- Applications requiring both user-friendly and technical error modes
- Systems with standardized exit code requirements

## Implementation Effort
**Low** - Standard error handling patterns with protocol extensions

## Related Patterns
- PATTERN-2025-030: Swift CLI Async Integration
- PATTERN-2025-031: Progressive API Compatibility
- Command Pattern for CLI architecture
- Error Monad pattern for functional error handling

## Real-world Usage
Applied in STORY-2025-008 Phase 2b CLI integration where domain errors from MacAddressSpoofingManager needed to be presented as user-friendly CLI messages while maintaining technical accuracy and providing appropriate exit codes.

---
*Pattern extracted from Phase 2b CLI Integration implementation - 2025-01-27*
