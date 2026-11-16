from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def core_rows():
    return [line.split('\t') for line in (ROOT / 'tests/core.tsv').read_text().splitlines()
            if line and not line.startswith('#')]


class CoreMetadataTests(unittest.TestCase):
    def test_twenty_unique_checks_reference_the_real_manifest(self):
        rows = core_rows()
        self.assertEqual(len(rows), 20)
        self.assertEqual(len({name for _, name, _ in rows}), 20)
        self.assertEqual({group: sum(row[0] == group for row in rows)
                          for group in ('bridge', 'kit', 'replay', 'utilities')},
                         {'bridge': 5, 'kit': 4, 'replay': 9, 'utilities': 2})
        environment = {**os.environ, 'SUITE_SHARD_INDEX': '0', 'SUITE_SHARD_COUNT': '1'}
        listed = subprocess.run(['bash', str(ROOT / 'tests/run_all.sh'), '--list'],
                                env=environment, capture_output=True, text=True, check=True)
        manifest = {line.split('\t')[0] for line in listed.stdout.splitlines()}
        self.assertTrue({name for _, name, _ in rows} <= manifest)
        self.assertEqual({name for _, name, needed in rows if needed == '1'},
                         {'phase35', 'godotlifetimes', 'phase4', 'replayreplica'})
        self.assertTrue(all(needed in ('0', '1') for _, _, needed in rows))


class CoreSelectionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='odin-core-selector-')
        self.root = Path(self.temporary.name)
        tests = self.root / 'tests'
        tests.mkdir()
        for name in ('run_core.sh', 'core.tsv', 'suite_report.py'):
            shutil.copy2(ROOT / 'tests' / name, tests / name)
        source = (ROOT / 'tests/run_all.sh').read_text()
        entries = []
        for name in [row[1] for row in core_rows()] + ['outside']:
            entries.append(f'    "{name}|CORE_{name}_OK|tests/{name}.sh||native"')
            (tests / f'{name}.sh').write_text(
                f'#!/usr/bin/env bash\ntouch "ran-{name}"\necho CORE_{name}_OK\n')
        start = source.index('TESTS=(')
        end = source.index('\n)\n', start) + len('\n)\n')
        source = source[:start] + 'TESTS=(\n' + '\n'.join(entries) + '\n)\n' + source[end:]
        start = source.index('TESTS+=(')
        end = source.index('\n)\n', start) + len('\n)\n')
        (tests / 'run_all.sh').write_text(source[:start] + source[end:])
        compiler = self.root / 'odin'
        compiler.write_text('#!/bin/sh\nfor a in "$@"; do case "$a" in -out:*) touch "${a#-out:}";; esac; done\n')
        compiler.chmod(0o755)
        self.environment = os.environ.copy()
        for key in ('GODOT', 'SUITE_SHARD_INDEX', 'SUITE_SHARD_COUNT', 'SKIP_WEB', 'TIMEOUT_SECS'):
            self.environment.pop(key, None)
        self.environment.update(ODIN_GODOT_ROOT=str(self.root), ODIN=str(compiler),
                                SUITE_LOGDIR=str(self.root / 'results'))

    def tearDown(self):
        self.temporary.cleanup()

    def invoke(self, *arguments, runner='run_core.sh', **environment):
        return subprocess.run(['bash', str(self.root / 'tests' / runner), *arguments],
                              env={**self.environment, **environment}, capture_output=True,
                              text=True, timeout=15)

    def test_unit_components_run_without_godot_and_ignore_inherited_shards(self):
        for component in ('kit', 'utilities', 'replay'):
            arguments = [component] + (['--unit'] if component == 'replay' else [])
            result = self.invoke(*arguments, SUITE_SHARD_INDEX='7', SUITE_SHARD_COUNT='8')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            report = json.loads((self.root / 'results/report.json').read_text())
            expected = {name for group, name, needed in core_rows()
                        if group == component and needed == '0'}
            self.assertEqual({row['name'] for row in report['results']}, expected)
            self.assertEqual(report['counts']['pass'], len(expected))
            self.assertTrue(report['complete'] and report['success'])
            self.assertEqual((report['selection']['shard_index'], report['selection']['shard_count']), (0, 1))

    def test_engine_components_and_noncore_selections_require_godot(self):
        for arguments in [('bridge',), ('replay',), ('all',)]:
            result = self.invoke(*arguments)
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn('GODOT must name an executable', result.stderr)
        for arguments in [('outside',), ()]:
            result = self.invoke(*arguments, runner='run_all.sh')
            self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
            self.assertIn('GODOT must name an executable', result.stderr)
        self.assertFalse(list(self.root.glob('ran-*')))

    def test_engine_component_uses_the_shared_runner_when_godot_is_present(self):
        result = self.invoke('bridge', GODOT=shutil.which('true'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        report = json.loads((self.root / 'results/report.json').read_text())
        self.assertEqual(report['counts']['pass'], 5)
        self.assertTrue((self.root / 'ran-phase35').is_file())

    def test_listing_and_invalid_component_or_duplicate_metadata(self):
        result = self.invoke('all', '--unit', '--list', SUITE_SHARD_INDEX='5', SUITE_SHARD_COUNT='8')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(result.stdout.splitlines()), 16)
        self.assertEqual(self.invoke('missing', '--list').returncode, 2)
        self.assertEqual(self.invoke('bridge', 'kit', '--list').returncode, 2)
        table = self.root / 'tests/core.tsv'
        rows = table.read_text().splitlines()
        rows[-1] = rows[-2]
        table.write_text('\n'.join(rows) + '\n')
        result = self.invoke('utilities', '--list')
        self.assertEqual(result.returncode, 2)
        self.assertIn('duplicate check', result.stderr)


if __name__ == '__main__':
    unittest.main()
