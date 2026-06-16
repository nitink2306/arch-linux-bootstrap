#!/bin/bash
set -euo pipefail
trap 'echo "[ERROR] Script failed at line $LINENO. Check /tmp/arch-install.log for details." >&2' ERR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for lib in log validate preset detect ui disk pacstrap chroot; do
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/${lib}.sh"
done
unset DISK HOSTNAME USERNAME TIMEZONE LOCALE
DRY_RUN=false; PRESET_FILE=""; PRESET_MODE=false; export PRESET_MODE

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --preset)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: --preset requires a file argument" >&2; exit 1
                fi
                PRESET_FILE="$2"; shift 2 ;;
            --dry-run) DRY_RUN=true; shift ;;
            --help) echo "Usage: arch-install.sh [--preset FILE] [--dry-run] [--help]"; exit 0 ;;
            *) echo "Error: Unknown option: $1" >&2; exit 1 ;;
        esac
    done
}

main() {
    parse_args "$@"
    log::setup
    echo "============================================================"
    echo " Arch Linux Installer"
    echo "============================================================"
    if [[ -n "$PRESET_FILE" ]]; then
        preset::load "$PRESET_FILE"; PRESET_MODE=true
        log::info "Preset loaded from $PRESET_FILE"
    fi
    BOOT_MODE=$(detect::boot_mode); log::info "Boot mode: $BOOT_MODE"
    MICROCODE=$(detect::cpu_vendor); log::info "Microcode: ${MICROCODE:-none}"
    REFLECTOR_COUNTRY="${REFLECTOR_COUNTRY:-United States}"
    ui::collect_inputs
    ui::confirm_summary
    log::info "Installation started."
    read -r PART1 PART2 <<< "$(detect::partition_names "$DISK")"
    if [[ "$DRY_RUN" == "true" ]]; then
        for fn in disk::partition disk::format disk::create_subvolumes \
                  disk::mount pacstrap::rank_mirrors pacstrap::install chroot::configure; do
            echo "[DRY RUN] skipping $fn"
        done
        return 0
    fi
    disk::partition "$DISK" "$BOOT_MODE"
    disk::format "$PART1" "$PART2" "$BOOT_MODE"
    disk::create_subvolumes "$PART2"
    disk::mount "$PART1" "$PART2" "$BOOT_MODE"
    log::persist
    mkdir -p /mnt/etc && genfstab -U /mnt >> /mnt/etc/fstab
    pacstrap::rank_mirrors "$REFLECTOR_COUNTRY"
    pacstrap::install "$MICROCODE"
    chroot::configure "$TIMEZONE" "$LOCALE" "$HOSTNAME" "$ROOT_PASSWORD" "$USERNAME" "$USER_PASSWORD" "$BOOT_MODE" "$DISK"
    preset::copy_to_system "$USERNAME" "$SCRIPT_DIR"
    disk::unmount; ui::prompt_reboot
}

main "$@"