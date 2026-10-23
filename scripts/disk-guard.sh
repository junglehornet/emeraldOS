# Target-only automount exclusion for whole-disk installations.
# Sourced by install.sh; these functions never unmount or erase anything.
moha_check_disk_unused() {
    local disk=$1 node holder
    if [[ -n $(lsblk -nr -o MOUNTPOINTS "$disk" | tr -d '[:space:]') ]]; then
        echo "Target $disk has mounted filesystems or active swap. Unmount it before retrying." >&2
        return 1
    fi
    while IFS= read -r node; do
        for holder in /sys/class/block/"${node##*/}"/holders/*; do
            [[ -e $holder ]] || continue
            echo "Target $node is used by ${holder##*/}; close that mapping before retrying." >&2
            return 1
        done
    done < <(lsblk -nrpo NAME "$disk")
}

moha_check_disk_idle() {
    local disk=$1 node
    moha_check_disk_unused "$disk" || return 1
    # Probe only after automount exclusion, and allow short-lived claims to clear.
    if ! python3 "$(dirname -- "${BASH_SOURCE[0]}")/disk-probe.py" "$disk"; then
        lsblk -o NAME,PATH,TYPE,FSTYPE,MOUNTPOINTS "$disk" >&2 || true
        if command -v fuser >/dev/null; then
            while IFS= read -r node; do
                fuser -v "$node" >&2 || true
            done < <(lsblk -nrpo NAME "$disk")
        fi
        echo 'No disk changes were made by this check. Inspect the holders above; do not force a wipe.' >&2
        return 1
    fi
}

moha_ignore_target() {
    local disk=$1 name=${1##*/}
    [[ $name =~ ^[a-zA-Z0-9_-]+$ ]] || return 1
    mkdir -p /run/udev/rules.d || return 1
    moha_udev_rule=$(mktemp /run/udev/rules.d/99-moha-install-XXXXXXXX.rules) || return 1
    printf 'SUBSYSTEM=="block", KERNEL=="%s", ENV{UDISKS_IGNORE}="1", ENV{UDISKS_AUTO}="0"\n' "$name" > "$moha_udev_rule" || return 1
    printf 'SUBSYSTEM=="block", KERNELS=="%s", ENV{UDISKS_IGNORE}="1", ENV{UDISKS_AUTO}="0"\n' "$name" >> "$moha_udev_rule" || return 1
    udevadm control --reload-rules || return 1
    udevadm trigger --action=change "/sys/class/block/$name" || return 1
    udevadm trigger --action=change --parent-match="/sys/class/block/$name" || return 1
    udevadm settle --timeout=30 || return 1
    moha_check_disk_idle "$disk"
}

moha_restore_target() {
    local name=${1##*/}
    [[ -n ${moha_udev_rule:-} ]] || return 0
    rm -f -- "$moha_udev_rule"
    udevadm control --reload-rules || true
    if [[ -e /sys/class/block/$name ]]; then
        udevadm trigger --action=change "/sys/class/block/$name" || true
        udevadm trigger --action=change --parent-match="/sys/class/block/$name" || true
        udevadm settle --timeout=30 || true
    fi
}
