#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# lib/ui.sh — Interactive prompts and menus

PAGE_SIZE=10

LOCALE_ARR=(
    "en_US.UTF-8" "en_GB.UTF-8" "en_CA.UTF-8" "en_AU.UTF-8"
    "de_DE.UTF-8" "fr_FR.UTF-8" "es_ES.UTF-8" "es_MX.UTF-8"
    "it_IT.UTF-8" "pt_BR.UTF-8" "pt_PT.UTF-8" "ru_RU.UTF-8"
    "zh_CN.UTF-8" "zh_TW.UTF-8" "ja_JP.UTF-8" "ko_KR.UTF-8"
    "ar_SA.UTF-8" "hi_IN.UTF-8" "nl_NL.UTF-8" "pl_PL.UTF-8"
    "sv_SE.UTF-8" "tr_TR.UTF-8"
)
DEFAULT_LOCALE="en_US.UTF-8"
DISK_FROM_PRESET=false

ui::collect_inputs() {
    ui::_select_disk
    ui::_prompt_hostname
    ui::_prompt_username
    ui::_prompt_root_password
    ui::_prompt_user_password
    ui::_select_timezone
    ui::_select_locale
}

ui::confirm_summary() {
    echo "============================================================"
    echo " Installation Summary"
    echo "============================================================"
    echo ""
    echo "  Boot mode   : $BOOT_MODE"
    echo "  Microcode   : ${MICROCODE:-none detected}"
    echo "  Disk        : $DISK"
    echo "  Hostname    : $HOSTNAME"
    echo "  Username    : $USERNAME"
    echo "  Timezone    : $TIMEZONE"
    echo "  Locale      : $LOCALE"
    echo "  Preset mode : $PRESET_MODE"
    echo ""
    echo "WARNING: $DISK will be wiped. This cannot be undone."
    echo ""
    if [[ "$DISK_FROM_PRESET" == "true" && "${DRY_RUN:-false}" == "false" ]]; then
        read -rp "Disk came from a preset — type its path ($DISK) to confirm the wipe: " DISK_CONFIRM
        if [[ "$DISK_CONFIRM" != "$DISK" ]]; then
            log::info "Disk confirmation did not match. Aborting."
            echo "Aborted."
            exit 0
        fi
    fi
    read -rp "Proceed with installation? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        log::info "Aborted by user."
        echo "Aborted."
        exit 0
    fi
}

ui::prompt_reboot() {
    echo "============================================================"
    echo " Installation Complete"
    echo "============================================================"
    echo ""
    echo "Done. Remove installation media and reboot."
    echo ""
    read -rp "Reboot now? (y/n): " REBOOT
    if [[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]]; then
        reboot
    else
        echo "You can reboot manually when ready."
    fi
}

# --- Private helpers ---

