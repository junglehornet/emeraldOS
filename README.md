# Moha Linux

Moha Linux is an Arch-based OS with a Hyprland desktop. Moha linux doesn't aim
to be a full distro with updates, a package manager, etc. Rather, Moha Linux is 
just a good starting place to use to configure your own Linux desktop. Moha linux
comes with some useful applications preinstalled as well as a fully configured
desktop environment, starship prompt, and login screen. Simply run install.sh from
an existing Arch system (such as an Arch installer ISO or a full Arch system)
to either install all of the configuration files that Moha includes into your
current system or install Moha linux and arch onto a new system.

# Repo File Structure

- `config/` maps to `~/.config/`: Hyprland, monitor rules, wallpapers, Waybar,
  notifications, launcher, terminal, editor, Fish, GTK/Qt appearance, Thunar,
  and desktop autostart entries.
- `home/` contains shell startup files and NVIDIA user preferences. Copy its
  dotfiles into your home directory.
- `system/etc/` mirrors system configuration under `/etc`, including locales,
  keyboard, package repositories, initramfs, greeters, and display configuration.
- `system/usr/share/sddm/themes/emerald/` contains the custom login theme.
- `inventory/` records installed explicit packages, foreign packages, enabled
  services, and the timezone. These are reference snapshots, not install scripts.
- `desktop-packages.txt`, `aur-packages.txt`, and `install.sh` provide the existing
  package lists. The installer wraps archinstall and restores the desktop.

## Install a new system

Run `sudo ./install.sh` to choose between setting up the current Arch system
and installing a new system on another drive.

For a new system, boot a current Arch Linux ISO or use an existing Arch system,
connect to the internet, and copy or clone this repository outside `/mnt`.
Choose full installation from the menu, or run `sudo ./install.sh --full`.
Missing archinstall dependencies are installed automatically on the host.
The script collects a hostname, username, password, and partitioning choice. It then runs
archinstall with `--silent`; archinstall presents no configuration menus.

Choose a whole-disk ext4 layout, optionally with a separate `/home` (specify the
root size), or prepare partitions yourself and mount them at `/mnt` first.
Whole-disk modes erase the selected disk after a typed confirmation. UEFI gets
a 1 GiB FAT32 EFI partition at `/boot`; legacy BIOS gets a BIOS boot partition
and a 1 GiB ext4 `/boot`. The remainder is root and optional home. Pre-mounted
UEFI layouts must have their FAT32 EFI partition mounted at `/mnt/boot`.
For pre-mounted BIOS layouts, prepare a GRUB-compatible disk layout yourself.
When retrying a partial installation with the pre-mounted option, an existing
regular account with the chosen username and `/home/username` home is reused.
Archinstall still applies the entered password, configured groups, and sudo access.

