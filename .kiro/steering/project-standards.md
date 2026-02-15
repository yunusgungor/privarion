# Project Standards and Guidelines

## Code Quality Standards

### Swift Language Conventions
- Follow Swift API Design Guidelines (apple.github.io/swift-api-design-guidelines)
- Use SwiftLint for code style enforcement (install via Homebrew: `brew install swiftlint`)
- Enable all Swift compiler warnings and treat them as errors
- Use Swift 5.9+ features where appropriate (async/await, actors)

### Naming Conventions
- Use PascalCase for types, enums, protocols: `IdentitySpoofingManager`, `NetworkFilter`
- Use camelCase for functions, properties, variables: `enableSpoofing()`, `isEnabled`
- Use SCREAMING_SNAKE_CASE for constants: `MAX_RETRY_COUNT`
- Prefix protocols with meaningful names: `NetworkFiltering`, `IdentityManaging`

### Architecture
- Follow MVVM for GUI components (Views + ViewModels)
- Use protocol-oriented programming for testability
- Implement dependency injection for all managers
- Keep functions under 50 lines
- Single responsibility principle: one type, one purpose

## Testing Requirements
- Minimum 80% code coverage for PrivarionCore
- Unit tests for all business logic in managers
- Integration tests for CLI commands
- UI tests for critical GUI flows
- Use XCTest framework
- Mock system calls and privileged operations

## Documentation Standards
- Use SwiftDoc for API documentation
- Document all public interfaces
- Include usage examples in doc comments
- Update README.md for any user-facing changes
- Maintain CHANGELOG following Keep a Changelog format

## Security Practices (Critical for Privacy Tool)
- NEVER commit secrets, keys, or credentials
- Use Keychain for sensitive data storage
- Validate all inputs from userland
- Implement proper error handling without information leakage
- Follow principle of least privilege
- Audit all system call interactions

## Performance Guidelines
- Profile before optimizing
- Use Instruments for memory/leak detection
- Implement proper lazy loading for heavy operations
- Use Swift Concurrency (async/await, actors) for parallel operations
- Monitor DNS proxy latency
