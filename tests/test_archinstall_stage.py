import importlib.util
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('stage', Path(__file__).parents[1] / 'scripts/archinstall-stage.py')
stage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage)


class OfflineKeyboardTests(unittest.TestCase):
    def test_staging_repairs_public_directories_without_opening_secrets(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            target = base / 'target'
            public = ('etc', 'etc/X11/xorg.conf.d', 'var/cache/pacman',
                      'var/lib/pacman/local', 'opt/mohaLinux')
            for relative in public + ('etc/ssl/private',):
                path = target / relative
                path.mkdir(parents=True, exist_ok=True)
                path.chmod(0o700)
            payload = base / 'payload'
            payload.mkdir()
            (payload / 'install.sh').write_text('# test payload\n')
            version = target / 'var/lib/pacman/local/ALPM_DB_VERSION'
            version.write_text('9\n')
            version.chmod(0o600)
            with patch.dict('os.environ', {'MOHA_PAYLOAD': str(payload)}), \
                    patch.object(stage, 'write_resolver_configuration'):
                stage.Plugin().on_install(SimpleNamespace(target=target))
            for relative in public:
                self.assertEqual((target / relative).stat().st_mode & 0o777, 0o755)
            self.assertEqual((target / 'etc/ssl/private').stat().st_mode & 0o777, 0o700)
            self.assertEqual(version.stat().st_mode & 0o777, 0o644)
            self.assertEqual((target / 'opt/mohaLinux/.target-root').read_text().strip(),
                             f'{target.stat().st_dev}:{target.stat().st_ino}')

    def test_dns_file_created_and_stale_symlink_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source = base / 'host-resolv.conf'
            source.write_text('nameserver 192.168.0.1\n')
            target = base / 'target'
            for stale in (False, True):
                stage.write_resolver_configuration(target, source)
                resolver = target / 'etc/resolv.conf'
                if stale:
                    resolver.unlink()
                    resolver.symlink_to('/run/systemd/resolve/stub-resolv.conf')
                    stage.write_resolver_configuration(target, source)
                self.assertFalse(resolver.is_symlink())
                self.assertEqual(resolver.read_text(), source.read_text())
                self.assertEqual(resolver.stat().st_mode & 0o777, 0o644)

    def test_retry_reuses_only_regular_account_in_target(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            installation = SimpleNamespace(target=target)
            user = SimpleNamespace(username='alice')
            plugin = stage.Plugin()
            self.assertFalse(plugin.on_user_create(installation, user))
            (target / 'etc').mkdir()
            passwd = target / 'etc/passwd'
            passwd.write_text('alice:x:1000:1000::/home/alice:/bin/bash\n')
            self.assertTrue(plugin.on_user_create(installation, user))
            self.assertFalse(plugin.on_user_create(installation, SimpleNamespace(username='bob')))
            self.assertEqual(passwd.read_text(), 'alice:x:1000:1000::/home/alice:/bin/bash\n')
            for entry in ('alice:x:0:0::/home/alice:/bin/bash\n',
                          'alice:x:1000:1000::/root:/bin/bash\n'):
                passwd.write_text(entry)
                with self.assertRaises(ValueError):
                    plugin.on_user_create(installation, user)

    def test_keyboard_is_ready_before_initramfs_without_skipping_build(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            etc = target / 'etc'
            etc.mkdir()
            (etc / 'vconsole.conf').write_text('KEYMAP=\nFONT=default8x16\n')
            (etc / 'locale.conf').write_text('LANG=en_US.UTF-8\n')
            result = stage.Plugin().on_mkinitcpio(SimpleNamespace(target=target))
            self.assertIs(result, False)
            self.assertEqual((etc / 'vconsole.conf').read_text(), 'KEYMAP=us\nFONT=default8x16\n')
            self.assertIn('Option "XkbLayout" "us"', (etc / 'X11/xorg.conf.d/00-keyboard.conf').read_text())
            self.assertEqual((etc / 'locale.conf').read_text(), 'LANG=en_US.UTF-8\n')
