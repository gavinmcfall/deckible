#!/bin/bash
# Bootible - Android Bootstrap Script
# ====================================
# Provisions Android gaming handhelds via Wireless ADB from a host machine.
#
# Supported Devices:
#   - Retroid Pocket, AYANEO, Odin, Logitech G Cloud
#   - Any Android device with Wireless ADB enabled
#
# Usage:
#   # Preview what will happen (dry run - default):
#   curl -fsSL https://bootible.dev/android | bash
#
#   # Run for real after reviewing:
#   bootible-android
#
# Or with a private repo:
#   curl -fsSL https://bootible.dev/android | bash -s -- owner/repo

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
DEVICE="android"
DRY_RUN="${BOOTIBLE_RUN:-0}"  # Dry run by default unless BOOTIBLE_RUN=1
[[ "$DRY_RUN" == "1" ]] && DRY_RUN=false || DRY_RUN=true
LOG_FILE=""
SELECTED_CONFIG=""
SELECTED_INSTANCE=""
CONNECTED_DEVICE=""

echo -e "${CYAN}"
echo "+=============================================================+"
echo "|                      Bootible                               |"
echo "|          Android Gaming Handheld Configuration              |"
echo "+=============================================================+"
echo -e "${NC}"

# =============================================================================
# LOGGING
# =============================================================================
# Saves session transcript to private/device/android/<instance>/Logs/ for debugging

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
    LOG_FILE="/tmp/bootible_android_${log_filename}"

    # Start logging - use script command for proper tty handling
    # This preserves stdin for interactive prompts while logging output
    exec 3>&1 4>&2
    exec > >(tee -a "$LOG_FILE") 2>&1

    echo "=== Bootible Android Log Started: $(date) ==="
    echo "Hostname: $hostname"
    echo "Dry Run: $DRY_RUN"
    echo "============================================="
    echo ""
}

move_log_to_private() {
    if [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]]; then
        return 0
    fi

    # Only move if we know the instance and private repo exists
    if [[ -z "$SELECTED_INSTANCE" || ! -d "$BOOTIBLE_DIR/private/.git" ]]; then
        return 0
    fi

    local logs_dir="$BOOTIBLE_DIR/private/device/$DEVICE/$SELECTED_INSTANCE/Logs"
    mkdir -p "$logs_dir"

    # Get just the filename without bootible_android_ prefix
    local log_filename
    log_filename=$(basename "$LOG_FILE" | sed 's/^bootible_android_//')
    local new_path="$logs_dir/$log_filename"

    cp "$LOG_FILE" "$new_path"
    LOG_FILE="$new_path"
    echo -e "${GREEN}+${NC} Log saved: device/$DEVICE/$SELECTED_INSTANCE/Logs/$log_filename"
}

