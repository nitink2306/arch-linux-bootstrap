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

# --- Command stubbing ---
# stub_setup creates a directory prepended to PATH; stub NAME [EXIT_CODE]
# drops a fake command there that records its invocation in $STUB_LOG.

stub_setup() {
    STUB_DIR="$BATS_TEST_TMPDIR/stubs"
    STUB_LOG="$BATS_TEST_TMPDIR/stub.log"
    mkdir -p "$STUB_DIR"
    : > "$STUB_LOG"
    PATH="$STUB_DIR:$PATH"
}

stub() {
    local name="$1"
    local exit_code="${2:-0}"
    cat > "$STUB_DIR/$name" << EOF
#!/bin/bash
printf '%s %s\n' "$name" "\$*" >> "$STUB_LOG"
exit $exit_code
EOF
    chmod +x "$STUB_DIR/$name"
}
