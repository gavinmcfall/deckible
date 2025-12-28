# Bootible

Universal configuration automation for gaming handhelds and desktops.

**Supported Devices:**
- **Steam Deck** (SteamOS/Arch Linux) - Ansible-based
- **ROG Ally X** (Windows 11) - PowerShell-based
- More coming soon (Bazzite, Ubuntu, Windows Desktop, macOS)

## Quick Start

### Steam Deck (SteamOS)

```bash
curl -fsSL https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/deck.sh | bash
```

### ROG Ally X (Windows)

Run in PowerShell as Administrator:
```powershell
irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/ally.ps1 | iex
```

### Other Devices (Coming Soon)

```bash
# Bazzite
curl -fsSL https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/bazzite.sh | bash

# Ubuntu
curl -fsSL https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/ubuntu.sh | bash
```

```powershell
# Windows Desktop
irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/windows.ps1 | iex
```

## What It Does

Bootible automates the setup of gaming handhelds with:

| Feature | Steam Deck | ROG Ally X |
|---------|------------|------------|
| Package Manager | Flatpak | winget |
| Apps | Discord, Spotify, VLC, etc. | Discord, Spotify, VLC, etc. |
| Gaming | Decky Loader, Proton-GE | Steam, Xbox, launchers |
| Streaming | Moonlight, Chiaki, Greenlight | Moonlight, Chiaki, Parsec |
| Remote Access | SSH, Tailscale, Sunshine | Tailscale, RDP |
| Emulation | EmuDeck | RetroArch, standalone emulators |
| Controller | StickDeck (use Deck as PC gamepad) | - |
| Optimization | SD card, shader cache | Windows gaming tweaks |

## Project Structure

```
bootible/
├── targets/
│   ├── ally.ps1              # ROG Ally bootstrap (Windows)
│   ├── deck.sh               # Steam Deck bootstrap (SteamOS)
│   ├── bazzite.sh            # Bazzite (coming soon)
│   ├── ubuntu.sh             # Ubuntu (coming soon)
│   ├── windows.ps1           # Windows Desktop (coming soon)
│   └── common/
│       ├── common.ps1        # Shared PowerShell functions
│       └── common.sh         # Shared shell functions
│
├── config/
│   ├── rog-ally/             # ROG Ally X configuration
│   │   ├── Run.ps1           # Main script
│   │   ├── config.yml        # Default settings
│   │   ├── modules/          # PowerShell modules
│   │   └── scripts/          # Install scripts (EmuDeck EA, etc.)
│   │
│   ├── steamdeck/            # Steam Deck configuration
│   │   ├── playbook.yml      # Ansible playbook
│   │   ├── config.yml        # Default settings
│   │   ├── roles/            # Ansible roles
│   │   ├── appimages/        # AppImage files
│   │   ├── flatpaks/         # Local .flatpak files
│   │   └── scripts/          # Install scripts
│   │
│   ├── bazzite/              # Bazzite (coming soon)
│   ├── ubuntu/               # Ubuntu (coming soon)
│   └── windows/              # Windows Desktop (coming soon)
│
└── private/                  # Your private config (separate repo)
    ├── rog-ally/
    │   ├── config.yml
    │   └── scripts/
    ├── steamdeck/
    │   ├── config.yml
    │   └── scripts/
    └── logs/
        ├── rog-ally/
        └── steamdeck/
```

## Configuration

### Default Config

Each device has a `config.yml` with sensible defaults. Most options are disabled by default - enable what you need.

### Private Config (Recommended)

Create a private repository for your personal settings:

```bash
./init-private-repo.sh
cd private
git remote add origin git@github.com:YOUR_USER/bootible-private.git
git push -u origin main
```

**Note:** The private repo must use `main` as the default branch and cannot have branch protection enabled (bootible auto-pushes dry run logs to `logs/<device>/`).

Then run with your private repo:

```bash
# Steam Deck
curl -fsSL https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/deck.sh | bash -s -- git@github.com:YOUR_USER/private.git

# ROG Ally (PowerShell)
$env:BOOTIBLE_PRIVATE = "https://github.com/YOUR_USER/private.git"
irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/ally.ps1 | iex
```

Your private config overrides the defaults, so you only need to specify what you want to change.

## Device-Specific Documentation

### Steam Deck

See [config/steamdeck/](config/steamdeck/) for:
- Available roles and options
- Decky plugins configuration
- EmuDeck setup
- Proton-GE installation

**Run manually:**
```bash
cd config/steamdeck
ansible-playbook playbook.yml --ask-become-pass
```

**Dry run (preview changes without applying):**
```bash
cd config/steamdeck
ansible-playbook playbook.yml --check
```

### ROG Ally X

See [config/rog-ally/](config/rog-ally/) for:
- Available modules and options
- Armoury Crate vs Handheld Companion
- Game streaming setup
- Windows optimization tweaks

**Run manually:**
```powershell
cd config/rog-ally
.\Run.ps1
```

**Dry run (preview changes without applying):**
```powershell
cd config/rog-ally
.\Run.ps1 -DryRun
```

**Post-Setup (Manual Steps):**

After running Bootible, there are some settings that require manual configuration via Armoury Crate UI:

- **VRAM Allocation**: Set to 6GB (Ally) or 10GB (Ally X) in Armoury Crate > Performance > GPU Settings
- **Controller Calibration**: Armoury Crate > Calibration (calibrate both sticks)
- **Custom Power Profile**: Create a 20W manual mode for optimal performance/battery balance
- **Battery Care**: Enable 80% charge limit if mostly docked
- **CPU Boost**: Add to quick settings for per-game toggling

For a complete walkthrough, see: [Everything You MUST Do - ROG ALLY & ALLY X](https://www.youtube.com/watch?v=oSdTNOPXcYk)

## Dry Run Mode

Both platforms support a dry run mode that previews changes without applying them. At the end of any run (dry or real), a system summary is displayed:

```
System Information:
  Hostname:    steamdeck
  IP Address:  192.168.1.100
  IP Type:     DHCP
  MAC Address: aa:bb:cc:dd:ee:ff
  Interface:   wlan0
```

This is useful for:
- Verifying network configuration before/after changes
- Documenting your device's current state
- Troubleshooting connectivity issues

## Re-running / Updating

```bash
# Steam Deck
cd ~/bootible && git pull && ./targets/deck.sh

# ROG Ally (PowerShell)
cd $env:USERPROFILE\bootible; git pull; .\targets\ally.ps1
```

## Adding New Devices

The modular structure makes it easy to add new devices:

1. Create a new config directory (e.g., `config/legiongo/`)
2. Add device-specific configuration and scripts
3. Create a new bootstrap script in `targets/` (e.g., `targets/legiongo.ps1`)
4. Submit a PR!

## License

MIT
