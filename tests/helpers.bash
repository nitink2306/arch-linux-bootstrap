# tests/helpers.bash — Shared test fixtures (mirrors archinstall's conftest.py)

FIXTURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/fixtures" && pwd)"

fixture_valid_preset() {
    echo "$FIXTURES_DIR/valid_preset.conf"
}

fixture_unknown_keys() {
    echo "$FIXTURES_DIR/unknown_keys.conf"
}

fixture_malicious_preset() {
    echo "$FIXTURES_DIR/malicious_preset.conf"
}

fixture_cpuinfo_intel() {
    echo "$FIXTURES_DIR/cpuinfo_intel"
}

fixture_cpuinfo_amd() {
    echo "$FIXTURES_DIR/cpuinfo_amd"
}
