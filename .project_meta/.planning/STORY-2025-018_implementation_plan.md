# STORY-2025-018 Implementation Planning Session
## TCC Permission Authorization Engine & Dynamic Security Policies

**Planning Session Date:** 23 Temmuz 2025  
**Story ID:** STORY-2025-018  
**Estimated Duration:** 16 hours  
**Complexity Score:** 7.5/10

---

## 🔬 Context7 Research Integration

### Spring Security Authorization Patterns Applied to macOS TCC

Based on Context7 research from Spring Security samples, the following patterns will be adapted for macOS TCC management:

#### 1. **Resource-Based Authorization Pattern**
```swift
// Spring Security equivalent: @PreAuthorize("hasPermission(#resource, 'READ')")
actor PermissionPolicyEngine {
    func evaluatePermission(
        for application: String,
        resource: TCCService,
        requestType: PermissionRequestType
    ) async -> PermissionDecision
}
```

#### 2. **Scope-Based Permission Validation**
```swift
// Spring Security equivalent: JWT scope validation
struct PermissionScope {
    let service: TCCService
    let duration: TimeInterval?
    let restrictions: [String: Any]
}
```

#### 3. **Policy-Driven Authorization**
```swift
// Spring Security equivalent: Security configuration DSL
struct TCCPermissionPolicy {
    let applicationPattern: String
    let service: TCCService
    let action: PermissionAction // deny, allow, temporary
    let conditions: [PolicyCondition]
}
```

---

## 🏗️ Technical Architecture

### Phase 1: TCC Database Access (6 hours)

#### TCCPermissionEngine.swift
```swift
import SQLite3
import Foundation

@available(macOS 12.0, *)
actor TCCPermissionEngine {
    private let databasePath = "/Library/Application Support/com.apple.TCC/TCC.db"
    private var database: OpaquePointer?
    
    // Core TCC database access functionality
    func connect() async throws -> Void
    func enumeratePermissions() async throws -> [TCCPermission]
    func getPermissionStatus(for bundleId: String, service: TCCService) async throws -> TCCPermissionStatus
    func monitorPermissionChanges() -> AsyncStream<TCCPermissionChange>
}

struct TCCPermission {
    let service: TCCService
    let bundleId: String
    let status: TCCPermissionStatus
    let lastModified: Date
    let promptCount: Int
}

enum TCCService: String, CaseIterable {
    case camera = "kTCCServiceCamera"
    case microphone = "kTCCServiceMicrophone"
    case location = "kTCCServiceLocationManager"
    case contacts = "kTCCServiceAddressBook"
    case calendar = "kTCCServiceCalendar"
    case photos = "kTCCServicePhotos"
    case fullDiskAccess = "kTCCServiceSystemPolicyAllFiles"
    case accessibility = "kTCCServiceAccessibility"
    case screenRecording = "kTCCServiceScreenCapture"
}

enum TCCPermissionStatus: Int {
    case denied = 0
    case unknown = 1
    case allowed = 2
    case limited = 3
}
```

### Phase 2: Permission Policy Engine Integration (6 hours)

#### PermissionPolicyEngine.swift
```swift
import Foundation

@available(macOS 12.0, *)
actor PermissionPolicyEngine {
    private let securityPolicyEngine: SecurityPolicyEngine
    private let tccEngine: TCCPermissionEngine
    private var permissionPolicies: [TCCPermissionPolicy] = []
    
    init(securityPolicyEngine: SecurityPolicyEngine, tccEngine: TCCPermissionEngine) {
        self.securityPolicyEngine = securityPolicyEngine
        self.tccEngine = tccEngine
    }
    
    // Integration with existing SecurityPolicyEngine
    func evaluatePermissionRequest(
        bundleId: String,
        service: TCCService,
        requestContext: PermissionRequestContext
    ) async throws -> PermissionDecision {
        
        // First check TCC database current status
        let currentStatus = try await tccEngine.getPermissionStatus(
            for: bundleId, 
            service: service
        )
        
        // Then evaluate against security policies
        let securityDecision = try await securityPolicyEngine.evaluatePolicy(
            for: .permissionRequest(bundleId: bundleId, service: service),
            context: requestContext
        )
        
        // Apply permission-specific policies
        let permissionDecision = evaluatePermissionPolicies(
            bundleId: bundleId,
            service: service,
            currentStatus: currentStatus,
            securityDecision: securityDecision
        )
        
        return permissionDecision
    }
    
    private func evaluatePermissionPolicies(
        bundleId: String,
        service: TCCService,
        currentStatus: TCCPermissionStatus,
        securityDecision: SecurityPolicyDecision
    ) -> PermissionDecision {
        // Policy evaluation logic
    }
}

struct PermissionDecision {
    let action: PermissionAction
    let reason: String
    let duration: TimeInterval?
    let restrictions: [String: Any]
    let logLevel: LogLevel
}

enum PermissionAction {
    case deny
    case allow
    case allowTemporary(duration: TimeInterval)
    case allowWithRestrictions([String: Any])
}

struct TCCPermissionPolicy {
    let id: UUID
    let name: String
    let applicationPattern: String // Regex or wildcard
    let service: TCCService
    let action: PermissionAction
    let conditions: [PolicyCondition]
    let priority: Int
    let enabled: Bool
}
```

