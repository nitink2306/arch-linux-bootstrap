#!/usr/bin/env bats
# test_log.bats — Output prefix and format checks

load 'helpers'

setup() {
    source "${BATS_TEST_DIRNAME}/../lib/log.sh"
}

@test "log::info outputs with timestamp prefix" {
    run log::info "test message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\]\ test\ message$ ]]
}

@test "log::warn outputs with WARN prefix" {
    run log::warn "warning message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\]\ \[WARN\]\ warning\ message$ ]]
}

@test "log::error outputs with ERROR prefix" {
    run log::error "error message"
    [ "$status" -eq 0 ]
    [[ "$output" =~ \[ERROR\]\ error\ message ]]
}

@test "log::info handles empty message" {
    run log::info ""
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^\[[0-9]{2}:[0-9]{2}:[0-9]{2}\]\ $ ]]
}

@test "log::info handles message with special characters" {
    run log::info "disk /dev/sda formatted"
    [ "$status" -eq 0 ]
    [[ "$output" =~ disk\ /dev/sda\ formatted ]]
}

# --- log::setup / log::persist / log::restore_console ---
# Run in a separate bash so the exec redirections stay contained.

@test "log::setup records the start marker in LOG_TMP" {
    local log_file="$BATS_TEST_TMPDIR/install.log"
    run bash -c "source '${BATS_TEST_DIRNAME}/../lib/log.sh'; LOG_TMP='$log_file'; log::setup"
    [ "$status" -eq 0 ]
    grep -q 'Install started at' "$log_file"
}

@test "log::setup tees subsequent output into LOG_TMP" {
    local log_file="$BATS_TEST_TMPDIR/install.log"
    run bash -c "source '${BATS_TEST_DIRNAME}/../lib/log.sh'; LOG_TMP='$log_file'; log::setup; echo tee-me; sleep 1"
    [ "$status" -eq 0 ]
    grep -q 'tee-me' "$log_file"
}

@test "log::persist copies the log and keeps logging to the final path" {
    local src="$BATS_TEST_TMPDIR/src.log" dst="$BATS_TEST_TMPDIR/dst.log"
    echo "earlier line" > "$src"
    run bash -c "source '${BATS_TEST_DIRNAME}/../lib/log.sh'; LOG_TMP='$src'; LOG_FINAL='$dst'; log::persist; sleep 1"
    [ "$status" -eq 0 ]
    grep -q 'earlier line' "$dst"
    grep -q 'persisting' "$dst"
}

@test "log::restore_console is a no-op when log::setup never ran" {
    run bash -c "source '${BATS_TEST_DIRNAME}/../lib/log.sh'; log::restore_console; echo still-alive"
    [ "$status" -eq 0 ]
    [[ "$output" == *"still-alive"* ]]
}