Whole-disk installation refuses mounted filesystems, active swap, and disks with
active device mappings. A temporary udev rule tells desktop automounters to
ignore only the selected disk and its partitions during installation. The rule
is removed on exit, including failures and interrupts. Block tools run with
`LOCK_BLOCK_DEVICE=1` to coordinate signature wiping with udev probing, as
recommended by the [wipefs manual](https://man.archlinux.org/man/wipefs.8.en).
The script never forces a wipe of a mounted partition or automatically unmounts
an in-use drive. If an earlier attempt reported `Device or resource busy`, close
applications using the target and unmount its partitions before retrying.
The disk may already have been partially erased by that failed attempt.
The exclusive-open check runs after automount protection and waits briefly for
transient claims to clear. Persistent failures print the target's mount layout
and process holders when `fuser` is available. Mounts in other namespaces may
not appear in the installer's mount listing; such claims still stop installation.

Defaults are minimal Arch, GRUB, the Linux kernel, US keyboard, en_US.UTF-8,
America/Chicago, your chosen hostname, NetworkManager, time synchronization, and
zram swap. Root login remains locked; the chosen user receives sudo access.
The plugin writes the US console and X11 keyboard settings directly into the
target before initramfs generation. Archinstall's online keymap step is disabled
to avoid its temporary systemd-machine/`localectl` transport requirement; locale
generation still runs normally.
Only password hashes go into temporary credentials under `/run`; those inputs
are removed when the script exits. Archinstall may retain its own root-only
credential and installation logs.
The private credential directory uses restrictive permissions, while archinstall
runs with a normal `022` umask. This keeps system directories accessible to
pacman's unprivileged downloader. Retrying an older partial installation repairs
the affected public directories without changing private key directories.

After the base installation, an archinstall plugin stages this repository into
`/opt/mohaLinux` and a custom command installs the union of the original package
lists and the recorded package inventories. Archinstall runs this custom command
through `arch-chroot` into the new installation before any package installation
or desktop provisioning begins. The provisioning stage verifies that `/` matches
the target filesystem recorded by the staging plugin and refuses to run elsewhere.
Foreign packages use yay as an
unprivileged build user. `yay-debug` comes from the yay build rather than being
requested as a separate AUR package. Missing or renamed packages stop installation
with an error. AUR builds can take substantial time and require internet access.

The desktop, Emerald SDDM theme, branding, NVIDIA settings and recorded system
services are restored. Home-directory paths are adjusted for the chosen login.
Fish, Starship, and Fastfetch are installed explicitly. The saved `config.fish`
initializes Starship and Fastfetch, and `starship.toml` restores the prompt.
As on the original system, the login shell is Bash and `.bashrc` starts Fish
for interactive sessions; the saved Bash startup files are restored as well.
Generated filesystem, encryption and GRUB settings are preserved. The initramfs
keeps the configured hooks except `autodetect`, and includes the `kms` hook, so
graphics and storage modules are available when moving the disk between PCs.
This produces a larger boot image. NVIDIA modules are not forced to load.
The package list includes Mesa, Intel and Radeon Vulkan drivers, NVIDIA's open
kernel driver and userspace libraries, corresponding 32-bit libraries for Steam,
Intel media acceleration, firmware, and both Intel and AMD CPU microcode.
The kernel selects the drivers for the hardware present at boot; no Xorg GPU
selection or global NVIDIA renderer override is installed.

GRUB is installed with its removable-media UEFI fallback path so another UEFI PC
can discover the disk without the original machine's firmware boot entry. Both
PCs still need compatible boot modes; this does not create a combined BIOS/UEFI
installation or configure Secure Boot. `nvidia-open` targets supported modern
NVIDIA GPUs; older NVIDIA cards can require a different legacy driver.
The saved monitor rules still describe the original monitors; Hyprland's existing
automatic monitor rule handles other displays.
The script leaves an `installation-complete` marker in `/opt/mohaLinux` on success
and does not reboot automatically. It does not restore personal files, passwords
for applications, or external projects such as Panorama.

Configuration generation tests: `python3 -m unittest discover -s tests -v`.
The wrapper also asks archinstall to parse its generated input with `--dry-run`
before starting the real installation. The complete installation still needs
validation in a disposable VM; configuration tests do not exercise partitioning,
GRUB installation, package availability, or AUR builds.

Archinstall integration follows its [guided installer](https://github.com/archlinux/archinstall/blob/master/archinstall/scripts/guided.py)
and [plugin hooks](https://github.com/archlinux/archinstall/blob/master/archinstall/lib/plugins.py).

## Set up an existing Arch system

Choose local desktop setup from the menu, or use
`sudo ./install.sh --local username`. With `--local` and no username, the script
uses the sudo user's account, or prompts when run directly as root. The account
must already exist. This mode uses the running system directly; it does not run
archinstall or change partitions, accounts, or passwords.

It installs the same packages and graphics support, applies the saved desktop
and shell settings, selects SDDM for the next boot, and enables the recorded
services. Existing configuration that will be replaced is backed up under
`/var/backups/moha-desktop.*`. Local pacman settings are retained and multilib is
enabled if absent. The portable initramfs is rebuilt. If an existing GRUB
configuration is present, it is regenerated; another bootloader is not replaced
or installed. Desktop and branding files are replaced by this repository's
settings. Active sessions are left running until you choose to reboot.

## Restore

Back up your existing configuration first. Merge the desired files from `config/`
into `~/.config/` and from `home/` into your home directory. Review system files
individually before copying them to their corresponding absolute paths with sudo.
Install the Emerald SDDM theme at the path mirrored in `system/`.

Some settings contain `/home/junglehornet` paths or monitor-specific values;
adjust them for the destination user and hardware. The initramfs configuration
loads NVIDIA modules. Review it for the target GPU and rebuild the initramfs with
`sudo mkinitcpio -P` after changing it. Generate configured locales with
`sudo locale-gen`. Review the service inventory before enabling services; select
one display manager. A greeter configuration being present does not imply it is
enabled. Set the timezone using the value in `inventory/timezone.txt`.

The desktop's `hypr/scripts/apply-theme` publishes its GNOME interface settings;
the binary dconf database is deliberately excluded.

## Exclusions

The configuration allowlist in `.gitignore` excludes browser and Discord
profiles, login sessions, PulseAudio cookies, binary dconf state, and unrelated
application data. Previously copied Discord data, PulseAudio cookies, binary
dconf state, and Qt file-dialog history have been removed from this directory.
SSH/GPG keys, password stores,
network credentials, histories, caches, machine IDs, account databases, and
filesystem UUIDs are not included. Boot partition contents require privileged
access and are not captured by this snapshot. This repository is configuration
and restore guidance, not a full disk backup.
