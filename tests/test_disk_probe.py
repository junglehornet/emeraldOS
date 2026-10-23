import errno
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('probe', Path(__file__).parents[1] / 'scripts/disk-probe.py')
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class DiskProbeTests(unittest.TestCase):
    def test_transient_claim_is_retried_and_fd_closed(self):
        with patch.object(probe.os, 'open', side_effect=[OSError(errno.EBUSY, 'busy'), 42]) as op, \
             patch.object(probe.os, 'close') as close, patch.object(probe.time, 'sleep') as sleep:
            probe.wait_for_exclusive_open('/dev/test', attempts=3)
            self.assertEqual(op.call_count, 2)
            close.assert_called_once_with(42)
            sleep.assert_called_once_with(0.25)

    def test_persistent_claim_stops_after_bounded_retries(self):
        with patch.object(probe.os, 'open', side_effect=OSError(errno.EBUSY, 'busy')) as op, \
             patch.object(probe.time, 'sleep') as sleep:
            with self.assertRaises(OSError):
                probe.wait_for_exclusive_open('/dev/test', attempts=3)
            self.assertEqual(op.call_count, 3)
            self.assertEqual(sleep.call_count, 2)

    def test_other_errors_are_not_retried(self):
        with patch.object(probe.os, 'open', side_effect=OSError(errno.ENOENT, 'gone')) as op, \
             patch.object(probe.time, 'sleep') as sleep:
            with self.assertRaises(OSError):
                probe.wait_for_exclusive_open('/dev/test')
            op.assert_called_once()
            sleep.assert_not_called()


if __name__ == '__main__':
    unittest.main()
