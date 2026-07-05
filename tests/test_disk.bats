#!/usr/bin/env bats
# test_disk.bats — Partitioning, formatting, and mounting with stubbed system tools

load 'helpers'

setup() {
    source "${BATS_TEST_DIRNAME}/../lib/log.sh"
    source "${BATS_TEST_DIRNAME}/../lib/disk.sh"
    stub_setup
    stub wipefs
    stub sgdisk
    stub partprobe
    stub parted
    stub sleep
    stub mount
    stub umount
    stub btrfs
    stub mkfs.fat
    stub mkfs.btrfs
    stub mountpoint 1   # default: /mnt not mounted
}

# --- disk::partition ---

@test "disk::partition wipes the disk before partitioning" {
    run disk::partition /dev/sda uefi
    [ "$status" -eq 0 ]
    grep -q '^wipefs -af /dev/sda$' "$STUB_LOG"
    grep -q '^sgdisk -Z /dev/sda$' "$STUB_LOG"
    grep -q '^partprobe /dev/sda$' "$STUB_LOG"
}

@test "disk::partition creates GPT layout with ESP for uefi" {
    run disk::partition /dev/sda uefi
    [ "$status" -eq 0 ]
    grep -q 'parted -s /dev/sda mklabel gpt' "$STUB_LOG"
    grep -q 'mkpart ESP fat32 1MiB 513MiB' "$STUB_LOG"
    grep -q 'set 1 esp on' "$STUB_LOG"
    grep -q 'mkpart primary btrfs 513MiB 100%' "$STUB_LOG"
}

@test "disk::partition creates GPT layout with bios_grub for bios" {
    # GPT for BIOS too: bios_grub is a GPT-only flag (parted rejects it on msdos)
    run disk::partition /dev/sda bios
    [ "$status" -eq 0 ]
    grep -q 'parted -s /dev/sda mklabel gpt' "$STUB_LOG"
    grep -q 'set 1 bios_grub on' "$STUB_LOG"
    grep -q 'mkpart primary btrfs 2MiB 100%' "$STUB_LOG"
    run grep -q 'esp' "$STUB_LOG"
    [ "$status" -ne 0 ]
}

# --- disk::format ---

@test "disk::format formats ESP and root for uefi" {
    run disk::format /dev/sda1 /dev/sda2 uefi
    [ "$status" -eq 0 ]
    grep -q '^mkfs.fat -F32 /dev/sda1$' "$STUB_LOG"
    grep -q '^mkfs.btrfs -f -L ArchRoot /dev/sda2$' "$STUB_LOG"
}

@test "disk::format skips ESP formatting for bios" {
    run disk::format /dev/sda1 /dev/sda2 bios
    [ "$status" -eq 0 ]
    grep -q '^mkfs.btrfs -f -L ArchRoot /dev/sda2$' "$STUB_LOG"
    run grep -q 'mkfs.fat' "$STUB_LOG"
    [ "$status" -ne 0 ]
}

# --- disk::create_subvolumes ---

@test "disk::create_subvolumes creates all four subvolumes" {
    run disk::create_subvolumes /dev/sda2
    [ "$status" -eq 0 ]
    grep -q '^mount /dev/sda2 /mnt$' "$STUB_LOG"
    grep -q '^btrfs subvolume create /mnt/@$' "$STUB_LOG"
    grep -q '^btrfs subvolume create /mnt/@home$' "$STUB_LOG"
    grep -q '^btrfs subvolume create /mnt/@snapshots$' "$STUB_LOG"
    grep -q '^btrfs subvolume create /mnt/@var_log$' "$STUB_LOG"
    grep -q '^umount /mnt$' "$STUB_LOG"
}

@test "disk::create_subvolumes unmounts a leftover /mnt from a previous run" {
    stub mountpoint 0   # /mnt is mounted
    run disk::create_subvolumes /dev/sda2
    [ "$status" -eq 0 ]
    [[ "$output" == *"already mounted"* ]]
    grep -q '^umount -R /mnt$' "$STUB_LOG"
}

# --- disk::mount ---

@test "disk::mount mounts subvolumes with compression and boot for uefi" {
    run disk::mount /dev/sda1 /dev/sda2 uefi
    [ "$status" -eq 0 ]
    grep -q '^mount -o noatime,compress=zstd,subvol=@ /dev/sda2 /mnt$' "$STUB_LOG"
    grep -q '^mount -o noatime,compress=zstd,subvol=@home /dev/sda2 /mnt/home$' "$STUB_LOG"
    grep -q '^mount -o noatime,compress=zstd,subvol=@snapshots /dev/sda2 /mnt/snapshots$' "$STUB_LOG"
    grep -q '^mount -o noatime,compress=zstd,subvol=@var_log /dev/sda2 /mnt/var/log$' "$STUB_LOG"
    grep -q '^mount /dev/sda1 /mnt/boot$' "$STUB_LOG"
}

@test "disk::mount does not mount a boot partition for bios" {
    run disk::mount /dev/sda1 /dev/sda2 bios
    [ "$status" -eq 0 ]
    run grep -q '/mnt/boot' "$STUB_LOG"
    [ "$status" -ne 0 ]
}

# --- disk::unmount ---

@test "disk::unmount succeeds when umount works" {
    run disk::unmount
    [ "$status" -eq 0 ]
    grep -q '^umount -R /mnt$' "$STUB_LOG"
}

@test "disk::unmount retries and reports failure when umount keeps failing" {
    stub umount 1
    run disk::unmount
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not unmount /mnt"* ]]
    [ "$(grep -c '^umount -R /mnt$' "$STUB_LOG")" -eq 3 ]
}
