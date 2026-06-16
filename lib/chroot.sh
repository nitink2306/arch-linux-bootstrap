#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# lib/chroot.sh — System configuration inside chroot
# Writes a standalone script to /mnt/tmp/ to avoid heredoc expansion bugs.
# Passwords handled via a separate 700-mode file, deleted after use.
# Uses ln -sf for service enabling (systemctl enable is a no-op in chroot).

chroot::configure() {
    local timezone="${1:-}"
    local locale="${2:-}"
    local hostname="${3:-}"
    local root_password="${4:-}"
    local username="${5:-}"
    local user_password="${6:-}"
    local boot_mode="${7:-}"
    local disk="${8:-}"

    log::info "Entering chroot..."

    mkdir -p /mnt/tmp

    # Write the password file with restricted permissions
    local pass_file="/mnt/tmp/arch-chroot-passwords"
    install -m 700 /dev/null "$pass_file"
    printf '%s:%s\n' "root" "$root_password" > "$pass_file"
    printf '%s:%s\n' "$username" "$user_password" >> "$pass_file"

    # Compute escaped locale for sed on the host side
    local escaped_locale
    escaped_locale=$(printf '%s' "$locale" | sed 's/\./\\./g')

    # Write the chroot setup script — host variables are interpolated at write time
    cat > /mnt/tmp/arch-chroot-setup.sh << SETUP_SCRIPT
#!/bin/bash
# Inherits set -euo pipefail from sourcing script

# timezone
ln -sf /usr/share/zoneinfo/${timezone} /etc/localtime
hwclock --systohc

# locale
sed -i "s/^#${escaped_locale} UTF-8\$/${locale} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${locale}" > /etc/locale.conf

# hostname
echo "${hostname}" > /etc/hostname
cat > /etc/hosts << HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${hostname}.localdomain ${hostname}
HOSTS

# passwords — read from restricted file, then delete
# Create user first so chpasswd can set both passwords
useradd -mG wheel ${username}
chpasswd < /tmp/arch-chroot-passwords
rm -f /tmp/arch-chroot-passwords

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
usermod -aG wheel,audio,video,optical,storage,input ${username}

# bootloader
if [ "${boot_mode}" = "uefi" ]; then
    pacman -S --noconfirm grub efibootmgr networkmanager sddm
else
    pacman -S --noconfirm grub networkmanager sddm
fi

if [ "${boot_mode}" = "uefi" ]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
    grub-install --target=i386-pc "${disk}"
fi

grub-mkconfig -o /boot/grub/grub.cfg

# enable services via symlinks (systemctl enable is a no-op in chroot)
mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sf /usr/lib/systemd/system/NetworkManager.service /etc/systemd/system/multi-user.target.wants/NetworkManager.service
ln -sf /usr/lib/systemd/system/sddm.service /etc/systemd/system/display-manager.service

# desktop environment
pacman -S --noconfirm --needed plasma kde-applications

SETUP_SCRIPT

    chmod +x /mnt/tmp/arch-chroot-setup.sh

    # Execute inside chroot
    arch-chroot /mnt /tmp/arch-chroot-setup.sh

    # Cleanup
    rm -f /mnt/tmp/arch-chroot-setup.sh
    rm -f /mnt/tmp/arch-chroot-passwords

    log::info "Chroot configuration complete."
}
