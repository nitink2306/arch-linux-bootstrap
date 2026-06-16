#!/usr/bin/env bats
# test_validate.bats — Parametrized-style valid/invalid cases per validate:: function

load 'helpers'

# Source the module under test
setup() {
    source "${BATS_TEST_DIRNAME}/../lib/validate.sh"
}

# --- validate::hostname ---

@test "validate::hostname accepts simple hostname" {
    run validate::hostname "myarch"
    [ "$status" -eq 0 ]
}

@test "validate::hostname accepts hostname with numbers" {
    run validate::hostname "arch42"
    [ "$status" -eq 0 ]
}

@test "validate::hostname accepts hostname with hyphens" {
    run validate::hostname "my-arch-pc"
    [ "$status" -eq 0 ]
}

@test "validate::hostname accepts single character" {
    run validate::hostname "a"
    [ "$status" -eq 0 ]
}

@test "validate::hostname accepts max length (63 chars)" {
    run validate::hostname "$(printf 'a%.0s' {1..63})"
    [ "$status" -eq 0 ]
}

@test "validate::hostname rejects empty string" {
    run validate::hostname ""
    [ "$status" -eq 1 ]
}

@test "validate::hostname rejects hostname starting with hyphen" {
    run validate::hostname "-invalid"
    [ "$status" -eq 1 ]
}

@test "validate::hostname rejects hostname ending with hyphen" {
    run validate::hostname "invalid-"
    [ "$status" -eq 1 ]
}

@test "validate::hostname rejects hostname with spaces" {
    run validate::hostname "my arch"
    [ "$status" -eq 1 ]
}

@test "validate::hostname rejects hostname with underscores" {
    run validate::hostname "my_arch"
    [ "$status" -eq 1 ]
}

@test "validate::hostname rejects hostname over 63 chars" {
    run validate::hostname "$(printf 'a%.0s' {1..64})"
    [ "$status" -eq 1 ]
}

# --- validate::username ---

@test "validate::username accepts simple name" {
    run validate::username "nitin"
    [ "$status" -eq 0 ]
}

@test "validate::username accepts name with numbers" {
    run validate::username "user42"
    [ "$status" -eq 0 ]
}

@test "validate::username accepts name with underscore" {
    run validate::username "my_user"
    [ "$status" -eq 0 ]
}

@test "validate::username accepts name with hyphen" {
    run validate::username "my-user"
    [ "$status" -eq 0 ]
}

@test "validate::username rejects empty string" {
    run validate::username ""
    [ "$status" -eq 1 ]
}

@test "validate::username rejects name starting with number" {
    run validate::username "1user"
    [ "$status" -eq 1 ]
}

@test "validate::username rejects name starting with uppercase" {
    run validate::username "User"
    [ "$status" -eq 1 ]
}

@test "validate::username rejects name with uppercase" {
    run validate::username "myUser"
    [ "$status" -eq 1 ]
}

@test "validate::username rejects name with spaces" {
    run validate::username "my user"
    [ "$status" -eq 1 ]
}

@test "validate::username rejects name over 32 chars" {
    run validate::username "$(printf 'a%.0s' {1..33})"
    [ "$status" -eq 1 ]
}

# --- validate::password ---

@test "validate::password accepts 8 character password" {
    run validate::password "12345678"
    [ "$status" -eq 0 ]
}

@test "validate::password accepts long password" {
    run validate::password "this_is_a_very_long_password_indeed"
    [ "$status" -eq 0 ]
}

@test "validate::password accepts password with special chars" {
    run validate::password "P@ss!w0rd"
    [ "$status" -eq 0 ]
}

@test "validate::password rejects empty password" {
    run validate::password ""
    [ "$status" -eq 1 ]
}

@test "validate::password rejects 7 character password" {
    run validate::password "1234567"
    [ "$status" -eq 1 ]
}

@test "validate::password rejects 1 character password" {
    run validate::password "a"
    [ "$status" -eq 1 ]
}
