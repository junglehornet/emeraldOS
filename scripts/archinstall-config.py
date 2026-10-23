"""Generate unattended archinstall input without touching disks."""
import json
import os
from pathlib import Path
import sys
import uuid


def configuration(env, uefi):
    layout = env['MOHA_LAYOUT']
    login = env['MOHA_LOGIN']
    if layout == '3':
        disk = {'config_type': 'pre_mounted_config', 'mountpoint': '/mnt'}
    else:
        sector = int(env['MOHA_SECTOR_BYTES'])
        mib = 1024**2
        end = int(env['MOHA_DISK_BYTES']) // mib - 2  # leave GPT backup space
        parts = []

        def partition(start, length, fs, mount, flags):
            def size(value):
                return {'unit': 'MiB', 'value': value,
                        'sector_size': {'unit': 'B', 'value': sector}}
            parts.append({'obj_id': str(uuid.uuid4()), 'status': 'create',
                          'type': 'primary', 'start': size(start), 'size': size(length),
                          'fs_type': fs, 'mountpoint': mount, 'mount_options': [],
                          'flags': flags, 'dev_path': None, 'btrfs': []})

        start = 1
        if not uefi:
            partition(start, 1, None, None, ['bios_grub'])
            start += 1
        partition(start, 1024, 'fat32' if uefi else 'ext4', '/boot',
                  ['boot', 'esp'] if uefi else ['boot'])
        start += 1024
        root_size = int(env['MOHA_ROOT_GIB']) * 1024 if layout == '2' else end - start
        if root_size <= 0 or start + root_size > end:
            raise ValueError('Invalid root partition size')
        partition(start, root_size, 'ext4', '/', [])
        if layout == '2':
            partition(start + root_size, end - start - root_size, 'ext4', '/home', [])
        disk = {'config_type': 'manual_partitioning',
                'device_modifications': [{'device': env['MOHA_DISK'], 'wipe': True,
                                          'partitions': parts}]}
    config = {
        'archinstall-language': 'English', 'disk_config': disk,
        'bootloader_config': {'bootloader': 'Grub', 'uki': False, 'removable': True},
        'bootloader': 'Grub',  # compatibility with earlier 3.x releases
        'hostname': env['MOHA_HOSTNAME'], 'kernels': ['linux'],
        # The staging plugin writes the US keymap offline before mkinitcpio.
        # A nonempty kb_layout makes archinstall boot a temporary systemd machine
        # and call localectl, which fails on some installed-system hosts.
        'locale_config': {'kb_layout': '', 'sys_lang': 'en_US', 'sys_enc': 'UTF-8',
                          'console_font': 'default8x16'},
        'timezone': 'America/Chicago', 'ntp': True,
        'network_config': {'type': 'nm'},
        'mirror_config': {
            'optional_repositories': ['multilib'],
            'custom_servers': [
                {'url': 'https://geo.mirror.pkgbuild.com/$repo/os/$arch'},
                {'url': 'https://fastly.mirror.pkgbuild.com/$repo/os/$arch'},
            ],
        },
        'profile_config': {'profile': {'main': 'Minimal'}},
        'swap': {'enabled': True, 'algorithm': 'zstd'},
        'packages': [], 'services': [],
        # Archinstall runs these commands through arch-chroot into its target.
        'custom_commands': [f'bash /opt/mohaLinux/install.sh --provision {login}'],
    }
    user = {'username': login, 'enc_password': env['MOHA_HASH'], 'sudo': True, 'groups': ['wheel']}
    return config, {'users': [user], '!users': [user]}


if __name__ == '__main__':
    config, creds = configuration(os.environ, Path('/sys/firmware/efi').exists())
    for name, value in [('config.json', config), ('creds.json', creds)]:
        p = Path(sys.argv[1]) / name
        p.write_text(json.dumps(value, indent=2) + '\n')
        p.chmod(0o600)
