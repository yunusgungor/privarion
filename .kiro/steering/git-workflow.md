# Git Workflow and Branching Strategy

## Branch Naming Convention

```
feature/description          - New features
fix/description               - Bug fixes
hotfix/critical-description   - Production fixes
refactor/description          - Code refactoring
docs/description              - Documentation updates
test/description              - Test additions
chore/description            - Maintenance tasks
```

Examples:
- `feature/mac-address-spoofing`
- `fix/dns-proxy-timeout`
- `hotfix/security-vulnerability`

## Commit Message Format

Follow Conventional Commits:

```
type(scope): description

[optional body]

[optional footer]
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code refactoring
- `test`: Test additions
- `chore`: Maintenance
- `security`: Security-related changes

### Examples
```
feat(network): add DNS over HTTPS support

fix(core): resolve race condition in identity spoofing

security(hook): patch syscall hook vulnerability
```

## Pull Request Guidelines
- Create PR from feature branch to `main`
- Include clear description of changes
- Link related issues using keywords (fixes #123, closes #456)
- Ensure all tests pass before requesting review
- Require at least one approval before merge
- Use squash merge to keep history clean

## Code Review Focus Areas
1. Security implications (critical for privacy tool)
2. Performance impact
3. Error handling completeness
4. Test coverage
5. API consistency with existing patterns

## Protected Branches
- `main` - Production branch, requires PR
- No direct commits allowed
