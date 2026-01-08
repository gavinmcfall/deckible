#!/bin/bash
# Bootible - Initialize Private Configuration Repository
# =======================================================
# Creates a new Git repository with the structure needed for
# private Bootible configuration.
#
# Usage:
#   ./init-private-repo.sh
#   cd private
#   git remote add origin git@github.com:YOUR_USER/YOUR_REPO.git
#   git push -u origin main

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRIVATE_PATH="$SCRIPT_DIR/private"
BOOTIBLE_RAW_URL="https://raw.githubusercontent.com/bootible/bootible/main"

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║       Bootible - Initialize Private Repository             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

if [[ -d "$PRIVATE_PATH/.git" ]]; then
    echo -e "${YELLOW}!${NC} Private repo already initialized at: $PRIVATE_PATH"
    echo ""
    echo "To add a new device, create:"
    echo "  private/device/<platform>/<DeviceName>/"
    echo "  └── config.yml"
    exit 0
fi

# =============================================================================
# Gather device information
# =============================================================================

echo -e "${BLUE}→${NC} Setting up your first device..."
echo ""

# Select device type
echo "Which device type are you configuring?"
echo ""
echo -e "  ${YELLOW}1${NC}) ROG Ally / Windows Handheld"
echo -e "  ${YELLOW}2${NC}) Steam Deck / SteamOS"
echo ""
read -rp "Select [1-2]: " device_choice

case "$device_choice" in
    1) DEVICE_TYPE="rog-ally" ;;
    2) DEVICE_TYPE="steamdeck" ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Get device name
echo ""
echo "What would you like to name this device?"
echo -e "${YELLOW}Tip:${NC} Use your hostname or a memorable name (e.g., 'GameDeck', 'MyAlly')"
echo ""
read -rp "Device name: " DEVICE_NAME

