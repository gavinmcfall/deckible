---
title: Supported Platforms
description: Overview of gaming handhelds and devices supported by Bootible
---

# Supported Platforms

Bootible supports multiple gaming platforms with platform-specific optimizations and tooling.

---

## Current Platforms

<div class="grid cards" markdown>

-   :material-controller:{ .lg .middle } **Steam Deck**

    ---

    Valve's Linux-based gaming handheld running SteamOS.

    - Ansible-based configuration
    - Flatpak application management
    - Decky Loader plugins
    - Btrfs snapshots for rollback

    [:octicons-arrow-right-24: Steam Deck Guide](steam-deck/index.md)

-   :material-laptop:{ .lg .middle } **ROG Ally**

    ---

    ASUS's Windows-based gaming handheld.

    - PowerShell module system
    - Winget package management
    - Windows optimization & debloating
    - System Restore Points

    [:octicons-arrow-right-24: ROG Ally Guide](rog-ally/index.md)

-   :material-android:{ .lg .middle } **Android** :material-beta:{ .beta }

    ---

    Android gaming handhelds via Wireless ADB.

    - Retroid Pocket, AYANEO, Odin, Logitech G Cloud
    - APK installation from URLs, F-Droid, or local files
    - System settings configuration
    - File push for ROMs/saves

    [:octicons-arrow-right-24: Android Guide](android/index.md)

</div>

---

## Platform Comparison

| Feature | Steam Deck | ROG Ally | Android |
|---------|------------|----------|---------|
| **OS** | SteamOS (Arch Linux) | Windows 11 | Android 11+ |
| **Package Manager** | Flatpak | Winget/Chocolatey | APK (ADB) |
| **Config Language** | YAML (Ansible) | YAML (PowerShell) | YAML (Bash) |
| **Provisioning** | On device | On device | From host via ADB |
| **Emulation** | EmuDeck | EmuDeck | RetroArch, standalone |
| **Remote Play** | Moonlight, Chiaki | Moonlight, Chiaki, Parsec | Moonlight, Chiaki, Steam Link |

---

## How Platform Detection Works

When you run the bootstrap command, Bootible detects your platform from the URL:

```bash
# Steam Deck - downloads deck.sh
curl -fsSL https://bootible.dev/deck | bash

# ROG Ally - downloads ally.ps1
irm https://bootible.dev/rog | iex

# Android - downloads android.sh (run from host machine)
curl -fsSL https://bootible.dev/android | bash
```

The platform determines:

1. **Which configuration template** to use (`config/steamdeck/`, `config/rog-ally/`, or `config/android/`)
2. **Which installer** to run (Ansible playbook, PowerShell runner, or Bash/ADB)
3. **Which package manager** installs applications

---

## Planned Platforms

Future platforms under consideration:

| Platform | OS | Status |
|----------|-----|--------|
| Bazzite | Fedora Atomic | Planned |
| CachyOS | Arch Linux | Planned |
| Windows Desktop | Windows 11 | Planned |
| Legion Go | Windows 11 | Uses ROG Ally config |

!!! tip "Request a Platform"
    Want Bootible support for another device? [Open an issue](https://github.com/bootible/bootible/issues) with your platform details.

---

## Architecture Overview

### Steam Deck (Ansible)

```
targets/deck.sh          # Bootstrap script
config/steamdeck/
├── playbook.yml         # Main Ansible playbook
├── config.yml           # Default configuration
└── roles/
    ├── base/            # Flathub, hostname, SD card
    ├── flatpak_apps/    # Application installation
    ├── ssh/             # SSH server setup
    ├── tailscale/       # VPN configuration
    ├── decky/           # Decky Loader + plugins
    ├── proton/          # Proton-GE, Protontricks
    ├── emulation/       # EmuDeck setup
    └── ...
```

### ROG Ally (PowerShell)

```
targets/ally.ps1         # Bootstrap script
config/rog-ally/
├── Run.ps1              # Main orchestrator
├── config.yml           # Default configuration
├── lib/
│   └── helpers.ps1      # Utility functions
└── modules/
    ├── validate.ps1     # Package validation
    ├── base.ps1         # Hostname, network, winget
    ├── apps.ps1         # Application installation
    ├── gaming.ps1       # Game platforms
    ├── streaming.ps1    # Streaming clients
    ├── ssh.ps1          # OpenSSH server
    ├── optimization.ps1 # Gaming tweaks
    ├── debloat.ps1      # Privacy settings
    └── ...
```

### Android (Bash + ADB) :material-beta:{ .beta }

```
targets/android.sh       # Bootstrap script (runs on host)
config/android/
├── Run.sh               # Provisioning engine
├── config.yml           # Default configuration (100+ apps)
└── lib/
    ├── adb-helpers.sh   # ADB wrapper functions
    ├── apk-install.sh   # APK installation
    ├── settings.sh      # Settings configuration
    └── files.sh         # File push logic
```

!!! note "Host-based provisioning"
    Unlike Steam Deck and ROG Ally, Android provisioning runs **from your computer** and connects to the Android device via Wireless ADB.
