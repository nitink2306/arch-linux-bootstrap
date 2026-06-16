#!/bin/bash
set -e

# ============================================================
# Arch Linux Install Script
# Supports: VM and bare metal, UEFI and BIOS, Intel and AMD
# Usage:
#   Interactive : bash arch-install.sh
#   With preset : bash arch-install.sh --preset presets/default.conf
# ============================================================

# ------------------------------------------------------------
# LOGGING
# Sets up dual logging to /tmp and later to the installed system
# ------------------------------------------------------------
LOG_TMP="/tmp/arch-install.log"
LOG_FINAL="/mnt/var/log/arch-install.log"
exec > >(tee -a "$LOG_TMP") 2>&1
echo "Install started at $(date)" >> "$LOG_TMP"

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

# ------------------------------------------------------------
# UNSET SHELL ENVIRONMENT VARIABLES
# Prevents shell environment (e.g. $HOSTNAME) from bleeding
# into prompt logic and falsely skipping interactive prompts
# ------------------------------------------------------------
unset DISK HOSTNAME USERNAME TIMEZONE LOCALE

# ------------------------------------------------------------
# PRESET LOADING
# If --preset flag is passed, load values from config file
# and skip interactive prompts for those values
# ------------------------------------------------------------
PRESET_FILE=""
PRESET_MODE=false

if [[ "$1" == "--preset" && -n "$2" ]]; then
    PRESET_FILE="$2"
    if [ ! -f "$PRESET_FILE" ]; then
        echo "Error: preset file '$PRESET_FILE' not found."
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$PRESET_FILE"
    PRESET_MODE=true
    log "Preset loaded from $PRESET_FILE"
fi

echo "============================================================"
echo " Arch Linux Installer"
echo "============================================================"
echo ""

# ------------------------------------------------------------
# AUTO-DETECT BOOT MODE
# ------------------------------------------------------------
if [ -d /sys/firmware/efi ]; then
    BOOT_MODE="uefi"
else
    BOOT_MODE="bios"
fi
log "Boot mode detected: $BOOT_MODE"

# ------------------------------------------------------------
# AUTO-DETECT CPU VENDOR
# ------------------------------------------------------------
CPU_VENDOR=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')
if [ "$CPU_VENDOR" = "GenuineIntel" ]; then
    MICROCODE="intel-ucode"
elif [ "$CPU_VENDOR" = "AuthenticAMD" ]; then
    MICROCODE="amd-ucode"
else
    MICROCODE=""
    log "Warning: Could not detect CPU vendor. Microcode will not be installed."
fi
log "CPU vendor detected: $CPU_VENDOR → ${MICROCODE:-none}"
echo ""

# ------------------------------------------------------------
# REFLECTOR — rank mirrors by speed before pacstrap
# Picks the 10 fastest HTTPS mirrors for your country
# Falls back silently if reflector isn't available
# ------------------------------------------------------------
log "Ranking mirrors with reflector..."
if command -v reflector &>/dev/null; then
    reflector \
        --country "United States" \
        --latest 20 \
        --protocol https \
        --sort rate \
        --number 10 \
        --save /etc/pacman.d/mirrorlist
    log "Mirrors updated."
else
    log "reflector not found — using default mirrorlist."
fi
echo ""

# ------------------------------------------------------------
# DISK SELECTION
# ------------------------------------------------------------
if [ -z "${DISK:-}" ]; then
    echo "Available disks:"
    echo ""
    lsblk -d -o NAME,SIZE,MODEL
    echo ""

    while true; do
        read -rp "Enter target disk (e.g. /dev/sda): " DISK
        if [ ! -b "$DISK" ]; then
            echo "Error: $DISK is not a valid block device. Try again."
            echo ""
            continue
        fi
        read -rp "Confirm target disk (type it again): " DISK_CONFIRM
        if [ "$DISK" = "$DISK_CONFIRM" ]; then
            log "Disk set to $DISK"
            echo ""
            break
        else
            echo "Disks do not match. Start over."
            echo ""
        fi
    done
else
    log "Disk loaded from preset: $DISK"
fi

# ------------------------------------------------------------
# HOSTNAME
# ------------------------------------------------------------
if [ -z "${HOSTNAME:-}" ]; then
    while true; do
        read -rp "Enter hostname: " HOSTNAME
        if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
            log "Hostname set to $HOSTNAME"
            echo ""
            break
        else
            echo "Invalid hostname. Letters, numbers, hyphens only. Cannot start or end with a hyphen. Max 63 characters."
            echo ""
        fi
    done
else
    log "Hostname loaded from preset: $HOSTNAME"
fi

