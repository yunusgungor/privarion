---
inclusion: manual
---

# Security Guidelines (Critical)

This document covers security-specific guidelines for Privarion, a privacy protection tool.

## System Hook Security

### DYLD Injection
- Validate all injected dylib signatures
- Implement integrity checks for hook functions
- Log all injection attempts (success/failure)

### Syscall Hooks
- Audit all hooked syscalls for potential bypasses
- Implement return value validation
- Prevent privilege escalation through hooks

## Network Security

### DNS Proxy
- Validate all DNS queries
- Implement DNS rebinding protection
- Use DNS over HTTPS when available
- Log blocked queries for audit

### Network Filtering
- Validate blocklist entries
- Prevent DNS cache poisoning
- Implement certificate pinning for updates

## Identity Spoofing

### Hardware Identifiers
- Secure random generation for spoofed values
- Persist spoofed values securely (Keychain)
- Implement proper rollback on disable
- Validate spoofed values don't conflict

## Data Protection

### Sensitive Data
- Use Keychain for:
  - Profile configurations
  - Spoofed identifiers
  - User credentials
- Never log sensitive data
- Implement secure memory handling

### Audit Logging
- Log all configuration changes
- Log all enable/disable events
- Log permission changes
- Maintain tamper-evident logs

## Privilege Management

### Least Privilege
- Request minimal entitlements
- Drop privileges when not needed
- Use sandboxing where possible

### Permission Handling
- Validate all permission requests
- Implement timeout for temporary permissions
- Audit permission usage

## Vulnerability Response

### Reporting
- Security issues: Do NOT open public issues
- Email: security@privarion.io (TBD)
- Response SLA: 24 hours for critical

### Patching
- Critical patches via hotfix branches
- CVE coordination for public vulnerabilities
- Security advisories for users
