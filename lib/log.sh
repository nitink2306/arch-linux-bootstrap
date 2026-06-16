#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# lib/log.sh — Logging functions
# Provides namespaced logging with timestamps

LOG_TMP="/tmp/arch-install.log"
LOG_FINAL="/mnt/var/log/arch-install.log"

log::setup() {
    exec > >(tee -a "$LOG_TMP") 2>&1
    echo "Install started at $(date)" >> "$LOG_TMP"
}

log::persist() {
    cp "$LOG_TMP" "$LOG_FINAL"
    exec > >(tee -a "$LOG_FINAL") 2>&1
    log::info "Log now persisting to $LOG_FINAL on installed system."
}

log::info() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

log::warn() {
    printf '[%s] [WARN] %s\n' "$(date '+%H:%M:%S')" "$*"
}

log::error() {
    printf '[%s] [ERROR] %s\n' "$(date '+%H:%M:%S')" "$*" >&2
}
