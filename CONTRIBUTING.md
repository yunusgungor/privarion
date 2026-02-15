# Contributing to Privarion

Thank you for your interest in contributing to Privarion!

## Code of Conduct

By participating in this project, you are expected to uphold our [Code of Conduct](https://github.com/privarion/privarion/blob/main/CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Bugs

1. Check if the bug has already been reported
2. Use the issue template for bug reports
3. Include detailed steps to reproduce

### Suggesting Features

1. Check the issue tracker for existing proposals
2. Use the issue template for feature requests
3. Explain why this feature would be useful

### Pull Requests

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes following our coding standards
4. Add tests for new functionality
5. Ensure all tests pass
6. Commit your changes with descriptive messages
7. Push to your fork and submit a pull request

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Xcode 14.3 or later
- Swift 5.9+

### Building

```bash
# Clone the repository
git clone https://github.com/privarion/privarion.git
cd privarion

# Build the project
swift build

# Run tests
swift test

# Run specific test suite
swift test --filter PrivarionCoreTests
```

### Coding Standards

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation for public APIs
- Keep functions small and focused
- Write tests for new functionality

## Commit Message Guidelines

```
type(scope): description

[optional body]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance

## Recognition

Contributors will be recognized in the README.md and on our website.

---

**Thank you for contributing to Privacy Protection!**
