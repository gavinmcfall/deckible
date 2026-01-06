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
        # --break-system-packages needed for PEP 668 (externally-managed-environment)
        pip3 install --user --break-system-packages ansible 2>/dev/null || \
        pip3 install --user ansible 2>/dev/null || \
        pip install --user --break-system-packages ansible 2>/dev/null || \
        pip install --user ansible
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

# =============================================================================
# GitHub Authentication (Device Flow)
# =============================================================================
# Provides QR code-based GitHub login for minimal typing on Steam Deck.
# Uses GitHub's OAuth Device Flow - scan QR with phone, authorize, done.

# Install GitHub CLI and dependencies
install_gh_cli() {
    local needs_install=false

    # Check for required tools
    if ! command -v gh &> /dev/null; then
        needs_install=true
    fi
    if ! command -v jq &> /dev/null; then
        needs_install=true
    fi
    if ! command -v qrencode &> /dev/null; then
        needs_install=true
    fi

    if [[ "$needs_install" == "false" ]]; then
        return 0
    fi

    echo -e "${BLUE}→${NC} Installing GitHub CLI and dependencies..."

    # Unlock filesystem temporarily
    trap 'sudo steamos-readonly enable 2>/dev/null' EXIT
    sudo steamos-readonly disable 2>/dev/null || true

    # Refresh keyring
    sudo pacman-key --init 2>/dev/null || true
    sudo pacman-key --populate archlinux 2>/dev/null || true

    # Install packages
    local packages=""
    command -v gh &> /dev/null || packages="$packages github-cli"
    command -v jq &> /dev/null || packages="$packages jq"
    command -v qrencode &> /dev/null || packages="$packages qrencode"

    if [[ -n "$packages" ]]; then
        # shellcheck disable=SC2086  # Intentional word splitting
        sudo pacman -S --noconfirm $packages
    fi

    # Restore read-only
    trap - EXIT
    sudo steamos-readonly enable 2>/dev/null || true

    echo -e "${GREEN}✓${NC} GitHub CLI ready"
}

# Display device code with QR in terminal
show_device_code() {
    local user_code="$1"
    local verification_url="https://github.com/login/device"

    clear
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                   GitHub Login Required                       ║${NC}"
    echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}║${NC}  Scan QR code with your phone, or visit:                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  ${GREEN}github.com/login/device${NC}                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║                                                               ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Generate QR code in terminal
    if command -v qrencode &> /dev/null; then
        qrencode -t ANSIUTF8 -m 2 "$verification_url"
    else
        echo -e "  ${YELLOW}(qrencode not installed - visit URL manually)${NC}"
    fi

    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}     Enter code: ${GREEN}${user_code}${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${YELLOW}Waiting for authorization...${NC}"
    echo ""
}

# Main GitHub authentication function
authenticate_github() {
    # GitHub CLI's OAuth client_id (public, used by gh CLI)
    local client_id="178c6fc778ccc68e1d6a"
    local scope="repo,read:org"

    echo -e "${BLUE}→${NC} Setting up GitHub authentication..."

    # Install gh CLI if needed
    install_gh_cli

    # Check if already authenticated
    if gh auth status &>/dev/null; then
        echo -e "${GREEN}✓${NC} Already authenticated with GitHub"
        return 0
    fi

    # Request device code from GitHub
    echo "  Requesting login code..."
    local response
    response=$(curl -s -X POST \
        -H "Accept: application/json" \
        -d "client_id=$client_id&scope=$scope" \
        "https://github.com/login/device/code")

    local device_code user_code interval expires_in
    device_code=$(echo "$response" | jq -r '.device_code // empty')
    user_code=$(echo "$response" | jq -r '.user_code // empty')
    interval=$(echo "$response" | jq -r '.interval // 5')
    expires_in=$(echo "$response" | jq -r '.expires_in // 900')

    if [[ -z "$device_code" || -z "$user_code" ]]; then
        echo -e "${RED}✗${NC} Failed to get device code from GitHub"
        echo "  Response: $response"
        return 1
    fi

    # Display QR code and user code
    show_device_code "$user_code"

    # Poll for token
    local poll_start max_wait current_interval access_token
    poll_start=$(date +%s)
    max_wait=$((expires_in > 300 ? 300 : expires_in))  # Cap at 5 minutes
    current_interval=$interval

    while true; do
        local now elapsed
        now=$(date +%s)
        elapsed=$((now - poll_start))

        if [[ $elapsed -ge $max_wait ]]; then
            echo ""
            echo -e "${RED}✗${NC} Authentication timed out"
            return 1
        fi

        sleep "$current_interval"

        # Poll for token
        local token_response
        token_response=$(curl -s -X POST \
            -H "Accept: application/json" \
            -d "client_id=$client_id&device_code=$device_code&grant_type=urn:ietf:params:oauth:grant-type:device_code" \
            "https://github.com/login/oauth/access_token")

        access_token=$(echo "$token_response" | jq -r '.access_token // empty')
        local error
        error=$(echo "$token_response" | jq -r '.error // empty')

        if [[ -n "$access_token" && "$access_token" != "null" ]]; then
            # Success!
            echo -e "\r  ${GREEN}✓ Authorized!${NC}                    "
            break
        elif [[ "$error" == "slow_down" ]]; then
            current_interval=$((current_interval + 5))
        elif [[ "$error" == "expired_token" ]]; then
            echo ""
            echo -e "${RED}✗${NC} Device code expired"
            return 1
        elif [[ "$error" == "access_denied" ]]; then
            echo ""
            echo -e "${RED}✗${NC} Authorization denied"
            return 1
        fi
        # authorization_pending is expected - continue polling
    done

    # Store token via gh CLI
    echo "  Storing credentials..."

    # Create secure temp file
    local token_file
    token_file="/tmp/gh-token-$(head -c 8 /dev/urandom | xxd -p).tmp"
    trap "rm -f '$token_file'" RETURN

    echo -n "$access_token" > "$token_file"
    chmod 600 "$token_file"

    # Pass to gh CLI
    if cat "$token_file" | gh auth login --with-token 2>/dev/null; then
        rm -f "$token_file"
        gh auth setup-git 2>/dev/null || true
        echo -e "${GREEN}✓${NC} GitHub authentication complete"

        # Export token for playbook
        GITHUB_TOKEN=$(gh auth token 2>/dev/null)
        export GITHUB_TOKEN
        return 0
    else
        rm -f "$token_file"
        echo -e "${RED}✗${NC} Failed to store GitHub credentials"
        return 1
    fi
}

