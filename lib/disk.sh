#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# lib/disk.sh — Disk partitioning, formatting, and mounting

disk::partition() {
    local disk="${1:-}"
    local boot_mode="${2:-}"

    log::info "Wiping $disk..."
    wipefs -af "$disk"
    sgdisk -Z "$disk"
    partprobe "$disk"
    sleep 2

    if [[ "$boot_mode" == "uefi" ]]; then
        log::info "Creating GPT partition table (UEFI)..."
        parted -s "$disk" \
            mklabel gpt \
            mkpart ESP fat32 1MiB 513MiB \
            set 1 esp on \
            mkpart primary btrfs 513MiB 100%
    else
        log::info "Creating MBR partition table (BIOS)..."
        parted -s "$disk" \
            mklabel msdos \
            mkpart primary 1MiB 2MiB \
            set 1 bios_grub on \
            mkpart primary btrfs 2MiB 100%
    fi

    log::info "Partitioning complete."
}

disk::format() {
    local part1="${1:-}"
    local part2="${2:-}"
    local boot_mode="${3:-}"

    log::info "Formatting partitions..."

    if [[ "$boot_mode" == "uefi" ]]; then
        mkfs.fat -F32 "$part1"
    fi

    mkfs.btrfs -f -L ArchRoot "$part2"

    log::info "Formatting complete."
}

disk::create_subvolumes() {
    local part2="${1:-}"

    log::info "Creating btrfs subvolumes..."

    mount "$part2" /mnt

    btrfs subvolume create /mnt/@
    btrfs subvolume create /mnt/@home
    btrfs subvolume create /mnt/@snapshots
    btrfs subvolume create /mnt/@var_log

    umount /mnt

    log::info "Subvolumes created."
}

disk::mount() {
    local part1="${1:-}"
    local part2="${2:-}"
    local boot_mode="${3:-}"

    log::info "Mounting filesystems..."

    mount -o noatime,compress=zstd,subvol=@ "$part2" /mnt

    mkdir -p /mnt/{boot,home,snapshots,var/log}

    mount -o noatime,compress=zstd,subvol=@home "$part2" /mnt/home
    mount -o noatime,compress=zstd,subvol=@snapshots "$part2" /mnt/snapshots
    mount -o noatime,compress=zstd,subvol=@var_log "$part2" /mnt/var/log

    if [[ "$boot_mode" == "uefi" ]]; then
        mount "$part1" /mnt/boot
    fi

    log::info "Filesystems mounted."
}

disk::unmount() {
    log::info "Unmounting filesystems..."
    # Release the tee file handle to prevent "target is busy" error
    exec > /dev/tty 2>&1
    umount -R /mnt
}
