#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
die() { echo "Error: $*" >&2; exit 1; }

if [[ ${1:-} == --help ]]; then
    cat <<'HELP'
Usage: sudo ./install.sh [--local [username] | --full]
With no option, choose desktop setup on this Arch system or a full Arch
installation on another drive. --local uses an existing account; --full
collects hostname, login/password and partitioning, then runs archinstall silently.
Full installation uses minimal Arch with GRUB followed by the Moha desktop.
Neither mode reboots automatically. Internet access is required.
HELP
    exit 0
fi
(( EUID == 0 )) || exec sudo bash "$0" "$@"

mode=${1:-}
if [[ -z $mode ]]; then
    echo '1) Install the desktop setup on this Arch system'
    echo '2) Install Arch and the desktop setup on another drive'
    read -r -p 'Installation mode [1/2]: ' choice
    case $choice in
        1) mode=--local ;;
        2) mode=--full ;;
        *) die 'Invalid installation mode.' ;;
    esac
fi
case $mode in
    --local) (( $# <= 2 )) || die 'Use --local [username].' ;;
    --full) (( $# <= 1 )) || die 'Use --full.' ;;
    --provision) [[ $# == 2 ]] || die 'Internal provisioning requires a username.' ;;
    *) die 'Unknown option; use --help.' ;;
esac
[[ -r /etc/os-release ]] || die 'Cannot identify this system.'
source /etc/os-release
[[ ${ID:-} == arch ]] || die 'Run this installer on Arch Linux or the Arch live ISO.'
if [[ $mode == --full ]]; then
    for input in desktop-packages.txt aur-packages.txt inventory/packages-explicit.txt inventory/packages-foreign.txt inventory/enabled-services.txt scripts/archinstall-config.py scripts/archinstall-stage.py scripts/disk-guard.sh scripts/disk-probe.py; do
        [[ -r $script_dir/$input ]] || die "Missing repository input: $input"
    done
    if ! command -v archinstall >/dev/null || ! command -v arch-chroot >/dev/null || ! command -v python3 >/dev/null || ! command -v openssl >/dev/null; then
        pacman -Syu --needed --noconfirm archinstall arch-install-scripts python openssl
    fi
    for command in archinstall arch-chroot python3 openssl lsblk findmnt blockdev udevadm; do
        command -v "$command" >/dev/null || die "Missing installation command: $command"
    done
    [[ -t 0 ]] || die 'An interactive terminal is needed for initial setup.'
    source "$script_dir/scripts/disk-guard.sh"
    while :; do
        read -r -p 'Hostname for the new machine: ' hostname
        [[ ${#hostname} -le 63 && $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]] && break
        echo 'Use 1–63 letters, digits, or hyphens, starting and ending with a letter or digit.'
    done
    read -r -p 'Login username: ' login
    [[ $login =~ ^[a-z_][a-z0-9_-]{0,30}$ && $login != root ]] || die 'Invalid username.'
    while :; do
        read -r -s -p 'Login password: ' password; echo
        read -r -s -p 'Confirm password: ' confirmation; echo
        [[ -n $password && $password == "$confirmation" ]] && break
        echo 'Passwords must be nonempty and match.'
    done
    password_hash=$(printf '%s' "$password" | openssl passwd -6 -stdin)
    unset password confirmation
    lsblk -e 7 -o NAME,PATH,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL
    echo '1) Erase a whole disk: boot partition + ext4 root'
    echo '2) Erase a whole disk: boot partition + ext4 root + separate ext4 /home'
    echo '3) Use partitions already mounted at /mnt (no formatting)'
    read -r -p 'Partitioning [1/2/3]: ' layout
    [[ $layout =~ ^[123]$ ]] || die 'Invalid partitioning choice.'
    disk=''; root_gib=0; disk_bytes=0; sector_bytes=512
    if [[ $layout != 3 ]]; then
        read -r -p 'Whole disk to ERASE (e.g. /dev/nvme0n1): ' disk
        disk=$(readlink -f -- "$disk")
        [[ -b $disk && $(lsblk -dn -o TYPE "$disk") == disk ]] || die 'Choose a whole disk.'
        # The exclusive probe runs after the temporary automount exclusion.
        moha_check_disk_unused "$disk" || die 'The selected disk is in use.'
        disk_bytes=$(blockdev --getsize64 "$disk")
        sector_bytes=$(blockdev --getss "$disk")
        (( disk_bytes >= 40 * 1024**3 )) || die 'At least 40 GiB is required.'
        if [[ $layout == 2 ]]; then
            read -r -p 'Root partition size in GiB (at least 32): ' root_gib
            [[ $root_gib =~ ^[1-9][0-9]{0,5}$ ]] || die 'Invalid root size.'
            (( root_gib >= 32 && (root_gib + 3) * 1024**3 < disk_bytes )) || die 'Root size leaves too little space for /home.'
        fi
        [[ $script_dir != /mnt && $script_dir != /mnt/* ]] || die 'Keep this repository outside /mnt.'
        mountpoint -q /mnt && die '/mnt is already mounted; choose option 3 or unmount it.'
        read -r -p "Type ERASE $disk to confirm destroying all data on this disk: " confirmation
        [[ $confirmation == "ERASE $disk" ]] || die 'Disk erase cancelled.'
    else
        mountpoint -q /mnt || die 'Mount your root partition at /mnt first.'
        [[ $(stat -Lc '%d:%i' /mnt) != "$(stat -Lc '%d:%i' /)" ]] || die 'The target must be a different root filesystem.'
        if [[ -d /sys/firmware/efi ]]; then
            mountpoint -q /mnt/boot || die 'Mount a FAT32 EFI system partition at /mnt/boot.'
            [[ $(findmnt -n -o FSTYPE /mnt/boot) == vfat ]] || die '/mnt/boot must be FAT32 for UEFI.'
        fi
        [[ $script_dir != /mnt && $script_dir != /mnt/* ]] || die 'Keep this repository outside /mnt.'
    fi
    umask 077
    setup_dir=$(mktemp -d /run/moha-install.XXXXXXXX)
    cleanup_full_install() {
        local result=$?
        trap - EXIT
        moha_restore_target "$disk"
        rm -rf -- "$setup_dir"
        exit "$result"
    }
    trap cleanup_full_install EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    export MOHA_HOSTNAME="$hostname" MOHA_LOGIN="$login" MOHA_HASH="$password_hash" MOHA_LAYOUT="$layout"
    export MOHA_DISK="$disk" MOHA_ROOT_GIB="$root_gib" MOHA_DISK_BYTES="$disk_bytes" MOHA_SECTOR_BYTES="$sector_bytes"
    python3 "$script_dir/scripts/archinstall-config.py" "$setup_dir"
    unset MOHA_HASH password_hash
    # Stage only reviewed repository inputs, never profiles or .git data.
    mkdir "$setup_dir/payload"
    cp -a "$script_dir"/{install.sh,desktop-packages.txt,aur-packages.txt,config,home,system,inventory} "$setup_dir/payload/"
    export MOHA_PAYLOAD="$setup_dir/payload"
    # Credentials and their parent directory are already private. System files
    # created by archinstall must be readable by users such as pacman's alpm.
    umask 022
    # Stage files through a host-side hook before provisioning the target.
    archinstall --silent --dry-run --config "$setup_dir/config.json" --creds "$setup_dir/creds.json" \
        --plugin "$script_dir/scripts/archinstall-stage.py" --mountpoint /mnt </dev/null
    if [[ $layout != 3 ]]; then
        moha_ignore_target "$disk" || die 'Cannot protect the target disk from automounting.'
    fi
    # util-linux honors this for wipefs and other block tools; coordinate with
    # udev's probes instead of racing them after the partition table changes.
    LOCK_BLOCK_DEVICE=1 archinstall --silent --config "$setup_dir/config.json" --creds "$setup_dir/creds.json" \
        --plugin "$script_dir/scripts/archinstall-stage.py" --mountpoint /mnt </dev/null
    # Run directly so provisioning output streams to the caller instead of
    # being captured by archinstall's custom-command runner.
    arch-chroot -S /mnt bash /opt/mohaLinux/install.sh --provision "$login" </dev/null
    echo 'Installation finished. Review archinstall output before rebooting.'
    exit 0
fi

if [[ $mode == --provision ]]; then
    # Run this stage via arch-chroot. Refuse to provision its host.
    [[ -r $script_dir/.target-root ]] || die 'Provisioning must run inside the new installation via arch-chroot.'
    [[ $(cat "$script_dir/.target-root") == "$(stat -Lc '%d:%i' /)" ]] || die 'Provisioning is not chrooted into the staged target filesystem.'
    # arch-chroot -S supplies a fresh /tmp whose default mode can be 0755.
    # Unprivileged package builds require the usual sticky, writable directory.
    chmod 1777 /tmp
    login=$2
else
    [[ ! -d /run/archiso ]] || die 'Local desktop setup requires an installed Arch system; choose full installation on the ISO.'
    login=${2:-${SUDO_USER:-}}
    if [[ -z $login || $login == root ]]; then
        read -r -p 'Existing username to configure: ' login
    fi
fi
[[ $login =~ ^[a-z_][a-z0-9_-]{0,30}$ && $login != root ]] || die 'Choose a regular user account.'
getent passwd "$login" >/dev/null || die 'Target login does not exist.'
login_home=$(getent passwd "$login" | cut -d: -f6)
[[ $login_home == /home/* && -d $login_home ]] || die 'Expected an existing /home user.'
for input in desktop-packages.txt aur-packages.txt inventory/packages-explicit.txt inventory/packages-foreign.txt inventory/enabled-services.txt; do
    [[ -r $script_dir/$input ]] || die "Missing repository input: $input"
done
if [[ $mode == --local ]]; then
    # Save files that desktop provisioning will replace, including user dotfiles.
    mkdir -p /var/backups
    backup_dir=$(mktemp -d /var/backups/moha-desktop.XXXXXXXX)
    mkdir -p "$backup_dir/home" "$backup_dir/etc"
    for path in .bashrc .bash_profile .bash_logout .nvidia-settings-rc; do
        [[ ! -e $login_home/$path ]] || cp -a "$login_home/$path" "$backup_dir/home/"
    done
    mkdir -p "$backup_dir/home/.config"
    for path in "$script_dir"/config/*; do
        name=${path##*/}
        [[ ! -e $login_home/.config/$name ]] || cp -a "$login_home/.config/$name" "$backup_dir/home/.config/"
    done
    for path in pacman.conf os-release lsb-release issue sddm sddm.conf.d X11/xorg.conf.d mkinitcpio.conf.d default/grub; do
        [[ -e /etc/$path ]] || continue
        if [[ -L /etc/$path ]]; then
            cp -L --preserve=mode,ownership,timestamps --parents "/etc/$path" "$backup_dir/"
        else
            cp -a --parents "/etc/$path" "$backup_dir/"
        fi
    done
    echo "Existing configuration backed up to $backup_dir"
    # Keep local repositories and other pacman preferences while enabling Steam.
    if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
    fi
else
    cp "$script_dir/system/etc/pacman.conf" /etc/pacman.conf
    # Use explicit fallback mirrors rather than an automatically selected host
    # that may no longer resolve when desktop provisioning starts.
    cp -a /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.moha-backup
    install -m 644 "$script_dir/system/etc/pacman.d/install-mirrorlist" /etc/pacman.d/mirrorlist
fi
pacman -Syu --noconfirm

# Merge the original installer lists with every explicitly installed package.
# Foreign packages are built through yay, including foreign dependencies.
mapfile -t aur_packages < <(cat "$script_dir/aur-packages.txt" "$script_dir/inventory/packages-foreign.txt" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' | sort -u)
mapfile -t all_packages < <(cat "$script_dir/desktop-packages.txt" "$script_dir/inventory/packages-explicit.txt" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//' | sed '/^$/d' | sort -u)
for package in "${all_packages[@]}" "${aur_packages[@]}"; do
    [[ $package =~ ^[a-z0-9][a-z0-9@._+-]*$ ]] || die "Invalid package name: $package"
done
repo_packages=(python)
for package in "${all_packages[@]}"; do
    foreign=false
    for aur_package in "${aur_packages[@]}"; do
        [[ $package != "$aur_package" ]] || foreign=true
    done
    [[ $foreign == true ]] || repo_packages+=("$package")
done
pacman -S --needed --noconfirm "${repo_packages[@]}"

# yay and makepkg must build as an unprivileged user, even when invoked by root.
pacman -S --needed --noconfirm base-devel git sudo
aur_build_dir=$(mktemp -d /tmp/aur-build.XXXXXXXXXX)
build_user="aur-${aur_build_dir##*.}"
sudoers_file="/etc/sudoers.d/$build_user"
build_user_created=false
cleanup() {
    rm -f -- "$sudoers_file"
    if [[ "$build_user_created" == true ]]; then
        # makepkg signature checks can leave GPG daemons holding this account.
        runuser -u "$build_user" -- env HOME="$aur_build_dir" \
            GNUPGHOME="$aur_build_dir/.gnupg" gpgconf --kill all || true
        userdel "$build_user"
    fi
    rm -rf -- "$aur_build_dir"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

useradd --system --user-group --home-dir "$aur_build_dir" --shell /bin/bash "$build_user"
build_user_created=true
chown "$build_user:$build_user" "$aur_build_dir"
printf '%s ALL=(root) NOPASSWD: /usr/bin/pacman\n' "$build_user" > "$sudoers_file"
chmod 0440 "$sudoers_file"
visudo -cf "$sudoers_file"

as_builder() {
    (cd -- "$aur_build_dir" && runuser -u "$build_user" -- env HOME="$aur_build_dir" TMPDIR="$aur_build_dir" "$@")
}

# Bootstrap yay only when it is missing, then let it resolve AUR dependencies.
if ! command -v yay > /dev/null 2>&1; then
    as_builder git clone -- https://aur.archlinux.org/yay.git "$aur_build_dir/yay"
    as_builder bash -c 'cd -- "$HOME/yay" && makepkg -si --needed --noconfirm'
fi

aur_targets=()
for package in "${aur_packages[@]}"; do
    [[ $package == yay || $package == yay-debug ]] || aur_targets+=("$package")
done
if (( ${#aur_targets[@]} )); then
    as_builder yay -S --needed --noconfirm --answerclean None --answerdiff None "${aur_targets[@]}"
fi

# Restore desktop files, translating the original user's absolute home paths.
login_home=$(getent passwd "$login" | cut -d: -f6)
[[ $login_home == /home/* ]] || die 'Expected a regular /home user.'
mkdir -p "$login_home/.config"
cp -a "$script_dir/config/." "$login_home/.config/"
cp -a "$script_dir/home/." "$login_home/"
python3 - "$login_home" <<'PY'
from pathlib import Path
import sys
home = Path(sys.argv[1])
paths = list((home / '.config').rglob('*')) + [home / '.bashrc', home / '.nvidia-settings-rc']
for p in paths:
    if not p.is_file() or p.is_symlink():
        continue
    try:
        text = p.read_text()
    except UnicodeDecodeError:
        continue
    if '/home/junglehornet' in text:
        p.write_text(text.replace('/home/junglehornet', str(home)))
PY
if [[ $mode == --provision ]]; then
    # Own the new user's home directory itself as well as all restored files.
    chown -R "$login:$(id -gn "$login")" "$login_home"
else
    chown -R "$login:$(id -gn "$login")" "$login_home/.config"
    for file in "$script_dir"/home/.*; do
        [[ -f $file ]] && chown "$login:$(id -gn "$login")" "$login_home/${file##*/}"
    done
fi
# Preserve generated initramfs hooks, fstab, locale and bootloader topology.
# Merge appearance and portable initramfs settings into the generated base.
for path in sddm.conf.d sddm X11/xorg.conf.d; do
    mkdir -p "/etc/$path"
    cp -a "$script_dir/system/etc/$path/." "/etc/$path/"
done
mkdir -p /usr/share/sddm/themes
cp -a "$script_dir/system/usr/share/sddm/themes/emerald" /usr/share/sddm/themes/
install -m 644 "$script_dir/system/etc/os-release" /etc/os-release
install -m 644 "$script_dir/system/etc/lsb-release" /etc/lsb-release
install -m 644 "$script_dir/system/etc/issue" /etc/issue
mkdir -p /etc/mkinitcpio.conf.d
rm -f /etc/mkinitcpio.conf.d/moha-nvidia.conf
install -m 644 "$script_dir/system/etc/mkinitcpio.conf.d/moha-portable.conf" /etc/mkinitcpio.conf.d/moha-portable.conf
# Keep archinstall's GRUB options, including encryption/root parameters.
if [[ $mode == --provision || -f /boot/grub/grub.cfg ]]; then
    # GRUB's 10_linux appends " Linux" to the distributor name.
    printf '\nGRUB_DISTRIBUTOR="Moha"\n' >> /etc/default/grub
fi
mkinitcpio -P
if [[ $mode == --provision || -f /boot/grub/grub.cfg ]]; then
    grub-mkconfig -o /boot/grub/grub.cfg
fi
while read -r unit state preset; do
    [[ -z $unit || $unit == \#* ]] && continue
    if [[ $unit == sddm.service ]]; then
        systemctl enable --force "$unit"
    else
        systemctl enable "$unit"
    fi
done < "$script_dir/inventory/enabled-services.txt"
systemctl set-default graphical.target
# Leave a clear completion marker for inspection after installation.
if [[ $mode == --provision ]]; then
    touch /opt/mohaLinux/installation-complete
fi
echo "Desktop setup completed for $login. Reboot when ready."
