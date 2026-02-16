# PrivarionGUI

SwiftUI application using Clean Architecture pattern.

## OVERVIEW

macOS GUI for privacy management. 15+ SwiftUI views with MVVM + Clean Architecture.

## STRUCTURE

```
Sources/PrivarionGUI/
├── BusinessLogic/
│   ├── AppState.swift           # Global state (868 lines)
│   ├── ViewModels/              # View models
│   ├── Interactors/             # Business logic
│   └── Search/                  # Search functionality
├── Presentation/
│   └── Views/
│       ├── ContentView.swift    # Main navigation
│       ├── DashboardView.swift  # Status overview
│       ├── MacAddressView.swift
│       ├── NetworkFilteringView.swift
│       ├── TemporaryPermissionsView.swift  # 1107 lines
│       ├── AdvancedPreferencesView.swift   # 700 lines
│       ├── SecondaryViews.swift            # 688 lines
│       └── Components/          # Reusable components
└── DataAccess/
    └── Repositories/            # Data layer
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| App entry | `PrivarionGUIApp.swift` | @main, keyboard shortcuts |
| Navigation | `ContentView.swift` | Main window, sidebar |
| Dashboard | `DashboardView.swift` | System status, modules |
| Global state | `AppState.swift` | 868 lines - needs refactoring |
| MAC addresses | `MacAddressView.swift` | MAC spoofing UI |
| Network | `NetworkFilteringView.swift` | Network controls |
| Permissions | `TemporaryPermissionsView.swift` | 1107 lines - too large |

## CONVENTIONS

- `@StateObject` / `@Observable` for state
- Clean Architecture: BusinessLogic → Presentation → DataAccess
- MVVM for all views
- `@ViewBuilder` for conditional content

## ANTI-PATTERNS

- **CRITICAL**: `AppState.switchProfile` force unwrap causes crashes
- **24 TODOs** across GUI - unimplemented features
- **Large views**: TemporaryPermissionsView (1107 lines), AdvancedPreferencesView (700 lines)
- DON'T use `!` - use `if let` / `guard`

## LARGE FILES (Refactor Targets)

| File | Lines | Issue |
|------|-------|-------|
| `AppState.swift` | 868 | Too large |
| `TemporaryPermissionsView.swift` | 1107 | Way too large |
| `AdvancedPreferencesView.swift` | 700 | Too large |
| `SecondaryViews.swift` | 688 | Too large |
