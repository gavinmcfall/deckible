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

</div>

---

## Platform Comparison

| Feature | Steam Deck | ROG Ally |
|---------|------------|----------|
| **OS** | SteamOS (Arch Linux) | Windows 11 |
| **Package Manager** | Flatpak | Winget/Chocolatey |
| **Config Language** | YAML (Ansible) | YAML (parsed by PowerShell) |
| **Backup Method** | Btrfs snapshots | System Restore |
| **Gaming Plugins** | Decky Loader | - |
| **Emulation** | EmuDeck (Linux) | EmuDeck (Windows) |
| **Remote Play** | Moonlight, Chiaki | Moonlight, Chiaki, Parsec |

---

## How Platform Detection Works

When you run the bootstrap command, Bootible detects your platform from the URL:

```bash
# Steam Deck - downloads deck.sh
curl -fsSL https://bootible.dev/deck | bash

# ROG Ally - downloads ally.ps1
irm https://bootible.dev/rog | iex
```

The platform determines:

1. **Which configuration template** to use (`config/steamdeck/` or `config/rog-ally/`)
2. **Which installer** to run (Ansible playbook or PowerShell runner)
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
