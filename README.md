# Bootible

Universal configuration automation for gaming handhelds.

**Supported Devices:**
- **Steam Deck** (SteamOS/Arch Linux) - Ansible-based
- **ROG Ally X** (Windows 11) - PowerShell-based
- More coming soon (Legion Go, Steam Deck OLED, etc.)

## Quick Start

### Steam Deck (Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/gavinmcfall/bootible/main/bootstrap.sh | bash
```

### ROG Ally X (Windows)

Run in PowerShell as Administrator:
```powershell
irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/bootstrap.ps1 | iex
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
├── bootstrap.sh          # Linux entry point
├── bootstrap.ps1         # Windows entry point
│
├── steamdeck/            # Steam Deck configuration
│   ├── playbook.yml      # Ansible playbook
│   ├── config.yml        # Default settings
│   └── roles/            # Ansible roles
│
├── rogally/              # ROG Ally X configuration
│   ├── Run.ps1           # PowerShell main script
│   ├── config.yml        # Default settings
│   └── modules/          # PowerShell modules
│
├── private/              # Your private config (separate repo)
│   ├── steamdeck/
│   │   └── config.yml
│   └── rogally/
│       └── config.yml
│
└── files/                # Local files for installation
    ├── steamdeck/
    └── rogally/
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
./bootstrap.sh git@github.com:YOUR_USER/bootible-private.git

# ROG Ally (PowerShell)
$env:BOOTIBLE_PRIVATE = "https://github.com/YOUR_USER/bootible-private.git"
.\bootstrap.ps1
```

Your private config overrides the defaults, so you only need to specify what you want to change.

## Device-Specific Documentation

### Steam Deck

See [steamdeck/](steamdeck/) for:
- Available roles and options
- Decky plugins configuration
- EmuDeck setup
- Proton-GE installation

**Run manually:**
```bash
cd steamdeck
ansible-playbook playbook.yml --ask-become-pass
```

**Dry run (preview changes without applying):**
```bash
cd steamdeck
ansible-playbook playbook.yml --check
```

### ROG Ally X

See [rogally/](rogally/) for:
- Available modules and options
- Armoury Crate vs Handheld Companion
- Game streaming setup
- Windows optimization tweaks

**Run manually:**
```powershell
cd rogally
.\Run.ps1
```

**Dry run (preview changes without applying):**
```powershell
cd rogally
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
cd ~/bootible && git pull && ./bootstrap.sh

# ROG Ally (PowerShell)
cd $env:USERPROFILE\bootible; git pull; .\bootstrap.ps1
```

## Adding New Devices

The modular structure makes it easy to add new devices:

1. Create a new directory (e.g., `legiongo/`)
2. Add device-specific configuration and scripts
3. Update `bootstrap.sh` / `bootstrap.ps1` to detect the device
4. Submit a PR!

## License

MIT
