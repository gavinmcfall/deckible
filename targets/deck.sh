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
#   # Preview what will happen (dry run - default):
#   curl -fsSL https://bootible.dev/deck | bash
#
#   # Run for real after reviewing:
#   BOOTIBLE_RUN=1 curl -fsSL https://bootible.dev/deck | bash
#
# Or with a private repo:
#   curl -fsSL https://bootible.dev/deck | bash -s -- owner/repo

set -e

# Ensure logs are pushed even on failure
cleanup_and_push_log() {
    local exit_code=$?

    # Only run cleanup if we've started (DEVICE is set)
    if [[ -n "${DEVICE:-}" && -n "${BOOTIBLE_DIR:-}" ]]; then
        # Try to push logs - don't let errors prevent exit
        push_log_to_git || true
    fi

    exit $exit_code
}
trap cleanup_and_push_log EXIT

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
DRY_RUN="${BOOTIBLE_RUN:-0}"  # Dry run by default unless BOOTIBLE_RUN=1
[[ "$DRY_RUN" == "1" ]] && DRY_RUN=false || DRY_RUN=true
LOG_FILE=""

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      Bootible                              ║"
echo "║         Universal Gaming Device Configuration              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# =============================================================================
# LOGGING
# =============================================================================
# Saves session transcript to private/logs/steamdeck/ for debugging

start_logging() {
    local suffix
    if [[ "$DRY_RUN" == "true" ]]; then
        suffix="_dryrun"
    else
        suffix="_run"
    fi

    local hostname
    hostname=$(hostname | tr '[:upper:]' '[:lower:]')
    local log_filename
    log_filename="$(date +%Y-%m-%d_%H%M%S)_${hostname}${suffix}.log"

    # Start in temp, move to private/logs later if available
    LOG_FILE="/tmp/bootible_${log_filename}"

    # Start logging - use script command for proper tty handling
    # This preserves stdin for interactive prompts while logging output
    exec 3>&1 4>&2
    exec > >(tee -a "$LOG_FILE") 2>&1

    echo "=== Bootible Log Started: $(date) ==="
    echo "Hostname: $hostname"
    echo "Dry Run: $DRY_RUN"
    echo "============================================="
    echo ""
}

move_log_to_private() {
    if [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]]; then
        return 0
    fi

    local logs_dir="$BOOTIBLE_DIR/private/logs/$DEVICE"

    # Only move if private repo exists
    if [[ -d "$BOOTIBLE_DIR/private/.git" ]]; then
        mkdir -p "$logs_dir"

        # Get just the filename without bootible_ prefix
        local log_filename
        log_filename=$(basename "$LOG_FILE" | sed 's/^bootible_//')
        local new_path="$logs_dir/$log_filename"

        cp "$LOG_FILE" "$new_path"
        LOG_FILE="$new_path"
        echo -e "${GREEN}✓${NC} Log saved: logs/$DEVICE/$log_filename"
    fi
}

