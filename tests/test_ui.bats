#!/usr/bin/env bats
# test_ui.bats — Paginated selection, disk confirmation, and summary confirmation
# Interactive prompts are driven with scripted stdin via herestrings.

load 'helpers'

setup() {
    source "${BATS_TEST_DIRNAME}/../lib/log.sh"
    source "${BATS_TEST_DIRNAME}/../lib/validate.sh"
    source "${BATS_TEST_DIRNAME}/../lib/ui.sh"
}

# --- ui::_select_paginated ---

paginated_result() {
    local out
    ui::_select_paginated out "$@"
    printf 'RESULT=%s\n' "$out"
}

@test "ui::_select_paginated selects item by number" {
    run paginated_result "" alpha beta gamma <<< "2"
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESULT=beta"* ]]
}

@test "ui::_select_paginated pages forward on ENTER and accepts global numbers" {
    # 15 items, PAGE_SIZE=10: ENTER shows the second page, then pick item 12
    run paginated_result "" $(seq -f 'item%g' 1 15) <<< $'\n12\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESULT=item12"* ]]
}

@test "ui::_select_paginated wraps to the first page at the end" {
    # Two ENTERs walk past the last page and wrap; then select item 1
    run paginated_result "" $(seq -f 'item%g' 1 15) <<< $'\n\n1\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESULT=item1"* ]]
}

@test "ui::_select_paginated returns default on ENTER at last page" {
    run paginated_result "gamma" alpha beta gamma <<< $'\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"RESULT=gamma"* ]]
}

@test "ui::_select_paginated rejects invalid and out-of-range input" {
    run paginated_result "" alpha beta gamma <<< $'abc\n0\n99\n3\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Invalid selection"* ]]
    [[ "$output" == *"RESULT=gamma"* ]]
}

# --- ui::_select_disk ---

disk_result() {
    DISK=""
    DISK_FROM_PRESET=false
    ui::_select_disk
    printf 'DISK=%s FROM_PRESET=%s\n' "$DISK" "$DISK_FROM_PRESET"
}

preset_disk_result() {
    DISK="$1"
    DISK_FROM_PRESET=false
    ui::_select_disk
    printf 'DISK=%s FROM_PRESET=%s\n' "$DISK" "$DISK_FROM_PRESET"
}

@test "ui::_select_disk accepts a disk typed twice" {
    stub_setup
    stub lsblk
    validate::block_device() { [[ "$1" == "/dev/sda" ]]; }
    run disk_result <<< $'/dev/sda\n/dev/sda\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"DISK=/dev/sda FROM_PRESET=false"* ]]
}

@test "ui::_select_disk restarts when confirmation does not match" {
    stub_setup
    stub lsblk
    validate::block_device() { [[ "$1" == /dev/sd? ]]; }
    run disk_result <<< $'/dev/sda\n/dev/sdb\n/dev/sda\n/dev/sda\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Disks do not match"* ]]
    [[ "$output" == *"DISK=/dev/sda"* ]]
}

@test "ui::_select_disk rejects an invalid device and reprompts" {
    stub_setup
    stub lsblk
    validate::block_device() { [[ "$1" == "/dev/sda" ]]; }
    run disk_result <<< $'/dev/bad\n/dev/sda\n/dev/sda\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"not a valid block device"* ]]
    [[ "$output" == *"DISK=/dev/sda"* ]]
}

@test "ui::_select_disk uses a valid preset disk without prompting" {
    validate::block_device() { [[ "$1" == "/dev/sda" ]]; }
    run preset_disk_result "/dev/sda" < /dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"Disk loaded from preset"* ]]
    [[ "$output" == *"DISK=/dev/sda FROM_PRESET=true"* ]]
}

@test "ui::_select_disk falls back to prompt when preset disk is invalid" {
    stub_setup
    stub lsblk
    validate::block_device() { [[ "$1" == "/dev/sda" ]]; }
    run preset_disk_result "/dev/bad" <<< $'/dev/sda\n/dev/sda\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"falling back to prompt"* ]]
    [[ "$output" == *"DISK=/dev/sda FROM_PRESET=false"* ]]
}

# --- ui::confirm_summary ---

confirm_result() {
    local from_preset="$1"
    BOOT_MODE="uefi"
    MICROCODE=""
    DISK="/dev/sda"
    HOSTNAME="myhost"
    USERNAME="user1"
    TIMEZONE="UTC"
    LOCALE="en_US.UTF-8"
    PRESET_MODE="$from_preset"
    DISK_FROM_PRESET="$from_preset"
    DRY_RUN=false
    ui::confirm_summary
    echo "PROCEEDED"
}

@test "ui::confirm_summary proceeds on y in interactive mode" {
    run confirm_result false <<< $'y\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"PROCEEDED"* ]]
}

@test "ui::confirm_summary aborts on n in interactive mode" {
    run confirm_result false <<< $'n\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Aborted."* ]]
    [[ "$output" != *"PROCEEDED"* ]]
}

@test "ui::confirm_summary in preset mode proceeds after typing the disk path" {
    # (prompt text is not asserted: read -rp only prints prompts on a TTY)
    run confirm_result true <<< $'/dev/sda\ny\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"PROCEEDED"* ]]
}

@test "ui::confirm_summary in preset mode consumes an extra confirmation line" {
    # A bare y (which suffices interactively) must NOT proceed in preset mode
    run confirm_result true <<< $'y\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"did not match"* ]]
    [[ "$output" != *"PROCEEDED"* ]]
}

@test "ui::confirm_summary in preset mode aborts when typed disk does not match" {
    run confirm_result true <<< $'/dev/sdb\n'
    [ "$status" -eq 0 ]
    [[ "$output" == *"did not match"* ]]
    [[ "$output" != *"PROCEEDED"* ]]
}