push_log_to_git() {
    local private_dir="$BOOTIBLE_DIR/private"

    if [[ ! -d "$private_dir/.git" ]]; then
        return 0
    fi

    # Need to know the instance for the log path
    if [[ -z "$SELECTED_INSTANCE" ]]; then
        return 0
    fi

    # The tee process is still writing to /tmp, so we need to find and copy
    # the temp log file to private device Logs before committing
    local temp_log
    temp_log=$(find /tmp -maxdepth 1 -name 'bootible_android_*.log' -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

    if [[ -z "$temp_log" || ! -f "$temp_log" ]]; then
        return 0
    fi

    local logs_dir="$private_dir/device/$DEVICE/$SELECTED_INSTANCE/Logs"
    mkdir -p "$logs_dir"

    # Copy final log content (tee is still appending to temp file)
    local log_filename
    log_filename=$(basename "$temp_log" | sed 's/^bootible_android_//')
    local final_log="$logs_dir/$log_filename"
    cp "$temp_log" "$final_log"

    local run_type
    if [[ "$DRY_RUN" == "true" ]]; then
        run_type="dry run"
    else
        run_type="run"
    fi

    cd "$private_dir"

    # Stage log files for this device instance
    git add "device/$DEVICE/$SELECTED_INSTANCE/Logs/"*.log 2>/dev/null || true

    # Check if there's anything to commit
    if git diff --cached --quiet 2>/dev/null; then
        echo -e "${GREEN}+${NC} Log saved (no changes to push)"
        return 0
    fi

    # Set git identity if not configured
    git config user.name 2>/dev/null || git config user.name "bootible"
    git config user.email 2>/dev/null || git config user.email "bootible@localhost"

    # Commit and push
    echo -e "${BLUE}>${NC} Committing log: device/$DEVICE/$SELECTED_INSTANCE/Logs/$log_filename"
    local commit_output
    if commit_output=$(git commit -m "log: android/$SELECTED_INSTANCE $run_type $(date '+%Y-%m-%d %H:%M')" 2>&1); then
        echo -e "${GREEN}+${NC} Committed"
        echo -e "${BLUE}>${NC} Pushing to remote..."

        # Try gh for push (most reliable after device flow auth)
        local push_success=false
        if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
            gh config set git_protocol https 2>/dev/null || true
            gh auth setup-git 2>/dev/null || true
            if git push 2>&1; then
                push_success=true
            fi
        fi

        # If gh push failed, try with token in URL
        if [[ "$push_success" != "true" ]]; then
            local token
            token=$(gh auth token 2>/dev/null || true)
            if [[ -n "$token" ]]; then
                local remote_url
                remote_url=$(git remote get-url origin)
                # Convert to HTTPS with token
                local auth_url
                auth_url=$(echo "$remote_url" | sed "s|https://github.com|https://${token}@github.com|" | sed "s|git@github.com:|https://${token}@github.com/|")
                if git push "$auth_url" HEAD 2>&1; then
                    push_success=true
                fi
            fi
        fi

        if [[ "$push_success" == "true" ]]; then
            echo -e "${GREEN}+${NC} Log pushed to private repo"
        else
            echo -e "${YELLOW}!${NC} Log saved locally (push failed)"
        fi
    else
        echo -e "${YELLOW}!${NC} Git commit failed: $commit_output"
    fi

    cd "$BOOTIBLE_DIR"
}

# =============================================================================
# HOST REQUIREMENTS
# =============================================================================
# Check and install required tools on the host machine

check_host_requirements() {
    echo -e "${BLUE}>${NC} Checking host requirements..."

    local missing=()

    # Check for ADB
    if ! command -v adb &> /dev/null; then
        missing+=("adb")
    fi

    # Check for curl
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi

    # Check for jq
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    # Check for yq
    if ! command -v yq &> /dev/null; then
        missing+=("yq")
    fi

    # Check for qrencode (optional but recommended)
    if ! command -v qrencode &> /dev/null; then
        echo -e "${YELLOW}!${NC} qrencode not installed (QR codes won't display)"
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${YELLOW}!${NC} Missing tools: ${missing[*]}"
        echo ""
        install_host_tools "${missing[@]}"
    else
        echo -e "${GREEN}+${NC} All required tools available"
    fi
}

install_host_tools() {
    local tools=("$@")

    echo -e "${BLUE}>${NC} Installing missing tools..."

    # Detect package manager
    local pm=""
    if command -v apt &> /dev/null; then
        pm="apt"
    elif command -v dnf &> /dev/null; then
        pm="dnf"
    elif command -v pacman &> /dev/null; then
        pm="pacman"
    elif command -v brew &> /dev/null; then
        pm="brew"
    fi

    for tool in "${tools[@]}"; do
        case "$tool" in
            adb)
                echo -e "${BLUE}>${NC} Installing Android Debug Bridge..."
                case "$pm" in
                    apt)
                        sudo apt update && sudo apt install -y android-tools-adb
                        ;;
                    dnf)
                        sudo dnf install -y android-tools
                        ;;
                    pacman)
                        sudo pacman -S --noconfirm android-tools
                        ;;
                    brew)
                        brew install android-platform-tools
                        ;;
                    *)
                        echo -e "${RED}X${NC} Cannot install ADB automatically."
                        echo "  Please install Android SDK Platform Tools:"
                        echo "  https://developer.android.com/tools/releases/platform-tools"
                        exit 1
                        ;;
                esac
                ;;
            curl)
                echo -e "${BLUE}>${NC} Installing curl..."
                case "$pm" in
                    apt) sudo apt install -y curl ;;
                    dnf) sudo dnf install -y curl ;;
                    pacman) sudo pacman -S --noconfirm curl ;;
                    brew) brew install curl ;;
                esac
                ;;
            jq)
                echo -e "${BLUE}>${NC} Installing jq..."
                case "$pm" in
                    apt) sudo apt install -y jq ;;
                    dnf) sudo dnf install -y jq ;;
                    pacman) sudo pacman -S --noconfirm jq ;;
                    brew) brew install jq ;;
                esac
                ;;
            yq)
                echo -e "${BLUE}>${NC} Installing yq..."
                # yq is often not in default repos, use binary install
                local yq_version="v4.40.5"
                local yq_binary="yq_linux_amd64"
                if [[ "$(uname -m)" == "aarch64" ]]; then
                    yq_binary="yq_linux_arm64"
                elif [[ "$(uname -s)" == "Darwin" ]]; then
                    yq_binary="yq_darwin_amd64"
                    if [[ "$(uname -m)" == "arm64" ]]; then
                        yq_binary="yq_darwin_arm64"
                    fi
                fi
                sudo curl -fsSL "https://github.com/mikefarah/yq/releases/download/${yq_version}/${yq_binary}" -o /usr/local/bin/yq
                sudo chmod +x /usr/local/bin/yq
                ;;
        esac

        if command -v "$tool" &> /dev/null; then
            echo -e "${GREEN}+${NC} $tool installed"
        else
            echo -e "${RED}X${NC} Failed to install $tool"
            exit 1
        fi
    done
}

