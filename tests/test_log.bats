#!/usr/bin/env bats
# test_log.sh — Output prefix and format checks

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
