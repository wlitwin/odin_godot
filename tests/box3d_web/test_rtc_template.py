"""Synthetic identity/publication tests; actual browser evidence is separate."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('rtc_template', ROOT / 'build/web_rtc_template.py')
template = importlib.util.module_from_spec(spec)
spec.loader.exec_module(template)


class TemplateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.function = (template.FUNCTION_START + b'p_id,p_buffer,p_length,p_raw){'
                         + template.INSERT_BEFORE + b'return 0}')
        self.javascript = self.function + template.FUNCTION_END + b'"iiiii";'
        self.payloads = {'godot.js': self.javascript, 'godot.wasm': b'engine bytes',
                         'godot.side.wasm': b'side bytes', 'godot.html': b'<html>unchanged</html>'}
        self.source = self.base / 'official.zip'
        self.write_zip(self.source, self.payloads)
        pins = patch.multiple(template, SOURCE_SHA=template.sha(self.source),
                              JS_SHA=template.digest(self.javascript),
                              FUNCTION_SHA=template.digest(self.function))
        pins.start()
        self.addCleanup(pins.stop)

    def write_zip(self, path, payloads):
        with zipfile.ZipFile(path, 'w') as archive:
            for name, data in payloads.items():
                info = zipfile.ZipInfo(name, (2026, 11, 1, 1, 2, 4))
                info.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(info, data)

    def test_reproducible_and_only_javascript_payload_changes(self):
        first, a = template.derive(self.source, self.base / 'first')
        second, b = template.derive(self.source, self.base / 'second')
        self.assertEqual(a['template']['sha256'], b['template']['sha256'])
        self.assertEqual(template.verify(first)['profile'], template.PROFILE)
        self.assertEqual(template.verify(second)['profile'], template.PROFILE)
        with zipfile.ZipFile(a['template']['path']) as archive:
            for name, data in self.payloads.items():
                if name == 'godot.js':
                    self.assertEqual(archive.read(name), template.patched_js(data))
                else:
                    self.assertEqual(archive.read(name), data)

    def test_wrong_source_or_function_leaves_destination_absent(self):
        wrong = self.base / 'wrong.zip'
        wrong.write_bytes(b'not the pinned source')
        with self.assertRaisesRegex(ValueError, 'ZIP identity'):
            template.derive(wrong, self.base / 'wrong-out')
        self.assertFalse((self.base / 'wrong-out').exists())
        with patch.object(template, 'FUNCTION_SHA', '0' * 64):
            with self.assertRaisesRegex(ValueError, 'preimage'):
                template.derive(self.source, self.base / 'wrong-function')
        self.assertFalse((self.base / 'wrong-function').exists())

    def test_existing_destination_and_source_are_preserved(self):
        output = self.base / 'existing'
        output.mkdir()
        sentinel = output / 'keep'
        sentinel.write_bytes(b'user data')
        before = self.source.read_bytes()
        with self.assertRaises(FileExistsError):
            template.derive(self.source, output)
        self.assertEqual(sentinel.read_bytes(), b'user data')
        self.assertEqual(self.source.read_bytes(), before)

    def test_forged_archive_and_hash_record_do_not_override_pinned_payloads(self):
        path, record = template.derive(self.source, self.base / 'derived')
        payloads = dict(self.payloads)
        payloads['godot.js'] = template.patched_js(payloads['godot.js'])
        payloads['godot.wasm'] = b'changed engine'
        self.write_zip(Path(record['template']['path']), payloads)
        record['template']['sha256'] = template.sha(Path(record['template']['path']))
        record['entry_sha256']['godot.wasm'] = template.digest(payloads['godot.wasm'])
        path.write_text(json.dumps(record))
        before = path.read_bytes()
        with self.assertRaisesRegex(ValueError, 'payload differs'):
            template.verify(path)
        self.assertEqual(path.read_bytes(), before)

    def test_select_changes_only_the_selected_web_release_option(self):
        path, record = template.derive(self.source, self.base / 'derived folder')
        project = self.base / 'project'
        project.mkdir()
        original = ('[preset.0]\nname="Local"\nplatform="Linux"\n'
                    '[preset.0.options]\ncustom_template/release="native unchanged"\n'
                    '[preset.1]\nname="Web"\nplatform="Web"\n'
                    '[preset.1.options]\ncustom_template/release=""\nvariant/thread_support=true\n')
        config = project / 'export_presets.cfg'
        config.write_text(original)
        result = template.select(path, project)
        expected = original.replace('custom_template/release=""',
                                    'custom_template/release=' + json.dumps(record['template']['path']))
        self.assertEqual(config.read_text(), expected)
        self.assertEqual(result['template_sha256'], record['template']['sha256'])

    def test_ambiguous_or_wrong_platform_preset_is_read_only(self):
        path, _ = template.derive(self.source, self.base / 'derived')
        project = self.base / 'project'
        project.mkdir()
        for original in ['[preset.0]\nname="Web"\nplatform="Linux"\n[preset.0.options]\n',
                         '[preset.0]\nname="Web"\nplatform="Web"\n[preset.0.options]\n'
                         '[preset.1]\nname="Web"\nplatform="Web"\n[preset.1.options]\n']:
            config = project / 'export_presets.cfg'
            config.write_text(original)
            with self.assertRaisesRegex(ValueError, 'exactly one'):
                template.select(path, project)
            self.assertEqual(config.read_text(), original)


if __name__ == '__main__':
    unittest.main()
