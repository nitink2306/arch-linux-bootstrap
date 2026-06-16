#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# lib/preset.sh — Safe preset file loading and saving
# Never uses 'source' — parses key=value lines with a whitelist

# Allowed preset keys
PRESET_ALLOWED_KEYS=(DISK HOSTNAME USERNAME TIMEZONE LOCALE REFLECTOR_COUNTRY)

preset::load() {
    local file="${1:-}"
    if [[ ! -f "$file" ]]; then
        log::error "Preset file '$file' not found."
        return 1
    fi

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip comments and blank lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue

        # Strip trailing carriage return (CRLF files)
        key="${key%$'\r'}"
        value="${value%$'\r'}"

        # Trim whitespace
        key="${key#"${key%%[![:space:]]*}"}"
        key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        # Strip surrounding quotes from value
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then
            value="${BASH_REMATCH[1]}"
        elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi

        # Only accept whitelisted keys
        local allowed=false
        local allowed_key
        for allowed_key in "${PRESET_ALLOWED_KEYS[@]}"; do
            if [[ "$key" == "$allowed_key" ]]; then
                allowed=true
                break
            fi
        done

        if [[ "$allowed" == "true" ]]; then
            # Safe assignment — key is validated against whitelist, value is literal text
            export "${key}=${value}"
        fi
    done < "$file"
}

preset::save() {
    local file="${1:-}"
    cat > "$file" << EOF
# arch-linux-bootstrap preset
# Generated on $(date)
# Passwords are never saved — you will always be prompted for those

DISK="${DISK:-}"
HOSTNAME="${HOSTNAME:-}"
USERNAME="${USERNAME:-}"
TIMEZONE="${TIMEZONE:-}"
LOCALE="${LOCALE:-}"
REFLECTOR_COUNTRY="${REFLECTOR_COUNTRY:-United States}"
EOF
}

preset::copy_to_system() {
    local username="${1:-}"
    local script_dir="${2:-}"
    local preset_file="$script_dir/presets/default.conf"

    if [[ -f "$preset_file" ]]; then
        cp "$preset_file" "/mnt/home/$username/arch-bootstrap-preset.conf"
        arch-chroot /mnt chown "$username:$username" "/home/$username/arch-bootstrap-preset.conf"
    fi
}
