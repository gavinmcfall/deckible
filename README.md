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
