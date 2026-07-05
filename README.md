# arch-linux-bootstrap

A script that takes you from a blank disk to a fully working Arch Linux system with KDE Plasma, in one guided run. You don't need to have installed Arch before — this README explains every step along the way.

Built by going through the installation manually first, understanding every decision, then automating the parts that should never be manual.

---

## What this is

A bash script that handles the entire Arch Linux installation process non-interactively after an upfront configuration step. You answer a handful of questions once at the start, review a summary, confirm, and walk away. It works on both VMs and bare metal, UEFI and BIOS systems, Intel and AMD CPUs.

## What this is not

A GUI installer, or a one-size-fits-all setup tool. It's also not a replacement for understanding what's happening under the hood — if something goes wrong partway through, you'll want to know enough to debug it. That's what this README is for. Read through it once before you run anything; none of it assumes you've installed Arch before.

---

## Requirements

- Arch Linux live ISO booted (download from [archlinux.org](https://archlinux.org/download/))
- Internet connection (ethernet recommended — WiFi on the live ISO requires manual `iwctl` setup not covered here)
- At least 20GB of disk space
- UEFI or BIOS firmware (both supported)

---

## Getting the script

The installer is split into a main script (`arch-install.sh`) and a set of helper modules under `lib/`. The main script needs those modules to be present alongside it, so you can't just download `arch-install.sh` on its own — you need the whole repo. There are two ways to get it onto your live ISO environment.

### Option 1 — One-line bootstrap (recommended for most users)

The installer is split into modules under `lib/`, so downloading `arch-install.sh` alone is not enough. The bootstrap script clones the full repo and hands off to the installer:

```bash
curl -sL https://raw.githubusercontent.com/nitink2306/arch-linux-bootstrap/main/bootstrap.sh | bash
```

To pin a specific release tag or branch instead of `main`:

```bash
curl -sL https://raw.githubusercontent.com/nitink2306/arch-linux-bootstrap/main/bootstrap.sh | ARCH_BOOTSTRAP_REF=v0.1.0 bash
```

As with any `curl | bash` pipeline, read the script first if you have any doubt — it is short by design.

### Option 2 — From a local Docker server (recommended for development and testing)

This approach is useful when you're actively iterating on the script and don't want to push to GitHub on every change. An nginx container on your host machine serves the repo over HTTP. Your VM pulls directly from it over the local network.

**On your host machine:**

1. Make sure Docker and Docker Compose are installed
2. Clone this repo and navigate into it
3. Find your host machine's local IP — on Windows run `ipconfig` and look for your Ethernet or WiFi adapter IPv4 address, not the VMware virtual adapter addresses
4. Start the server:

```bash
docker compose -f docker/docker-compose.yml up -d
```

Verify it's working by opening `http://localhost:8080` in a browser on your host. You should see a directory listing of the repo.

**On the live ISO (VM must be set to bridged networking):**

```bash
curl http://<host-ip>:8080/bootstrap.sh -O
chmod +x bootstrap.sh
bash bootstrap.sh
```

The key requirement is that your VM uses **bridged networking**, not NAT. Bridged mode puts the VM on the same network as your host so it can reach your host's IP directly. NAT isolates the VM behind a virtual router and the host IP won't be reachable.

Any edits you make to the scripts on your host are served immediately — no container restart needed.

**Stop the server when done:**

```bash
docker compose -f docker/docker-compose.yml down
```

---

## Quickstart

Boot the Arch live ISO, get the script using either method above, then follow the prompts. The script will ask you for everything it needs before touching your disk, and nothing is written until you confirm a final summary.

### Optional flags

```bash
bash arch-install.sh --preset presets/default.conf   # skip prompts using saved answers
bash arch-install.sh --dry-run                       # walk through prompts without touching the disk
bash arch-install.sh --help                          # show usage
```

**`--preset FILE`** — loads answers (disk, hostname, username, timezone, locale, mirror country) from a config file instead of prompting for them. Passwords are never stored in a preset and are always prompted for separately. See [Presets](#presets) below.

**`--dry-run`** — runs auto-detection, collects your inputs, and prints the confirmation summary, but skips every step that would actually touch the disk (partitioning, formatting, pacstrap, chroot). Useful for checking that your inputs validate correctly before committing to a real install.

### Flags

```
arch-install.sh [--preset FILE] [--dry-run] [--help]
```

- `--preset FILE` — pre-fill answers from a preset file (see below). Passwords are never stored in presets and are always prompted.
- `--dry-run` — walk through detection, input collection, and validation, then print what a real run would do without touching the disk. Note: dry-run also skips the preflight checks (root, live-ISO tools, network), so a clean dry run does not guarantee a real run will start.
- `--help` — print usage.

### Preset files

A preset is a plain `KEY=value` file (see `presets/default.conf.example`). Only these keys are read; anything else is ignored, and values are never executed as code:

```
DISK="/dev/sda"
HOSTNAME="myarch"
USERNAME="me"
TIMEZONE="America/Chicago"
LOCALE="en_US.UTF-8"
REFLECTOR_COUNTRY="United States"
```

Because a stale preset can point at the wrong disk, preset runs add an extra safety step: you must type the disk path back before the wipe is allowed to proceed. After a successful install, the preset used is copied to `~/arch-bootstrap-preset.conf` on the new system so the install can be reproduced.

---

## What the script does

### 1. Auto-detection

Before asking you anything, the script silently detects two things:

**Boot mode** — checks for `/sys/firmware/efi`. If it exists, you're on UEFI. If not, BIOS. This determines the boot partition type (EFI System Partition vs BIOS boot partition) and the GRUB install flags used later. Both modes use a GPT partition table.

**CPU vendor** — reads `/proc/cpuinfo` to detect Intel or AMD and installs the correct microcode package (`intel-ucode` or `amd-ucode`). Microcode is low-level CPU firmware that gets loaded at boot. It fixes hardware bugs and security vulnerabilities that exist in the CPU itself. On a VM this matters less, on bare metal it is important. If the vendor can't be determined (some VMs and unusual CPUs don't expose a `vendor_id` line), the script just skips microcode installation rather than failing.

---

### 2. Input collection

The script collects everything it needs upfront so there are no surprises mid-install. Every input is validated before being accepted. If you're using a preset (see below), any value it provides is validated the same way and only falls back to a prompt if it's missing or invalid.

**Disk selection** — runs `lsblk` so you can see available disks, then asks you to type the target disk path (e.g. `/dev/sda`). You have to type it twice to confirm. A block device check ensures what you typed actually exists on the system. This is the most dangerous step — the selected disk will be completely wiped.

**Hostname** — the name your machine identifies itself as on the network. Validated for RFC-compliant characters: letters (either case), numbers, hyphens. Cannot start or end with a hyphen. Max 63 characters.

**Username** — your personal user account. Validated for Linux username rules: must start with a lowercase letter, lowercase letters/numbers/underscores/hyphens only, max 32 characters.

**Root password** — the password for the `root` superuser account. Prompted separately from your user password by design. Not having a root password or sharing it with your user account is a security risk. Must be at least 8 characters, cannot contain a colon (`:` is the field separator of the `chpasswd` mechanism used to set it), and must be confirmed by typing twice.

**User password** — the password for your personal account. Same rules, separate prompt. We don't assume these should be the same.

**Timezone** — presented as a two-step paginated menu. First pick a region (America, Europe, Asia, etc.), then pick a city within it. Pagination shows 10 entries at a time, press Enter to see more.

**Locale** — determines language, date format, number format, and character encoding for your system. Presented as a paginated numbered list of 22 common locales. Default is `en_US.UTF-8`. Press Enter at the end of the list to accept the default.

---

### 3. Summary and confirmation

Before anything is written to disk, the script prints a full summary of every collected value and detected setting. You get one `y/n` prompt. Typing anything other than `y` aborts cleanly with no changes made. When the disk came from a preset file you must additionally type the disk path back, matching the rigor of the interactive double-confirmation.

Before input collection the script also runs preflight checks: it must be root, the live-ISO tools (`pacstrap`, `arch-chroot`, `sgdisk`, ...) must be present, the network must be reachable, and the selected disk must be at least 20GiB with nothing mounted on it. If anything fails mid-install, the error handler unmounts `/mnt` so the installer can simply be re-run.

---

### 4. Partitioning

**Why we wipe first** — `wipefs` clears existing filesystem signatures and `sgdisk -Z` destroys the existing partition table. This ensures a clean slate regardless of what was on the disk before.

**UEFI layout (GPT)**
```
/dev/sda1 — 512MB   EFI System Partition (FAT32)
/dev/sda2 — rest    Linux filesystem (btrfs)
```

**BIOS layout (GPT)**
```
/dev/sda1 — 1MB     BIOS boot partition (no filesystem, just the bios_grub flag)
/dev/sda2 — rest    Linux filesystem (btrfs)
```

The BIOS boot partition is where GRUB embeds itself when booting a GPT disk on BIOS firmware (the `bios_grub` flag is GPT-only). It has no filesystem — it's raw space GRUB writes directly into.

**NVMe naming** — NVMe and eMMC drives use a different partition naming convention (`/dev/nvme0n1p1` instead of `/dev/sda1`). The script detects this automatically from the disk path and adjusts accordingly.

---

### 5. Filesystem

We chose **btrfs** over the more common ext4 for one primary reason: snapshots.

Btrfs is a copy-on-write filesystem. When a file is modified, the original data is not overwritten immediately — the new version is written elsewhere and the pointer is updated. This makes snapshots nearly instantaneous and space-efficient, since a snapshot is just a reference to existing blocks, not a full copy.

**The subvolume layout**

Btrfs subvolumes look like directories but behave like independent filesystem roots. We create four:

| Subvolume | Mounted at | Reason |
|-----------|------------|--------|
| `@` | `/` | Root of the system |
| `@home` | `/home` | User files — isolated so rolling back root doesn't affect personal data |
| `@snapshots` | `/snapshots` | Where snapshot tools store snapshots — isolated to prevent recursive snapshots |
| `@var_log` | `/var/log` | System logs — excluded from snapshots intentionally so logs persist across rollbacks for debugging |

**Mount flags applied to all btrfs subvolumes**

`noatime` — by default Linux records a timestamp every time any file is read. On a busy system this is a lot of unnecessary writes. Disabling it improves performance, especially on SSDs.

`compress=zstd` — transparent compression. Files are compressed automatically on write and decompressed on read. zstd is fast with good compression ratios, effectively giving you more usable space with minimal CPU overhead.

---

### 6. fstab

`genfstab` reads the currently mounted filesystems and generates `/etc/fstab` — the file the system reads on every boot to know what to mount and where. We use the `-U` flag to identify partitions by UUID rather than device name. UUIDs are tied to the filesystem itself, so they remain stable even if you add or remove drives (which can shuffle device names like `/dev/sda`).

This step has to happen after all mounts are in place. Whatever is mounted at the time `genfstab` runs is exactly what gets written into fstab.

---

### 7. Mirror ranking

Before installing anything, the script runs [`reflector`](https://wiki.archlinux.org/title/Reflector) (if it's available on the live ISO) to rank Arch's package mirrors by actual download speed, filtered to a country of your choosing. By default this is `United States` — you can override it by setting `REFLECTOR_COUNTRY` in a preset file. The ranked list is written to `/etc/pacman.d/mirrorlist` and used for the rest of the install. If `reflector` isn't available, the script quietly falls back to whatever mirrorlist the live ISO already has — it's a speed optimization, not a hard requirement.

---

### 8. Base system installation

`pacstrap` is an Arch-specific tool that installs packages into a target directory rather than the running system. Everything here lands on your actual drive at `/mnt`.

**Packages installed**

| Package | Purpose |
|---------|---------|
| `base` | Minimal Arch userspace and package manager (pacman) |
| `base-devel` | Build tools — required for compiling AUR packages later |
| `linux` | The kernel |
| `linux-firmware` | Firmware blobs for hardware (WiFi cards, GPUs, etc.) |
| `sudo` | Allows your user account to run commands as root |
| `vim` | Text editor for config files |
| `git` | Version control — also needed to clone AUR packages |
| `intel-ucode` or `amd-ucode` | CPU microcode (whichever applies) |

Everything else — GRUB, NetworkManager, SDDM, zram, KDE Plasma — is installed later, once we're inside the new system (see below). `pacstrap` only lays down the minimal bootable base.

---

### 9. System configuration (inside chroot)

`arch-chroot` switches the root from the live USB into your installed system at `/mnt`. From this point on, every command runs as if you're inside the real system. This is how changes like setting passwords and installing the bootloader actually stick.

The script writes a standalone setup script into `/mnt/tmp/`, passes your answers in as environment variables (never interpolated directly into shell code, to avoid injection issues), and executes it with `arch-chroot`. It's cleaned up afterwards.

**Timezone** — creates a symlink from `/etc/localtime` to the correct zone file in `/usr/share/zoneinfo/`. Then `hwclock --systohc` syncs the hardware clock (which keeps running when the machine is off) to the system clock.

**Locale** — uncomments exactly one line in `/etc/locale.gen` matching your chosen locale, then runs `locale-gen` to compile it. Sets `LANG` in `/etc/locale.conf` so the system knows which locale to use.

**Hostname and hosts file** — writes your hostname to `/etc/hostname` and creates `/etc/hosts` with the standard localhost entries plus a `127.0.1.1` entry mapping back to your hostname. This prevents various tools from hanging while trying to resolve the local machine name.

**Passwords** — written to a temporary file with `600` permissions, then set non-interactively using `chpasswd`, which reads `username:password` from stdin. The temp file is deleted immediately after. This is the standard way scripts set passwords without an interactive prompt.

**Sudo access** — your user is added to the `wheel` group during creation. But being in wheel means nothing until the sudoers file enables it. We uncomment `%wheel ALL=(ALL:ALL) ALL` in `/etc/sudoers` using `sed` — the `%` means group, so every wheel member gets full sudo access.

**User groups**

| Group | Purpose |
|-------|---------|
| `wheel` | sudo access |
| `audio` | Direct audio hardware access |
| `video` | Direct video hardware access |
| `optical` | CD/DVD drive access |
| `storage` | Mount removable drives without root |
| `input` | Input device access — relevant for Wayland compositors |

**zram** — instead of a dedicated swap partition, we use zram. This creates a compressed swap device that lives in RAM itself. Counterintuitive but much faster than disk swap — when memory is tight, pages are compressed and kept in RAM rather than written to disk. Configured at half your total RAM with zstd compression.

---

### 10. Bootloader

**Why GRUB** — GRUB is the most widely supported bootloader and the community standard for Arch. Alternatives like systemd-boot exist but GRUB handles both UEFI and BIOS in one tool, which fits our goal of a single script that works everywhere.

**UEFI install**
```bash
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
```
Writes GRUB to the EFI partition and registers it with the UEFI firmware so it appears in the boot menu.

**BIOS install**
```bash
grub-install --target=i386-pc /dev/sda
```
Embeds GRUB directly into the 1MB BIOS boot partition we created earlier.

`grub-mkconfig` generates the actual config file GRUB reads at boot. It scans for installed kernels and writes entries for them. This needs to be re-run any time you update the kernel.

---

### 11. Desktop environment

We chose **KDE Plasma** over other desktop environments for a few reasons:

- Familiar to anyone coming from Windows or GNOME — traditional taskbar, system tray, draggable windows
- Extremely configurable through a GUI — almost nothing requires editing config files for basic use
- Excellent Wayland support out of the box
- Recommended login manager is SDDM, which we're already installing

**Why not GNOME** — GNOME is the Ubuntu default and a solid choice, but KDE gives more control without requiring terminal knowledge. Personal preference is a valid reason too.

**Why not a tiling window manager** — tools like Hyprland, Sway, or Niri are powerful but require significant configuration and a steep learning curve before they're usable as a daily driver. If you have a job and a life, start with KDE.

**SDDM** — the login manager that greets you before you log in. When you installed the `plasma` package, it dropped a `plasma.desktop` session file into `/usr/share/wayland-sessions/`. SDDM reads that file to know KDE exists and how to launch it. The chain on every boot is: `systemd → SDDM → you log in → KDE Plasma`.

---

### 12. Services and reboot

Inside the chroot, the script enables `NetworkManager` and `sddm` by symlinking their unit files into `/etc/systemd/system/` — the normal `systemctl enable` doesn't work inside a chroot since systemd isn't actually running there, so the script does by hand what `systemctl enable` would otherwise do for you.

- `NetworkManager` — handles network connections after boot. Without this you have no internet on the installed system.
- `sddm` — the login manager. Without this you boot to a TTY with no GUI.

Once the chroot phase is done, the script copies your preset (if one was used, or if `presets/default.conf` exists) into your new user's home directory as `arch-bootstrap-preset.conf`, so you have a record of what was installed. Passwords are never included in this file.

Finally, it unmounts all filesystems cleanly with `umount -R /mnt` before offering to reboot.

---

## Presets

Presets let you skip re-answering the same prompts on repeated installs (e.g. across several VMs, or after a failed attempt). A preset is a simple `key="value"` file — copy the example and fill in your own values:

```bash
cp presets/default.conf.example presets/default.conf
# edit presets/default.conf with your values
bash arch-install.sh --preset presets/default.conf
```

Only six keys are recognized: `DISK`, `HOSTNAME`, `USERNAME`, `TIMEZONE`, `LOCALE`, `REFLECTOR_COUNTRY`. Anything else in the file is ignored. **Passwords are never read from or written to a preset file** — you'll always be prompted for both, every time, regardless of preset. Any preset value that fails validation (say, a disk that doesn't exist on this machine) is discarded and you'll be prompted for it as usual, so it's safe to reuse the same preset file across different machines.

`presets/default.conf` is gitignored, since it can contain machine-specific info like your disk path and hostname — only the `.example` file is tracked.

---

## Logging

Everything the script prints is also written to `/tmp/arch-install.log` on the live ISO from the moment it starts. Once your target disk is mounted, the log is copied to `/mnt/var/log/arch-install.log` so it survives the install and is readable from your new system afterward — useful if something goes wrong partway through and you want to see exactly what ran. Because `/var/log` lives on its own `@var_log` subvolume, this log also survives any future btrfs rollback.

---

## What we leave for you

These are deliberate omissions — things that depend on your preferences, workflow, or hardware.

**AUR helper** — the Arch User Repository contains community-maintained packages not in the official repos. To use it you need a helper like `yay`. After first boot, run the bundled helper as your normal user:
```bash
bash setup.sh
```
Or do it manually:
```bash
git clone https://aur.archlinux.org/yay.git
cd yay && makepkg -si
cd .. && rm -rf yay
```
After that, `yay -S <package>` works just like `pacman -S`. This is exactly what `setup.sh` in this repo does, if you'd rather run one command than copy-paste the above.

**Snapshot tooling** — we created the `@snapshots` subvolume but didn't install a snapshot manager. [Timeshift](https://github.com/linuxmint/timeshift) or [Snapper](https://wiki.archlinux.org/title/snapper) are the common choices. Timeshift is easier to set up, Snapper integrates better with pacman hooks for automatic pre/post-update snapshots.

**VMware guest tools** — if you're running in VMware and want display scaling:
```bash
sudo pacman -S open-vm-tools
sudo systemctl enable vmtoolsd vmware-vmblock-fuse
reboot
```

**Dotfiles** — shell config, git config, editor config. Entirely personal. A good starting point is keeping them in a git repo and symlinking them into place.

**Additional software** — pacman covers most things. Check there before reaching for AUR:
```bash
pacman -Ss <search term>   # search
pacman -S <package>        # install
yay -S <package>           # install from AUR
```

**Shell** — the default is bash. If you want zsh or fish, install them with pacman and set your default shell with `chsh -s $(which zsh)`.

---

## Package management quick reference

Coming from Ubuntu/Debian:

| apt | pacman |
|-----|--------|
| `apt install` | `pacman -S` |
| `apt remove` | `pacman -R` |
| `apt purge` | `pacman -Rns` |
| `apt update && apt upgrade` | `pacman -Syu` |
| `apt search` | `pacman -Ss` |
| `apt show` | `pacman -Si` |
| `apt list --installed` | `pacman -Q` |

Run `pacman -Syu` regularly. Arch is a rolling release — there are no version upgrades, just a continuous stream of updates.

---

## Decisions we made and why

| Decision | Reasoning |
|----------|-----------|
| btrfs over ext4 | Snapshot support. Copy-on-write gives you free rollbacks. |
| zram over swap partition | Faster than disk swap, no wasted partition space |
| KDE over GNOME or tiling WMs | Familiar, configurable, production-ready out of the box |
| GRUB over systemd-boot | Supports both UEFI and BIOS in one tool |
| UUID in fstab over device names | Stable across hardware changes |
| `noatime` mount flag | Reduces unnecessary writes, better SSD longevity |
| `compress=zstd` | Free space savings with negligible performance cost |
| Separate `@home` subvolume | Roll back root without touching user data |
| Separate `@var_log` subvolume | Logs persist across rollbacks for debugging |
| Double-confirm disk selection | One wrong keystroke on bare metal is unrecoverable |
| Separate root and user passwords | Security — never assume these should be the same |
| Whitelisted preset keys, no `source` | A preset file is untrusted input; parsing it key-by-key avoids executing arbitrary shell code |

---

## Troubleshooting

**Script fails at grub-install on UEFI**
Make sure the EFI partition is mounted at `/boot` before the script runs. The script handles this but if you're debugging manually, verify with `lsblk`.

**No internet after reboot**
NetworkManager might not have started. Run `sudo systemctl start NetworkManager` then `nmcli device wifi connect <SSID>` for WiFi or check `ip link` for ethernet.

**Display doesn't scale in VMware**
Install `open-vm-tools` as described in the "What we leave for you" section above.

**pacman fails with signature errors**
Clock might be out of sync. Run `timedatectl set-ntp true` and wait a few seconds before retrying.

**Something else went wrong partway through**
Check `/tmp/arch-install.log` on the live ISO (or `/var/log/arch-install.log` on the installed system, if it got that far) for a full timestamped record of what ran before the failure.

---

## Development

Tests live in `tests/` and use [bats](https://github.com/bats-core/bats-core). Run them locally with:

```bash
bats tests/
```

Three GitHub Actions workflows run on every push: [shellcheck](.github/workflows/shellcheck.yaml) for lint warnings, [bats](.github/workflows/bats.yaml) for the test suite, and [bandit](.github/workflows/bandit.yaml) for a security scan. A separate [CD workflow](.github/workflows/CD.yml) builds and publishes the Docker dev-server image on pushes to `main`.

---

## Scope

x86-64 only (BIOS or UEFI). CPU microcode is auto-detected for Intel and AMD; other architectures are not supported.

---

## Contributing

Found a bug or have a suggestion? Open an issue or PR. If you're adding support for a new feature, follow the existing pattern — prompt for anything variable, auto-detect anything deterministic, never assume.

Tests run with [bats](https://github.com/bats-core/bats-core): `bats tests/`. Lint with `shellcheck --severity=warning $(git ls-files '*.sh')`. Both run in CI on every PR, along with a loop-device integration test of the disk pipeline.

---

## License

MIT — see [LICENSE](LICENSE).
