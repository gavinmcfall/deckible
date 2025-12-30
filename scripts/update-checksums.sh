#!/bin/bash
# Generate SHA256 checksums for Cloudflare worker integrity verification
# Run this after modifying targets/ally.ps1 or targets/deck.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$REPO_ROOT"

# Calculate hashes
ALLY_HASH=$(sha256sum targets/ally.ps1 | cut -d' ' -f1)
DECK_HASH=$(sha256sum targets/deck.sh | cut -d' ' -f1)

echo "SHA256 Checksums for cloudflare/_worker.js"
echo "==========================================="
echo ""
echo "Update the ROUTES object with these values:"
echo ""
echo "  '/rog': {"
echo "    path: '/targets/ally.ps1',"
echo "    description: 'ROG Ally (Windows)',"
echo "    sha256: '$ALLY_HASH',"
echo "  },"
echo "  '/deck': {"
echo "    path: '/targets/deck.sh',"
echo "    description: 'Steam Deck (SteamOS)',"
echo "    sha256: '$DECK_HASH',"
echo "  },"
echo ""
echo "IMPORTANT: Deploy scripts and worker together to avoid integrity failures."
