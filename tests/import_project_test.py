from pathlib import Path
import os
import subprocess
import tempfile
import unittest

HELPER = Path(__file__).with_name('import_project.sh').resolve()


class ImportBarrierTests(unittest.TestCase):
    def run_import(self, program):
        with tempfile.TemporaryDirectory(prefix='odin-import-test-') as directory:
            root = Path(directory)
            godot = root / 'godot'
            godot.write_text('#!/usr/bin/env bash\n' + program + '\n')
            godot.chmod(0o755)
            project = root / 'project with spaces'
            project.mkdir()
            (project / 'project.godot').write_text('config_version=5\n')
            (project / 'fixture.gdextension').write_text(
                '[configuration]\nentry_symbol="fixture_init"\n'
                'compatibility_minimum="4.7"\n\n[libraries]\n'
                'linux.debug.x86_64="res://libfixture.so"\n')
            log = root / 'import.log'
            environment = os.environ.copy()
            environment['GODOT'] = str(godot)
            environment['ODIN_GODOT_ROOT'] = str(HELPER.parent.parent)
            result = subprocess.run(['bash', '-c', 'source "$1"; '
                'odin_godot_test_import "$2" "/native library.so" "$3"',
                'import-test', str(HELPER), str(project), str(log)], env=environment,
                capture_output=True, text=True)
            self.assertEqual((project / '.godot/extension_list.cfg').read_text(),
                             'res://fixture.gdextension\n')
            return result, log.read_text()

    def test_failed_import_retains_the_actual_error_log(self):
        result, log = self.run_import('echo "fixture importer failed"; exit 7')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('fixture importer failed', log)
        self.assertIn('Godot import failed', result.stderr)

    def test_successful_process_with_resource_error_is_rejected(self):
        result, log = self.run_import('echo "ERROR: missing imported texture"')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('missing imported texture', log)
        self.assertIn('Godot import reported errors', result.stderr)


if __name__ == '__main__':
    unittest.main()
