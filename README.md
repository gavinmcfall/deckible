# Deckible

**Deck** + Ans**ible** = Automated Steam Deck setup.

Deckible configures your Steam Deck with a single command. Apps, plugins, remote access, emulation - all configurable, all automated.

## Features

- **Desktop Apps**: Discord, Spotify, Firefox, VLC, Plex, and 30+ more via Flatpak
- **Gaming Enhancements**: Decky Loader + 20 plugins, Proton-GE, Protontricks
- **Remote Access**: SSH, Tailscale VPN, Sunshine game streaming
- **Game Streaming**: Moonlight, Chiaki (PlayStation), Greenlight (Xbox)
- **Emulation**: EmuDeck download (run GUI wizard after)
- **Password Managers**: 1Password, Bitwarden, KeePassXC, Proton Pass (Flatpak or Distrobox)

Everything survives SteamOS updates.

## Quick Start

### Switch to Desktop Mode

1. Press the **Steam** button
2. Select **Power** → **Switch to Desktop**
3. Wait for Desktop Mode to load

> **Tip**: To use the on-screen keyboard, make sure Steam is running in Desktop Mode.
> Press **Steam + X** to toggle the keyboard. If it doesn't work, launch Steam from
> the application menu first.

### Open a Terminal

1. Click the application menu (bottom left corner)
2. Search for "Konsole" or find it under **System** → **Konsole**

### Run These Commands

```bash
# 1. Set sudo password (if not already done)
passwd

# 2. Install Ansible
sudo steamos-readonly disable
sudo pacman -S ansible
sudo steamos-readonly enable

# 3. Clone and run
git clone https://github.com/gavinmcfall/deckible.git
cd deckible
./setup.sh
ansible-playbook playbook.yml --ask-become-pass
```

> **Keyboard tip**: Use **Steam + X** to bring up the on-screen keyboard when
> entering your password or typing commands.

## Configuration

### Option 1: Edit Directly (Simple)

Edit `group_vars/all.yml` to enable/disable features:

```yaml
# Apps
install_discord: true
install_spotify: true
install_plex: true

# Gaming
install_decky: true
install_proton_ge: true

# Remote Access
install_ssh: true
install_tailscale: true
```

### Option 2: Private Overlay (Recommended)

Keep your personal settings in a separate private repository:

```bash
./setup.sh git@github.com:YOUR_USERNAME/your-private-repo.git
```

Your private repo overrides defaults:

```
deckible-private/
├── group_vars/
│   └── all.yml          # Your settings (overrides deckible defaults)
└── files/
    └── appimages/
        └── EmuDeck EA SteamOS.desktop.download  # Patreon files, etc.
```

Benefits:
- Keep deckible updated without losing your settings
- Store private files (Patreon downloads) securely
- Share your Deck config across devices

## Run Specific Components

Use tags to run only what you need:

```bash
# Just desktop apps
ansible-playbook playbook.yml --tags apps --ask-become-pass

# Just gaming stuff (Decky, Proton)
ansible-playbook playbook.yml --tags gaming --ask-become-pass

# Just remote access (SSH, Tailscale)
ansible-playbook playbook.yml --tags remote --ask-become-pass

# Just emulation
ansible-playbook playbook.yml --tags emulation --ask-become-pass
```

Available tags: `base`, `apps`, `flatpak`, `ssh`, `tailscale`, `remote_desktop`, `remote`, `decky`, `plugins`, `proton`, `gaming`, `emulation`, `distrobox`

## What Gets Installed

### Desktop Apps (Flatpak)

| App | Variable | Default |
|-----|----------|---------|
| Discord | `install_discord` | false |
| Spotify | `install_spotify` | false |
| VLC | `install_vlc` | false |
| Firefox | `install_firefox` | false |
| Chromium | `install_chromium` | false |
| VS Code | `install_vscode` | false |
| OBS Studio | `install_obs` | false |
| Flatseal | `install_flatseal` | true |

### Game Streaming

| App | Variable | Default | Description |
|-----|----------|---------|-------------|
| Moonlight | `install_moonlight` | false | Stream FROM PC |
| Chiaki4deck | `install_chiaki` | false | PlayStation Remote Play |
| Greenlight | `install_greenlight` | false | Xbox/xCloud streaming |
| Sunshine | `install_sunshine` | false | Stream TO other devices |

### Media & Productivity

| App | Variable | Default |
|-----|----------|---------|
| Plex | `install_plex` | false |
| Jellyfin | `install_jellyfin` | false |
| Syncthing | `install_syncthing` | false |
| LibreOffice | `install_libreoffice` | false |
| GIMP | `install_gimp` | false |
| Thunderbird | `install_thunderbird` | false |

### Gaming Launchers

| App | Variable | Default | Description |
|-----|----------|---------|-------------|
| Heroic | `install_heroic` | false | Epic/GOG games |
| Lutris | `install_lutris` | false | Universal launcher |
| Bottles | `install_bottles` | false | Wine prefix manager |

### Password Managers

```yaml
password_manager: "none"           # 1password, bitwarden, keepassxc, protonpass, none
password_manager_install_method: "flatpak"  # flatpak or distrobox
```

Distrobox gives full features (system auth, SSH agent) but requires more setup.

### Decky Plugins

All plugins are configurable in `decky_plugins:`. Key plugins:

| Plugin | Default | Description |
|--------|---------|-------------|
| PowerTools | enabled | CPU/GPU control |
| ProtonDB Badges | enabled | Compatibility ratings |
| SteamGridDB | enabled | Custom artwork |
| CSS Loader | disabled | Visual themes |
| HLTB | disabled | Game completion times |

## After Running

