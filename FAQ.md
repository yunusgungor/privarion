# Frequently Asked Questions (FAQ)

## General

### What is Privarion?

Privarion is a comprehensive privacy protection system for macOS that prevents applications from fingerprinting your device and collecting personal information. It provides identity spoofing, network filtering, and system-level protection.

### What does Privarion protect against?

- **Device Fingerprinting**: Randomizes MAC addresses, hostnames, and hardware identifiers
- **Network Tracking**: Blocks telemetry, ads, and tracking servers at DNS level
- **System Monitoring**: Intercepts and monitors system calls
- **Privacy Leaks**: Prevents applications from accessing sensitive system information

---

## Installation

### What are the system requirements?

- macOS 13.0 (Ventura) or later
- 100 MB free storage
- Full Disk Access (optional, for TCC database features)

### How do I install Privarion?

See the [Installation Guide](INSTALLATION.md) for detailed instructions.

### Why does Privarion need Full Disk Access?

Full Disk Access is required to read the TCC (Transparency, Consent, and Control) database, which stores all application permission settings. Without this, Privarion cannot monitor or manage TCC permissions.

---

## Usage

### How do I start using Privarion?

1. Install Privarion
2. Launch the app or use `privarion start`
3. Select a privacy profile
4. Enable desired protection modules

### What profiles are available?

- **Default**: Balanced privacy protection
- **Work**: Optimized for work environments
- **Maximum**: Highest privacy protection
- **Custom**: User-defined configuration

### Can I use Privarion without the GUI?

Yes! Privarion includes a full-featured CLI:

```bash
privarion status
privarion config list
privarion profile switch work
privarion identity spoof --random
```

---

## Privacy & Security

### Does Privarion collect any data?

No. Privarion is designed with privacy-first principles:
- No cloud connectivity required
- All data stays local
- No telemetry or analytics sent anywhere

### Can Privarion break my applications?

Privarion is designed to be safe:
- Changes are reversible
- Snapshot/rollback system available
- Careful default configurations

However, some applications may behave unexpectedly if their network access is blocked.

### Is Privarion safe to use?

Yes, Privarion has been tested and validated:
- No critical security vulnerabilities
- 100% success rate in stress tests
- Comprehensive audit logging

---

## Troubleshooting

### A website isn't loading

Check if it's blocked by network filtering:
```bash
privarion network status
```

Add to allowlist if needed:
```bash
privarion network allowlist add example.com
```

### Application won't launch

Some apps require specific permissions. Check:
```bash
privarion logs --lines 50
```

### Permission denied errors

Grant required permissions:
1. System Settings → Privacy & Security → Full Disk Access
2. Enable PrivarionGUI

### How do I reset everything?

```bash
privarion config reset --force
privarion identity restore
```

---

## Technical

### What programming languages/frameworks are used?

- **Swift**: Primary language
- **SwiftUI**: GUI framework
- **SwiftNIO**: High-performance networking
- **C**: Low-level system hooks

### Is the source code available?

Yes! Privarion is open source:
https://github.com/privarion/privarion

### How can I contribute?

See the [Contributing Guide](CONTRIBUTING.md)

---

## Support

### Where can I get help?

- **GitHub Issues**: https://github.com/privarion/privarion/issues
- **Discussions**: https://github.com/privarion/privarion/discussions

### How do I report a bug?

1. Check if the bug is already reported
2. Use the issue template
3. Include steps to reproduce
4. Attach relevant logs

---

## License

Privarion is licensed under the [MIT License](LICENSE).