push_log_to_git() {
    local private_dir="$BOOTIBLE_DIR/private"

    if [[ ! -d "$private_dir/.git" ]]; then
        return 0
    fi

    # The tee process is still writing to /tmp, so we need to find and copy
    # the temp log file to private/logs before committing
    local temp_log
    temp_log=$(ls -t /tmp/bootible_*.log 2>/dev/null | head -1)

    if [[ -z "$temp_log" || ! -f "$temp_log" ]]; then
        return 0
    fi

    local logs_dir="$private_dir/logs/$DEVICE"
    mkdir -p "$logs_dir"

    # Copy final log content (tee is still appending to temp file)
    local log_filename
    log_filename=$(basename "$temp_log" | sed 's/^bootible_//')
    local final_log="$logs_dir/$log_filename"
    cp "$temp_log" "$final_log"

    local run_type
    if [[ "$DRY_RUN" == "true" ]]; then
        run_type="dry run"
    else
        run_type="run"
    fi

    cd "$private_dir"

    # Stage log files
    git add "logs/$DEVICE/"*.log 2>/dev/null || true

    # Check if there's anything to commit
    if git diff --cached --quiet 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Log saved (no changes to push)"
        return 0
    fi

    # Set git identity if not configured
    git config user.name 2>/dev/null || git config user.name "bootible"
    git config user.email 2>/dev/null || git config user.email "bootible@localhost"

    # Commit and push
    echo -e "${BLUE}→${NC} Committing log: logs/$DEVICE/$log_filename"
    local commit_output
    if commit_output=$(git commit -m "log: $DEVICE $run_type $(date '+%Y-%m-%d %H:%M')" 2>&1); then
        echo -e "${GREEN}✓${NC} Committed: $commit_output"
        echo -e "${BLUE}→${NC} Pushing to remote..."

        # Ensure gh credential helper is set up for push
        if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
            gh auth setup-git 2>/dev/null || true
        fi

        local push_output
        if push_output=$(git push 2>&1); then
            echo -e "${GREEN}✓${NC} Log pushed to private repo"
        else
            echo -e "${YELLOW}!${NC} Log saved locally (push requires repo write access)"
        fi
    else
        echo -e "${YELLOW}!${NC} Git commit failed: $commit_output"
    fi

    cd "$BOOTIBLE_DIR"
}

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

    # Refresh keyrings (both Arch and SteamOS)
    echo "  Refreshing package keyrings..."
    sudo pacman-key --init 2>/dev/null || true
    sudo pacman-key --populate archlinux 2>/dev/null || true
    sudo pacman-key --populate holo 2>/dev/null || true

    # Update keyring packages first
    sudo pacman -Sy --noconfirm archlinux-keyring 2>/dev/null || true

    # Install packages
    local packages=""
    command -v gh &> /dev/null || packages="$packages github-cli"
    command -v jq &> /dev/null || packages="$packages jq"
    command -v qrencode &> /dev/null || packages="$packages qrencode"

    if [[ -n "$packages" ]]; then
        # shellcheck disable=SC2086  # Intentional word splitting
        if ! sudo pacman -S --noconfirm $packages; then
            echo -e "${YELLOW}!${NC} Pacman install failed, trying with --overwrite..."
            # shellcheck disable=SC2086
            sudo pacman -S --noconfirm --overwrite '*' $packages || true
        fi
    fi

    # Restore read-only
    trap - EXIT
    sudo steamos-readonly enable 2>/dev/null || true

    # Verify gh was installed
    if command -v gh &> /dev/null; then
        echo -e "${GREEN}✓${NC} GitHub CLI ready"
    else
        echo -e "${RED}✗${NC} GitHub CLI installation failed"
        return 1
    fi
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
        plugin_count=$(awk '/^decky_plugins:/,/^[^ ]/' "$config_file" 2>/dev/null | grep -c "enabled: true" 2>/dev/null) || plugin_count=0

        if [[ "$plugin_count" =~ ^[0-9]+$ ]] && [[ $plugin_count -gt 3 ]]; then
            return 0  # Need auth
        fi
    fi

    # Check if private repo uses SSH (needs auth for push)
    if [[ -n "$PRIVATE_REPO" && "$PRIVATE_REPO" == git@* ]]; then
        return 0  # Need auth for SSH
    fi

    return 1  # No need
}

# Clear stale git/gh credentials that might be causing issues
clear_git_credentials() {
    echo -e "${YELLOW}!${NC} Clearing stale credentials..."
    # Clear gh auth
    gh auth logout --hostname github.com 2>/dev/null || true
    # Clear git credential helpers
    git config --global --unset-all credential.helper 2>/dev/null || true
    # Clear any URL rewriting
    git config --global --unset-all 'url.git@github.com:.insteadOf' 2>/dev/null || true
    git config --global --unset-all 'url.ssh://git@github.com/.insteadOf' 2>/dev/null || true
}