# Paginated numeric menu over a list of items.
# Usage: ui::_select_paginated OUT_VAR DEFAULT ITEM...
# Shows PAGE_SIZE items at a time; ENTER pages forward and wraps around.
# If DEFAULT is non-empty, ENTER on the last page selects it instead of wrapping.
# Item numbers are global (1..total), so a number works from any page.
ui::_select_paginated() {
    local __outvar="$1" default="$2"
    shift 2
    local items=("$@")
    local total=${#items[@]}
    local start=0 end i input

    while true; do
        end=$((start + PAGE_SIZE))
        (( end > total )) && end=$total

        for (( i=start; i<end; i++ )); do
            echo "  $((i + 1))) ${items[$i]}"
        done
        echo ""

        if (( end < total )); then
            read -rp "Enter number to select or press ENTER for more: " input
        elif [[ -n "$default" ]]; then
            read -rp "Enter number to select or press ENTER for default [$default]: " input
        else
            read -rp "Enter number to select or press ENTER to start over: " input
        fi

        if [[ -z "$input" ]]; then
            if (( end >= total )) && [[ -n "$default" ]]; then
                printf -v "$__outvar" '%s' "$default"
                echo ""
                return 0
            fi
            start=$end
            (( start >= total )) && start=0
            echo ""
            continue
        fi

        if [[ "$input" =~ ^[0-9]+$ ]] && (( input >= 1 && input <= total )); then
            printf -v "$__outvar" '%s' "${items[$((input - 1))]}"
            echo ""
            return 0
        fi

        echo "Invalid selection. Try again."
        echo ""
    done
}

ui::_select_disk() {
    if [[ -n "${DISK:-}" ]]; then
        if validate::block_device "$DISK"; then
            log::info "Disk loaded from preset: $DISK"
            DISK_FROM_PRESET=true
            return
        else
            log::warn "Preset DISK '$DISK' is not a valid block device; falling back to prompt."
            DISK=""
        fi
    fi

    echo "Available disks:"
    echo ""
    lsblk -d -o NAME,SIZE,MODEL
    echo ""

    while true; do
        read -rp "Enter target disk (e.g. /dev/sda): " DISK
        if ! validate::block_device "$DISK"; then
            echo "Error: $DISK is not a valid block device. Try again."
            echo ""
            continue
        fi
        read -rp "Confirm target disk (type it again): " DISK_CONFIRM
        if [[ "$DISK" == "$DISK_CONFIRM" ]]; then
            log::info "Disk set to $DISK"
            echo ""
            break
        else
            echo "Disks do not match. Start over."
            echo ""
        fi
    done
}

ui::_prompt_hostname() {
    if [[ -n "${HOSTNAME:-}" ]]; then
        if validate::hostname "$HOSTNAME"; then
            log::info "Hostname loaded from preset: $HOSTNAME"
            return
        else
            log::warn "Preset HOSTNAME '$HOSTNAME' is invalid; falling back to prompt."
            HOSTNAME=""
        fi
    fi

    while true; do
        read -rp "Enter hostname: " HOSTNAME
        if validate::hostname "$HOSTNAME"; then
            log::info "Hostname set to $HOSTNAME"
            echo ""
            break
        else
            echo "Invalid hostname. Letters, numbers, hyphens only. Cannot start or end with a hyphen. Max 63 characters."
            echo ""
        fi
    done
}

ui::_prompt_username() {
    if [[ -n "${USERNAME:-}" ]]; then
        if validate::username "$USERNAME"; then
            log::info "Username loaded from preset: $USERNAME"
            return
        else
            log::warn "Preset USERNAME '$USERNAME' is invalid; falling back to prompt."
            USERNAME=""
        fi
    fi

    while true; do
        read -rp "Enter username: " USERNAME
        if validate::username "$USERNAME"; then
            log::info "Username set to $USERNAME"
            echo ""
            break
        else
            echo "Invalid username. Must start with a lowercase letter, lowercase only, no spaces, max 32 characters."
            echo ""
        fi
    done
}

ui::_prompt_root_password() {
    echo "Set root password:"
    while true; do
        read -rsp "Root password: " ROOT_PASSWORD
        echo ""
        if ! validate::password "$ROOT_PASSWORD"; then
            echo "Password must be at least 8 characters and must not contain ':'. Try again."
            echo ""
            continue
        fi
        read -rsp "Confirm root password: " ROOT_PASSWORD_CONFIRM
        echo ""
        if [[ "$ROOT_PASSWORD" == "$ROOT_PASSWORD_CONFIRM" ]]; then
            log::info "Root password set."
            echo ""
            break
        else
            echo "Passwords do not match. Try again."
            echo ""
        fi
    done
}

ui::_prompt_user_password() {
    echo "Set password for $USERNAME:"
    while true; do
        read -rsp "User password: " USER_PASSWORD
        echo ""
        if ! validate::password "$USER_PASSWORD"; then
            echo "Password must be at least 8 characters and must not contain ':'. Try again."
            echo ""
            continue
        fi
        read -rsp "Confirm user password: " USER_PASSWORD_CONFIRM
        echo ""
        if [[ "$USER_PASSWORD" == "$USER_PASSWORD_CONFIRM" ]]; then
            log::info "User password set."
            echo ""
            break
        else
            echo "Passwords do not match. Try again."
            echo ""
        fi
    done
}

ui::_select_timezone() {
    if [[ -n "${TIMEZONE:-}" ]]; then
        if validate::timezone "$TIMEZONE"; then
            log::info "Timezone loaded from preset: $TIMEZONE"
            return
        else
            log::warn "Preset TIMEZONE '$TIMEZONE' is invalid; falling back to prompt."
            TIMEZONE=""
        fi
    fi

    echo "Select timezone region:"
    echo ""

    mapfile -t REGIONS < <(find /usr/share/zoneinfo/ -mindepth 1 -maxdepth 1 -type d ! -name 'posix' ! -name 'right' ! -name '*.*' -printf '%f\n' | sort)
    local region
    ui::_select_paginated region "" "${REGIONS[@]}"
    log::info "Region set to $region"

    echo "Select timezone city:"
    echo ""

    mapfile -t CITIES < <(find /usr/share/zoneinfo/"$region"/ -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | sort)
    local city
    ui::_select_paginated city "" "${CITIES[@]}"
    TIMEZONE="$region/$city"
    log::info "Timezone set to $TIMEZONE"
}

ui::_select_locale() {
    if [[ -n "${LOCALE:-}" ]]; then
        local valid_locale=false
        local l
        for l in "${LOCALE_ARR[@]}"; do
            if [[ "$l" == "$LOCALE" ]]; then
                valid_locale=true
                break
            fi
        done
        if $valid_locale; then
            log::info "Locale loaded from preset: $LOCALE"
            return
        else
            log::warn "Preset LOCALE '$LOCALE' is not a supported locale; falling back to prompt."
            LOCALE=""
        fi
    fi

    echo "Available locales (default: $DEFAULT_LOCALE):"
    echo ""

    ui::_select_paginated LOCALE "$DEFAULT_LOCALE" "${LOCALE_ARR[@]}"
    log::info "Locale set to $LOCALE"
}
