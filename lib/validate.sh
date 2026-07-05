#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# lib/validate.sh — Validation functions (read-only; block_device queries lsblk)
# Each function returns 0 (valid) or 1 (invalid)

# Usernames that collide with accounts created by the base system
VALIDATE_RESERVED_USERNAMES=(
    root bin daemon mail ftp http nobody dbus git uuidd tss
    systemd-coredump systemd-network systemd-oom systemd-journal-remote
    systemd-journal-upload systemd-resolve systemd-timesync
)

validate::hostname() {
    local name="${1:-}"
    [[ "$name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

validate::username() {
    local name="${1:-}"
    [[ "$name" =~ ^[a-z][a-z0-9_-]{0,31}$ ]] || return 1
    local reserved
    for reserved in "${VALIDATE_RESERVED_USERNAMES[@]}"; do
        if [[ "$name" == "$reserved" ]]; then
            return 1
        fi
    done
    return 0
}

validate::password() {
    local pass="${1:-}"
    [[ ${#pass} -ge 8 && "$pass" != *:* ]]
}

validate::block_device() {
    local dev="${1:-}"
    [[ -b "$dev" ]] || return 1
    validate::_disk_usable "$dev"
}

# Whole-disk (or loop) device with nothing mounted — safe to wipe.
# Rejects partitions, RAID/LVM members, and disks with active mounts or swap.
validate::_disk_usable() {
    local dev="${1:-}"
    local type mounts
    type=$(lsblk -dno TYPE "$dev" 2>/dev/null) || return 1
    [[ "$type" == "disk" || "$type" == "loop" ]] || return 1
    mounts=$(lsblk -no MOUNTPOINTS "$dev" 2>/dev/null) || return 1
    [[ -z "${mounts//[[:space:]]/}" ]]
}

validate::timezone() {
    local tz="${1:-}"
    # No traversal outside the zoneinfo database
    [[ "$tz" != *".."* && "$tz" != /* ]] || return 1
    [[ -f "/usr/share/zoneinfo/$tz" ]]
}
