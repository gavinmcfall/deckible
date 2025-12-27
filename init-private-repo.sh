#!/bin/bash
# Bootible - Initialize Private Configuration Repository
# =======================================================
# Creates a new Git repository with the structure needed for
# private Bootible configuration. Push this to your own private
# GitHub/GitLab repo.
#
# Usage:
#   ./init-private-repo.sh
#   # Then: cd private && git remote add origin <your-repo-url>
#   # Then: git push -u origin main

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_PATH="$SCRIPT_DIR/private"

echo -e "${BLUE}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║       Bootible - Initialize Private Repository             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [[ -d "$PRIVATE_PATH/.git" ]]; then
    echo -e "${YELLOW}!${NC} Private repo already initialized"
    exit 0
fi

echo -e "${BLUE}→${NC} Creating private repository structure..."

# Create directories for each device
mkdir -p "$PRIVATE_PATH/steamdeck/files/flatpaks"
mkdir -p "$PRIVATE_PATH/steamdeck/files/appimages"
mkdir -p "$PRIVATE_PATH/rogally/files/installers"
mkdir -p "$PRIVATE_PATH/rogally/files/configs"

# Create Steam Deck example config
cat > "$PRIVATE_PATH/steamdeck/config.yml" << 'EOF'
# My Steam Deck Configuration
# ============================
# This file overrides defaults from steamdeck/config.yml
# Only include settings you want to change.

---
# Apps I use
install_discord: true
install_spotify: true
install_vlc: true

# Password manager
password_manager: "1password"
password_manager_install_method: "distrobox"

# Streaming
install_moonlight: true
install_chiaki: true
install_greenlight: true

# Remote access
install_ssh: true
install_tailscale: true
install_remote_desktop: true
install_sunshine: true

# Emulation
install_emudeck: true

# Gaming
install_decky: true
install_proton_tools: true

# All Decky plugins enabled
decky_plugins:
  powertools:
    enabled: true
  protondb_badges:
    enabled: true
  steamgriddb:
    enabled: true
  css_loader:
    enabled: true
EOF

# Create ROG Ally example config
cat > "$PRIVATE_PATH/rogally/config.yml" << 'EOF'
# My ROG Ally X Configuration
# ============================
# This file overrides defaults from rogally/config.yml
# Only include settings you want to change.

---
# Apps I use
install_discord: true
install_spotify: true
install_vlc: true

# Password manager
password_manager: "1password"

# Gaming platforms
install_steam: true
install_gog_galaxy: true
install_epic_launcher: true

# Streaming
install_moonlight: true
install_chiaki: true

# Remote access
install_tailscale: true

# Emulation
install_emulation: true
install_retroarch: true
install_dolphin: true
install_pcsx2: true
install_duckstation: true

# Paths
games_path: "D:\\Games"
roms_path: "D:\\Emulation\\ROMs"
bios_path: "D:\\Emulation\\BIOS"
EOF

# Create README
cat > "$PRIVATE_PATH/README.md" << 'EOF'
# Bootible Private Configuration

This is my private overlay repository for [bootible](https://github.com/gavinmcfall/bootible).

## Structure

```
├── steamdeck/
│   ├── config.yml           # Steam Deck settings
│   └── files/
│       ├── flatpaks/        # Local .flatpak files
│       └── appimages/       # Local AppImages
│
└── rogally/
    ├── config.yml           # ROG Ally settings
    └── files/
        ├── installers/      # Local installers
        └── configs/         # App config files
```

## Usage

1. Clone bootible:
   ```bash
   git clone https://github.com/gavinmcfall/bootible.git
   cd bootible
   ```

2. Link this private repo:
   ```bash
   # Linux/Steam Deck
   ./bootstrap.sh git@github.com:YOUR_USER/bootible-private.git

   # Windows/ROG Ally (PowerShell)
   $env:BOOTIBLE_PRIVATE = "https://github.com/YOUR_USER/bootible-private.git"
   .\bootstrap.ps1
   ```

3. Run the setup - it will automatically use your private config!
EOF

# Create .gitignore
cat > "$PRIVATE_PATH/.gitignore" << 'EOF'
# Don't commit large binary files
*.exe
*.msi
*.zip
*.7z
*.flatpak
*.AppImage

# But keep directory structure
!.gitkeep

# Sensitive files
*.key
*.pem
credentials*
*secret*
EOF

# Add .gitkeep files
touch "$PRIVATE_PATH/steamdeck/files/flatpaks/.gitkeep"
touch "$PRIVATE_PATH/steamdeck/files/appimages/.gitkeep"
touch "$PRIVATE_PATH/rogally/files/installers/.gitkeep"
touch "$PRIVATE_PATH/rogally/files/configs/.gitkeep"

# Initialize git repo
cd "$PRIVATE_PATH"
git init
git add .
git commit -m "Initial private configuration for bootible"

echo ""
echo -e "${GREEN}✓${NC} Private repository initialized at: $PRIVATE_PATH"
echo ""
echo "Next steps:"
echo "  1. Create a private repo on GitHub/GitLab"
echo "  2. cd private"
echo "  3. git remote add origin <your-repo-url>"
echo "  4. git push -u origin main"
echo ""
echo "Edit the config files for your devices:"
echo "  - private/steamdeck/config.yml"
echo "  - private/rogally/config.yml"
echo ""
