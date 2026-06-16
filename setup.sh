#!/bin/bash
set -e

# ------------------------------------------------------------
# Post-install setup — run as normal user after first boot
# ------------------------------------------------------------

echo "============================================================"
echo " Arch Post-Install Setup"
echo "============================================================"
echo ""

# ------------------------------------------------------------
# YAY — AUR helper
# ------------------------------------------------------------
echo "Installing yay..."

cd ~
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay

echo "yay installed."
echo ""

echo "============================================================"
echo " Setup complete. You're good to go."
echo "============================================================"