# =============================================================================
# GitHub Authentication (Device Flow)
# =============================================================================
# Provides QR code-based GitHub login for minimal typing.
# Uses GitHub's OAuth Device Flow - scan QR with phone, authorize, done.

# Install GitHub CLI and dependencies
install_gh_cli() {
    if command -v gh &> /dev/null; then
        return 0
    fi

    echo -e "${BLUE}>${NC} Installing GitHub CLI..."

    # Detect package manager
    if command -v apt &> /dev/null; then
        # Add GitHub CLI repo for apt
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update && sudo apt install -y gh
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y gh
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm github-cli
    elif command -v brew &> /dev/null; then
        brew install gh
    else
        echo -e "${YELLOW}!${NC} Cannot install GitHub CLI automatically"
        echo "  Visit: https://cli.github.com/manual/installation"
        return 1
    fi

    if command -v gh &> /dev/null; then
        echo -e "${GREEN}+${NC} GitHub CLI installed"
    fi
}

# Display device code with QR in terminal
show_device_code() {
    local user_code="$1"
    local verification_url="https://github.com/login/device"

    clear
    echo ""
    echo -e "${CYAN}+===============================================================+${NC}"
    echo -e "${CYAN}|                   GitHub Login Required                       |${NC}"
    echo -e "${CYAN}+===============================================================+${NC}"
    echo -e "${CYAN}|                                                               |${NC}"
    echo -e "${CYAN}|${NC}  Scan QR code with your phone, or visit:                     ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  ${GREEN}github.com/login/device${NC}                                    ${CYAN}|${NC}"
    echo -e "${CYAN}|                                                               |${NC}"
    echo -e "${CYAN}+===============================================================+${NC}"
    echo ""

    # Generate QR code in terminal
    if command -v qrencode &> /dev/null; then
        qrencode -t ANSIUTF8 -m 2 "$verification_url"
    else
        echo -e "  ${YELLOW}(qrencode not installed - visit URL manually)${NC}"
    fi

    echo ""
    echo -e "${CYAN}+===============================================================+${NC}"
    echo -e "${CYAN}|${NC}                                                               ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}     Enter code: ${GREEN}${user_code}${NC}                                  ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}                                                               ${CYAN}|${NC}"
    echo -e "${CYAN}+===============================================================+${NC}"
    echo ""
    echo -e "  ${YELLOW}Waiting for authorization...${NC}"
    echo ""
}

