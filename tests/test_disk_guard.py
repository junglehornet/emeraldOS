"""Exercise disk-guard control flow with mocked commands; no devices are opened."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

GUARD = Path(__file__).parents[1] / 'scripts/disk-guard.sh'


class DiskGuardTests(unittest.TestCase):
    def run_guard(self, code, **env):
        return subprocess.run(['bash', '-c', 'set -euo pipefail; source "$1"; ' + code,
                               'test', str(GUARD)], env={**os.environ, **env},
                              capture_output=True, text=True)

    def test_mounted_target_is_refused_before_exclusive_open(self):
        result = self.run_guard('lsblk() { echo /media/target; }; '
                                'python3() { echo unexpected >&2; }; '
                                'moha_check_disk_idle /dev/test')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('mounted filesystems', result.stderr)
        self.assertNotIn('unexpected', result.stderr)

    def test_rule_is_target_only_and_cleanup_removes_it(self):
        with tempfile.TemporaryDirectory() as directory:
            rule = Path(directory) / 'guard.rules'
            result = self.run_guard('mkdir() { :; }; mktemp() { printf "%s" "$TEST_RULE"; }; '
                                    'udevadm() { echo "$*"; }; '
                                    'moha_check_disk_idle() { :; }; '
                                    'moha_ignore_target /dev/sdc; cat "$TEST_RULE"; '
                                    'moha_restore_target /dev/sdc; [[ ! -e $TEST_RULE ]]',
                                    TEST_RULE=str(rule))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('KERNEL=="sdc"', result.stdout)
            self.assertIn('KERNELS=="sdc"', result.stdout)
            self.assertNotIn('KERNEL=="sdc*"', result.stdout)
            self.assertIn('UDISKS_IGNORE}="1"', result.stdout)
            self.assertIn('settle --timeout=30', result.stdout)

    def test_reload_failure_stops_before_idle_check(self):
        with tempfile.TemporaryDirectory() as directory:
            result = self.run_guard('mkdir() { :; }; mktemp() { printf "%s" "$TEST_RULE"; }; '
                                    'udevadm() { return 1; }; '
                                    'moha_check_disk_idle() { echo unexpected; }; '
                                    'moha_ignore_target /dev/sdc',
                                    TEST_RULE=str(Path(directory) / 'guard.rules'))
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('unexpected', result.stdout)


if __name__ == '__main__':
    unittest.main()
