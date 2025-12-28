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
    if ! sudo -v < /dev/tty; then
        echo -e "${RED}✗${NC} Sudo authentication failed"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Sudo access confirmed"
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
            if [[ -f "$HOME/.bashrc" ]] && ! grep -q '$HOME/.local/bin' "$HOME/.bashrc"; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
                echo -e "${GREEN}✓${NC} Added ~/.local/bin to PATH in .bashrc"
            fi
            return 0
        fi
    fi

    # Fall back to pacman
    echo "  Using pacman..."
    sudo steamos-readonly disable 2>/dev/null || true

    # Refresh keyring to avoid PGP signature errors
    echo "  Refreshing pacman keyring..."
    sudo pacman-key --init 2>/dev/null || true
    sudo pacman-key --populate archlinux 2>/dev/null || true
    sudo pacman -Sy --noconfirm archlinux-keyring 2>/dev/null || true

    sudo pacman -S --noconfirm ansible
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

# Run device-specific playbook
run_playbook() {
    echo ""
    echo -e "${BLUE}→${NC} Running $DEVICE configuration..."
    echo ""

    cd "$BOOTIBLE_DIR/config/$DEVICE"

    case $DEVICE in
        steamdeck)
            ansible-playbook playbook.yml --ask-become-pass < /dev/tty
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
    install_ansible
    echo ""
    clone_bootible
    echo ""
    setup_private
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
    echo "  cd ~/bootible && git pull && ./bootstrap.sh"
}

main "$@"
