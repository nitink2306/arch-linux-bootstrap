#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------
# Post-install setup — run as normal user after first boot
# ------------------------------------------------------------

echo "============================================================"
echo " Arch Post-Install Setup"
echo "============================================================"
echo ""

if [[ $EUID -eq 0 ]]; then
    echo "Error: run this as your normal user, not root (makepkg refuses to run as root)." >&2
    exit 1
fi

for cmd in git makepkg; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required. Install git and base-devel first." >&2
        exit 1
    fi
done

# ------------------------------------------------------------
# YAY — AUR helper
# ------------------------------------------------------------
if command -v yay &>/dev/null; then
    echo "yay is already installed — nothing to do."
    exit 0
fi

echo "Installing yay..."

BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

git clone https://aur.archlinux.org/yay.git "$BUILD_DIR/yay"
(cd "$BUILD_DIR/yay" && makepkg -si --noconfirm)

echo "yay installed."
echo ""

echo "============================================================"
echo " Setup complete. You're good to go."
echo "============================================================"
