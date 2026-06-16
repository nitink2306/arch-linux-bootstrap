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

ui::_select_disk() {
    if [[ -n "${DISK:-}" ]]; then
        if validate::block_device "$DISK"; then
            log::info "Disk loaded from preset: $DISK"
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
    local total=${#REGIONS[@]}
    local start=0

    while true; do
        local end=$((start + PAGE_SIZE))
        (( end > total )) && end=$total

        for (( i=start; i<end; i++ )); do
            echo "  $((i + 1))) ${REGIONS[$i]}"
        done

        echo ""
        if (( end < total )); then
            read -rp "Enter number to select or press ENTER for more: " REGION_INPUT
        else
            start=0
            read -rp "Enter number to select or press ENTER to start over: " REGION_INPUT
        fi

        if [[ -z "$REGION_INPUT" ]]; then
            start=$end
            (( start >= total )) && start=0
            echo ""
            continue
        fi

        if [[ "$REGION_INPUT" =~ ^[0-9]+$ ]] && (( REGION_INPUT >= 1 && REGION_INPUT <= total )); then
            local region="${REGIONS[$((REGION_INPUT - 1))]}"
            log::info "Region set to $region"
            echo ""
            break
        else
            echo "Invalid selection. Try again."
            echo ""
        fi
    done

    echo "Select timezone city:"
    echo ""

    mapfile -t CITIES < <(find /usr/share/zoneinfo/"$region"/ -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
    total=${#CITIES[@]}
    start=0

    while true; do
        local end=$((start + PAGE_SIZE))
        (( end > total )) && end=$total

        for (( i=start; i<end; i++ )); do
            echo "  $((i + 1))) ${CITIES[$i]}"
        done

        echo ""
        if (( end < total )); then
            read -rp "Enter number to select or press ENTER for more: " CITY_INPUT
        else
            start=0
            read -rp "Enter number to select or press ENTER to start over: " CITY_INPUT
        fi

        if [[ -z "$CITY_INPUT" ]]; then
            start=$end
            (( start >= total )) && start=0
            echo ""
            continue
        fi

        if [[ "$CITY_INPUT" =~ ^[0-9]+$ ]] && (( CITY_INPUT >= 1 && CITY_INPUT <= total )); then
            local city="${CITIES[$((CITY_INPUT - 1))]}"
            TIMEZONE="$region/$city"
            log::info "Timezone set to $TIMEZONE"
            echo ""
            break
        else
            echo "Invalid selection. Try again."
            echo ""
        fi
    done
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

    local total=${#LOCALE_ARR[@]}
    local start=0

    echo "Available locales (default: $DEFAULT_LOCALE):"
    echo ""

    while true; do
        local end=$((start + PAGE_SIZE))
        (( end > total )) && end=$total

        for (( i=start; i<end; i++ )); do
            echo "  $((i + 1))) ${LOCALE_ARR[$i]}"
        done

        echo ""
        if (( end < total )); then
            read -rp "Enter number to select, press ENTER for more, or press ENTER at end for default [$DEFAULT_LOCALE]: " LOCALE_INPUT
        else
            start=0
            read -rp "Enter number to select, press ENTER for default [$DEFAULT_LOCALE], or press ENTER to start over: " LOCALE_INPUT
        fi

        if [[ -z "$LOCALE_INPUT" ]] && (( end >= total )); then
            LOCALE="$DEFAULT_LOCALE"
            log::info "Locale set to $LOCALE"
            echo ""
            break
        elif [[ -z "$LOCALE_INPUT" ]]; then
            start=$end
            echo ""
            continue
        elif [[ "$LOCALE_INPUT" =~ ^[0-9]+$ ]] && (( LOCALE_INPUT >= 1 && LOCALE_INPUT <= total )); then
            LOCALE="${LOCALE_ARR[$((LOCALE_INPUT - 1))]}"
            log::info "Locale set to $LOCALE"
            echo ""
            break
        else
            echo "Invalid selection. Try again."
            echo ""
        fi
    done
}
