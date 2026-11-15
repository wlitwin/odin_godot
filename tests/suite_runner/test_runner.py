from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SuiteRunnerTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='odin-suite-runner-')
        self.root = Path(self.temporary.name)
        tests = self.root / 'tests'
        tests.mkdir()
        shutil.copy2(ROOT / 'tests/suite_report.py', tests)
        source = (ROOT / 'tests/run_all.sh').read_text()
        start = source.index('TESTS=(')
        end = source.index('\n)\n', start) + len('\n)\n')
        self.entries = [
            'pass|PASS_OK|tests/pass.sh||native',
            'failed|PASS_OK|tests/failed.sh||native',
            'markerfailed|PASS_OK|tests/markerfailed.sh|SKIP_OK|native',
            'browser|BROWSER_OK|tests/browser.sh||browser',
            'mixed|MIXED_OK|tests/mixed.sh|SUITE_NATIVE_ONLY_OK|mixed',
            'mixedfailed|MIXED_OK|tests/mixedfailed.sh|SUITE_NATIVE_ONLY_OK|mixed',
            'slow|SLOW_OK|tests/slow.sh||native',
        ]
        source = source[:start] + 'TESTS=(\n' + '\n'.join('    "' + x + '"' for x in self.entries) + '\n)\n' + source[end:]
        start = source.index('TESTS+=(')
        end = source.index('\n)\n', start) + len('\n)\n')
        source = source[:start] + source[end:]
        (tests / 'run_all.sh').write_text(source)
        scripts = {
            'pass': 'echo "CORE_LIMIT=$(ulimit -c)"\necho PASS_OK\n',
            'failed': 'exit 7\n',
            'markerfailed': 'echo SKIP_OK\nexit 7\n',
            'browser': 'touch browser-ran\necho BROWSER_OK\n',
            'mixed': 'touch native-ran\nif [[ "${SKIP_WEB:-0}" == 1 ]]; then echo MIXED_OK; echo SUITE_NATIVE_ONLY_OK; exit 0; fi\ntouch browser-ran\necho MIXED_OK\n',
            'mixedfailed': 'echo SUITE_NATIVE_ONLY_OK\nexit 9\n',
            'slow': 'touch started\nsleep 30\necho SLOW_OK\n',
        }
        for name, body in scripts.items():
            (tests / (name + '.sh')).write_text('#!/usr/bin/env bash\nset -eu\n' + body)
        fake = self.root / 'fake-odin'
        fake.write_text('#!/bin/sh\nfor arg in "$@"; do case "$arg" in -out:*) touch "${arg#-out:}";; esac; done\n')
        fake.chmod(0o755)
        self.environment = os.environ.copy()
        self.environment.update(ODIN_GODOT_ROOT=str(self.root), GODOT=shutil.which('true'), ODIN=str(fake))
        for key in ('SUITE_SHARD_INDEX', 'SUITE_SHARD_COUNT', 'SUITE_LOGDIR', 'SKIP_WEB', 'TIMEOUT_SECS'):
            self.environment.pop(key, None)

    def tearDown(self):
        self.temporary.cleanup()

    def run_suite(self, *names, **environment):
        env = {**self.environment, **environment}
        return subprocess.run(['bash', str(self.root / 'tests/run_all.sh'), *names],
                              env=env, capture_output=True, text=True, timeout=20)

    def report(self):
        return json.loads((self.root / 'tests/.logs/report.json').read_text())

    def test_focus_reports_omitted_checks(self):
        result = self.run_suite('pass')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        report = self.report()
        self.assertTrue(report['success'])
        self.assertEqual(report['selection']['selected_count'], 1)
        self.assertEqual(report['selection']['omitted_count'], 6)
        self.assertNotIn('ALL GREEN', result.stdout)
        self.assertIn('CORE_LIMIT=0', (self.root / 'tests/.logs/pass.log').read_text())

    def test_explicit_browser_skip_keeps_mixed_native_checks(self):
        result = self.run_suite('browser', 'mixed', SKIP_WEB='1')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.root / 'native-ran').exists())
        self.assertFalse((self.root / 'browser-ran').exists())
        rows = self.report()['results']
        self.assertEqual([r['status'] for r in rows], ['SKIP', 'SKIP'])
        self.assertFalse(rows[0]['native_checks_completed'])
        self.assertTrue(rows[1]['native_checks_completed'])

    def test_skip_marker_cannot_hide_nonzero_exit(self):
        for name in ('markerfailed', 'mixedfailed'):
            result = self.run_suite(name, SKIP_WEB='1')
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertEqual(self.report()['results'][0]['status'], 'FAIL')

    def test_browser_runs_when_enabled(self):
        result = self.run_suite('browser', 'mixed', SKIP_WEB='0')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.root / 'browser-ran').exists())
        self.assertEqual(self.report()['counts']['pass'], 2)

    def test_shards_partition_the_original_manifest(self):
        partitions = []
        for index in range(4):
            result = self.run_suite('--list', SUITE_SHARD_INDEX=str(index), SUITE_SHARD_COUNT='4')
            self.assertEqual(result.returncode, 0, result.stderr)
            partitions.append({line.split('\t')[0] for line in result.stdout.splitlines()})
        self.assertEqual(set.union(*partitions), {x.split('|')[0] for x in self.entries})
        self.assertEqual(sum(map(len, partitions)), len(self.entries))

    def test_bad_selection_and_shards_fail(self):
        self.assertEqual(self.run_suite('--list', 'missing').returncode, 2)
        for index, count in [('1', '1'), ('-1', '4'), ('a', '4'), ('0', '0')]:
            result = self.run_suite('--list', SUITE_SHARD_INDEX=index, SUITE_SHARD_COUNT=count)
            self.assertEqual(result.returncode, 2)

    def test_timeout_is_retained_as_failure(self):
        result = self.run_suite('slow', TIMEOUT_SECS='1')
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(self.report()['results'][0]['status'], 'TIMEOUT')
        self.assertFalse(self.report()['success'])

    def test_interruption_retains_incomplete_report(self):
        process = subprocess.Popen(['bash', str(self.root / 'tests/run_all.sh'), 'slow'],
            env=self.environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            while not (self.root / 'started').exists():
                self.assertIsNone(process.poll())
                self.assertLess(time.monotonic(), deadline)
                time.sleep(.02)
            process.terminate()
            stdout, stderr = process.communicate(timeout=15)
            self.assertEqual(process.returncode, 143, stdout + stderr)
            report = self.report()
            self.assertFalse(report['complete'])
            self.assertFalse(report['success'])
            self.assertEqual(report['results'][0]['status'], 'ABORTED')
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()


class RealManifestTests(unittest.TestCase):
    def test_all_entries_declare_capability(self):
        # Inspect the whole manifest even when CI runs this test inside a shard.
        environment = {**os.environ, 'SUITE_SHARD_INDEX': '0', 'SUITE_SHARD_COUNT': '1'}
        result = subprocess.run(['bash', str(ROOT / 'tests/run_all.sh'), '--list'],
            cwd=ROOT, env=environment, capture_output=True, text=True, check=True)
        rows = [line.split('\t') for line in result.stdout.splitlines()]
        self.assertGreater(len(rows), 300)
        entries = {name: (capability, script) for name, capability, script in rows}
        self.assertEqual(len(entries), len(rows))
        self.assertEqual(entries['replaybrowsercheckpoint'][0], 'native')
        self.assertEqual(entries['kitwasm'][0], 'native')
        self.assertEqual(entries['replayp2pparty'][0], 'browser')
        self.assertEqual(entries['replayrenderaudit'][0], 'mixed')
        for name, (capability, script) in entries.items():
            self.assertTrue((ROOT / script).is_file(), name)
            if capability == 'mixed':
                source = (ROOT / script).read_text()
                self.assertIn('SUITE_NATIVE_ONLY_OK', source, name)
                self.assertIn('SKIP_WEB', source, name)
            if capability == 'native':
                # A new browser invocation must declare a browser/mixed check.
                # WebAssembly compilation and Node-only unit checks still run.
                for line in (ROOT / script).read_text().splitlines():
                    if line.lstrip().startswith('#'):
                        continue
                    browser_call = re.search(
                        r'\b(?:bash|python3|node) .*?(?:/web\.sh|/web_run\.sh|/browser[^/]*\.(?:py|mjs)|/.*web_drive\.mjs|/execute_web\.(?:py|sh))',
                        line)
                    self.assertIsNone(browser_call, name + ': ' + line)


if __name__ == '__main__':
    unittest.main()
