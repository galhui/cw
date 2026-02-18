#!/bin/bash
#
# cw installer / updater
#
# Install:
#   curl -fsSL https://raw.githubusercontent.com/galhui/cw/main/install.sh | bash
#
# Or clone and run:
#   git clone https://github.com/galhui/cw.git && cd cw && ./install.sh
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

REPO_URL="https://github.com/galhui/cw"
RAW_URL="https://raw.githubusercontent.com/galhui/cw/main/cw"
INSTALL_DIR="${CW_INSTALL_DIR:-$HOME/bin}"
CW_PATH="$INSTALL_DIR/cw"

echo -e "${BOLD}cw${NC} - Claude Workspace manager installer"
echo ""

# Check dependencies
check_deps() {
    local missing=()

    if ! command -v tmux &>/dev/null; then
        missing+=("tmux")
    fi
    if ! command -v python3 &>/dev/null; then
        missing+=("python3")
    fi
    if ! command -v claude &>/dev/null; then
        missing+=("claude (Claude Code CLI)")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}Missing dependencies:${NC}"
        for dep in "${missing[@]}"; do
            echo -e "  - $dep"
        done
        echo ""

        if [[ " ${missing[*]} " =~ " tmux " ]]; then
            if command -v brew &>/dev/null; then
                echo -e "  ${CYAN}brew install tmux${NC}"
            elif command -v apt &>/dev/null; then
                echo -e "  ${CYAN}sudo apt install tmux${NC}"
            fi
        fi

        if [[ " ${missing[*]} " =~ " claude " ]]; then
            echo -e "  ${CYAN}npm install -g @anthropic-ai/claude-code${NC}"
        fi

        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_cw() {
    mkdir -p "$INSTALL_DIR"

    # If running from cloned repo, copy the local file
    if [ -f "$(dirname "$0")/cw" ]; then
        cp "$(dirname "$0")/cw" "$CW_PATH"
    else
        # Download from GitHub
        echo -e "Downloading from ${CYAN}$RAW_URL${NC}..."
        curl -fsSL "$RAW_URL" -o "$CW_PATH"
    fi

    chmod +x "$CW_PATH"
    echo -e "${GREEN}Installed: $CW_PATH${NC}"

    # Check if INSTALL_DIR is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo ""
        echo -e "${YELLOW}$INSTALL_DIR is not in your PATH.${NC}"
        echo "Add this to your shell profile (~/.zshrc or ~/.bashrc):"
        echo ""
        echo -e "  ${CYAN}export PATH=\"$INSTALL_DIR:\$PATH\"${NC}"
        echo ""
    fi
}

show_version() {
    echo -e "${GREEN}cw installed successfully!${NC}"
    echo ""
    echo -e "Quick start:"
    echo -e "  ${CYAN}cw add myapp ~/projects/myapp${NC}    # Register a project"
    echo -e "  ${CYAN}cw myapp${NC}                         # Start Claude in it"
    echo -e "  ${CYAN}cw list${NC}                          # See active sessions"
    echo ""
    echo -e "Update later with:"
    echo -e "  ${CYAN}cw update${NC}"
    echo ""
    echo -e "Full docs: ${CYAN}$REPO_URL${NC}"
}

check_deps
install_cw
show_version