# Main GitHub authentication function
authenticate_github() {
    # GitHub CLI's OAuth client_id (public, used by gh CLI)
    local client_id="178c6fc778ccc68e1d6a"
    local scope="repo,read:org,admin:public_key"

    echo -e "${BLUE}>${NC} Setting up GitHub authentication..."

    # Install gh CLI if needed
    install_gh_cli

    # Check if already authenticated
    if gh auth status &>/dev/null; then
        echo -e "${GREEN}+${NC} Already authenticated with GitHub"
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
        echo -e "${RED}X${NC} Failed to get device code from GitHub"
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
            echo -e "${RED}X${NC} Authentication timed out"
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
            echo -e "\r  ${GREEN}+ Authorized!${NC}                    "
            break
        elif [[ "$error" == "slow_down" ]]; then
            current_interval=$((current_interval + 5))
        elif [[ "$error" == "expired_token" ]]; then
            echo ""
            echo -e "${RED}X${NC} Device code expired"
            return 1
        elif [[ "$error" == "access_denied" ]]; then
            echo ""
            echo -e "${RED}X${NC} Authorization denied"
            return 1
        fi
        # authorization_pending is expected - continue polling
    done

    # Store token via gh CLI
    echo "  Storing credentials..."

    # Create secure temp file
    local token_file
    token_file="/tmp/gh-token-$(head -c 8 /dev/urandom | xxd -p).tmp"
    # shellcheck disable=SC2064  # Intentional: expand token_file now, not at signal time
    trap "rm -f '$token_file'" RETURN

    echo -n "$access_token" > "$token_file"
    chmod 600 "$token_file"

    # Pass to gh CLI
    if cat "$token_file" | gh auth login --with-token 2>/dev/null; then
        rm -f "$token_file"
        gh auth setup-git 2>/dev/null || true
        echo -e "${GREEN}+${NC} GitHub authentication complete"

        # Export token for later use
        GITHUB_TOKEN=$(gh auth token 2>/dev/null)
        export GITHUB_TOKEN
        return 0
    else
        rm -f "$token_file"
        echo -e "${RED}X${NC} Failed to store GitHub credentials"
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
        echo -e "${BLUE}>${NC} Updating existing bootible..."
        cd "$BOOTIBLE_DIR"
        git fetch origin main && git reset --hard origin/main && git clean -fd
    else
        echo -e "${BLUE}>${NC} Cloning bootible..."
        rm -rf "$BOOTIBLE_DIR" 2>/dev/null || true
        # Simple clone - public repo, should just work
        if ! git clone https://github.com/bootible/bootible.git "$BOOTIBLE_DIR"; then
            # If clone fails, credentials are probably broken - clear and retry
            clear_git_credentials
            git clone https://github.com/bootible/bootible.git "$BOOTIBLE_DIR"
        fi
        cd "$BOOTIBLE_DIR"
    fi
    echo -e "${GREEN}+${NC} Bootible ready at $BOOTIBLE_DIR"
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

    echo -e "${BLUE}>${NC} Setting up private configuration..."
    echo "  Repo: $PRIVATE_REPO"

    # Authenticate with GitHub if needed
    if ! gh auth status &>/dev/null 2>&1; then
        echo ""
        echo -e "${BLUE}>${NC} GitHub authentication required for private repo"
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
            echo -e "${GREEN}+${NC} Private configuration linked"
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
            echo -e "${GREEN}+${NC} Private configuration linked"
            return 0
        fi

        echo -e "${YELLOW}!${NC} Failed to clone private repo"
        echo "  Continuing without private config..."
        return 0
    fi

    echo -e "${GREEN}+${NC} Private configuration linked"
}

# Create a new device instance in private repo
create_device_instance() {
    local instance_name="$1"
    local instance_dir="$PRIVATE_DEVICE_DIR/$instance_name"

    echo -e "${BLUE}>${NC} Creating new device instance: $instance_name"

    # Create directory structure
    mkdir -p "$instance_dir/Logs"
    mkdir -p "$instance_dir/apks"

    # Create starter config from template
    cat > "$instance_dir/config.yml" << 'EOF'
# Device Configuration
# ====================
# Customize this file for your Android device.
# See config/android/config.yml for all available options.

---
# Connection (update with your device's IP)
connection:
  method: wireless
  ip: ""
  port: 5555

# APK Installation
# Enable apps by setting enabled: true
# See config/android/apps-reference.md for app descriptions
#
# Sources:
#   url    - Download from URL
#   fdroid - Download from F-Droid
#   local  - Use file from private repo:
#            path: "android/apks/App.apk"  (shared, in private/android/apks/)
#            path: "device/android/DEVICE_NAME/apks/App.apk"  (device-specific)
install_apks: true
apks:
  # Recommended starter apps
  fdroid:
    enabled: true
    source: url
    url: "https://f-droid.org/F-Droid.apk"
    package_name: "org.fdroid.fdroid"

  tailscale:
    enabled: false
    source: url
    url: "https://pkgs.tailscale.com/stable/tailscale-android.apk"
    package_name: "com.tailscale.ipn"

  moonlight:
    enabled: false
    source: url
    url: "https://github.com/moonlight-stream/moonlight-android/releases/latest/download/Moonlight.apk"
    package_name: "com.limelight"

  # Example local APK (uncomment and adjust):
  # my_local_app:
  #   enabled: false
  #   source: local
  #   path: "android/apks/MyApp.apk"
  #   package_name: "com.example.myapp"

# Settings Configuration
configure_settings: true
settings:
  global:
    # Reduce animations for better performance
    window_animation_scale: "0.5"
    transition_animation_scale: "0.5"
    animator_duration_scale: "0.5"

# File Push (optional)
# Paths are relative to private/ directory
# Examples:
#   local_path: "android/roms"  (shared, in private/android/roms/)
#   local_path: "device/android/DEVICE_NAME/roms"  (device-specific)
push_files: false
files:
  # roms:
  #   enabled: false
  #   local_path: "android/roms"
  #   device_path: "/sdcard/RetroArch/roms"
  custom: []

# Shell Commands (optional)
execute_commands: false
commands:
  pre: []
  post: []

# Device Profile (optional)
# Options: retroid_pocket, ayaneo, odin, logitech_g_cloud, generic
device_profile: ""

# Debug options
verbose: false
show_commands: false
EOF

    echo -e "${GREEN}+${NC} Created: device/android/$instance_name/"
    echo -e "  ${BLUE}>${NC} config.yml - Edit this to customize your device"
    echo -e "  ${BLUE}>${NC} apks/      - Place local APK files here"
    echo -e "  ${BLUE}>${NC} Logs/      - Provisioning logs saved here"
}

