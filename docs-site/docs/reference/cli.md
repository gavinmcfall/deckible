---
title: CLI Reference
description: Command-line options for Bootible
---

# CLI Reference

Command-line usage for Bootible bootstrap scripts and runners.

---

## Bootstrap Commands

The one-liner commands that download and run Bootible.

### Steam Deck

```bash
curl -fsSL https://bootible.dev/deck | bash
```

**What it does:**

1. Downloads `deck.sh` from bootible.dev
2. Verifies SHA256 checksum
3. Runs the bootstrap script

**Alternative (manual):**

```bash
# Download
curl -fsSL https://bootible.dev/deck -o deck.sh

# Verify (optional)
sha256sum deck.sh

# Run
chmod +x deck.sh
./deck.sh
```

### ROG Ally

```powershell
irm https://bootible.dev/rog | iex
```

**What it does:**

1. Downloads `ally.ps1` from bootible.dev
2. Executes in PowerShell

**Alternative (manual):**

```powershell
# Download
Invoke-WebRequest -Uri https://bootible.dev/rog -OutFile ally.ps1

# Run
.\ally.ps1
```

---

## The `bootible` Command

After bootstrap, `bootible` is installed for easy re-runs.

### Steam Deck

```bash
# Basic usage - applies your config
bootible

# With options (passed to ansible-playbook)
bootible --check  # Dry run
bootible -v       # Verbose
bootible -vvv     # Very verbose
```

**Location:** `~/.local/bin/bootible`

**What it runs:**

```bash
cd ~/bootible/config/steamdeck && \
ansible-playbook playbook.yml \
  --ask-become-pass \
  -e @../private/device/steamdeck/$INSTANCE/config.yml \
  -e device_instance=$INSTANCE
```

### ROG Ally

```powershell
# Basic usage - applies your config
bootible

# Available in PowerShell after bootstrap
```

**Location:** Added to PATH

**What it runs:**

```powershell
Set-Location $env:USERPROFILE\bootible\config\rog-ally
.\Run.ps1
```

---

## Steam Deck: Ansible Options

The Steam Deck uses Ansible. You can pass standard Ansible options.

### Common Options

```bash
# Dry run (check mode)
bootible --check

# Verbose output
bootible -v
bootible -vv
bootible -vvv

# Run specific tags/roles
bootible --tags ssh,tailscale

# Skip specific tags/roles
bootible --skip-tags decky

# Limit to specific config values
bootible -e "install_discord=true"
```

### Running Manually

```bash
cd ~/bootible/config/steamdeck

# Basic
ansible-playbook playbook.yml --ask-become-pass

# With private config
ansible-playbook playbook.yml --ask-become-pass \
  -e @../private/device/steamdeck/MySteamDeck/config.yml \
  -e device_instance=MySteamDeck

# Check mode (dry run)
ansible-playbook playbook.yml --check --ask-become-pass
```

### Available Tags

Tags let you run specific parts:

| Tag | Description |
|-----|-------------|
| `always` | Always runs (pre-tasks, post-tasks) |
| `base` | Base setup (Flathub, hostname) |
| `apps`, `flatpak` | Flatpak applications |
| `ssh`, `remote` | SSH configuration |
| `tailscale`, `vpn` | Tailscale VPN |
| `remote_desktop`, `streaming` | Sunshine/remote desktop |
| `decky`, `plugins`, `gaming` | Decky Loader |
| `proton`, `wine` | Proton tools |
| `emulation`, `roms` | EmuDeck |
| `stickdeck`, `controller` | StickDeck |
| `waydroid`, `android` | Waydroid |
| `distrobox`, `containers` | Distrobox apps |

**Examples:**

```bash
# Only SSH and Tailscale
bootible --tags ssh,tailscale

# Everything except Decky
bootible --skip-tags decky

# Only gaming-related
bootible --tags gaming
```

---

## ROG Ally: PowerShell Options

### Run.ps1 Parameters

```powershell
# Dry run
.\Run.ps1 -DryRun

# Specific modules
.\Run.ps1 -Tags base,apps

# Skip modules
.\Run.ps1 -SkipTags debloat

# Verbose
.\Run.ps1 -Verbose
```

### Available Tags

| Tag | Description |
|-----|-------------|
| `validate` | Package validation (dry-run only) |
| `base` | Hostname, network, winget |
| `apps` | Desktop applications |
| `gaming` | Game platforms |
| `streaming` | Streaming clients |
| `remote_access` | VPN, remote desktop |
| `ssh` | OpenSSH configuration |
| `emulation` | EmuDeck |
| `rog_ally` | Device-specific tools |
| `optimization` | Gaming tweaks |
| `debloat` | Privacy settings |

**Examples:**

```powershell
# Only base and gaming
.\Run.ps1 -Tags base,gaming

# Skip privacy tweaks
.\Run.ps1 -SkipTags debloat

# Dry run specific modules
.\Run.ps1 -Tags optimization -DryRun
```

---

## Reference

#### Environment Variables

=== "Steam Deck"

    | Variable | Description |
    |----------|-------------|
    | `BOOTIBLE_PRIVATE_REPO` | Override private repo path |
    | `BOOTIBLE_INSTANCE` | Override device instance |
    | `GITHUB_TOKEN` | GitHub API token |

=== "ROG Ally"

    | Variable | Description |
    |----------|-------------|
    | `BOOTIBLE_PRIVATE_REPO` | Override private repo path |
    | `BOOTIBLE_INSTANCE` | Override device instance |

#### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | General error |
| `2` | Configuration error |
| `3` | Network error |
| `4` | User cancelled |

#### Logging

=== "Steam Deck"

    ```
    private/device/steamdeck/<instance>/Logs/
    └── YYYY-MM-DD_HHMMSS_<hostname>_<mode>.log
    ```

=== "ROG Ally"

    ```
    private\device\rog-ally\<instance>\Logs\
    ```

Logs are automatically pushed to your private repo after each run.
