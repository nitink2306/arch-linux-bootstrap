#!/bin/bash
set -euo pipefail

# tests/integration/disk_loop_test.sh — End-to-end disk pipeline on a loop device
#
# Creates a sparse image, attaches it as a loop device, and runs the real
# disk:: functions (partition, format, subvolumes, mount, unmount) for both
# boot modes, asserting the resulting layout. Needs root and loop support
# (run in CI with a privileged container).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/log.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/detect.sh"
# shellcheck source=/dev/null
source "$REPO_ROOT/lib/disk.sh"

IMG=""
LOOP=""

# if-statements, not `[[ ]] &&` lists: on the happy path LOOP/IMG are empty,
# and a failing && list as the trap's last command becomes the script's exit code
cleanup() {
    umount -R /mnt 2>/dev/null || true
    if [[ -n "$LOOP" ]]; then
        losetup -d "$LOOP" 2>/dev/null || true
    fi
    if [[ -n "$IMG" ]]; then
        rm -f "$IMG"
    fi
}
trap cleanup EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

# No udev in containers — create partition device nodes from sysfs
ensure_partition_nodes() {
    local loop_name part dev
    loop_name=$(basename "$LOOP")
    for part in "/sys/block/$loop_name/$loop_name"p*; do
        [[ -d "$part" ]] || continue
        dev="/dev/$(basename "$part")"
        if [[ ! -b "$dev" ]]; then
            mknod "$dev" b "$(cut -d: -f1 "$part/dev")" "$(cut -d: -f2 "$part/dev")"
        fi
    done
}

run_mode() {
    local mode="$1"
    echo "=== Testing disk pipeline in $mode mode ==="

    IMG=$(mktemp /tmp/arch-disk-test.XXXXXX.img)
    truncate -s 25G "$IMG"
    LOOP=$(losetup --find --show --partscan "$IMG")
    echo "Loop device: $LOOP"

    local part1 part2
    read -r part1 part2 <<< "$(detect::partition_names "$LOOP")"

    disk::partition "$LOOP" "$mode"
    ensure_partition_nodes
    [[ -b "$part1" ]] || fail "$part1 was not created"
    [[ -b "$part2" ]] || fail "$part2 was not created"

    # GPT in both modes; BIOS uses a bios_grub partition instead of an ESP
    parted -s "$LOOP" print | grep -q 'gpt' || fail "expected GPT label"
    if [[ "$mode" == "uefi" ]]; then
        parted -s "$LOOP" print | grep -qi 'esp' || fail "expected ESP flag"
    else
        parted -s "$LOOP" print | grep -q 'bios_grub' || fail "expected bios_grub flag"
    fi

    disk::format "$part1" "$part2" "$mode"
    disk::create_subvolumes "$part2"
    disk::mount "$part1" "$part2" "$mode"

    findmnt -n /mnt >/dev/null || fail "/mnt not mounted"
    findmnt -n /mnt/home >/dev/null || fail "/mnt/home not mounted"
    findmnt -n /mnt/var/log >/dev/null || fail "/mnt/var/log not mounted"
    findmnt -n -o OPTIONS /mnt | grep -q 'compress=zstd' || fail "compress=zstd missing on /mnt"
    btrfs subvolume list /mnt | grep -q '@home' || fail "@home subvolume missing"
    btrfs subvolume list /mnt | grep -q '@snapshots' || fail "@snapshots subvolume missing"
    if [[ "$mode" == "uefi" ]]; then
        findmnt -n /mnt/boot >/dev/null || fail "/mnt/boot not mounted"
    fi

    disk::unmount || fail "disk::unmount failed"
    if findmnt -n /mnt >/dev/null; then
        fail "/mnt still mounted after disk::unmount"
    fi

    losetup -d "$LOOP"; LOOP=""
    rm -f "$IMG"; IMG=""
    echo "=== $mode mode: OK ==="
}

run_mode uefi
run_mode bios

echo "All disk integration tests passed."
