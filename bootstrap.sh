#!/bin/bash
set -euo pipefail

# bootstrap.sh — curl entrypoint for arch-linux-bootstrap
# Usage: curl -sL https://raw.githubusercontent.com/nitink2306/arch-linux-bootstrap/main/bootstrap.sh | bash
#
# Clones the full repo so that lib/ modules are available, then hands off to arch-install.sh.

REPO_URL="https://github.com/nitink2306/arch-linux-bootstrap.git"
CLONE_DIR="/tmp/arch-bootstrap"

if ! command -v git &>/dev/null; then
    echo "Error: git is required but not installed. Install git and re-run." >&2
    exit 1
fi

if [ -d "$CLONE_DIR/.git" ]; then
    echo "Updating arch-linux-bootstrap..."
    git -C "$CLONE_DIR" pull --ff-only
elif [ ! -d "$CLONE_DIR" ]; then
    echo "Cloning arch-linux-bootstrap..."
    git clone --depth=1 "$REPO_URL" "$CLONE_DIR"
else
    echo "Directory exists but is not a git repo; re-cloning..."
    rm -rf "$CLONE_DIR"
    git clone --depth=1 "$REPO_URL" "$CLONE_DIR"
fi

if [ -e /dev/tty ]; then
    exec bash "$CLONE_DIR/arch-install.sh" "$@" </dev/tty
else
    exec bash "$CLONE_DIR/arch-install.sh" "$@"
fi
