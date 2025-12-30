#!/bin/bash
# Bootible - Universal Bootstrap Script
# ======================================
# Detects your device and runs the appropriate configuration.
#
# Supported Devices:
#   - Steam Deck (SteamOS/Arch Linux)
#   - ROG Ally X (Windows - redirects to PowerShell)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/deck.sh | bash
#
# Or with a private repo:
#   curl -fsSL https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/deck.sh | bash -s -- git@github.com:USER/bootible-private.git

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PRIVATE_REPO="${1:-}"
BOOTIBLE_DIR="$HOME/bootible"
DEVICE=""

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      Bootible                              ║"
echo "║         Universal Gaming Device Configuration              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Detect device type
detect_device() {
    echo -e "${BLUE}→${NC} Detecting device..."

    # Check for Windows (shouldn't happen via bash, but just in case)
    if [[ "$OS" == "Windows_NT" ]]; then
        echo -e "${YELLOW}!${NC} Windows detected - use targets/ally.ps1 instead"
        echo ""
        echo "Run this in PowerShell:"
        echo "  irm https://raw.githubusercontent.com/gavinmcfall/bootible/main/targets/ally.ps1 | iex"
        exit 0
    fi

    # Check for SteamOS / Steam Deck
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release

        if [[ "$ID" == "steamos" ]] || [[ "$VARIANT_ID" == "steamdeck" ]]; then
            DEVICE="steamdeck"
            echo -e "${GREEN}✓${NC} Detected: Steam Deck (SteamOS)"
            return 0
        fi

        if [[ "$ID" == "arch" ]] || [[ "$ID_LIKE" == *"arch"* ]]; then
            DEVICE="steamdeck"
            echo -e "${GREEN}✓${NC} Detected: Arch-based system (using Steam Deck config)"
            return 0
        fi
    fi

    # Check for ROG Ally on Linux (unlikely but possible with Bazzite etc.)
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        PRODUCT=$(cat /sys/class/dmi/id/product_name)
        if [[ "$PRODUCT" == *"ROG Ally"* ]]; then
            DEVICE="steamdeck"  # Use Steam Deck config for Linux on ROG Ally
            echo -e "${GREEN}✓${NC} Detected: ROG Ally (Linux) - using Steam Deck config"
            return 0
        fi
    fi

    echo -e "${YELLOW}!${NC} Unknown device - defaulting to Steam Deck configuration"
    DEVICE="steamdeck"
}

# Check for sudo password
check_sudo() {
    echo -e "${BLUE}→${NC} Checking sudo access..."
    if sudo -n true 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Sudo access confirmed"
        return 0
    fi

    # Check if password is set
    if passwd -S "$USER" 2>/dev/null | grep -q " NP "; then
        echo -e "${YELLOW}!${NC} No sudo password set"
        echo ""
        echo "You need to set a password first. Run this command:"
        echo ""
        echo -e "  ${GREEN}passwd${NC}"
        echo ""
        echo "Then re-run the bootstrap script."
        exit 1
    fi

    # Verify sudo works
    echo "Enter your sudo password to continue:"
    # shellcheck disable=SC2024  # Intentional: redirect stdin from tty, not stdout
    if ! sudo -v < /dev/tty; then
        echo -e "${RED}✗${NC} Sudo authentication failed"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Sudo access confirmed"
}

# Create Btrfs snapshot (restore point)
create_snapshot() {
    echo -e "${BLUE}→${NC} Creating system snapshot..."

    # Check if root is Btrfs
    if ! findmnt -n -o FSTYPE / | grep -q btrfs; then
        echo -e "${YELLOW}!${NC} Filesystem is not Btrfs - skipping snapshot"
        return 0
    fi

    SNAPSHOT_DIR="/.snapshots"
    SNAPSHOT_NAME="pre-bootible-$(date +%Y%m%d-%H%M%S)"

    # Create snapshots directory if needed
    if [[ ! -d "$SNAPSHOT_DIR" ]]; then
        sudo mkdir -p "$SNAPSHOT_DIR"
    fi

    # Create the snapshot
    if sudo btrfs subvolume snapshot / "$SNAPSHOT_DIR/$SNAPSHOT_NAME" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Snapshot created: $SNAPSHOT_DIR/$SNAPSHOT_NAME"
        echo ""
        echo -e "  ${CYAN}To restore if needed:${NC}"
        echo "    sudo btrfs subvolume set-default $SNAPSHOT_DIR/$SNAPSHOT_NAME"
        echo "    sudo reboot"
        echo ""
    else
        echo -e "${YELLOW}!${NC} Could not create snapshot (may need root subvolume)"
        echo "  Continuing without snapshot..."
    fi
}

