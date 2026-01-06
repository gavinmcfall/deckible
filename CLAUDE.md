# Bootible Project Instructions

## Core Design Principle

**CRITICAL**: The purpose of this project is to minimize typing on devices with on-screen keyboards (Steam Deck, ROG Ally).

The user experience MUST be:
1. One command to dry run: `curl -fsSL https://bootible.dev/deck | bash`
2. One command to apply: `bootible`

**NO exceptions. NO extra steps:**
- NO sourcing terminals
- NO setting environment variables
- NO typing full paths
- NO additional flags or parameters
- The script MUST handle everything automatically

If any change requires the user to type more than `bootible` for the real run, the implementation is wrong. Fix the script, not the instructions.

## Platform Parity

Steam Deck (`deck.sh`) and ROG Ally (`ally.ps1`) should have feature parity:
- GitHub Device Flow authentication with QR code
- Automatic log push to private repo
- Dry run by default via curl, real run via local command
- Handle all edge cases gracefully (missing networks, check mode, etc.)
