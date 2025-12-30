# Bootible

> One-liner setup for gaming handhelds and desktops.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Supported Devices

| Device | Platform | Status |
|--------|----------|--------|
| Steam Deck | SteamOS (Arch) | Ready |
| ROG Ally (All Varients) | Windows 11 | Ready |
| Bazzite | Fedora | Planned |
| Ubuntu | Linux | Planned |
| Windows Desktop | Windows 10/11 | Planned |

---

## Quick Start

### Steam Deck

```bash
curl -fsSL https://bootible.dev/deck | bash
```

### ROG Ally (All Varients)

Run in **PowerShell as Administrator**:

```powershell
irm https://bootible.dev/rog | iex
```

That's it! Bootible runs in **dry-run mode** by default so you can preview changes. When ready, just type `bootible` to apply.

<details>
<summary>Alternative: Direct GitHub URLs</summary>

```bash
# Steam Deck
curl -fsSL https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/deck.sh | bash

# ROG Ally (All Varients)
irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/ally.ps1 | iex
```
</details>

---

## What Gets Installed

| Category | Steam Deck | ROG Ally (All Varients) |
|----------|------------|------------|
| **Package Manager** | Flatpak | winget |
| **Apps** | Discord, Spotify, VLC, browsers | Discord, Spotify, VLC, browsers |
| **Gaming** | Decky Loader, Proton-GE | Steam, Xbox, game launchers |
| **Streaming** | Moonlight, Chiaki, Greenlight | Moonlight, Chiaki, Parsec |
| **Remote Access** | SSH, Tailscale, Sunshine | Tailscale, RDP |
| **Emulation** | EmuDeck, RetroArch | EmuDeck, RetroArch |
| **Optimization** | SD card setup, shader cache | Debloat, gaming tweaks |

Everything is **disabled by default** - enable only what you need in your config.

---

## Private Configuration

Store your personal settings in a private repo that syncs across devices.

### Option 1: Quick Setup (Recommended)

```bash
# Clone bootible
git clone https://github.com/gavinmcfall/bootible.git
cd bootible

# Create private config structure
./init-private-repo.sh

# Push to your private repo
cd private
git remote add origin git@github.com:YOUR_USER/my-bootible-config.git
git push -u origin main
```

### Option 2: Create Manually

[![Create Private Repo](https://img.shields.io/badge/GitHub-Create%20Private%20Repo-181717?logo=github)](https://github.com/new?name=bootible-private&visibility=private)

Then add this structure:

```
your-private-repo/
├── rog-ally/
│   ├── config.yml          # Your ROG Ally settings
│   └── scripts/            # EmuDeck EA, etc.
├── steamdeck/
│   ├── config.yml          # Your Steam Deck settings
│   └── scripts/            # EmuDeck EA, etc.
└── logs/
    ├── rog-ally/           # Dry run logs (auto-generated)
    └── steamdeck/
```

### Using Your Private Config

**Steam Deck:**
```bash
curl -fsSL https://bootible.dev/deck | bash -s -- git@github.com:YOU/your-config.git
```

**ROG Ally (All Varients):**
```powershell
irm https://bootible.dev/rog | iex
# When prompted, enter your GitHub username and repo name
```

> **Note:** Private repo requires `main` branch, no branch protection (bootible auto-pushes dry run logs).

---

## Project Structure

```
bootible/
├── targets/                    # Bootstrap scripts
│   ├── ally.ps1               # ROG Ally (Windows)
│   ├── deck.sh                # Steam Deck (SteamOS)
│   └── common/                # Shared functions
│
├── config/                     # Device configurations
│   ├── rog-ally/
│   │   ├── Run.ps1            # Main script
│   │   ├── config.yml         # Default settings
│   │   ├── modules/           # Feature modules
│   │   └── scripts/           # Install scripts
│   │
│   └── steamdeck/
│       ├── playbook.yml       # Ansible playbook
│       ├── config.yml         # Default settings
│       └── roles/             # Ansible roles
│
├── cloudflare/                 # URL shortener
│   └── worker/                # Cloudflare Worker (bootible.dev)
│
└── private/                    # Your private config (separate repo)
```

---

## Configuration Reference

### Example: Enable common apps

```yaml
# private/rog-ally/config.yml
install_discord: true
install_spotify: true
install_vlc: true
password_manager: "1password"
```

### Example: Enable game streaming

```yaml
install_moonlight: true
install_chiaki: true      # PlayStation Remote Play
install_greenlight: true  # Xbox streaming
```

### Example: Custom paths

```yaml
games_path: "D:\\Games"
roms_path: "D:\\Emulation\\ROMs"
bios_path: "D:\\Emulation\\BIOS"
```

### Example: Steam Deck with Decky plugins

```yaml
# private/steamdeck/config.yml
install_decky_loader: true
decky_plugins:
  - css_loader
  - protondb_badges
  - steamgriddb
  # ... more plugins

# IMPORTANT: Set this to avoid GitHub API rate limits (60 req/hour without)
# Without a token, installing 10+ plugins may fail silently
github_token: "ghp_your_token_here"
```

> **Note:** Create a [GitHub personal access token](https://github.com/settings/tokens) with no special scopes (public access only). Required if enabling many Decky plugins.

See full config options:
- [ROG Ally defaults](config/rog-ally/config.yml)
- [Steam Deck defaults](config/steamdeck/config.yml)

---

## Running Manually

### Steam Deck

```bash
cd ~/bootible/config/steamdeck
ansible-playbook playbook.yml --ask-become-pass

# Dry run
ansible-playbook playbook.yml --check
```

### ROG Ally (All Varients)

```powershell
cd $env:USERPROFILE\bootible\config\rog-ally
.\Run.ps1

# Dry run
.\Run.ps1 -DryRun
```

---

## Re-running / Updating

After initial setup, just run:

```bash
# Steam Deck
bootible

# ROG Ally (from anywhere)
bootible
```

Or pull latest and re-run:

```bash
cd ~/bootible && git pull && ./targets/deck.sh
```

---

## Post-Setup (ROG Ally)

Some settings require manual configuration via Armoury Crate:

- **VRAM**: Set to 6GB (Ally) or 10GB (Ally X)
- **Controller Calibration**: Calibrate both sticks
- **Power Profile**: Create 20W manual mode for balanced performance
- **Battery Care**: Enable 80% limit if mostly docked

See: [Everything You MUST Do - ROG ALLY](https://www.youtube.com/watch?v=oSdTNOPXcYk)

---

## Adding New Devices

1. Create `config/<device>/` with config and scripts
2. Create `targets/<device>.sh` or `.ps1`
3. Submit a PR!

---

## License

MIT
