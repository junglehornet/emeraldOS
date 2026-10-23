"""Wait briefly for transient block-device claims without modifying the disk."""
import errno
import os
import sys
import time


def wait_for_exclusive_open(path, attempts=20, delay=0.25):
    for attempt in range(attempts):
        try:
            fd = os.open(path, os.O_RDONLY | os.O_EXCL)
        except OSError as exc:
            if exc.errno != errno.EBUSY or attempt == attempts - 1:
                raise
            time.sleep(delay)
        else:
            os.close(fd)
            return


if __name__ == '__main__':
    try:
        wait_for_exclusive_open(sys.argv[1])
    except OSError as exc:
        sys.exit(f'Target {sys.argv[1]} remains unavailable after automount protection: {exc}. '
                 'A mount in another namespace, an active mapping, or a process may still hold it.')
