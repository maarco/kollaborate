#!/bin/zsh
# Kollaborate Installation Script
# Works both locally and remotely via curl

set -e

INSTALL_DIR="$HOME/.kollaborate"
SHELL_RC=""

# MAXIMUM BRIGHTNESS - Lime and Cyan theme with BOLD
CYAN='\033[1;38;2;0;255;255m'
LIME='\033[1;38;2;0;255;0m'
RESET='\033[0m'

# Detect if running from local repo or via curl
if [[ -f "$(dirname "$0")/kollaborate" ]]; then
    # Local installation
    SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
    INSTALL_METHOD="local"
else
    # Remote installation via curl
    INSTALL_METHOD="remote"
    REPO_URL="https://raw.githubusercontent.com/yourusername/kollaborate/main"
fi

# Detect shell config file
if [[ -n "$ZSH_VERSION" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" ]]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC="$HOME/.profile"
fi

echo -e "${CYAN}╔══════════════════════════════════╗${RESET}"
echo -e "${CYAN}║     Kollaborate Installation     ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════╝${RESET}"
echo ""
echo "Install directory: $INSTALL_DIR"
echo "Shell config file: $SHELL_RC"
echo ""

# Check if already installed
if [[ -d "$INSTALL_DIR" ]]; then
    echo -e "${CYAN}[!] Found existing installation${RESET}"
    echo -e "${CYAN}    Updating...${RESET}"
    echo ""
else
    echo -e "${LIME}[+] Creating $INSTALL_DIR${RESET}"
    mkdir -p "$INSTALL_DIR"
fi

# Install files based on method
echo -e "${LIME}[+] Installing Kollaborate files...${RESET}"

if [[ "$INSTALL_METHOD" == "local" ]]; then
    # Copy from local directory
    cp "$SOURCE_DIR/kollaborate" "$INSTALL_DIR/kollaborate"
    cp "$SOURCE_DIR/kollaborate.sh" "$INSTALL_DIR/kollaborate.sh"
    cp "$SOURCE_DIR/kollaborate.md" "$INSTALL_DIR/kollaborate.md"
    echo -e "${LIME}    Copied from $SOURCE_DIR${RESET}"
else
    # Download from remote
    if command -v curl &> /dev/null; then
        curl -fsSL "$REPO_URL/kollaborate" -o "$INSTALL_DIR/kollaborate"
        curl -fsSL "$REPO_URL/kollaborate.sh" -o "$INSTALL_DIR/kollaborate.sh"
        curl -fsSL "$REPO_URL/kollaborate.md" -o "$INSTALL_DIR/kollaborate.md"
    elif command -v wget &> /dev/null; then
        wget -q "$REPO_URL/kollaborate" -O "$INSTALL_DIR/kollaborate"
        wget -q "$REPO_URL/kollaborate.sh" -O "$INSTALL_DIR/kollaborate.sh"
        wget -q "$REPO_URL/kollaborate.md" -O "$INSTALL_DIR/kollaborate.md"
    else
        echo -e "${CYAN}[!] Error: curl or wget required for remote installation${RESET}"
        exit 1
    fi
    echo -e "${LIME}    Downloaded from $REPO_URL${RESET}"
fi

chmod +x "$INSTALL_DIR/kollaborate"
chmod +x "$INSTALL_DIR/kollaborate.sh"

# Add to shell config if not already present
if ! grep -q "KOLLABORATE_HOME" "$SHELL_RC" 2>/dev/null; then
    echo "" >> "$SHELL_RC"
    echo "# Kollaborate - Autonomous Multi-Agent Development Framework" >> "$SHELL_RC"
    echo "export KOLLABORATE_HOME=\"$INSTALL_DIR\"" >> "$SHELL_RC"
    echo "export PATH=\"\$KOLLABORATE_HOME:\$PATH\"" >> "$SHELL_RC"

    echo ""
    echo -e "${LIME}[+] Added to $SHELL_RC${RESET}"
    echo ""
    echo -e "${LIME}    export KOLLABORATE_HOME=\"$INSTALL_DIR\"${RESET}"
    echo -e "${LIME}    export PATH=\"\$KOLLABORATE_HOME:\$PATH\"${RESET}"
else
    echo ""
    echo -e "${CYAN}[!] $SHELL_RC already configured${RESET}"
fi

echo ""
echo -e "${LIME}✓ Installation complete!${RESET}"
echo ""
echo "Installed files:"
echo "  - ${CYAN}$INSTALL_DIR/kollaborate${RESET} (CLI)"
echo "  - ${CYAN}$INSTALL_DIR/kollaborate.sh${RESET} (Daemon)"
echo "  - ${CYAN}$INSTALL_DIR/kollaborate.md${RESET} (Template)"
echo ""
echo "To use immediately, run:"
echo -e "    ${CYAN}source $SHELL_RC${RESET}"
echo ""
echo "Or open a new terminal and run:"
echo -e "    ${CYAN}kollaborate help${RESET}"
echo ""
