# SecurityEventHandler Protocol

## Overview

The `SecurityEventHandler` protocol provides an extensible mechanism for processing security events in the Privarion System Extension. It allows custom handlers to be registered with the `SecurityEventProcessor` to implement custom security policies, logging, monitoring, and enforcement logic.

**Requirements:** 2.5

## Protocol Definition

```swift
public protocol SecurityEventHandler {
    /// Check if handler can process this event type
    func canHandle(_ eventType: SecurityEventType) -> Bool
    
    /// Handle process execution event
    func handleProcessExecution(_ event: ProcessExecutionEvent) async -> ESAuthResult
    
    /// Handle file access event
    func handleFileAccess(_ event: FileAccessEvent) async -> ESAuthResult
    
    /// Handle network event
    func handleNetworkEvent(_ event: NetworkEvent) async -> ESAuthResult
}
```

## Key Features

- **Pluggable Architecture**: Register multiple handlers with the SecurityEventProcessor
- **Event Filtering**: Handlers can specify which event types they process via `canHandle(_:)`
- **Async Support**: All handler methods support async/await for non-blocking operations
- **Authorization Control**: Handlers return `ESAuthResult` to allow, deny, or modify events
- **Composability**: Multiple handlers can be combined using `CompositeSecurityEventHandler`

## Event Types

- `.processExecution` - Process launch events (ES_EVENT_TYPE_AUTH_EXEC)
- `.fileAccess` - File access events (ES_EVENT_TYPE_AUTH_OPEN)
- `.networkConnection` - Network connection events
- `.dnsQuery` - DNS query events

## Authorization Results

```swift
public enum ESAuthResult {
    case allow                      // Allow the operation
    case deny                       // Deny the operation
    case allowWithModification(Data) // Allow with modified data
}
```

## Example Implementations

### 1. Logging Handler

Logs all security events for audit purposes:

```swift
let loggingHandler = LoggingSecurityEventHandler()
await processor.registerHandler(loggingHandler)
```

**Use Case**: Comprehensive audit logging for compliance and forensics

### 2. Suspicious Path Blocker

Blocks execution of binaries from suspicious paths (e.g., /tmp):

```swift
let pathBlocker = SuspiciousPathBlocker(suspiciousPaths: ["/tmp", "/var/tmp"])
await processor.registerHandler(pathBlocker)
```

**Use Case**: Prevent execution of potentially malicious binaries from temporary directories

### 3. Sensitive File Access Monitor

Monitors and logs access to sensitive files (SSH keys, passwords, etc.):

```swift
let fileMonitor = SensitiveFileAccessMonitor(
    sensitivePatterns: [".ssh/", ".aws/", "password", "secret"]
)
await processor.registerHandler(fileMonitor)
```

**Use Case**: Detect unauthorized access to sensitive credentials and configuration files

### 4. Rate Limiting Handler

Prevents fork bombs by rate-limiting process executions:

```swift
let rateLimiter = RateLimitingHandler(maxExecutionsPerSecond: 100)
await processor.registerHandler(rateLimiter)
```

**Use Case**: Protect against denial-of-service attacks via excessive process creation

### 5. Composite Handler

Combines multiple handlers into a single handler:

```swift
let composite = CompositeSecurityEventHandler(handlers: [
    loggingHandler,
    pathBlocker,
    fileMonitor,
    rateLimiter
])
await processor.registerHandler(composite)
```

**Use Case**: Apply multiple security policies in a single registration

## Creating Custom Handlers

### Basic Handler Template

```swift
public class MyCustomHandler: SecurityEventHandler {
    private let logger: Logger
    
    public init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "com.privarion.handlers.custom")
    }
    
    public func canHandle(_ eventType: SecurityEventType) -> Bool {
        // Return true for event types this handler processes
        return eventType == .processExecution
    }
    
    public func handleProcessExecution(_ event: ProcessExecutionEvent) async -> ESAuthResult {
        // Implement custom logic
        logger.info("Processing: \(event.executablePath)")
        
        // Return authorization decision
        return .allow
    }
    
    public func handleFileAccess(_ event: FileAccessEvent) async -> ESAuthResult {
        return .allow
    }
    
    public func handleNetworkEvent(_ event: NetworkEvent) async -> ESAuthResult {
        return .allow
    }
}
```

### Handler Best Practices

1. **Performance**: Keep handler logic fast (<100ms) to avoid system slowdown
2. **Error Handling**: Handle errors gracefully and log failures
3. **Selective Processing**: Use `canHandle(_:)` to filter irrelevant events
4. **Logging**: Use structured logging for debugging and audit trails
5. **Thread Safety**: Handlers may be called concurrently; ensure thread safety
6. **Default Allow**: When in doubt, return `.allow` to avoid breaking system functionality

## Registration

Register handlers with the SecurityEventProcessor:

```swift
let policyEngine = ProtectionPolicyEngine()
let processor = SecurityEventProcessor(policyEngine: policyEngine)

// Register individual handlers
await processor.registerHandler(loggingHandler)
await processor.registerHandler(pathBlocker)
await processor.registerHandler(fileMonitor)
```

## Handler Execution Order

Handlers are executed in registration order. If any handler returns `.deny`, the operation is denied immediately without calling subsequent handlers.

```swift
// Handler 1 (logging) - always allows
// Handler 2 (path blocker) - may deny
// Handler 3 (file monitor) - only called if handler 2 allows
```

## Event Data Structures

### ProcessExecutionEvent

```swift
public struct ProcessExecutionEvent {
    let processID: pid_t
    let executablePath: String
    let arguments: [String]
    let environment: [String: String]
    let parentProcessID: pid_t
}
```

### FileAccessEvent

```swift
public struct FileAccessEvent {
    let processID: pid_t
    let filePath: String
    let accessType: FileAccessType // .read, .write, .execute
}
```

### NetworkEvent

```swift
public struct NetworkEvent {
    let id: UUID
    let timestamp: Date
    let processID: pid_t
    let sourceIP: String
    let sourcePort: Int
    let destinationIP: String
    let destinationPort: Int
    let protocol: NetworkProtocol // .tcp, .udp, .icmp
    let domain: String?
}
```

## Testing

Example handlers include comprehensive unit tests demonstrating:

- Handler registration and lifecycle
- Event filtering via `canHandle(_:)`
- Authorization decisions (allow/deny)
- Custom configuration and patterns
- Composite handler behavior

Run tests:

```bash
swift test --filter ExampleSecurityEventHandlersTests
```

## Integration with Protection Policies

Handlers work alongside the `ProtectionPolicyEngine`:

1. **Policy Engine** evaluates application-level policies (protection level, VM isolation)
2. **Event Handlers** apply custom security logic (path blocking, rate limiting)
3. **Combined Result** determines final authorization decision

Both systems can deny operations independently, providing defense in depth.

## Future Extensions

Potential handler implementations:

- **Malware Scanner**: Scan executables before allowing execution
- **Behavioral Analysis**: Detect anomalous process behavior patterns
- **Network Firewall**: Block connections to malicious IPs/domains
- **Data Loss Prevention**: Prevent sensitive data exfiltration
- **Compliance Enforcer**: Enforce organizational security policies
- **Machine Learning**: Use ML models to detect threats

## See Also

- `SecurityEventProcessor.swift` - Main event processing logic
- `ExampleSecurityEventHandlers.swift` - Example implementations
- `ExampleSecurityEventHandlersTests.swift` - Comprehensive test suite
- `ProtectionPolicyEngine.swift` - Application-level policy enforcement
