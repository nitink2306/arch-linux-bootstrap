#!/usr/bin/env bats
# test_args.bats — arch-install.sh argument parsing (exits before any system access)

INSTALLER="${BATS_TEST_DIRNAME}/../arch-install.sh"

@test "--help prints usage and exits 0" {
    run bash "$INSTALLER" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage: arch-install.sh"* ]]
    [[ "$output" == *"--preset"* ]]
    [[ "$output" == *"--dry-run"* ]]
}

@test "unknown option exits 1 with an error" {
    run bash "$INSTALLER" --bogus
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown option: --bogus"* ]]
}

@test "--preset without an argument exits 1 with an error" {
    run bash "$INSTALLER" --preset
    [ "$status" -eq 1 ]
    [[ "$output" == *"--preset requires a file argument"* ]]
}

@test "--preset with a missing file exits with an error" {
    # --dry-run skips preflight so the failure comes from preset::load
    run bash "$INSTALLER" --dry-run --preset /nonexistent/preset.conf
    [ "$status" -ne 0 ]
    [[ "$output" == *"not found"* ]]
}
