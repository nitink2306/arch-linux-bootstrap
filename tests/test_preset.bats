#!/usr/bin/env bats
# test_preset.bats — Safe parsing, unknown keys, no code execution

load 'helpers'

setup() {
    # Source dependencies
    source "${BATS_TEST_DIRNAME}/../lib/log.sh"
    source "${BATS_TEST_DIRNAME}/../lib/preset.sh"

    # Override log::error to not interfere with tests
    log::error() { :; }
}

@test "preset::load parses valid preset correctly" {
    unset DISK HOSTNAME USERNAME TIMEZONE LOCALE REFLECTOR_COUNTRY
    preset::load "$(fixture_valid_preset)"
    [ "$DISK" = "/dev/sda" ]
    [ "$HOSTNAME" = "testarch" ]
    [ "$USERNAME" = "testuser" ]
    [ "$TIMEZONE" = "America/Chicago" ]
    [ "$LOCALE" = "en_US.UTF-8" ]
    [ "$REFLECTOR_COUNTRY" = "United States" ]
}

@test "preset::load ignores unknown keys" {
    unset DISK HOSTNAME USERNAME TIMEZONE LOCALE UNKNOWN_KEY EVIL_SETTING
    preset::load "$(fixture_unknown_keys)"
    [ "$DISK" = "/dev/sda" ]
    [ "$HOSTNAME" = "testarch" ]
    [ -z "${UNKNOWN_KEY:-}" ]
    [ -z "${EVIL_SETTING:-}" ]
}

@test "preset::load does not execute command substitution in values" {
    # Create a canary file that would be deleted if $(rm ...) executes
    touch /tmp/canary

    unset DISK HOSTNAME USERNAME TIMEZONE LOCALE REFLECTOR_COUNTRY
    preset::load "$(fixture_malicious_preset)"

    # The canary file must still exist — proof that $(rm ...) did not execute
    [ -f /tmp/canary ]
    rm -f /tmp/canary

    # Values should contain the literal text, not executed output
    [[ "$DISK" == *'rm /tmp/canary'* ]]
}

@test "preset::load strips double quotes from values" {
    local tmp_file
    tmp_file="$(mktemp)"
    printf 'HOSTNAME="my-quoted-host"\n' > "$tmp_file"

    unset HOSTNAME
    preset::load "$tmp_file"
    [ "$HOSTNAME" = "my-quoted-host" ]
    rm -f "$tmp_file"
}

@test "preset::load strips single quotes from values" {
    local tmp_file
    tmp_file="$(mktemp)"
    printf "HOSTNAME='my-squoted-host'\n" > "$tmp_file"

    unset HOSTNAME
    preset::load "$tmp_file"
    [ "$HOSTNAME" = "my-squoted-host" ]
    rm -f "$tmp_file"
}

@test "preset::load returns error for missing file" {
    run preset::load "/nonexistent/file.conf"
    [ "$status" -eq 1 ]
}

@test "preset::save produces double-quoted values" {
    DISK="/dev/nvme0n1"
    HOSTNAME="myhost"
    USERNAME="testuser"
    TIMEZONE="America/New_York"
    LOCALE="en_US.UTF-8"
    REFLECTOR_COUNTRY="Germany"

    local tmp_file
    tmp_file="$(mktemp)"
    preset::save "$tmp_file"

    # All values should be double-quoted
    grep -q 'DISK="/dev/nvme0n1"' "$tmp_file"
    grep -q 'HOSTNAME="myhost"' "$tmp_file"
    grep -q 'USERNAME="testuser"' "$tmp_file"

    # No password should appear
    ! grep -qi "password" "$tmp_file"

    rm -f "$tmp_file"
}
