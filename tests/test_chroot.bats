#!/usr/bin/env bats
# test_chroot.bats — chroot::configure with a stubbed arch-chroot
# Requires write access to /mnt (runs as root in the CI container).

load 'helpers'

setup() {
    source "${BATS_TEST_DIRNAME}/../lib/log.sh"
    source "${BATS_TEST_DIRNAME}/../lib/chroot.sh"
    stub_setup

    if ! mkdir -p /mnt/tmp 2>/dev/null; then
        skip "cannot write to /mnt (not running as root)"
    fi

    # arch-chroot stub: record args and capture the password file / setup
    # script at invocation time, since chroot::configure deletes them after.
    cat > "$STUB_DIR/arch-chroot" << EOF
#!/bin/bash
printf 'arch-chroot %s\n' "\$*" >> "$STUB_LOG"
stat -c '%a' /mnt/tmp/arch-chroot-passwords > "$BATS_TEST_TMPDIR/pass_perms"
cp /mnt/tmp/arch-chroot-passwords "$BATS_TEST_TMPDIR/pass_contents"
bash -n /mnt/tmp/arch-chroot-setup.sh
EOF
    chmod +x "$STUB_DIR/arch-chroot"
}

teardown() {
    rm -f /mnt/tmp/arch-chroot-passwords /mnt/tmp/arch-chroot-setup.sh
}

run_configure() {
    chroot::configure "America/Chicago" "en_US.UTF-8" "myhost" "rootpass1" "user1" "userpass1" "uefi" "/dev/sda"
}

@test "chroot::configure writes password file with 600 permissions" {
    run run_configure
    [ "$status" -eq 0 ]
    [ "$(cat "$BATS_TEST_TMPDIR/pass_perms")" = "600" ]
}

@test "chroot::configure password file holds root and user credentials" {
    run run_configure
    [ "$status" -eq 0 ]
    grep -q '^root:rootpass1$' "$BATS_TEST_TMPDIR/pass_contents"
    grep -q '^user1:userpass1$' "$BATS_TEST_TMPDIR/pass_contents"
}

@test "chroot::configure generates a syntactically valid setup script" {
    # the stub runs bash -n on the setup script and fails on syntax errors
    run run_configure
    [ "$status" -eq 0 ]
}

@test "chroot::configure passes config via environment variables" {
    run run_configure
    [ "$status" -eq 0 ]
    grep -q 'CHROOT_TIMEZONE=America/Chicago' "$STUB_LOG"
    grep -q 'CHROOT_LOCALE=en_US.UTF-8' "$STUB_LOG"
    grep -q 'CHROOT_HOSTNAME=myhost' "$STUB_LOG"
    grep -q 'CHROOT_USERNAME=user1' "$STUB_LOG"
    grep -q 'CHROOT_BOOT_MODE=uefi' "$STUB_LOG"
    grep -q 'CHROOT_DISK=/dev/sda' "$STUB_LOG"
}

@test "chroot::configure never passes passwords through the environment" {
    run run_configure
    [ "$status" -eq 0 ]
    run grep -q 'rootpass1' "$STUB_LOG"
    [ "$status" -ne 0 ]
    run grep -q 'userpass1' "$STUB_LOG"
    [ "$status" -ne 0 ]
}

@test "chroot::configure removes password file and setup script afterwards" {
    run run_configure
    [ "$status" -eq 0 ]
    [ ! -e /mnt/tmp/arch-chroot-passwords ]
    [ ! -e /mnt/tmp/arch-chroot-setup.sh ]
}
