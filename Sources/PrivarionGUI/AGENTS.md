# PrivarionGUI

SwiftUI application with Clean Architecture.

## OVERVIEW

15+ SwiftUI views + MVVM pattern. BusinessLogic/Presentation/DataAccess structure.

## STRUCTURE

```
Sources/PrivarionGUI/
├── BusinessLogic/     # ViewModels, state, navigation
│   ├── AppState.swift        # Main app state (868 lines)
│   ├── ViewModels/
│   └── Interactors/
├── Presentation/
│   └── Views/         # 15+ SwiftUI views
└── DataAccess/
    └── Repositories/  # Data layer
```

## KEY FILES

| File | Purpose |
|------|---------|
| `PrivarionGUIApp.swift` | @main entry point |
| `ContentView.swift` | Main navigation |
| `DashboardView.swift` | Status dashboard |
| `AppState.swift` | Global state (CRITICAL: has force unwrap bug) |

## CONVENTIONS

- SwiftUI with `@StateObject` / `@Observable`
- Clean Architecture: BusinessLogic → Presentation → DataAccess
- Use `@ViewBuilder` for conditional content
- MVVM pattern for all views

## ANTI-PATTERNS

- AppState.switchProfile has force unwrap causing crashes
- 24 TODOs for unimplemented features
- DON'T use force unwrap (`!`) - use `if let` / `guard`