# Check if GitHub auth is needed
needs_github_auth() {
    # Already authenticated?
    if command -v gh &> /dev/null && gh auth status &>/dev/null; then
        # Export existing token
        GITHUB_TOKEN=$(gh auth token 2>/dev/null)
        export GITHUB_TOKEN
        return 1  # No need to auth
    fi

    # Check config for enabled Decky plugins (>3 = rate limit risk)
    local config_file="$BOOTIBLE_DIR/config/$DEVICE/config.yml"
    local private_config="$BOOTIBLE_DIR/private/$DEVICE/config.yml"

    # Use private config if it exists
    if [[ -f "$private_config" ]]; then
        config_file="$private_config"
    fi

    if [[ -f "$config_file" ]]; then
        # Count enabled plugins in decky_plugins section
        local plugin_count
        plugin_count=$(awk '/^decky_plugins:/,/^[^ ]/' "$config_file" | grep -c "enabled: true" 2>/dev/null || echo 0)

        if [[ $plugin_count -gt 3 ]]; then
            return 0  # Need auth
        fi
    fi

    # Check if private repo uses SSH (needs auth for push)
    if [[ -n "$PRIVATE_REPO" && "$PRIVATE_REPO" == git@* ]]; then
        return 0  # Need auth for SSH
    fi

    return 1  # No need
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

# Setup private repo - prompt if not provided
setup_private() {
    PRIVATE_PATH="$BOOTIBLE_DIR/private"

    # If not provided via argument, prompt interactively
    if [[ -z "$PRIVATE_REPO" ]]; then
        echo ""
        echo -n "Do you have a private config repo? (y/N): "
        read -r response < /dev/tty

        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -n "Private repo (e.g., owner/repo): "
            read -r repo_path < /dev/tty

            if [[ -n "$repo_path" ]]; then
                PRIVATE_REPO="https://github.com/$repo_path.git"
            fi
        fi
    fi

    # If no private repo, skip
    if [[ -z "$PRIVATE_REPO" ]]; then
        return 0
    fi

    echo -e "${BLUE}→${NC} Setting up private configuration..."
    echo "  Repo: $PRIVATE_REPO"

    # Authenticate with GitHub if needed
    if ! gh auth status &>/dev/null 2>&1; then
        echo ""
        echo -e "${BLUE}→${NC} GitHub authentication required for private repo"
        authenticate_github || {
            echo -e "${YELLOW}!${NC} Skipping private repo (authentication failed)"
            return 0
        }
    fi

    # Clone or update private repo
    if [[ -d "$PRIVATE_PATH/.git" ]]; then
        echo "  Updating existing private config..."
        cd "$PRIVATE_PATH"
        git pull
        cd "$BOOTIBLE_DIR"
    else
        rm -rf "$PRIVATE_PATH"
        echo "  Cloning private config..."
        if command -v gh &>/dev/null; then
            # Extract owner/repo from URL
            local repo_slug
            repo_slug=$(echo "$PRIVATE_REPO" | sed 's|https://github.com/||' | sed 's|\.git$||' | sed 's|git@github.com:||')
            gh repo clone "$repo_slug" "$PRIVATE_PATH" 2>/dev/null || git clone "$PRIVATE_REPO" "$PRIVATE_PATH"
        else
            git clone "$PRIVATE_REPO" "$PRIVATE_PATH"
        fi
    fi

    echo -e "${GREEN}✓${NC} Private configuration linked"
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

    # Add GitHub token if available
    if [[ -n "$GITHUB_TOKEN" ]]; then
        EXTRA_VARS="$EXTRA_VARS -e github_token=$GITHUB_TOKEN"
        echo -e "${GREEN}✓${NC} GitHub token available for API calls"
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

    # Check if GitHub auth is needed (many plugins or private repo)
    if needs_github_auth; then
        echo ""
        echo -e "${BLUE}→${NC} GitHub login recommended (many plugins enabled)"
        authenticate_github || echo -e "${YELLOW}!${NC} Continuing without GitHub auth (may hit rate limits)"
        echo ""
    fi

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
