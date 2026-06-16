#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# lib/validate.sh — Pure validation functions (no I/O, no logging)
# Each function returns 0 (valid) or 1 (invalid)

validate::hostname() {
    local name="${1:-}"
    [[ "$name" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

validate::username() {
    local name="${1:-}"
    [[ "$name" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]
}

validate::password() {
    local pass="${1:-}"
    [[ ${#pass} -ge 8 && "$pass" != *:* ]]
}

validate::block_device() {
    local dev="${1:-}"
    [[ -b "$dev" ]]
}

validate::timezone() {
    local tz="${1:-}"
    [[ -f "/usr/share/zoneinfo/$tz" ]]
}