# Clone bootible
clone_bootible() {
    if [[ -d "$BOOTIBLE_DIR/.git" ]]; then
        echo -e "${BLUE}→${NC} Updating existing bootible..."
        cd "$BOOTIBLE_DIR"
        git fetch origin main && git reset --hard origin/main && git clean -fd
    else
        echo -e "${BLUE}→${NC} Cloning bootible..."
        rm -rf "$BOOTIBLE_DIR" 2>/dev/null || true
        # Simple clone - public repo, should just work
        if ! git clone https://github.com/gavinmcfall/bootible.git "$BOOTIBLE_DIR"; then
            # If clone fails, credentials are probably broken - clear and retry
            clear_git_credentials
            git clone https://github.com/gavinmcfall/bootible.git "$BOOTIBLE_DIR"
        fi
        cd "$BOOTIBLE_DIR"
    fi
    echo -e "${GREEN}✓${NC} Bootible ready at $BOOTIBLE_DIR"
}

# Setup private repo - prompt if not provided
setup_private() {
    PRIVATE_PATH="$BOOTIBLE_DIR/private"

    # If not provided via argument, prompt interactively
    if [[ -z "$PRIVATE_REPO" ]]; then
        echo "" > /dev/tty
        echo -n "Do you have a private config repo? (y/N): " > /dev/tty
        read -r response < /dev/tty

        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -n "Your GitHub username: " > /dev/tty
            read -r github_user < /dev/tty
            GITHUB_USER="$github_user"

            echo -n "Private repo (e.g., owner/repo): " > /dev/tty
            read -r repo_path < /dev/tty

            if [[ -n "$repo_path" ]]; then
                # If repo_path doesn't contain /, prepend the username
                if [[ "$repo_path" != *"/"* && -n "$github_user" ]]; then
                    repo_path="${github_user}/${repo_path}"
                fi
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

    # Configure gh to store credentials for git
    if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
        gh auth setup-git 2>/dev/null || true
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

        # Get repo slug for gh clone
        local repo_slug
        repo_slug=$(echo "$PRIVATE_REPO" | sed 's|https://github.com/||' | sed 's|\.git$||' | sed 's|git@github.com:||')

        # Try gh repo clone (uses authenticated HTTPS)
        gh config set git_protocol https 2>/dev/null || true
        if gh repo clone "$repo_slug" "$PRIVATE_PATH" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Private configuration linked"
            return 0
        fi

        # Clone failed - clear credentials and re-authenticate
        echo -e "${YELLOW}!${NC} Clone failed, refreshing authentication..."
        clear_git_credentials

        # Re-authenticate
        if ! authenticate_github; then
            echo -e "${YELLOW}!${NC} Authentication failed, continuing without private config"
            return 0
        fi

        # Retry clone with fresh auth
        gh config set git_protocol https 2>/dev/null || true
        if gh repo clone "$repo_slug" "$PRIVATE_PATH"; then
            echo -e "${GREEN}✓${NC} Private configuration linked"
            return 0
        fi

        echo -e "${YELLOW}!${NC} Failed to clone private repo"
        echo "  Continuing without private config..."
        return 0
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

# =============================================================================
# INSTALLATION SUMMARY
# =============================================================================
# Show what was enabled in config for user awareness

show_installation_summary() {
    local config_file="$SELECTED_CONFIG"
    [[ -z "$config_file" ]] && config_file="$BOOTIBLE_DIR/config/$DEVICE/config.yml"

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    Installation Summary                        ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Helper to check and display feature
    show_feature() {
        local key="$1"
        local display_name="$2"
        local note="${3:-}"

        if grep -qE "^${key}:\s*(true|yes)" "$config_file" 2>/dev/null; then
            if [[ -n "$note" ]]; then
                echo -e "  ${GREEN}✓${NC} $display_name ${YELLOW}($note)${NC}"
            else
                echo -e "  ${GREEN}✓${NC} $display_name"
            fi
        fi
    }

    echo -e "${BLUE}System:${NC}"
    show_feature "create_snapshot" "Btrfs snapshot created"
    show_feature "install_ssh" "SSH server enabled"
    show_feature "install_tailscale" "Tailscale VPN"

    echo ""
    echo -e "${BLUE}Gaming:${NC}"
    show_feature "install_decky" "Decky Loader" "restart Steam to see plugins"
    show_feature "install_proton_ge" "Proton-GE"
    show_feature "install_emudeck" "EmuDeck" "run wizard in Desktop Mode"
    show_feature "install_waydroid" "Waydroid Android" "run installer in Desktop Mode"

    echo ""
    echo -e "${BLUE}Streaming:${NC}"
    show_feature "install_moonlight" "Moonlight (client)"
    show_feature "install_sunshine" "Sunshine (server)"
    show_feature "install_chiaki" "Chiaki (PlayStation Remote)"
    show_feature "install_greenlight" "Greenlight (Xbox/xCloud)"

    echo ""
    echo -e "${BLUE}Apps:${NC}"
    show_feature "install_discord" "Discord"
    show_feature "install_1password" "1Password"
    show_feature "install_anydesk" "AnyDesk"
    show_feature "install_flatseal" "Flatseal"

    # Count enabled Decky plugins
    local plugin_count
    plugin_count=$(awk '/^decky_plugins:/,/^[^ ]/' "$config_file" 2>/dev/null | grep -c "enabled: true" 2>/dev/null) || plugin_count=0
    if [[ "$plugin_count" =~ ^[0-9]+$ ]] && [[ $plugin_count -gt 0 ]]; then
        echo ""
        echo -e "${BLUE}Decky Plugins:${NC} $plugin_count enabled"
    fi

    echo ""
}

# =============================================================================
# HEALTH CHECKS
# =============================================================================
# Verify key installations after playbook runs

run_health_checks() {
    echo ""
    echo -e "${BLUE}→${NC} Running health checks..."

    local checks_passed=0
    local checks_failed=0
    local config_file="$SELECTED_CONFIG"
    [[ -z "$config_file" ]] && config_file="$BOOTIBLE_DIR/config/$DEVICE/config.yml"

    # Helper to check if a feature is enabled in config
    config_enabled() {
        local key="$1"
        grep -qE "^${key}:\s*(true|yes)" "$config_file" 2>/dev/null
    }

    # Helper to report check result
    report_check() {
        local name="$1"
        local status="$2"
        if [[ "$status" == "ok" ]]; then
            echo -e "  ${GREEN}✓${NC} $name"
            ((checks_passed++))
        else
            echo -e "  ${RED}✗${NC} $name"
            ((checks_failed++))
        fi
    }

    # Check Decky Loader if enabled
    if config_enabled "install_decky"; then
        if [[ -d "$HOME/homebrew" ]] || [[ -d "$HOME/.local/share/decky" ]]; then
            report_check "Decky Loader installed" "ok"
        else
            report_check "Decky Loader installed" "fail"
        fi
    fi

    # Check SSH if enabled
    if config_enabled "install_ssh"; then
        if systemctl is-active sshd &>/dev/null; then
            report_check "SSH service running" "ok"
        else
            report_check "SSH service running" "fail"
        fi
    fi

    # Check Tailscale if enabled
    if config_enabled "install_tailscale"; then
        if command -v tailscale &>/dev/null; then
            report_check "Tailscale installed" "ok"
        else
            report_check "Tailscale installed" "fail"
        fi
    fi

    # Check Flatpak apps if enabled
    if config_enabled "install_flatpak_apps"; then
        if command -v flatpak &>/dev/null && [[ $(flatpak list 2>/dev/null | wc -l) -gt 0 ]]; then
            report_check "Flatpak apps available" "ok"
        else
            report_check "Flatpak apps available" "fail"
        fi
    fi

    # Check EmuDeck if enabled
    if config_enabled "install_emudeck"; then
        if [[ -f "$HOME/Applications/EmuDeck.AppImage" ]] || [[ -d "$HOME/Emulation" ]]; then
            report_check "EmuDeck staged" "ok"
        else
            report_check "EmuDeck staged" "fail"
        fi
    fi

    # Check Proton-GE if enabled
    if config_enabled "install_proton_ge"; then
        local proton_dir="$HOME/.steam/root/compatibilitytools.d"
        if [[ -d "$proton_dir" ]] && ls "$proton_dir"/GE-Proton* &>/dev/null 2>&1; then
            report_check "Proton-GE installed" "ok"
        else
            report_check "Proton-GE installed" "fail"
        fi
    fi

    echo ""
    if [[ $checks_failed -eq 0 ]]; then
        echo -e "${GREEN}✓${NC} All health checks passed ($checks_passed/$checks_passed)"
    else
        echo -e "${YELLOW}!${NC} Health checks: $checks_passed passed, $checks_failed failed"
        echo "  Some features may need manual setup or a restart"
    fi
}

# Run device-specific playbook
run_playbook() {
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}→${NC} Running $DEVICE configuration (DRY RUN)..."
    else
        echo -e "${BLUE}→${NC} Running $DEVICE configuration..."
    fi
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

    # Build ansible command with dry run flag if needed
    local ansible_cmd="ansible-playbook playbook.yml"
    if [[ "$DRY_RUN" == "true" ]]; then
        ansible_cmd="$ansible_cmd --check --diff"
        echo -e "${YELLOW}!${NC} Running in check mode (no changes will be made)"
        echo ""
    fi

    # Refresh sudo credentials before running ansible
    sudo -v < /dev/tty

    case $DEVICE in
        steamdeck)
            if [[ -n "$EXTRA_VARS" ]]; then
                # shellcheck disable=SC2086  # Intentional word splitting for ansible args
                $ansible_cmd $EXTRA_VARS --ask-become-pass < /dev/tty
            else
                # shellcheck disable=SC2086  # Intentional word splitting for ansible args
                $ansible_cmd --ask-become-pass < /dev/tty
            fi
            ;;
        *)
            echo -e "${RED}✗${NC} Unknown device type: $DEVICE"
            exit 1
            ;;
    esac
}