# Select config file (if multiple exist in private)
select_config() {
    SELECTED_CONFIG=""
    SELECTED_INSTANCE=""
    PRIVATE_DEVICE_DIR="$BOOTIBLE_DIR/private/device/$DEVICE"
    DEFAULT_CONFIG="$BOOTIBLE_DIR/config/$DEVICE/config.yml"

    # Check if private repo exists but no device directory
    if [[ -d "$BOOTIBLE_DIR/private/.git" && ! -d "$PRIVATE_DEVICE_DIR" ]]; then
        mkdir -p "$PRIVATE_DEVICE_DIR"
    fi

    # Find device instance directories (each subdirectory is a device instance)
    DEVICE_INSTANCES=()
    if [[ -d "$PRIVATE_DEVICE_DIR" ]]; then
        while IFS= read -r -d '' dir; do
            DEVICE_INSTANCES+=("$dir")
        done < <(find "$PRIVATE_DEVICE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | sort -z)
    fi

    # If no private repo, use default
    if [[ ! -d "$BOOTIBLE_DIR/private/.git" ]]; then
        echo -e "${BLUE}>${NC} Using default configuration (no private repo)"
        SELECTED_CONFIG="$DEFAULT_CONFIG"
        SELECTED_INSTANCE="default"
        return
    fi

    # If no device instances, prompt to create one
    if [[ ${#DEVICE_INSTANCES[@]} -eq 0 ]]; then
        echo -e "${CYAN}No Android device configurations found.${NC}"
        echo ""
        echo -n "Create a new device configuration? (Y/n): " > /dev/tty
        read -r create_new < /dev/tty

        if [[ ! "$create_new" =~ ^[Nn]$ ]]; then
            echo ""
            echo -n "Enter device name (e.g., Retroid-5, Odin-2): " > /dev/tty
            read -r instance_name < /dev/tty

            if [[ -n "$instance_name" ]]; then
                # Sanitize name (replace spaces with dashes, remove special chars)
                instance_name=$(echo "$instance_name" | tr ' ' '-' | tr -cd '[:alnum:]-_')
                create_device_instance "$instance_name"
                SELECTED_INSTANCE="$instance_name"
                SELECTED_CONFIG="$PRIVATE_DEVICE_DIR/$instance_name/config.yml"
                echo ""
                return
            fi
        fi

        echo -e "${BLUE}>${NC} Using default configuration"
        SELECTED_CONFIG="$DEFAULT_CONFIG"
        SELECTED_INSTANCE="default"
        return
    fi

    # Build selection menu
    echo -e "${CYAN}Available configurations:${NC}"
    echo ""
    for i in "${!DEVICE_INSTANCES[@]}"; do
        local instance_name
        instance_name=$(basename "${DEVICE_INSTANCES[$i]}")
        local num=$((i + 1))
        echo -e "  ${YELLOW}$num${NC}) $instance_name"
    done
    local new_option=$((${#DEVICE_INSTANCES[@]} + 1))
    echo -e "  ${YELLOW}$new_option${NC}) [Create new device]"
    echo ""

    while true; do
        echo -n "Select configuration [1-$new_option]: " > /dev/tty
        read -r selection < /dev/tty

        # Create new device
        if [[ "$selection" == "$new_option" ]]; then
            echo ""
            echo -n "Enter device name (e.g., Retroid-5, Odin-2): " > /dev/tty
            read -r instance_name < /dev/tty

            if [[ -n "$instance_name" ]]; then
                instance_name=$(echo "$instance_name" | tr ' ' '-' | tr -cd '[:alnum:]-_')
                create_device_instance "$instance_name"
                SELECTED_INSTANCE="$instance_name"
                SELECTED_CONFIG="$PRIVATE_DEVICE_DIR/$instance_name/config.yml"
                echo ""
                return
            else
                echo -e "${YELLOW}!${NC} Invalid name, please try again"
                continue
            fi
        fi

        # Select existing device
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#DEVICE_INSTANCES[@]} ]]; then
            local idx=$((selection - 1))
            SELECTED_INSTANCE=$(basename "${DEVICE_INSTANCES[$idx]}")
            SELECTED_CONFIG="${DEVICE_INSTANCES[$idx]}/config.yml"
            echo ""
            echo -e "${GREEN}+${NC} Selected: $SELECTED_INSTANCE"
            return
        else
            echo -e "${RED}Invalid selection. Please enter a number between 1 and $new_option${NC}"
        fi
    done
}

# =============================================================================
# ANDROID DEVICE CONNECTION
# =============================================================================

# Pair with device (Android 11+ Wireless Debugging)
pair_device() {
    local ip="$1"
    local pairing_port="$2"
    local pairing_code="$3"

    if [[ -n "$pairing_code" && -n "$pairing_port" ]]; then
        # Auto-pair with provided code
        echo -e "${BLUE}>${NC} Pairing with $ip:$pairing_port..."
        if echo "$pairing_code" | adb pair "$ip:$pairing_port" 2>/dev/null; then
            echo -e "${GREEN}+${NC} Paired successfully"
            return 0
        else
            echo -e "${RED}X${NC} Pairing failed"
            return 1
        fi
    fi

    # Interactive pairing flow
    clear
    echo ""
    echo -e "${CYAN}+===============================================================+${NC}"
    echo -e "${CYAN}|              Android Wireless Debugging Setup                 |${NC}"
    echo -e "${CYAN}+===============================================================+${NC}"
    echo -e "${CYAN}|                                                               |${NC}"
    echo -e "${CYAN}|${NC}  On your Android device:                                     ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}                                                               ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  1. Go to ${GREEN}Settings > Developer Options${NC}                     ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  2. Enable ${GREEN}Wireless Debugging${NC}                               ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  3. Tap ${GREEN}Pair device with pairing code${NC}                       ${CYAN}|${NC}"
    echo -e "${CYAN}|${NC}  4. Note the ${GREEN}IP address:Port${NC} and ${GREEN}Pairing code${NC}              ${CYAN}|${NC}"
    echo -e "${CYAN}|                                                               |${NC}"
    echo -e "${CYAN}+===============================================================+${NC}"
    echo ""

    # If we can generate QR, show instruction page QR
    if command -v qrencode &> /dev/null; then
        local help_url="https://developer.android.com/tools/adb#wireless"
        echo -e "${BLUE}Scan for detailed instructions:${NC}"
        qrencode -t ANSIUTF8 -m 1 "$help_url"
        echo ""
    fi

    echo -n "Enter pairing IP:PORT (e.g., 192.168.1.100:37847): "
    read -r pairing_address < /dev/tty

    echo -n "Enter pairing code (6 digits): "
    read -r pairing_code < /dev/tty

    echo ""
    echo -e "${BLUE}>${NC} Pairing with $pairing_address..."
    if echo "$pairing_code" | adb pair "$pairing_address" 2>/dev/null; then
        echo -e "${GREEN}+${NC} Paired successfully!"
        return 0
    else
        echo -e "${RED}X${NC} Pairing failed. Check the code and try again."
        return 1
    fi
}

# Connect to device
connect_device() {
    local ip="$1"
    local port="${2:-5555}"

    echo -e "${BLUE}>${NC} Connecting to $ip:$port..."

    # Try to connect
    local attempts=0
    local max_attempts=3

    while [[ $attempts -lt $max_attempts ]]; do
        local result
        result=$(adb connect "$ip:$port" 2>&1)

        if echo "$result" | grep -qE "(connected|already connected)"; then
            echo -e "${GREEN}+${NC} Connected to $ip:$port"
            CONNECTED_DEVICE="$ip:$port"

            # Verify connection with shell command
            if adb -s "$ip:$port" shell echo "bootible-test" 2>/dev/null | grep -q "bootible-test"; then
                return 0
            fi
        fi

        attempts=$((attempts + 1))
        if [[ $attempts -lt $max_attempts ]]; then
            echo -e "${YELLOW}!${NC} Retrying in 5 seconds..."
            sleep 5
        fi
    done

    echo -e "${RED}X${NC} Failed to connect after $max_attempts attempts"
    return 1
}

# Discover or connect to device
discover_or_connect_device() {
    # First check if already connected
    local connected
    connected=$(adb devices | grep -v "^List" | grep -v "^$" | grep -v "offline" | head -1)

    if [[ -n "$connected" ]]; then
        local device_id
        device_id=$(echo "$connected" | awk '{print $1}')
        echo -e "${GREEN}+${NC} Already connected: $device_id"
        CONNECTED_DEVICE="$device_id"
        return 0
    fi

    # Check config for pre-configured IP
    local config_ip config_port
    if [[ -f "$SELECTED_CONFIG" ]]; then
        config_ip=$(yq '.connection.ip // ""' "$SELECTED_CONFIG" 2>/dev/null)
        config_port=$(yq '.connection.port // 5555' "$SELECTED_CONFIG" 2>/dev/null)
    fi

    if [[ -n "$config_ip" && "$config_ip" != "null" && "$config_ip" != '""' ]]; then
        connect_device "$config_ip" "${config_port:-5555}"
        return $?
    fi

    # Manual entry
    echo ""
    echo -e "${BLUE}No device connected. Enter device IP address.${NC}"
    echo ""
    echo -n "Device IP (e.g., 192.168.1.100): "
    read -r device_ip < /dev/tty

    # Check if we need to pair first
    echo ""
    echo -n "Has this computer been paired with the device before? (y/N): "
    read -r paired_before < /dev/tty

    if [[ ! "$paired_before" =~ ^[Yy]$ ]]; then
        pair_device "$device_ip" "" ""
    fi

    # Get port from config or default
    local port="${config_port:-5555}"
    connect_device "$device_ip" "$port"
}

# =============================================================================
# PROVISIONING
# =============================================================================

run_provisioning() {
    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}>${NC} Running Android configuration (DRY RUN)..."
    else
        echo -e "${BLUE}>${NC} Running Android configuration..."
    fi
    echo ""

    # Source the provisioning engine
    local run_script="$BOOTIBLE_DIR/config/android/Run.sh"
    if [[ ! -f "$run_script" ]]; then
        echo -e "${RED}X${NC} Provisioning script not found: $run_script"
        return 1
    fi

    # Export variables for the provisioning script
    export BOOTIBLE_DIR
    export SELECTED_CONFIG
    export SELECTED_INSTANCE
    export CONNECTED_DEVICE
    export DRY_RUN
    export GITHUB_TOKEN

    # Run the provisioning script
    # shellcheck source=/dev/null
    source "$run_script"
}

# =============================================================================
# HEALTH CHECKS
# =============================================================================

run_health_checks() {
    if [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi

    echo ""
    echo -e "${BLUE}>${NC} Running health checks..."

    local checks_passed=0
    local checks_failed=0

    # Check device is still connected
    if adb -s "$CONNECTED_DEVICE" shell echo "test" &>/dev/null; then
        echo -e "  ${GREEN}+${NC} Device connected"
        ((checks_passed++))
    else
        echo -e "  ${RED}X${NC} Device disconnected"
        ((checks_failed++))
    fi

    # Check installed packages if APKs were requested
    local install_apks
    install_apks=$(yq '.install_apks // false' "$SELECTED_CONFIG" 2>/dev/null)
    if [[ "$install_apks" == "true" ]]; then
        local apk_count
        apk_count=$(yq '.apks | to_entries | map(select(.value.enabled == true)) | length' "$SELECTED_CONFIG" 2>/dev/null || echo 0)
        if [[ $apk_count -gt 0 ]]; then
            echo -e "  ${GREEN}+${NC} APK installation completed ($apk_count requested)"
            ((checks_passed++))
        fi
    fi

    echo ""
    if [[ $checks_failed -eq 0 ]]; then
        echo -e "${GREEN}+${NC} All health checks passed ($checks_passed/$checks_passed)"
    else
        echo -e "${YELLOW}!${NC} Health checks: $checks_passed passed, $checks_failed failed"
    fi
}

# =============================================================================
# INSTALLATION SUMMARY
# =============================================================================

show_summary() {
    echo ""
    echo -e "${CYAN}===============================================================${NC}"
    echo -e "${CYAN}                    Installation Summary                        ${NC}"
    echo -e "${CYAN}===============================================================${NC}"
    echo ""

    echo -e "${BLUE}Device:${NC} $CONNECTED_DEVICE"
    echo -e "${BLUE}Config:${NC} $SELECTED_INSTANCE"
    echo ""

    if [[ -f "$SELECTED_CONFIG" ]]; then
        # Show enabled features
        local install_apks configure_settings push_files
        install_apks=$(yq '.install_apks // false' "$SELECTED_CONFIG" 2>/dev/null)
        configure_settings=$(yq '.configure_settings // false' "$SELECTED_CONFIG" 2>/dev/null)
        push_files=$(yq '.push_files // false' "$SELECTED_CONFIG" 2>/dev/null)

        echo -e "${BLUE}Features:${NC}"
        if [[ "$install_apks" == "true" ]]; then
            local apk_count
            apk_count=$(yq '.apks | to_entries | map(select(.value.enabled == true)) | length' "$SELECTED_CONFIG" 2>/dev/null || echo 0)
            echo -e "  ${GREEN}+${NC} APK Installation ($apk_count apps)"
        fi
        if [[ "$configure_settings" == "true" ]]; then
            echo -e "  ${GREEN}+${NC} Settings Configuration"
        fi
        if [[ "$push_files" == "true" ]]; then
            echo -e "  ${GREEN}+${NC} File Push"
        fi
    fi

    echo ""
}

# Install bootible-android command wrapper
install_bootible_command() {
    echo -e "${BLUE}>${NC} Installing 'bootible-android' command..."

    # bootible-android command defaults to real run (user already did dry run via curl)
    local cmd_content="#!/bin/bash
cd \"$BOOTIBLE_DIR\" && git pull && BOOTIBLE_RUN=1 ./targets/android.sh \"\$@\""

    # Install to ~/.local/bin (user-writable, typically in PATH)
    local cmd_dir="$HOME/.local/bin"
    local cmd_path="$cmd_dir/bootible-android"

    mkdir -p "$cmd_dir"
    echo "$cmd_content" > "$cmd_path"
    chmod +x "$cmd_path"

    # Add to PATH if not already there
    if [[ ":$PATH:" != *":$cmd_dir:"* ]]; then
        echo -e "${YELLOW}!${NC} Add ~/.local/bin to PATH:"
        echo '  export PATH="$HOME/.local/bin:$PATH"'
        # Add to bashrc if not there
        # shellcheck disable=SC2016  # Intentional: check for literal string
        if [[ -f "$HOME/.bashrc" ]] && ! grep -q 'HOME/.local/bin' "$HOME/.bashrc"; then
            # shellcheck disable=SC2016  # Intentional: write literal $HOME
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            echo -e "${GREEN}+${NC} Added to ~/.bashrc"
        fi
    fi

    echo -e "${GREEN}+${NC} Installed 'bootible-android' command"
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    # Start logging early
    start_logging

    check_host_requirements
    echo ""

    # Check if GitHub auth is needed (many plugins or private repo)
    if needs_github_auth || [[ -n "$PRIVATE_REPO" ]]; then
        echo ""
        echo -e "${BLUE}>${NC} GitHub login recommended for private repo"
        authenticate_github || echo -e "${YELLOW}!${NC} Continuing without GitHub auth"
        echo ""
    fi

    clone_bootible
    echo ""

    setup_private
    echo ""

    select_config
    echo ""

    # Move log to private repo now that we know the device instance
    move_log_to_private

    install_bootible_command
    echo ""

    discover_or_connect_device
    echo ""

    run_provisioning

    # Run health checks and show summary (only on real runs, not dry runs)
    if [[ "$DRY_RUN" != "true" ]]; then
        run_health_checks
    fi

    show_summary

    echo ""
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}+=====================================================+${NC}"
        echo -e "${YELLOW}|                  DRY RUN COMPLETE                   |${NC}"
        echo -e "${YELLOW}+=====================================================+${NC}"
        echo ""
        echo "Review the output above. When ready to apply changes:"
        echo ""
        echo -e "  ${GREEN}bootible-android${NC}"
    else
        echo -e "${GREEN}+=====================================================+${NC}"
        echo -e "${GREEN}|                   Setup Complete!                   |${NC}"
        echo -e "${GREEN}+=====================================================+${NC}"
        echo ""
        echo "Device: $CONNECTED_DEVICE"
        echo ""
        echo "Next steps:"
        echo "  - Check your installed apps"
        echo "  - Verify settings were applied"
        echo "  - Test pushed files are accessible"
    fi

    echo ""
    echo "To re-run anytime:"
    echo -e "  ${GREEN}bootible-android${NC}"
    echo ""

    # Log push handled by EXIT trap (cleanup_and_push_log)
}

main "$@"
