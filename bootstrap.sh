#!/bin/bash
set -euo pipefail

# bootstrap.sh — curl entrypoint for arch-linux-bootstrap
# Usage: curl -sL https://raw.githubusercontent.com/nitink2306/arch-linux-bootstrap/main/bootstrap.sh | bash
#
# Clones the full repo so that lib/ modules are available, then hands off to arch-install.sh.
# Pin a release instead of main with: ARCH_BOOTSTRAP_REF=v0.1.0

REPO_URL="https://github.com/nitink2306/arch-linux-bootstrap.git"
REF="${ARCH_BOOTSTRAP_REF:-main}"

if ! command -v git &>/dev/null; then
    echo "Error: git is required but not installed. Install git and re-run." >&2
    exit 1
fi

# Fresh private clone dir every run — never reuse a fixed world-writable /tmp
# path where stale or pre-planted code could end up executed as root.
CLONE_DIR="$(mktemp -d /tmp/arch-bootstrap.XXXXXX)"

echo "Cloning arch-linux-bootstrap (${REF})..."
git clone --depth=1 --branch "$REF" "$REPO_URL" "$CLONE_DIR"

if [ -e /dev/tty ]; then
    exec bash "$CLONE_DIR/arch-install.sh" "$@" </dev/tty
else
    exec bash "$CLONE_DIR/arch-install.sh" "$@"
fi
