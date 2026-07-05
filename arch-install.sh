#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for lib in log validate preset detect ui disk pacstrap chroot; do
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/lib/${lib}.sh"
done
unset DISK HOSTNAME USERNAME TIMEZONE LOCALE REFLECTOR_COUNTRY
DRY_RUN=false; PRESET_FILE=""; PRESET_MODE=false; export PRESET_MODE

on_error() {
    local line="$1"
    echo "[ERROR] Script failed at line $line. Check /tmp/arch-install.log for details." >&2
    if mountpoint -q /mnt 2>/dev/null; then
        echo "[ERROR] Cleaning up: unmounting /mnt so the installer can be re-run..." >&2
        umount -R /mnt 2>/dev/null \
            || echo "[ERROR] Could not unmount /mnt — run 'umount -R /mnt' before retrying." >&2
    fi
}
trap 'on_error $LINENO' ERR

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

preflight() {
    if [[ $EUID -ne 0 ]]; then
        log::error "This installer must run as root (from the Arch live ISO)."
        exit 1
    fi
    local cmd
    for cmd in pacstrap arch-chroot genfstab sgdisk parted wipefs partprobe \
               lsblk blockdev mkfs.fat mkfs.btrfs btrfs curl; do
        if ! command -v "$cmd" &>/dev/null; then
            log::error "Required command '$cmd' not found — run this from the Arch live ISO."
            exit 1
        fi
    done
    log::info "Checking network connectivity..."
    if ! curl -sSf --max-time 10 -o /dev/null https://archlinux.org; then
        log::error "No network connectivity. Connect first (e.g. 'iwctl' for Wi-Fi), then re-run."
        exit 1
    fi
}

preflight_disk() {
    local disk="$1"
    local size min_size=$((20 * 1024 * 1024 * 1024))
    size=$(blockdev --getsize64 "$disk")
    if (( size < min_size )); then
        log::error "Disk $disk is smaller than the required 20GiB ($size bytes)."
        exit 1
    fi
}

install_fstab() {
    local fstab_tmp
    fstab_tmp=$(mktemp)
    mkdir -p /mnt/etc
    genfstab -U /mnt > "$fstab_tmp"
    if ! grep -q 'UUID=' "$fstab_tmp"; then
        rm -f "$fstab_tmp"
        log::error "genfstab produced no UUID entries — refusing to write an unbootable fstab."
        exit 1
    fi
    cat "$fstab_tmp" > /mnt/etc/fstab
    rm -f "$fstab_tmp"
    log::info "fstab written."
}

main() {
    parse_args "$@"
    log::setup
    echo "============================================================"
    echo " Arch Linux Installer"
    echo "============================================================"
    if [[ "$DRY_RUN" == "false" ]]; then
        preflight
    fi
    if [[ -n "$PRESET_FILE" ]]; then
        preset::load "$PRESET_FILE"; PRESET_MODE=true
        log::info "Preset loaded from $PRESET_FILE"
    fi
    BOOT_MODE=$(detect::boot_mode); log::info "Boot mode: $BOOT_MODE"
    MICROCODE=$(detect::cpu_vendor); log::info "Microcode: ${MICROCODE:-none}"
    REFLECTOR_COUNTRY="${REFLECTOR_COUNTRY:-United States}"
    ui::collect_inputs
    if [[ "$DRY_RUN" == "false" ]]; then
        preflight_disk "$DISK"
    fi
    ui::confirm_summary
    log::info "Installation started."
    read -r PART1 PART2 <<< "$(detect::partition_names "$DISK")"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo "[DRY RUN] No changes were made. A real run would:"
        echo "[DRY RUN]   wipe and partition   $DISK ($BOOT_MODE)"
        echo "[DRY RUN]   boot partition       $PART1"
        echo "[DRY RUN]   root partition       $PART2 (btrfs subvolumes: @ @home @snapshots @var_log)"
        echo "[DRY RUN]   rank mirrors         reflector --country '$REFLECTOR_COUNTRY'"
        echo "[DRY RUN]   pacstrap packages    base base-devel linux linux-firmware sudo vim git${MICROCODE:+ $MICROCODE}"
        echo "[DRY RUN]   configure system     timezone=$TIMEZONE locale=$LOCALE hostname=$HOSTNAME user=$USERNAME"
        return 0
    fi
    disk::partition "$DISK" "$BOOT_MODE"
    disk::format "$PART1" "$PART2" "$BOOT_MODE"
    disk::create_subvolumes "$PART2"
    disk::mount "$PART1" "$PART2" "$BOOT_MODE"
    log::persist
    install_fstab
    pacstrap::rank_mirrors "$REFLECTOR_COUNTRY"
    pacstrap::install "$MICROCODE"
    chroot::configure "$TIMEZONE" "$LOCALE" "$HOSTNAME" "$ROOT_PASSWORD" "$USERNAME" "$USER_PASSWORD" "$BOOT_MODE" "$DISK"
    preset::copy_to_system "$USERNAME" "$SCRIPT_DIR"
    if disk::unmount; then
        ui::prompt_reboot
    else
        log::warn "Skipping reboot prompt — unmount /mnt manually, then reboot."
    fi
}

main "$@"
