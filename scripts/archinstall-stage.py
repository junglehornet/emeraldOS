"""Configure the target offline and stage the desktop payload."""
import os
from pathlib import Path
import shutil

__archinstall__version__ = float('inf')


def write_resolver_configuration(target, source=Path('/etc/resolv.conf')):
    # arch-chroot skips its host DNS bind mount when this file is absent.
    # Replace stale stub symlinks too: their service is not running in a chroot.
    content = source.read_text()
    if not any(line.split('#', 1)[0].strip().startswith('nameserver ')
               for line in content.splitlines()):
        raise ValueError('Host resolv.conf has no DNS nameservers')
    destination = Path(target) / 'etc/resolv.conf'
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.unlink(missing_ok=True)
    destination.write_text(content)
    destination.chmod(0o644)


def write_keyboard_configuration(target):
    etc = Path(target) / 'etc'
    etc.mkdir(parents=True, exist_ok=True)
    (etc / 'vconsole.conf').write_text('KEYMAP=us\nFONT=default8x16\n')
    xorg = etc / 'X11/xorg.conf.d'
    xorg.mkdir(parents=True, exist_ok=True)
    (xorg / '00-keyboard.conf').write_text(
        'Section "InputClass"\n'
        '    Identifier "system-keyboard"\n'
        '    MatchIsKeyboard "on"\n'
        '    Option "XkbLayout" "us"\n'
        'EndSection\n'
    )


class Plugin:
    def on_user_create(self, installation, user):
        # Retrying a pre-mounted installation preserves its account database.
        # Handle only the creation step; archinstall still updates the password,
        # configured groups, and sudo access after this hook returns True.
        passwd = Path(installation.target) / 'etc/passwd'
        if not passwd.exists():
            return False
        for line in passwd.read_text().splitlines():
            fields = line.split(':')
            if fields[0] != user.username:
                continue
            if (len(fields) != 7 or not fields[2].isdigit()
                    or not 1000 <= int(fields[2]) < 65534
                    or fields[5] != f'/home/{user.username}'):
                raise ValueError(f'Refusing to reuse unexpected target account: {user.username}')
            return True
        return False

    def on_mkinitcpio(self, installation):
        # This runs before archinstall's initial initramfs build. Returning False
        # leaves its normal initramfs generation (including disk hooks) enabled.
        write_keyboard_configuration(installation.target)
        return False

    def on_install(self, installation):
        write_keyboard_configuration(installation.target)
        write_resolver_configuration(installation.target)
        # Repair public directories left private by older installer retries.
        for relative in ('etc', 'etc/X11/xorg.conf.d', 'var/cache/pacman',
                         'var/lib/pacman/local'):
            directory = Path(installation.target) / relative
            if directory.is_dir():
                directory.chmod(0o755)
        database = Path(installation.target) / 'var/lib/pacman'
        if database.is_dir():
            # Package metadata is public, including ALPM_DB_VERSION. makepkg
            # queries it as an ordinary user before resolving dependencies.
            for entry in database.rglob('*'):
                if entry.is_symlink():
                    continue
                entry.chmod(0o755 if entry.is_dir() else 0o644)
        target = Path(installation.target) / 'opt/mohaLinux'
        shutil.copytree(os.environ['MOHA_PAYLOAD'], target, dirs_exist_ok=True)
        target.chmod(0o755)
        root = Path(installation.target).stat()
        (target / '.target-root').write_text(f'{root.st_dev}:{root.st_ino}\n')
