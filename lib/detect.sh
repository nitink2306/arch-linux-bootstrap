#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# lib/detect.sh — Hardware and environment detection

detect::boot_mode() {
    if [[ -d /sys/firmware/efi ]]; then
        echo "uefi"
    else
        echo "bios"
    fi
}

detect::cpu_vendor() {
    local cpuinfo="${1:-/proc/cpuinfo}"
    local vendor
    vendor=$(grep -m1 "vendor_id" "$cpuinfo" | awk '{print $3}')

    case "$vendor" in
        GenuineIntel) echo "intel-ucode" ;;
        AuthenticAMD) echo "amd-ucode" ;;
        *) echo "" ;;
    esac
}

detect::partition_names() {
    local disk="${1:-}"
    if [[ "$disk" == *"nvme"* || "$disk" == *"mmcblk"* ]]; then
        echo "${disk}p1 ${disk}p2"
    else
        echo "${disk}1 ${disk}2"
    fi
}