### Decky Loader
1. Switch to Gaming Mode
2. Press `...` button (Quick Access Menu)
3. Look for Decky tab (plug icon)

### Tailscale (if installed)
1. Open Tailscale from Application Menu
2. Click "Log in"
3. Authorize the device

### EmuDeck (if installed)
1. Double-click EmuDeck on Desktop
2. Follow setup wizard
3. Copy ROMs to `~/Emulation/roms/<system>/`
4. Run Steam ROM Manager

### Proton-GE
Right-click game > Properties > Compatibility > Force specific tool > GE-Proton

## Factory Reset Recovery

After a Steam Deck factory reset:

1. Complete initial setup wizard
2. Update SteamOS fully (Settings > System > Updates)
3. Pair Bluetooth devices (controllers, headphones)
4. Update dock firmware if using official dock
5. Run deckible:
   ```bash
   passwd  # Set sudo password
   sudo steamos-readonly disable && sudo pacman -S ansible && sudo steamos-readonly enable
   git clone https://github.com/gavinmcfall/deckible.git
   cd deckible
   ./setup.sh  # Optionally link private repo
   ansible-playbook playbook.yml --ask-become-pass
   ```

## File Structure

```
deckible/
├── setup.sh                 # Setup script
├── playbook.yml             # Main playbook
├── ansible.cfg              # Ansible configuration
├── inventory.yml            # Localhost inventory
├── group_vars/
│   └── all.yml              # Default configuration
├── files/                   # Local files (gitignored)
├── private/                 # Your private overlay (gitignored)
└── roles/
    ├── base/                # Flathub setup
    ├── flatpak_apps/        # Desktop applications
    ├── ssh/                 # SSH server
    ├── tailscale/           # Tailscale VPN
    ├── remote_desktop/      # Sunshine/VNC
    ├── decky/               # Decky Loader + plugins
    ├── proton/              # Proton-GE, Protontricks
    ├── emulation/           # EmuDeck
    └── distrobox/           # Containerized apps
```

## Creating a Private Overlay Repo

A private overlay repo lets you:
- Keep your personal settings separate from deckible
- Store private files (Patreon downloads, etc.) securely
- Update deckible without losing your customizations
- Sync your config across multiple Steam Decks

### Step 1: Create the Repository

**On GitHub:**
1. Go to [github.com/new](https://github.com/new)
2. Name it something like `deckible-private` or `steamdeck-config`
3. **Important**: Set visibility to **Private**
4. Check "Add a README file"
5. Click "Create repository"

### Step 2: Clone and Set Up Structure

```bash
# Clone your new private repo
git clone git@github.com:YOUR_USERNAME/deckible-private.git
cd deckible-private

# Create the required directory structure
mkdir -p group_vars files/appimages files/flatpaks

# Create .gitkeep files to track empty directories
touch files/appimages/.gitkeep files/flatpaks/.gitkeep
```

### Step 3: Create Your Configuration

Copy the default config and customize it:

```bash
# If you have deckible cloned already:
cp ../deckible/group_vars/all.yml group_vars/all.yml

# Or download it directly:
curl -o group_vars/all.yml https://raw.githubusercontent.com/gavinmcfall/deckible/main/group_vars/all.yml
```

Edit `group_vars/all.yml` to enable what you want:

```yaml
# Example customizations
install_discord: true
install_spotify: true
install_plex: true

install_ssh: true
install_tailscale: true

install_decky: true
install_emudeck: true

password_manager: "1password"
password_manager_install_method: "distrobox"
```

### Step 4: Add Private Files (Optional)

If you have Patreon/early access files:

```bash
# EmuDeck Early Access
cp ~/Downloads/EmuDeck\ EA\ SteamOS.desktop.download files/appimages/

# Any local .flatpak files
cp ~/Downloads/SomeApp.flatpak files/flatpaks/
```

### Step 5: Commit and Push

```bash
git add -A
git commit -m "Initial deckible private config"
git push
```

### Step 6: Link to Deckible

On your Steam Deck (or wherever you run deckible):

```bash
cd deckible
./setup.sh git@github.com:YOUR_USERNAME/deckible-private.git
```

This clones your private repo into `deckible/private/`.

### Final Structure

Your private repo should look like this:

```
deckible-private/
├── README.md
├── group_vars/
│   └── all.yml              # Your personal settings
└── files/
    ├── appimages/
    │   ├── .gitkeep
    │   └── EmuDeck EA SteamOS.desktop.download  # Optional
    └── flatpaks/
        └── .gitkeep
```

### Updating Your Config

After making changes to your private repo:

```bash
# In your private repo
git add -A && git commit -m "Update config" && git push

# On your Steam Deck, pull the changes
cd deckible/private
git pull

# Re-run the playbook
cd ..
ansible-playbook playbook.yml --ask-become-pass
```

### Multiple Steam Decks

Your private config works on any Steam Deck:

```bash
# On a new/different Deck
git clone https://github.com/gavinmcfall/deckible.git
cd deckible
./setup.sh git@github.com:YOUR_USERNAME/deckible-private.git
ansible-playbook playbook.yml --ask-become-pass
```

Same config, same apps, every time.

## Troubleshooting

### "Sudo password required"
Run with `--ask-become-pass` or set password with `passwd`.

### Flatpak install fails
```bash
flatpak update
```

### Decky not showing
Restart Gaming Mode: hold power > Restart Steam

### After SteamOS update
Re-run the playbook. You may need to reinstall Ansible first.

## Contributing

PRs welcome! Please:
- Test on actual Steam Deck hardware
- Keep defaults conservative (opt-in, not opt-out)
- Add comments explaining what tasks do

## License

MIT
