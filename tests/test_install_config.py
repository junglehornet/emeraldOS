import importlib.util
from pathlib import Path
import unittest
import subprocess

spec = importlib.util.spec_from_file_location('config', Path(__file__).parents[1] / 'scripts/archinstall-config.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ConfigurationTests(unittest.TestCase):
    def config(self, layout='1', uefi=True, sector='512'):
        env = {'MOHA_LAYOUT': layout, 'MOHA_LOGIN': 'alice', 'MOHA_HASH': '$6$test',
               'MOHA_HOSTNAME': 'alice-desktop',
               'MOHA_DISK': '/dev/test', 'MOHA_SECTOR_BYTES': sector,
               'MOHA_DISK_BYTES': str(128 * 1024**3), 'MOHA_ROOT_GIB': '48'}
        return module.configuration(env, uefi)

    def test_uefi_and_bios_layouts_fit_disk(self):
        for uefi in (True, False):
            for layout in ('1', '2'):
                for sector in ('512', '4096'):
                    with self.subTest(uefi=uefi, layout=layout, sector=sector):
                        cfg, creds = self.config(layout, uefi, sector)
                        self.assertEqual(cfg['bootloader_config']['bootloader'], 'Grub')
                        self.assertTrue(cfg['bootloader_config']['removable'])
                        self.assertEqual(cfg['locale_config']['kb_layout'], '')
                        self.assertEqual(cfg['locale_config']['sys_lang'], 'en_US')
                        parts = cfg['disk_config']['device_modifications'][0]['partitions']
                        previous_end = 1
                        for p in parts:
                            self.assertEqual(p['start']['value'], previous_end)
                            self.assertGreater(p['size']['value'], 0)
                            previous_end += p['size']['value']
                        self.assertEqual(previous_end, 128 * 1024 - 2)
                        self.assertEqual([p for p in parts if p['mountpoint'] == '/boot'][0]['fs_type'], 'fat32' if uefi else 'ext4')
                        self.assertEqual(any(p['mountpoint'] == '/home' for p in parts), layout == '2')
                        if not uefi:
                            self.assertIn('bios_grub', parts[0]['flags'])
                        self.assertNotIn('$6$test', str(cfg))
                        self.assertEqual(creds['users'][0]['username'], 'alice')

    def test_pre_mounted_never_requests_wipe(self):
        cfg, _ = self.config('3')
        self.assertEqual(cfg['disk_config'], {'config_type': 'pre_mounted_config', 'mountpoint': '/mnt'})

    def test_uses_requested_hostname(self):
        for layout in ('1', '2', '3'):
            with self.subTest(layout=layout):
                cfg, _ = self.config(layout)
                self.assertEqual(cfg['hostname'], 'alice-desktop')

    def test_mirrors_use_custom_servers_without_region_lookup(self):
        from archinstall.lib.models.mirrors import MirrorConfiguration

        cfg, _ = self.config('3')
        mirrors = MirrorConfiguration.parse_args(cfg['mirror_config'])

        class NoRegionLookup:
            def get_status_by_region(self, *args, **kwargs):
                raise AssertionError('Explicit servers must not require a region lookup')

        self.assertEqual(mirrors.regions_config(NoRegionLookup()), '')
        rendered = mirrors.custom_servers_config()
        self.assertIn('Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch', rendered)
        self.assertIn('Server = https://fastly.mirror.pkgbuild.com/$repo/os/$arch', rendered)

    def test_portable_initramfs_keeps_encryption_and_adds_graphics(self):
        hook = Path(__file__).parents[1] / 'system/etc/mkinitcpio.conf.d/moha-portable.conf'
        for hooks in ('base systemd autodetect sd-encrypt lvm2 filesystems',
                      'base systemd autodetect kms sd-encrypt lvm2 filesystems'):
            result = subprocess.run(
                ['bash', '-c', 'read -ra HOOKS <<< "$1"; MODULES=(custom); source "$2"; '
                 'printf "%s\\n" "${HOOKS[@]}"; [[ ${MODULES[0]} == custom ]]',
                 'test', hooks, str(hook)], capture_output=True, text=True, check=True)
            actual = result.stdout.splitlines()
            self.assertNotIn('autodetect', actual)
            self.assertEqual(actual.count('kms'), 1)
            self.assertIn('sd-encrypt', actual)
            self.assertIn('lvm2', actual)


if __name__ == '__main__':
    unittest.main()
