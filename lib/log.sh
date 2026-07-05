#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# lib/log.sh — Logging functions
# Provides namespaced logging with timestamps

LOG_TMP="/tmp/arch-install.log"
LOG_FINAL="/mnt/var/log/arch-install.log"

log::setup() {
    # Save the original stdout/stderr so they can be restored later
    # (disk::unmount needs to release the tee handle on /mnt/var/log)
    exec 3>&1 4>&2
    LOG_CONSOLE_SAVED=true
    exec > >(tee -a "$LOG_TMP") 2>&1
    echo "Install started at $(date)" >> "$LOG_TMP"
}

log::restore_console() {
    # Point stdout/stderr back at the descriptors saved by log::setup.
    # No-op when log::setup never ran.
    if [[ "${LOG_CONSOLE_SAVED:-false}" == "true" ]]; then
        exec 1>&3 2>&4
    fi
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
