#!/usr/bin/env bats
# test_detect.sh — Mocked cpuinfo and /sys/firmware/efi

load 'helpers'

setup() {
    source "${BATS_TEST_DIRNAME}/../lib/detect.sh"
}

# --- detect::cpu_vendor ---

@test "detect::cpu_vendor returns intel-ucode for Intel CPU" {
    run detect::cpu_vendor "$(fixture_cpuinfo_intel)"
    [ "$status" -eq 0 ]
    [ "$output" = "intel-ucode" ]
}

@test "detect::cpu_vendor returns amd-ucode for AMD CPU" {
    run detect::cpu_vendor "$(fixture_cpuinfo_amd)"
    [ "$status" -eq 0 ]
    [ "$output" = "amd-ucode" ]
}

@test "detect::cpu_vendor returns empty for unknown CPU" {
    local tmp_file="/tmp/cpuinfo_unknown"
    printf 'processor\t: 0\nvendor_id\t: UnknownVendor\n' > "$tmp_file"

    run detect::cpu_vendor "$tmp_file"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    rm -f "$tmp_file"
}

# --- detect::partition_names ---

@test "detect::partition_names handles nvme disk" {
    run detect::partition_names "/dev/nvme0n1"
    [ "$status" -eq 0 ]
    [ "$output" = "/dev/nvme0n1p1 /dev/nvme0n1p2" ]
}

@test "detect::partition_names handles sata disk" {
    run detect::partition_names "/dev/sda"
    [ "$status" -eq 0 ]
    [ "$output" = "/dev/sda1 /dev/sda2" ]
}

@test "detect::partition_names handles mmcblk disk" {
    run detect::partition_names "/dev/mmcblk0"
    [ "$status" -eq 0 ]
    [ "$output" = "/dev/mmcblk0p1 /dev/mmcblk0p2" ]
}

@test "detect::partition_names handles vda disk" {
    run detect::partition_names "/dev/vda"
    [ "$status" -eq 0 ]
    [ "$output" = "/dev/vda1 /dev/vda2" ]
}

# --- detect::boot_mode ---

@test "detect::boot_mode returns uefi when /sys/firmware/efi exists" {
    if [ ! -d /sys/firmware/efi ]; then
        skip "Not running on UEFI system"
    fi
    run detect::boot_mode
    [ "$status" -eq 0 ]
    [ "$output" = "uefi" ]
}

@test "detect::boot_mode returns bios when /sys/firmware/efi missing" {
    if [ -d /sys/firmware/efi ]; then
        skip "Running on UEFI system"
    fi
    run detect::boot_mode
    [ "$status" -eq 0 ]
    [ "$output" = "bios" ]
}