# Install bootible command wrapper
install_bootible_command() {
    echo -e "${BLUE}→${NC} Installing 'bootible' command..."

    # bootible command defaults to real run (user already did dry run via curl)
    local cmd_content="#!/bin/bash
cd \"$BOOTIBLE_DIR\" && git pull && BOOTIBLE_RUN=1 ./targets/deck.sh \"\$@\""

    # Install to /usr/local/bin (already in PATH, works immediately)
    local cmd_path="/usr/local/bin/bootible"

    # SteamOS has read-only filesystem - unlock it temporarily
    sudo steamos-readonly disable 2>/dev/null || true

    echo "$cmd_content" | sudo tee "$cmd_path" > /dev/null
    sudo chmod +x "$cmd_path"

    # Re-lock filesystem
    sudo steamos-readonly enable 2>/dev/null || true

    echo -e "${GREEN}✓${NC} Installed 'bootible' command"
}

# Main
main() {
    # Start logging early
    start_logging

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

    # Move log to private repo if available
    move_log_to_private

    select_config
    echo ""

    # Check if GitHub auth is needed (many plugins or private repo)
    if needs_github_auth; then
        echo ""
        echo -e "${BLUE}→${NC} GitHub login recommended (many plugins enabled)"
        authenticate_github || echo -e "${YELLOW}!${NC} Continuing without GitHub auth (may hit rate limits)"
        echo ""
    fi

    install_bootible_command
    echo ""

    run_playbook

    # Run health checks and show summary (only on real runs, not dry runs)
    if [[ "$DRY_RUN" != "true" ]]; then
        run_health_checks
        show_installation_summary
    fi

    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        # Show what would be installed in dry run mode
        show_installation_summary

        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║                  DRY RUN COMPLETE                          ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "Review the output above. When ready to apply changes:"
        echo ""
        echo -e "  ${GREEN}bootible${NC}"
    else
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
    fi

    echo ""
    echo "To re-run anytime:"
    echo -e "  ${GREEN}bootible${NC}"
    echo ""

    # Log push handled by EXIT trap (cleanup_and_push_log)
}

main "$@"