# Install Ansible (for Steam Deck)
install_ansible() {
    if command -v ansible-playbook &> /dev/null; then
        echo -e "${GREEN}✓${NC} Ansible already installed"
        return 0
    fi

    echo -e "${BLUE}→${NC} Installing Ansible..."

    # Try pip first (survives SteamOS updates)
    if command -v pip &> /dev/null || command -v pip3 &> /dev/null; then
        echo "  Using pip (recommended - survives updates)..."
        pip3 install --user ansible || pip install --user ansible
        export PATH="$HOME/.local/bin:$PATH"
        if command -v ansible-playbook &> /dev/null; then
            echo -e "${GREEN}✓${NC} Ansible installed via pip"
            # Persist PATH for future sessions if not already in bashrc
            # shellcheck disable=SC2016  # Intentional: check for literal string, not expanded
            if [[ -f "$HOME/.bashrc" ]] && ! grep -q '$HOME/.local/bin' "$HOME/.bashrc"; then
                # shellcheck disable=SC2016  # Intentional: write literal $HOME, not expanded
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
                echo -e "${GREEN}✓${NC} Added ~/.local/bin to PATH in .bashrc"
            fi
            return 0
        fi
    fi

    # Fall back to pacman
    echo "  Using pacman..."

    # Set trap to restore read-only mode on exit/error
    trap 'sudo steamos-readonly enable 2>/dev/null' EXIT
    sudo steamos-readonly disable 2>/dev/null || true

    # Refresh keyring to avoid PGP signature errors
    echo "  Refreshing pacman keyring..."
    sudo pacman-key --init 2>/dev/null || true
    sudo pacman-key --populate archlinux 2>/dev/null || true
    sudo pacman -Sy --noconfirm archlinux-keyring 2>/dev/null || true

    sudo pacman -S --noconfirm ansible

    # Clear trap and restore read-only (trap will fire on exit anyway)
    trap - EXIT
    sudo steamos-readonly enable 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Ansible installed via pacman"
}

# Clone bootible
clone_bootible() {
    if [[ -d "$BOOTIBLE_DIR" ]]; then
        echo -e "${BLUE}→${NC} Updating existing bootible..."
        cd "$BOOTIBLE_DIR"
        git pull
    else
        echo -e "${BLUE}→${NC} Cloning bootible..."
        git clone https://github.com/gavinmcfall/bootible.git "$BOOTIBLE_DIR"
        cd "$BOOTIBLE_DIR"
    fi
    echo -e "${GREEN}✓${NC} Bootible ready at $BOOTIBLE_DIR"
}

# Setup private repo if provided
setup_private() {
    if [[ -n "$PRIVATE_REPO" ]]; then
        echo -e "${BLUE}→${NC} Setting up private configuration..."

        PRIVATE_PATH="$BOOTIBLE_DIR/private"

        if [[ -d "$PRIVATE_PATH/.git" ]]; then
            cd "$PRIVATE_PATH"
            git pull
            cd "$BOOTIBLE_DIR"
        else
            rm -rf "$PRIVATE_PATH"
            git clone "$PRIVATE_REPO" "$PRIVATE_PATH"
        fi

        echo -e "${GREEN}✓${NC} Private configuration linked"
    fi
}

