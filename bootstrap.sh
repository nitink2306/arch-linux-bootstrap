#!/bin/bash
set -euo pipefail

# bootstrap.sh — curl entrypoint for arch-linux-bootstrap
# Usage: curl -sL https://raw.githubusercontent.com/nitink2306/arch-linux-bootstrap/main/bootstrap.sh | bash
#
# Clones the full repo so that lib/ modules are available, then hands off to arch-install.sh.

REPO_URL="https://github.com/nitink2306/arch-linux-bootstrap.git"
CLONE_DIR="/tmp/arch-bootstrap"

if [ ! -d "$CLONE_DIR" ]; then
    echo "Cloning arch-linux-bootstrap..."
    git clone --depth=1 "$REPO_URL" "$CLONE_DIR"
fi

exec bash "$CLONE_DIR/arch-install.sh" "$@"
