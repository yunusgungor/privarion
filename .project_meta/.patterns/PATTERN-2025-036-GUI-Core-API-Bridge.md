# PATTERN-2025-036: GUI-Core API Bridge Pattern

## Pattern Context
**Created**: 2025-07-01  
**Story**: STORY-2025-008 Phase 2c - GUI Integration  
**Category**: Architecture Integration  
**Complexity**: Advanced  

## Problem
GUI applications need to integrate with core business logic APIs that may have different paradigms (async/sync, error handling, data formats). Direct coupling leads to tight dependencies, difficult testing, and poor separation of concerns.

## Solution

### Core Bridge Architecture
```swift
// Core API (Business Logic Layer)
class CoreAPI {
    static func performOperation() async throws -> CoreResult {
        // Complex business logic
    }
}

// GUI State Bridge
@MainActor
class GUIStateBridge: ObservableObject {
    @Published var uiState: UIState = .idle
    @Published var errorMessage: String?
    
    private let coreAPI: CoreAPI
    
    func executeOperation() async {
        uiState = .loading
        errorMessage = nil
        
        do {
            let result = try await coreAPI.performOperation()
            uiState = .success(result.toUIModel())
        } catch {
            uiState = .error
            errorMessage = error.localizedDescription
        }
    }
}
```

### Data Transformation Layer
```swift
// Core Domain Model
struct CoreNetworkInterface {
    let identifier: String
    let macAddress: String
    let isActive: Bool
}

// GUI Model
struct UINetworkInterface: Hashable {
    let id: String
    let displayName: String
    let macAddress: String
    let status: InterfaceStatus
    
    init(from core: CoreNetworkInterface) {
        self.id = core.identifier
        self.displayName = core.identifier.uppercased()
        self.macAddress = core.macAddress
        self.status = core.isActive ? .active : .inactive
    }
}
```

## Key Components

### 1. State Translation Layer
- Converts core API states to GUI-appropriate states
- Handles loading, success, error state mapping
- Provides UI-specific data formatting

### 2. Error Handling Bridge
- Translates technical errors to user-friendly messages
- Maintains error context for debugging
- Provides recovery action suggestions

### 3. Async-to-Reactive Bridge
- Converts async/await calls to @Published reactive streams
- Manages operation lifecycle in GUI context
- Handles cancellation and cleanup

### 4. Data Model Transformation
- Maps core domain models to UI models
- Adds UI-specific properties (display formatting, colors, etc.)
- Maintains model consistency across layers

## Implementation Example

```swift
// From Privarion MacAddressState.swift
@MainActor
class MacAddressState: ObservableObject {
    @Published var interfaces: [NetworkInterface] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let coreManager = MacAddressSpoofingManager.shared
    
    // Bridge async core API to reactive GUI state
    func loadInterfaces() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Core API call
            let coreInterfaces = try await coreManager.getAvailableInterfaces()
            
            // Transform to GUI models
            interfaces = coreInterfaces.map { interface in
                NetworkInterface(
                    id: interface.identifier,
                    name: interface.displayName,
                    macAddress: interface.macAddress,
                    isActive: interface.isActive
                )
            }
        } catch {
            // Error translation
            errorMessage = translateError(error)
        }
        
        isLoading = false
    }
    
    private func translateError(_ error: Error) -> String {
        switch error {
        case MacAddressError.interfaceNotFound:
            return "Network interface not found. Please check your connection."
        case MacAddressError.permissionDenied:
            return "Permission denied. Please run with administrator privileges."
        default:
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}
```

## Benefits
- **Separation of Concerns**: GUI logic separated from business logic
- **Testability**: Each layer can be tested independently
- **Maintainability**: Changes in core API don't directly affect GUI
- **User Experience**: Proper loading states and error handling
- **Type Safety**: Strong typing across layer boundaries

## When to Use
- Complex applications with distinct business logic and UI layers
- APIs with different paradigms (sync/async, different error types)
- Applications requiring sophisticated state management
- Projects with multiple UI frontends (CLI, GUI, web)

## When Not to Use
- Simple applications with minimal business logic
- Prototypes or proof-of-concept projects
- When GUI and core logic are tightly coupled by design

## Architecture Diagram
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   SwiftUI View  │ → │ GUI State Bridge │ → │   Core API      │
│                 │   │                  │   │                 │
│ - UI Components │   │ - State Mgmt     │   │ - Business Logic│
│ - User Events   │   │ - Error Handling │   │ - Data Access   │
│ - Presentation  │   │ - Data Transform │   │ - Domain Models │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Testing Strategy
```swift
class GUIStateBridgeTests: XCTestCase {
    @MainActor
    func testSuccessfulOperation() async {
        let mockCoreAPI = MockCoreAPI()
        let bridge = GUIStateBridge(coreAPI: mockCoreAPI)
        
        await bridge.executeOperation()
        
        XCTAssertEqual(bridge.uiState, .success)
        XCTAssertNil(bridge.errorMessage)
    }
    
    @MainActor
    func testErrorHandling() async {
        let mockCoreAPI = MockCoreAPI(shouldFail: true)
        let bridge = GUIStateBridge(coreAPI: mockCoreAPI)
        
        await bridge.executeOperation()
        
        XCTAssertEqual(bridge.uiState, .error)
        XCTAssertNotNil(bridge.errorMessage)
    }
}
```

## Related Patterns
- PATTERN-2025-035: SwiftUI Async State Management
- PATTERN-2025-033: SwiftUI Clean Architecture Integration
- Bridge Pattern (GoF)
- Adapter Pattern
- Model-View-ViewModel (MVVM)

## Anti-Patterns to Avoid
- Direct API calls from SwiftUI Views
- Exposing core domain models directly to UI
- Inconsistent error handling across layers
- Mixing GUI state with business logic state

## Evolution Notes
- Modern Swift Concurrency has simplified async bridging
- SwiftUI @StateObject/@ObservableObject provide reactive foundation
- Future evolution may include more sophisticated state machines
- Combine framework integration possible for complex reactive flows
