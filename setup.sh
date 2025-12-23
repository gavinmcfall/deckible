#!/bin/bash
# Deckible Setup Script
# =====================
# Sets up deckible and optionally clones your private configuration repo.
#
# Usage:
#   ./setup.sh                     # Interactive setup
#   ./setup.sh <private-repo-url>  # Clone private repo directly
#   ./setup.sh --skip-private      # Skip private repo setup

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════╗"
echo "║         Deckible Setup                ║"
echo "║   Steam Deck Ansible Configuration    ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"

# Check if running on Steam Deck / Arch
check_system() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "arch" ]] || [[ "$ID_LIKE" == *"arch"* ]]; then
            echo -e "${GREEN}✓${NC} Running on Arch-based system"
            return 0
        fi
    fi
    echo -e "${YELLOW}⚠${NC} Not running on Arch/SteamOS - some features may not work"
    return 0
}

# Check for Ansible
check_ansible() {
    if command -v ansible-playbook &> /dev/null; then
        echo -e "${GREEN}✓${NC} Ansible is installed"
        return 0
    else
        echo -e "${YELLOW}⚠${NC} Ansible not found"
        echo ""
        echo "Install Ansible with one of these methods:"
        echo ""
        echo "  Option 1 - pacman (needs steamos-readonly disable):"
        echo "    sudo steamos-readonly disable"
        echo "    sudo pacman -S ansible"
        echo "    sudo steamos-readonly enable"
        echo ""
        echo "  Option 2 - pip (survives updates):"
        echo "    pip install --user ansible"
        echo ""
        return 1
    fi
}

# Setup private repository
setup_private_repo() {
    local private_url="$1"

    if [[ -d "private" ]]; then
        echo -e "${YELLOW}⚠${NC} private/ directory already exists"
        read -p "   Remove and re-clone? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf private
        else
            echo "   Keeping existing private/ directory"
            return 0
        fi
    fi

    if [[ -n "$private_url" ]]; then
        echo -e "${BLUE}→${NC} Cloning private repository..."
        if git clone "$private_url" private; then
            echo -e "${GREEN}✓${NC} Private repository cloned"
        else
            echo -e "${RED}✗${NC} Failed to clone private repository"
            return 1
        fi
    fi
}

# Interactive private repo setup
interactive_private_setup() {
    echo ""
    echo -e "${BLUE}Private Configuration Repository${NC}"
    echo "================================="
    echo ""
    echo "Deckible supports a private overlay repository for:"
    echo "  - Your personal settings (group_vars/all.yml)"
    echo "  - Private files (Patreon downloads, etc.)"
    echo ""
    echo "Options:"
    echo "  1) Enter your private repo URL"
    echo "  2) Create a new private repo (shows template)"
    echo "  3) Skip (use defaults only)"
    echo ""
    read -p "Choice [1-3]: " -n 1 -r choice
    echo ""

    case $choice in
        1)
            read -p "Private repo URL (git@... or https://...): " private_url
            if [[ -n "$private_url" ]]; then
                setup_private_repo "$private_url"
            fi
            ;;
        2)
            show_private_template
            ;;
        3)
            echo -e "${BLUE}→${NC} Skipping private repo setup"
            echo "   You can add one later: ./setup.sh <repo-url>"
            ;;
        *)
            echo -e "${YELLOW}⚠${NC} Invalid choice, skipping private repo"
            ;;
    esac
}

# Show template for creating private repo
show_private_template() {
    echo ""
    echo -e "${BLUE}Creating Your Private Repository${NC}"
    echo "================================="
    echo ""
    echo "1. Create a new private repo on GitHub/GitLab"
    echo "   Name suggestion: deckible-private"
    echo ""
    echo "2. Clone it and create this structure:"
    echo ""
    echo -e "${YELLOW}"
    cat << 'EOF'
deckible-private/
├── group_vars/
│   └── all.yml          # Your personal settings
└── files/
    ├── appimages/       # EmuDeck EA, etc.
    │   └── .gitkeep
    └── flatpaks/        # Local .flatpak files
        └── .gitkeep
EOF
    echo -e "${NC}"
    echo ""
    echo "3. Copy the default config to start:"
    echo "   cp group_vars/all.yml <your-private-repo>/group_vars/all.yml"
    echo ""
    echo "4. Edit your settings, commit, and push"
    echo ""
    echo "5. Run: ./setup.sh <your-private-repo-url>"
    echo ""
    read -p "Press Enter to continue..."
}

# Main setup flow
main() {
    check_system
    echo ""

    # Handle command line arguments
    if [[ "$1" == "--skip-private" ]]; then
        echo -e "${BLUE}→${NC} Skipping private repo setup"
    elif [[ -n "$1" ]]; then
        setup_private_repo "$1"
    else
        interactive_private_setup
    fi

    echo ""
    check_ansible || true

    echo ""
    echo -e "${GREEN}Setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review/edit your configuration:"
    if [[ -d "private" ]]; then
        echo "     - Private settings: private/group_vars/all.yml"
    else
        echo "     - Settings: group_vars/all.yml"
    fi
    echo ""
    echo "  2. Run the playbook:"
    echo "     ansible-playbook playbook.yml --ask-become-pass"
    echo ""
    echo "  3. For specific components only:"
    echo "     ansible-playbook playbook.yml --tags apps --ask-become-pass"
    echo ""
}

main "$@"
