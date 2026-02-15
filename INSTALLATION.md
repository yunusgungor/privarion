# Installation Guide

## System Requirements

- **Operating System**: macOS 13.0 (Ventura) or later
- **Architecture**: Apple Silicon (arm64) or Intel (x86_64)
- **Storage**: 100 MB free space
- **Permissions**: Full Disk Access (for TCC database access)

## Installation Methods

### Method 1: DMG Installation (Recommended)

1. Download the latest `Privarion-x.x.x.dmg` from [Releases](https://github.com/privarion/privarion/releases)
2. Open the DMG file
3. Drag `PrivarionGUI.app` to your Applications folder
4. Launch Privarion from Applications

### Method 2: Homebrew

```bash
# Add the tap
brew tap privarion/privarion

# Install Privarion
brew install privarion

# Launch the GUI
open -a PrivarionGUI

# Or use the CLI
privarion --help
```

### Method 3: Build from Source

```bash
# Clone the repository
git clone https://github.com/privarion/privarion.git
cd privarion

# Build the project
swift build -c release

# The binaries will be in .build/release/
# - privacyctl (CLI tool)
# - PrivarionGUI.app (GUI application)

# Install CLI tool
cp .build/release/privacyctl /usr/local/bin/

# Install GUI app
cp -R .build/release/PrivarionGUI.app /Applications/
```

## Initial Setup

### 1. Grant Permissions

Privarion requires certain permissions to function:

1. **Full Disk Access**: Required for TCC database access
   - System Settings → Privacy & Security → Full Disk Access
   - Enable PrivarionGUI

2. **Accessibility** (optional): Required for advanced syscall monitoring
   - System Settings → Privacy & Security → Accessibility
   - Enable PrivarionGUI if needed

### 2. Initial Configuration

On first launch:

1. The app will guide you through initial setup
2. Select your preferred privacy profile
3. Enable desired protection modules
4. Configure network filtering rules (optional)

### 3. Verify Installation

```bash
# Check CLI version
privarion --version

# Check system status
privarion status

# View available modules
privarion config list
```

## Configuration

### CLI Configuration

```bash
# View all settings
privarion config list

# Enable a module
privarion config set modules.identitySpoofing.enabled true

# Switch profile
privarion profile switch default
```

### GUI Configuration

1. Open PrivarionGUI
2. Navigate to Settings
3. Configure preferences
4. Changes apply immediately

## Troubleshooting

### Permission Issues

If you see permission errors:

```bash
# Check current permissions
privarion status --detailed

# Re-grant Full Disk Access
# System Settings → Privacy & Security → Full Disk Access
```

### Installation Fails

1. Check system requirements are met
2. Verify you have admin privileges
3. Try rebuilding from source

### Module Not Working

1. Check module status: `privarion status --detailed`
2. Review logs: `privarion logs --lines 50`
3. Restart the system: `privarion stop && privarion start`

## Uninstallation

### DMG/App Store Version

1. Drag PrivarionGUI.app to Trash
2. Optionally remove config: `rm -rf ~/.privarion`

### Homebrew Version

```bash
brew uninstall privarion
```

### Source Installation

```bash
# Remove CLI tool
rm /usr/local/bin/privarion

# Remove GUI app
rm -rf /Applications/PrivarionGUI.app

# Remove configuration
rm -rf ~/.privarion
```

## Support

- **Issues**: https://github.com/privarion/privarion/issues
- **Discussions**: https://github.com/privarion/privarion/discussions
- **Documentation**: https://privarion.dev/docs

---

For more help, see the [User Manual](docs/USER_MANUAL.md)