# ------------------------------------------------------------
# USERNAME
# ------------------------------------------------------------
if [ -z "${USERNAME:-}" ]; then
    while true; do
        read -rp "Enter username: " USERNAME
        if [[ "$USERNAME" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
            log "Username set to $USERNAME"
            echo ""
            break
        else
            echo "Invalid username. Must start with a lowercase letter, lowercase only, no spaces, max 32 characters."
            echo ""
        fi
    done
else
    log "Username loaded from preset: $USERNAME"
fi

# ------------------------------------------------------------
# ROOT PASSWORD
# Passwords are never loaded from preset — always prompted
# ------------------------------------------------------------
echo "Set root password:"
while true; do
    read -rsp "Root password: " ROOT_PASSWORD
    echo ""
    if [ -z "$ROOT_PASSWORD" ]; then
        echo "Password cannot be empty. Try again."
        echo ""
        continue
    fi
    read -rsp "Confirm root password: " ROOT_PASSWORD_CONFIRM
    echo ""
    if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ]; then
        log "Root password set."
        echo ""
        break
    else
        echo "Passwords do not match. Try again."
        echo ""
    fi
done

# ------------------------------------------------------------
# USER PASSWORD
# ------------------------------------------------------------
echo "Set password for $USERNAME:"
while true; do
    read -rsp "User password: " USER_PASSWORD
    echo ""
    if [ -z "$USER_PASSWORD" ]; then
        echo "Password cannot be empty. Try again."
        echo ""
        continue
    fi
    read -rsp "Confirm user password: " USER_PASSWORD_CONFIRM
    echo ""
    if [ "$USER_PASSWORD" = "$USER_PASSWORD_CONFIRM" ]; then
        log "User password set."
        echo ""
        break
    else
        echo "Passwords do not match. Try again."
        echo ""
    fi
done

# ------------------------------------------------------------
# TIMEZONE
# ------------------------------------------------------------
PAGE_SIZE=10

if [ -z "${TIMEZONE:-}" ]; then
    echo "Select timezone region:"
    echo ""

    mapfile -t REGIONS < <(find /usr/share/zoneinfo/ -mindepth 1 -maxdepth 1 -type d ! -name 'posix' ! -name 'right' ! -name '*.*' -printf '%f\n' | sort)
    TOTAL=${#REGIONS[@]}
    START=0

    while true; do
        END=$((START + PAGE_SIZE))
        [ $END -gt $TOTAL ] && END=$TOTAL

        for i in $(seq $START $((END - 1))); do
            echo "  $((i + 1))) ${REGIONS[$i]}"
        done

        echo ""
        if [ $END -lt $TOTAL ]; then
            read -rp "Enter number to select or press ENTER for more: " REGION_INPUT
        else
            START=0
            read -rp "Enter number to select or press ENTER to start over: " REGION_INPUT
        fi

        if [ -z "$REGION_INPUT" ]; then
            START=$END
            [ $START -ge $TOTAL ] && START=0
            echo ""
            continue
        fi

        if [[ "$REGION_INPUT" =~ ^[0-9]+$ ]] && [ "$REGION_INPUT" -ge 1 ] && [ "$REGION_INPUT" -le $TOTAL ]; then
            REGION="${REGIONS[$((REGION_INPUT - 1))]}"
            log "Region set to $REGION"
            echo ""
            break
        else
            echo "Invalid selection. Try again."
            echo ""
        fi
    done

    echo "Select timezone city:"
    echo ""

    mapfile -t CITIES < <(find /usr/share/zoneinfo/"$REGION"/ -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
    TOTAL=${#CITIES[@]}
    START=0

    while true; do
        END=$((START + PAGE_SIZE))
        [ $END -gt $TOTAL ] && END=$TOTAL

        for i in $(seq $START $((END - 1))); do
            echo "  $((i + 1))) ${CITIES[$i]}"
        done

        echo ""
        if [ $END -lt $TOTAL ]; then
            read -rp "Enter number to select or press ENTER for more: " CITY_INPUT
        else
            START=0
            read -rp "Enter number to select or press ENTER to start over: " CITY_INPUT
        fi

        if [ -z "$CITY_INPUT" ]; then
            START=$END
            [ $START -ge $TOTAL ] && START=0
            echo ""
            continue
        fi

        if [[ "$CITY_INPUT" =~ ^[0-9]+$ ]] && [ "$CITY_INPUT" -ge 1 ] && [ "$CITY_INPUT" -le $TOTAL ]; then
            CITY="${CITIES[$((CITY_INPUT - 1))]}"
            TIMEZONE="$REGION/$CITY"
            log "Timezone set to $TIMEZONE"
            echo ""
            break
        else
            echo "Invalid selection. Try again."
            echo ""
        fi
    done
else
    log "Timezone loaded from preset: $TIMEZONE"
fi

# ------------------------------------------------------------
# LOCALE
# ------------------------------------------------------------
LOCALE_ARR=(
    "en_US.UTF-8"
    "en_GB.UTF-8"
    "en_CA.UTF-8"
    "en_AU.UTF-8"
    "de_DE.UTF-8"
    "fr_FR.UTF-8"
    "es_ES.UTF-8"
    "es_MX.UTF-8"
    "it_IT.UTF-8"
    "pt_BR.UTF-8"
    "pt_PT.UTF-8"
    "ru_RU.UTF-8"
    "zh_CN.UTF-8"
    "zh_TW.UTF-8"
    "ja_JP.UTF-8"
    "ko_KR.UTF-8"
    "ar_SA.UTF-8"
    "hi_IN.UTF-8"
    "nl_NL.UTF-8"
    "pl_PL.UTF-8"
    "sv_SE.UTF-8"
    "tr_TR.UTF-8"
)
DEFAULT_LOCALE="en_US.UTF-8"

if [ -z "${LOCALE:-}" ]; then
    TOTAL=${#LOCALE_ARR[@]}
    START=0

    echo "Available locales (default: $DEFAULT_LOCALE):"
    echo ""

    while true; do
        END=$((START + PAGE_SIZE))
        [ $END -gt $TOTAL ] && END=$TOTAL

        for i in $(seq $START $((END - 1))); do
            echo "  $((i + 1))) ${LOCALE_ARR[$i]}"
        done

        echo ""
        if [ $END -lt $TOTAL ]; then
            read -rp "Enter number to select, press ENTER for more, or press ENTER at end for default [$DEFAULT_LOCALE]: " LOCALE_INPUT
        else
            START=0
            read -rp "Enter number to select, press ENTER for default [$DEFAULT_LOCALE], or press ENTER to start over: " LOCALE_INPUT
        fi

        if [ -z "$LOCALE_INPUT" ] && [ $END -ge $TOTAL ]; then
            LOCALE="$DEFAULT_LOCALE"
            log "Locale set to $LOCALE"
            echo ""
            break
        elif [ -z "$LOCALE_INPUT" ]; then
            START=$END
            echo ""
            continue
        elif [[ "$LOCALE_INPUT" =~ ^[0-9]+$ ]] && [ "$LOCALE_INPUT" -ge 1 ] && [ "$LOCALE_INPUT" -le $TOTAL ]; then
            LOCALE="${LOCALE_ARR[$((LOCALE_INPUT - 1))]}"
            log "Locale set to $LOCALE"
            echo ""
            break
        else
            echo "Invalid selection. Try again."
            echo ""
        fi
    done
else
    log "Locale loaded from preset: $LOCALE"
fi

# ------------------------------------------------------------
# SUMMARY + CONFIRMATION
# ------------------------------------------------------------
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
    log "Aborted by user."
    echo "Aborted."
    exit 0
fi

echo ""
log "Installation started."

# ------------------------------------------------------------
# PARTITION NAMING
# ------------------------------------------------------------
if [[ "$DISK" == *"nvme"* ]]; then
    PART1="${DISK}p1"
    PART2="${DISK}p2"
else
    PART1="${DISK}1"
    PART2="${DISK}2"
fi

# ------------------------------------------------------------
# WIPE + PARTITION
# ------------------------------------------------------------
log "Wiping $DISK..."
wipefs -af "$DISK"
sgdisk -Z "$DISK"

if [ "$BOOT_MODE" = "uefi" ]; then
    log "Creating GPT partition table (UEFI)..."
    parted -s "$DISK" \
        mklabel gpt \
        mkpart ESP fat32 1MiB 513MiB \
        set 1 esp on \
        mkpart primary btrfs 513MiB 100%
else
    log "Creating MBR partition table (BIOS)..."
    parted -s "$DISK" \
        mklabel msdos \
        mkpart primary 1MiB 2MiB \
        set 1 bios_grub on \
        mkpart primary btrfs 2MiB 100%
fi

log "Partitioning complete."
echo ""

# ------------------------------------------------------------
# FORMAT
# ------------------------------------------------------------
log "Formatting partitions..."

if [ "$BOOT_MODE" = "uefi" ]; then
    mkfs.fat -F32 "$PART1"
fi

mkfs.btrfs -f -L ArchRoot "$PART2"

log "Formatting complete."
echo ""

# ------------------------------------------------------------
# BTRFS SUBVOLUMES
# ------------------------------------------------------------
log "Creating btrfs subvolumes..."

mount "$PART2" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log

umount /mnt

log "Subvolumes created."
echo ""

# ------------------------------------------------------------
# MOUNT
# ------------------------------------------------------------
log "Mounting filesystems..."

mount -o noatime,compress=zstd,subvol=@ "$PART2" /mnt

mkdir -p /mnt/{boot,home,snapshots,var/log}

mount -o noatime,compress=zstd,subvol=@home "$PART2" /mnt/home
mount -o noatime,compress=zstd,subvol=@snapshots "$PART2" /mnt/snapshots
mount -o noatime,compress=zstd,subvol=@var_log "$PART2" /mnt/var/log

if [ "$BOOT_MODE" = "uefi" ]; then
    mount "$PART1" /mnt/boot
fi

log "Filesystems mounted."
echo ""

# ------------------------------------------------------------
# COPY LOG TO INSTALLED SYSTEM
# Now that /mnt/var/log is mounted we start persisting the log
# ------------------------------------------------------------
cp "$LOG_TMP" "$LOG_FINAL"
exec > >(tee -a "$LOG_FINAL") 2>&1
log "Log now persisting to $LOG_FINAL on installed system."

# ------------------------------------------------------------
# FSTAB
# ------------------------------------------------------------
log "Generating fstab..."
mkdir -p /mnt/etc
genfstab -U /mnt >> /mnt/etc/fstab
log "fstab generated."
echo ""

# ------------------------------------------------------------
# PACSTRAP
# ------------------------------------------------------------
log "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware sudo vim git $MICROCODE
log "Base system installed."
echo ""

# ------------------------------------------------------------
# SAVE PRESET
# Ask user if they want to save their answers as a preset
# Saved to presets/default.conf relative to script location
# Passwords are never saved
# ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$SCRIPT_DIR/presets"

read -rp "Save these settings as a preset for future installs? (y/n): " SAVE_PRESET
if [[ "$SAVE_PRESET" == "y" || "$SAVE_PRESET" == "Y" ]]; then
    cat > "$SCRIPT_DIR/presets/default.conf" << PRESET
# arch-linux-bootstrap preset
# Generated on $(date)
# Passwords are never saved — you will always be prompted for those

DISK=$DISK
HOSTNAME=$HOSTNAME
USERNAME=$USERNAME
TIMEZONE=$TIMEZONE
LOCALE=$LOCALE
PRESET
    log "Preset saved to $SCRIPT_DIR/presets/default.conf"
    echo ""
fi

# ------------------------------------------------------------
# CHROOT
# ------------------------------------------------------------
log "Entering chroot..."

arch-chroot /mnt /bin/bash << CHROOT

set -e

# timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# locale
ESCAPED_LOCALE=$(echo "$LOCALE" | sed 's/\./\\./g')
sed -i "s/^#\${ESCAPED_LOCALE} UTF-8\$/\${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# hostname
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
HOSTS

# passwords
echo "root:$ROOT_PASSWORD" | chpasswd
useradd -mG wheel $USERNAME
echo "$USERNAME:$USER_PASSWORD" | chpasswd

# sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# zram
pacman -S --noconfirm zram-generator
cat > /etc/systemd/zram-generator.conf << ZRAM
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
ZRAM

# user groups
usermod -aG wheel,audio,video,optical,storage,input $USERNAME

# bootloader
pacman -S --noconfirm grub efibootmgr networkmanager sddm

if [ "$BOOT_MODE" = "uefi" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
    grub-install --target=i386-pc "$DISK"
fi

grub-mkconfig -o /boot/grub/grub.cfg

# enable services
systemctl enable NetworkManager
systemctl enable sddm
ln -sf /usr/lib/systemd/system/NetworkManager.service /etc/systemd/system/multi-user.target.wants/NetworkManager.service
ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service

# desktop environment
pacman -S --noconfirm --needed plasma kde-applications

CHROOT

log "Chroot configuration complete."
echo ""

# ------------------------------------------------------------
# COPY FINAL LOG INTO INSTALLED SYSTEM
# ------------------------------------------------------------
cp "$LOG_TMP" "$LOG_FINAL"
log "Final log saved to $LOG_FINAL"

# ------------------------------------------------------------
# UNMOUNT + REBOOT
# ------------------------------------------------------------
echo "============================================================"
echo " Installation Complete"
echo "============================================================"
echo ""
log "Unmounting filesystems..."
umount -R /mnt
echo ""
echo "Done. Remove installation media and reboot."
echo ""
read -rp "Reboot now? (y/n): " REBOOT
if [[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]]; then
    reboot
else
    echo "You can reboot manually when ready."
fi