### Phase 3: Temporary Permission Management (4 hours)

#### TemporaryPermissionManager.swift
```swift
import Foundation

@available(macOS 12.0, *)
actor TemporaryPermissionManager {
    private var activeGrants: [UUID: TemporaryPermissionGrant] = [:]
    private var expirationTimer: Timer?
    
    func grantTemporaryPermission(
        bundleId: String,
        service: TCCService,
        duration: TimeInterval,
        restrictions: [String: Any] = [:]
    ) async throws -> UUID {
        
        let grantId = UUID()
        let grant = TemporaryPermissionGrant(
            id: grantId,
            bundleId: bundleId,
            service: service,
            grantedAt: Date(),
            expiresAt: Date().addingTimeInterval(duration),
            restrictions: restrictions
        )
        
        activeGrants[grantId] = grant
        scheduleExpiration(for: grant)
        
        // Log the temporary grant
        Logger.tcc.info("Granted temporary \(service.rawValue) access to \(bundleId) for \(duration)s")
        
        return grantId
    }
    
    func revokeTemporaryPermission(_ grantId: UUID) async {
        guard let grant = activeGrants.removeValue(forKey: grantId) else { return }
        
        // Cleanup and logging
        Logger.tcc.info("Revoked temporary \(grant.service.rawValue) access for \(grant.bundleId)")
    }
    
    func checkPermissionValidity(
        bundleId: String, 
        service: TCCService
    ) async -> TemporaryPermissionStatus {
        // Check if bundle has active temporary permission
    }
    
    private func scheduleExpiration(for grant: TemporaryPermissionGrant) {
        // Timer-based automatic cleanup
    }
}

struct TemporaryPermissionGrant {
    let id: UUID
    let bundleId: String
    let service: TCCService
    let grantedAt: Date
    let expiresAt: Date
    let restrictions: [String: Any]
}

enum TemporaryPermissionStatus {
    case active(grant: TemporaryPermissionGrant)
    case expired
    case notGranted
}
```

---

## 🧪 Testing Strategy

### Unit Tests
- TCCPermissionEngine database access tests
- PermissionPolicyEngine policy evaluation tests
- TemporaryPermissionManager grant lifecycle tests
- Integration tests with SecurityPolicyEngine

### Mock TCC Scenarios
```swift
class MockTCCDatabase {
    // Simulate various TCC.db states
    // Test permission enumeration
    // Test permission status changes
}

class TCCPermissionEngineTests: XCTestCase {
    func testPermissionEnumeration() async throws {
        // Test complete TCC.db scan performance (<50ms)
    }
    
    func testPermissionStatusLookup() async throws {
        // Test individual permission queries
    }
    
    func testPermissionChangeMonitoring() async throws {
        // Test real-time permission change detection
    }
}

class PermissionPolicyEngineTests: XCTestCase {
    func testPolicyEvaluation() async throws {
        // Test policy matching and decision logic
    }
    
    func testSecurityPolicyEngineIntegration() async throws {
        // Test unified policy evaluation
    }
}
```

---

## 🔧 CLI Integration

### New Commands
```bash
# Permission management
privacyctl tcc list --service camera
privacyctl tcc status --app "Zoom.app" 
privacyctl tcc deny --app "Malware.app" --service microphone
privacyctl tcc allow-temporary --app "Meeting.app" --service camera --duration 1h

# Policy management
privacyctl tcc policy create --name "deny-unknown-camera" --pattern "*.app" --service camera --action deny
privacyctl tcc policy list
privacyctl tcc policy enable --name "deny-unknown-camera"

# Monitoring
privacyctl tcc monitor --live
privacyctl tcc audit --since "1 hour ago"
```

---

## 📊 Success Metrics

1. **Permission enumeration performance**: <50ms for complete TCC.db scan
2. **Policy evaluation accuracy**: 100% consistent policy enforcement  
3. **Temporary permission reliability**: 99.9% automatic cleanup success
4. **Integration test coverage**: 95% with SecurityPolicyEngine
5. **Zero permission leaks**: All temporary grants must expire correctly

---

## 🔒 Security Considerations

1. **TCC.db Access**: Requires Full Disk Access entitlement
2. **Read-Only First**: Start with read-only TCC access, manipulation via system APIs
3. **Privacy Protection**: No sensitive data logging or storage
4. **Privilege Escalation**: Minimal additional privileges beyond existing requirements

---

## 🚀 Implementation Timeline

- **Day 1-2**: Phase 1 - TCC Database Access (6 hours)
- **Day 3-4**: Phase 2 - Policy Engine Integration (6 hours)  
- **Day 5**: Phase 3 - Temporary Permissions & CLI (4 hours)

**Total Estimated Duration**: 16 hours across 5 working days
