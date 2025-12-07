#!/bin/zsh
# Kollaborate Installation Script
# Adds kollaborate to your PATH

set -e

KOLLABORATE_DIR="$(cd "$(dirname "$0")" && pwd)"
SHELL_RC=""

# Detect shell config file
if [[ -n "$ZSH_VERSION" ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" ]]; then
    SHELL_RC="$HOME/.bashrc"
else
    SHELL_RC="$HOME/.profile"
fi

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           Kollaborate Installation                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Kollaborate directory: $KOLLABORATE_DIR"
echo "Shell config file: $SHELL_RC"
echo ""

# Check if already installed
if grep -q "KOLLABORATE_HOME" "$SHELL_RC" 2>/dev/null; then
    echo "[!] Kollaborate already configured in $SHELL_RC"
    echo "    To reinstall, remove the existing configuration first."
    exit 0
fi

# Add to shell config
echo "" >> "$SHELL_RC"
echo "# Kollaborate - Autonomous Multi-Agent Development Framework" >> "$SHELL_RC"
echo "export KOLLABORATE_HOME=\"$KOLLABORATE_DIR\"" >> "$SHELL_RC"
echo "export PATH=\"\$KOLLABORATE_HOME:\$PATH\"" >> "$SHELL_RC"

echo "[+] Added to $SHELL_RC:"
echo "    export KOLLABORATE_HOME=\"$KOLLABORATE_DIR\""
echo "    export PATH=\"\$KOLLABORATE_HOME:\$PATH\""
echo ""
echo "Installation complete!"
echo ""
echo "To use immediately, run:"
echo "    source $SHELL_RC"
echo ""
echo "Or open a new terminal and run:"
echo "    kollaborate help"
echo ""
