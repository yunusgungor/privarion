# PROJECT KNOWLEDGE BASE

**Generated:** 2026-02-16
**Commit:** 1b61a3c
**Branch:** main

## OVERVIEW

Privarion is a macOS privacy protection system that prevents application fingerprinting. Written in Swift with C interop for low-level hooks. Provides CLI (`privacyctl`) + SwiftUI GUI.

## STRUCTURE

```
.
├── Sources/
│   ├── PrivarionCore/     # 46 files - privacy engine
│   ├── PrivarionGUI/      # SwiftUI app (MVVM)
│   ├── PrivacyCtl/        # CLI (ArgumentParser)
│   └── PrivarionHook/     # C syscall hooks
├── Tests/
│   ├── PrivarionCoreTests/  # 32 files
│   └── PrivarionGUITests/
├── Package.swift          # SPM (5 deps)
└── PRD.md                 # Product spec
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Identity spoofing | `Sources/PrivarionCore/Identity*.swift` | Hardware ID manipulation |
| Network filtering | `Sources/PrivarionCore/Network*.swift` | DNS proxy, blocklists |
| Syscall hooks | `Sources/PrivarionHook/` | C interop |
| CLI commands | `Sources/PrivacyCtl/main.swift` | 121KB - all commands inline |
| GUI views | `Sources/PrivarionGUI/Presentation/Views/` | 15+ SwiftUI views |
| Tests | `Tests/PrivarionCoreTests/` | XCTest, mocks |

## CONVENTIONS (THIS PROJECT)

- **Architecture**: Clean Architecture in GUI (BusinessLogic/Presentation/DataAccess), flat in Core
- **CLI**: Swift ArgumentParser, commands in `main.swift` (not modular)
- **Testing**: XCTest with mock interactors, `@testable import`
- **Error handling**: Custom `PrivarionError` enum, NOT using `try?` silently (90 instances exist - avoid)
- **No linting**: No SwiftLint/SwiftFormat config

## ANTI-PATTERNS

- **DON'T** use `try?` without handling errors (90 instances found)
- **DON'T** use force unwrap (`!`) - causes crashes (found in AppState.switchProfile)
- **DON'T** swallow errors silently - ConfigurationProfileManager has "Handle error silently" comments
- **AVOID** large files - Core has 48 files in single flat directory

## UNIQUE STYLES

- **Mixed C/Swift**: PrivarionHook uses C with module.map for Swift interop
- **Dual entry points**: GUI has redundant empty `PrivarionGUIExecutable/main.swift`
- **Inline CLI commands**: All 14 commands in single 121KB main.swift
- **Security-focused**: Extensive security engines (AnomalyDetection, ThreatDetection, SecurityPolicy)

## COMMANDS

```bash
swift build              # Dev build
swift build -c release   # Release
swift test              # All tests
swift test --filter PrivarionCoreTests  # Specific suite
swift run privacyctl --help
swift run PrivarionGUI
```

## NOTES

- Requires macOS 13.0+, Swift 5.9+
- 24 TODOs across codebase - unimplemented features in GUI profiles/logs
- No CI/CD configured
- Dependencies: swift-argument-parser, swift-log, swift-collections, KeyboardShortcuts, swift-nio


# AI-DLC and Spec-Driven Development

Kiro-style Spec Driven Development implementation on AI-DLC (AI Development Life Cycle)

## Project Context

### Paths
- Steering: `.kiro/steering/`
- Specs: `.kiro/specs/`

### Steering vs Specification

**Steering** (`.kiro/steering/`) - Guide AI with project-wide rules and context
**Specs** (`.kiro/specs/`) - Formalize development process for individual features

### Active Specifications
- Check `.kiro/specs/` for active specifications
- Use `/kiro-spec-status [feature-name]` to check progress

## Development Guidelines
- Think in English, generate responses in English. All Markdown content written to project files (e.g., requirements.md, design.md, tasks.md, research.md, validation reports) MUST be written in the target language configured for this specification (see spec.json.language).

## Minimal Workflow
- Phase 0 (optional): `/kiro-steering`, `/kiro-steering-custom`
- Phase 1 (Specification):
  - `/kiro-spec-init "description"`
  - `/kiro-spec-requirements {feature}`
  - `/kiro-validate-gap {feature}` (optional: for existing codebase)
  - `/kiro-spec-design {feature} [-y]`
  - `/kiro-validate-design {feature}` (optional: design review)
  - `/kiro-spec-tasks {feature} [-y]`
- Phase 2 (Implementation): `/kiro-spec-impl {feature} [tasks]`
  - `/kiro-validate-impl {feature}` (optional: after implementation)
- Progress check: `/kiro-spec-status {feature}` (use anytime)

## Development Rules
- 3-phase approval workflow: Requirements → Design → Tasks → Implementation
- Human review required each phase; use `-y` only for intentional fast-track
- Keep steering current and verify alignment with `/kiro-spec-status`
- Follow the user's instructions precisely, and within that scope act autonomously: gather the necessary context and complete the requested work end-to-end in this run, asking questions only when essential information is missing or the instructions are critically ambiguous.

## Steering Configuration
- Load entire `.kiro/steering/` as project memory
- Default files: `product.md`, `tech.md`, `structure.md`
- Custom files are supported (managed via `/kiro-steering-custom`)