# Validate device name (no spaces, alphanumeric + dash/underscore)
if [[ ! "$DEVICE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "${RED}Invalid name.${NC} Use only letters, numbers, dashes, and underscores."
    exit 1
fi

echo ""
echo -e "${GREEN}✓${NC} Creating config for: ${CYAN}$DEVICE_NAME${NC} ($DEVICE_TYPE)"
echo ""

# =============================================================================
# Create directory structure
# =============================================================================

echo -e "${BLUE}→${NC} Creating private repository structure..."

# Device instance directory
mkdir -p "$PRIVATE_PATH/device/$DEVICE_TYPE/$DEVICE_NAME/Logs"
mkdir -p "$PRIVATE_PATH/device/$DEVICE_TYPE/$DEVICE_NAME/Images"

# Shared directories
mkdir -p "$PRIVATE_PATH/scripts"
mkdir -p "$PRIVATE_PATH/ssh-keys"

# =============================================================================
# Pull latest config from bootible
# =============================================================================

echo -e "${BLUE}→${NC} Fetching latest config template from bootible..."

CONFIG_URL="$BOOTIBLE_RAW_URL/config/$DEVICE_TYPE/config.yml"
CONFIG_DEST="$PRIVATE_PATH/device/$DEVICE_TYPE/$DEVICE_NAME/config.yml"

if curl -fsSL "$CONFIG_URL" -o "$CONFIG_DEST" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Downloaded config template"
else
    # Fallback to local copy if network fails
    echo -e "${YELLOW}!${NC} Network unavailable, using local template..."
    if [[ -f "$SCRIPT_DIR/config/$DEVICE_TYPE/config.yml" ]]; then
        cp "$SCRIPT_DIR/config/$DEVICE_TYPE/config.yml" "$CONFIG_DEST"
    else
        echo -e "${RED}✗${NC} No config template available"
        exit 1
    fi
fi

# =============================================================================
# Create README
# =============================================================================

cat > "$PRIVATE_PATH/README.md" << EOF
# Bootible Private Configuration

My private overlay for [bootible](https://github.com/bootible/bootible).

## Structure

\`\`\`
├── device/                          # Device configurations
│   ├── rog-ally/
│   │   └── <DeviceName>/            # One folder per device
│   │       ├── config.yml           # Device configuration
│   │       ├── Logs/                # Run logs
│   │       └── Images/              # Wallpapers, avatars
│   └── steamdeck/
│       └── <DeviceName>/
│           └── ...
│
├── scripts/                         # Shared scripts (EmuDeck EA, etc.)
└── ssh-keys/                        # SSH public keys
\`\`\`

## How It Works

Bootible detects your device type from the URL, then prompts you to
select which device instance to configure:

\`\`\`
Select device:
  1) $DEVICE_NAME
  2) AnotherDevice

Select [1-2]:
\`\`\`

## Usage

### First Run (Bootstrap)

**Steam Deck:**
\`\`\`bash
curl -fsSL https://bootible.dev/deck | bash
\`\`\`

**ROG Ally:**
\`\`\`powershell
irm https://bootible.dev/rog | iex
\`\`\`

When prompted, enter your private repo: \`YOUR_USER/YOUR_REPO\`

### Re-run

\`\`\`bash
bootible
\`\`\`

## Adding More Devices

1. Create a new device folder:
   \`\`\`
   device/<platform>/<NewDeviceName>/
   ├── config.yml
   ├── Logs/
   └── Images/
   \`\`\`

2. Copy config from an existing device or download fresh:
   \`\`\`bash
   curl -fsSL https://raw.githubusercontent.com/bootible/bootible/main/config/<platform>/config.yml \\
     -o device/<platform>/<NewDeviceName>/config.yml
   \`\`\`

3. Run bootible - your new device will appear in the selection menu

## EmuDeck Early Access

If you have EmuDeck Patreon access, place scripts in \`scripts/\`:

| Platform | File |
|----------|------|
| Steam Deck | \`EmuDeck EA SteamOS.desktop.download\` |
| ROG Ally / Windows | \`EmuDeck EA Windows.bat\` |
EOF

# =============================================================================
# Create .gitignore
# =============================================================================

cat > "$PRIVATE_PATH/.gitignore" << 'EOF'
# Large binary files (download these, don't commit)
*.exe
*.msi
*.zip
*.7z
*.flatpak
*.AppImage

# Keep directory structure
!.gitkeep

# Sensitive files (private keys - only commit .pub files)
*.key
*.pem
id_*
!*.pub
credentials*
*secret*

# Editor/IDE
.vscode/
.idea/
*.swp
*~

# OS files
.DS_Store
Thumbs.db
EOF

# =============================================================================
# Create device README
# =============================================================================

mkdir -p "$PRIVATE_PATH/device"
cat > "$PRIVATE_PATH/device/README.md" << 'EOF'
# Device Configurations

Each subdirectory represents a device type (platform), and within each
platform are folders for individual devices (by name/hostname).

## Structure

```
device/
├── rog-ally/
│   ├── MyAlly/
│   │   ├── config.yml    # This device's settings
│   │   ├── Logs/         # Run logs (auto-pushed)
│   │   └── Images/       # Wallpapers, lockscreen, avatars
│   └── WorkAlly/
│       └── ...
└── steamdeck/
    └── GameDeck/
        └── ...
```

## Adding a New Device

1. Create folder: `device/<platform>/<DeviceName>/`
2. Add subdirectories: `Logs/`, `Images/`
3. Copy or download `config.yml`
4. Customize the config for your device
5. Run bootible - it will detect the new device
EOF

# Add .gitkeep files to preserve empty directories
touch "$PRIVATE_PATH/device/$DEVICE_TYPE/$DEVICE_NAME/Logs/.gitkeep"
touch "$PRIVATE_PATH/device/$DEVICE_TYPE/$DEVICE_NAME/Images/.gitkeep"
touch "$PRIVATE_PATH/scripts/.gitkeep"
touch "$PRIVATE_PATH/ssh-keys/.gitkeep"

# =============================================================================
# Initialize git repo
# =============================================================================

cd "$PRIVATE_PATH"
git init
git add .
git commit -m "Initial bootible private configuration

Device: $DEVICE_NAME ($DEVICE_TYPE)

🤖 Generated with bootible init-private-repo.sh"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Private Repository Initialized!               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Created:"
echo -e "  ${CYAN}device/$DEVICE_TYPE/$DEVICE_NAME/config.yml${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Create a private repo on GitHub:"
echo "     https://github.com/new"
echo ""
echo "  2. Push this repo:"
echo -e "     ${YELLOW}cd private${NC}"
echo -e "     ${YELLOW}git remote add origin git@github.com:YOUR_USER/YOUR_REPO.git${NC}"
echo -e "     ${YELLOW}git push -u origin main${NC}"
echo ""
echo "  3. Edit your device config:"
echo -e "     ${YELLOW}private/device/$DEVICE_TYPE/$DEVICE_NAME/config.yml${NC}"
echo ""
echo "  4. Run bootible on your device!"
echo ""