# Select config file (if multiple exist in private)
select_config() {
    SELECTED_CONFIG=""
    PRIVATE_DEVICE_DIR="$BOOTIBLE_DIR/private/$DEVICE"
    DEFAULT_CONFIG="$BOOTIBLE_DIR/config/$DEVICE/config.yml"

    # Check if private device config directory exists
    if [[ ! -d "$PRIVATE_DEVICE_DIR" ]]; then
        echo -e "${BLUE}→${NC} Using default configuration"
        SELECTED_CONFIG="$DEFAULT_CONFIG"
        return
    fi

    # Find config files in private directory
    CONFIG_FILES=()
    while IFS= read -r -d '' file; do
        CONFIG_FILES+=("$file")
    done < <(find "$PRIVATE_DEVICE_DIR" -maxdepth 1 -name "config*.yml" -print0 2>/dev/null | sort -z)

    # If no private configs, use default
    if [[ ${#CONFIG_FILES[@]} -eq 0 ]]; then
        echo -e "${BLUE}→${NC} Using default configuration"
        SELECTED_CONFIG="$DEFAULT_CONFIG"
        return
    fi

    # If only one config, use it automatically
    if [[ ${#CONFIG_FILES[@]} -eq 1 ]]; then
        SELECTED_CONFIG="${CONFIG_FILES[0]}"
        local config_name
        config_name=$(basename "$SELECTED_CONFIG")
        echo -e "${GREEN}✓${NC} Using config: $config_name"
        return
    fi

    # Multiple configs - let user choose
    echo -e "${CYAN}Multiple configurations found:${NC}"
    echo ""
    for i in "${!CONFIG_FILES[@]}"; do
        local config_name
        config_name=$(basename "${CONFIG_FILES[$i]}")
        local num=$((i + 1))
        echo -e "  ${YELLOW}$num${NC}) $config_name"
    done
    echo ""

    while true; do
        echo -n "Select configuration [1-${#CONFIG_FILES[@]}]: "
        read -r selection < /dev/tty

        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#CONFIG_FILES[@]} ]]; then
            local idx=$((selection - 1))
            SELECTED_CONFIG="${CONFIG_FILES[$idx]}"
            local config_name
            config_name=$(basename "$SELECTED_CONFIG")
            echo ""
            echo -e "${GREEN}✓${NC} Selected: $config_name"
            return
        else
            echo -e "${RED}Invalid selection. Please enter a number between 1 and ${#CONFIG_FILES[@]}${NC}"
        fi
    done
}

# Run device-specific playbook
run_playbook() {
    echo ""
    echo -e "${BLUE}→${NC} Running $DEVICE configuration..."
    echo ""

    cd "$BOOTIBLE_DIR/config/$DEVICE"

    # Build extra vars for ansible if using private config
    EXTRA_VARS=""
    if [[ -n "$SELECTED_CONFIG" && "$SELECTED_CONFIG" != "$BOOTIBLE_DIR/config/$DEVICE/config.yml" ]]; then
        EXTRA_VARS="-e @$SELECTED_CONFIG"
        echo -e "${BLUE}→${NC} Config: $(basename "$SELECTED_CONFIG")"
        echo ""
    fi

    case $DEVICE in
        steamdeck)
            if [[ -n "$EXTRA_VARS" ]]; then
                # shellcheck disable=SC2086  # Intentional word splitting for ansible args
                ansible-playbook playbook.yml $EXTRA_VARS --ask-become-pass < /dev/tty
            else
                ansible-playbook playbook.yml --ask-become-pass < /dev/tty
            fi
            ;;
        *)
            echo -e "${RED}✗${NC} Unknown device type: $DEVICE"
            exit 1
            ;;
    esac
}

# Main
main() {
    detect_device
    echo ""
    check_sudo
    echo ""
    create_snapshot
    echo ""
    install_ansible
    echo ""
    clone_bootible
    echo ""
    setup_private
    echo ""
    select_config
    echo ""
    run_playbook

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   Setup Complete!                          ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Device: $DEVICE"
    echo ""
    echo "Next steps:"
    case $DEVICE in
        steamdeck)
            echo "  • Switch to Gaming Mode to see Decky plugins"
            echo "  • Run EmuDeck wizard if you enabled emulation"
            echo "  • Check README for post-install configuration"
            ;;
    esac
    echo ""
    echo "To re-run or update:"
    echo "  cd ~/bootible && git pull && ./targets/deck.sh"
}

main "$@"
