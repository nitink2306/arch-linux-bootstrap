#!/bin/bash
set -e

# ============================================================
# Arch Linux Install Script
# Supports: VM and bare metal, UEFI and BIOS, Intel and AMD
# ============================================================

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
echo "Boot mode detected: $BOOT_MODE"

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
    echo "Warning: Could not detect CPU vendor. Microcode will not be installed."
fi
echo "CPU vendor detected: $CPU_VENDOR → $MICROCODE"
echo ""

# ------------------------------------------------------------
# DISK SELECTION
# ------------------------------------------------------------
echo "Available disks:"
echo ""
lsblk -d -o NAME,SIZE,MODEL
echo ""

while true; do
    read -p "Enter target disk (e.g. /dev/sda): " DISK
    if [ ! -b "$DISK" ]; then
        echo "Error: $DISK is not a valid block device. Try again."
        echo ""
        continue
    fi
    read -p "Confirm target disk (type it again): " DISK_CONFIRM
    if [ "$DISK" = "$DISK_CONFIRM" ]; then
        echo "Disk set to $DISK"
        echo ""
        break
    else
        echo "Disks do not match. Start over."
        echo ""
    fi
done

# ------------------------------------------------------------
# HOSTNAME
# ------------------------------------------------------------
while true; do
    read -p "Enter hostname: " HOSTNAME
    if [[ "$HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
        echo "Hostname set to $HOSTNAME"
        echo ""
        break
    else
        echo "Invalid hostname. Letters, numbers, hyphens only. Cannot start or end with a hyphen. Max 63 characters."
        echo ""
    fi
done

# ------------------------------------------------------------
# USERNAME
# ------------------------------------------------------------
while true; do
    read -p "Enter username: " USERNAME
    if [[ "$USERNAME" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
        echo "Username set to $USERNAME"
        echo ""
        break
    else
        echo "Invalid username. Must start with a lowercase letter, lowercase only, no spaces, max 32 characters."
        echo ""
    fi
done

# ------------------------------------------------------------
# ROOT PASSWORD
# ------------------------------------------------------------
echo "Set root password:"
while true; do
    read -sp "Root password: " ROOT_PASSWORD
    echo ""
    if [ -z "$ROOT_PASSWORD" ]; then
        echo "Password cannot be empty. Try again."
        echo ""
        continue
    fi
    read -sp "Confirm root password: " ROOT_PASSWORD_CONFIRM
    echo ""
    if [ "$ROOT_PASSWORD" = "$ROOT_PASSWORD_CONFIRM" ]; then
        echo "Root password set."
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
    read -sp "User password: " USER_PASSWORD
    echo ""
    if [ -z "$USER_PASSWORD" ]; then
        echo "Password cannot be empty. Try again."
        echo ""
        continue
    fi
    read -sp "Confirm user password: " USER_PASSWORD_CONFIRM
    echo ""
    if [ "$USER_PASSWORD" = "$USER_PASSWORD_CONFIRM" ]; then
        echo "User password set."
        echo ""
        break
    else
        echo "Passwords do not match. Try again."
        echo ""
    fi
done

# ------------------------------------------------------------
# TIMEZONE — numbered region then city with pagination
# ------------------------------------------------------------
echo "Select timezone region:"
echo ""

REGIONS=($(ls /usr/share/zoneinfo/ | grep -v '\.' | grep -v 'posix' | grep -v 'right' | sort))
PAGE_SIZE=10
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
        read -p "Enter number to select or press ENTER for more: " REGION_INPUT
    else
        START=0
        read -p "Enter number to select or press ENTER to start over: " REGION_INPUT
    fi

    if [ -z "$REGION_INPUT" ]; then
        START=$END
        [ $START -ge $TOTAL ] && START=0
        echo ""
        continue
    fi

    if [[ "$REGION_INPUT" =~ ^[0-9]+$ ]] && [ "$REGION_INPUT" -ge 1 ] && [ "$REGION_INPUT" -le $TOTAL ]; then
        REGION="${REGIONS[$((REGION_INPUT - 1))]}"
        echo "Region set to $REGION"
        echo ""
        break
    else
        echo "Invalid selection. Try again."
        echo ""
    fi
done

echo "Select timezone city:"
echo ""

CITIES=($(ls /usr/share/zoneinfo/$REGION/ | sort))
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
        read -p "Enter number to select or press ENTER for more: " CITY_INPUT
    else
        START=0
        read -p "Enter number to select or press ENTER to start over: " CITY_INPUT
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
        echo "Timezone set to $TIMEZONE"
        echo ""
        break
    else
        echo "Invalid selection. Try again."
        echo ""
    fi
done

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
        read -p "Enter number to select, press ENTER for more, or press ENTER at end for default [$DEFAULT_LOCALE]: " LOCALE_INPUT
    else
        START=0
        read -p "Enter number to select, press ENTER for default [$DEFAULT_LOCALE], or press ENTER to start over: " LOCALE_INPUT
    fi

    if [ -z "$LOCALE_INPUT" ] && [ $END -ge $TOTAL ]; then
        LOCALE="$DEFAULT_LOCALE"
        echo "Locale set to $LOCALE"
        echo ""
        break
    elif [ -z "$LOCALE_INPUT" ]; then
        START=$END
        echo ""
        continue
    elif [[ "$LOCALE_INPUT" =~ ^[0-9]+$ ]] && [ "$LOCALE_INPUT" -ge 1 ] && [ "$LOCALE_INPUT" -le $TOTAL ]; then
        LOCALE="${LOCALE_ARR[$((LOCALE_INPUT - 1))]}"
        echo "Locale set to $LOCALE"
        echo ""
        break
    else
        echo "Invalid selection. Try again."
        echo ""
    fi
done

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
echo ""
echo "WARNING: $DISK will be wiped. This cannot be undone."
echo ""
read -p "Proceed with installation? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Starting installation..."

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
echo "Wiping $DISK..."
wipefs -af "$DISK"
sgdisk -Z "$DISK"

if [ "$BOOT_MODE" = "uefi" ]; then
    echo "Creating GPT partition table (UEFI)..."
    parted -s "$DISK" \
        mklabel gpt \
        mkpart ESP fat32 1MiB 513MiB \
        set 1 esp on \
        mkpart primary btrfs 513MiB 100%
else
    echo "Creating MBR partition table (BIOS)..."
    parted -s "$DISK" \
        mklabel msdos \
        mkpart primary 1MiB 2MiB \
        set 1 bios_grub on \
        mkpart primary btrfs 2MiB 100%
fi

echo "Partitioning complete."
echo ""

# ------------------------------------------------------------
# FORMAT
# ------------------------------------------------------------
echo "Formatting partitions..."

if [ "$BOOT_MODE" = "uefi" ]; then
    mkfs.fat -F32 "$PART1"
fi

mkfs.btrfs -f -L ArchRoot "$PART2"

echo "Formatting complete."
echo ""

# ------------------------------------------------------------
# BTRFS SUBVOLUMES
# ------------------------------------------------------------
echo "Creating btrfs subvolumes..."

mount "$PART2" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log

umount /mnt

echo "Subvolumes created."
echo ""

# ------------------------------------------------------------
# MOUNT
# ------------------------------------------------------------
echo "Mounting filesystems..."

mount -o noatime,compress=zstd,subvol=@ "$PART2" /mnt

mkdir -p /mnt/{boot,home,snapshots,var/log}

mount -o noatime,compress=zstd,subvol=@home "$PART2" /mnt/home
mount -o noatime,compress=zstd,subvol=@snapshots "$PART2" /mnt/snapshots
mount -o noatime,compress=zstd,subvol=@var_log "$PART2" /mnt/var/log

if [ "$BOOT_MODE" = "uefi" ]; then
    mount "$PART1" /mnt/boot
fi

echo "Filesystems mounted."
echo ""

# ------------------------------------------------------------
# FSTAB
# ------------------------------------------------------------
echo "Generating fstab..."

mkdir -p /mnt/etc
genfstab -U /mnt >> /mnt/etc/fstab

echo "fstab generated."
echo ""

# ------------------------------------------------------------
# PACSTRAP
# ------------------------------------------------------------
echo "Installing base system..."

pacstrap /mnt base base-devel linux linux-firmware sudo vim git $MICROCODE

echo "Base system installed."
echo ""

# ------------------------------------------------------------
# CHROOT
# ------------------------------------------------------------
echo "Entering chroot..."

arch-chroot /mnt /bin/bash << CHROOT

set -e

# timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# locale
ESCAPED_LOCALE=$(echo "$LOCALE" | sed 's/\./\\./g')
sed -i "s/^#${ESCAPED_LOCALE} UTF-8$/${LOCALE} UTF-8/" /etc/locale.gen
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

echo "Chroot configuration complete."
echo ""

# ------------------------------------------------------------
# UNMOUNT + REBOOT
# ------------------------------------------------------------
echo "============================================================"
echo " Installation Complete"
echo "============================================================"
echo ""
echo "Unmounting filesystems..."
umount -R /mnt
echo ""
echo "Done. Remove installation media and reboot."
echo ""
read -p "Reboot now? (y/n): " REBOOT
if [[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]]; then
    reboot
else
    echo "You can reboot manually when ready."
fi
