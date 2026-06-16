#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# lib/pacstrap.sh — Mirror ranking and base system installation

pacstrap::rank_mirrors() {
    local country="${1:-United States}"

    log::info "Ranking mirrors with reflector..."
    if command -v reflector &>/dev/null; then
        reflector \
            --country "$country" \
            --latest 20 \
            --protocol https \
            --sort rate \
            --number 10 \
            --save /etc/pacman.d/mirrorlist
        log::info "Mirrors updated."
    else
        log::info "reflector not found — using default mirrorlist."
    fi
}

pacstrap::install() {
    local microcode="${1:-}"

    log::info "Installing base system..."

    local -a PACKAGES=(base base-devel linux linux-firmware sudo vim git)

    if [[ -n "$microcode" ]]; then
        PACKAGES+=("$microcode")
    fi

    pacstrap /mnt "${PACKAGES[@]}"

    log::info "Base system installed."
}
