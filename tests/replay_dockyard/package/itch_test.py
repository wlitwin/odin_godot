"""HTML5 ZIP layout, launch configuration and explicit-upload checks."""
import importlib.util
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import unittest
from unittest import mock
import zipfile

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('dockyard_publish', ROOT / 'examples/replay_dockyard/publish.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


class ItchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        export = self.base / 'export-input/export'
        export.mkdir(parents=True)
        (export / 'index.html').write_text('<html><head><title>Synthetic</title></head><body></body></html>')
        (export / 'index.pck').write_bytes(b'opaque synthetic pack')
        (export / 'index.wasm').write_bytes(b'opaque synthetic wasm')
        record = export.parent / 'report.json'
        record.write_text(json.dumps({'result': 'EXPORTED_BROWSER_PENDING', 'export_files': tool.package.files(export)}))
        qa = self.base / 'qa.json'
        qa.write_text(json.dumps({'result': 'SYNTHETIC_NOT_QUALIFIED',
                                 'deployed_service': {'url': 'wss://rooms.example/dockyard'}}))
        runtime = self.base / 'runtime/report.json'
        runtime.parent.mkdir()
        runtime.write_text(json.dumps({'all_five_byte_equal': True, 'host': {'cohort': '1234567890abcdef'},
                                       'client': {'cohort': '1234567890abcdef'}}))
        (runtime.parent / 'export-binding.json').write_text(json.dumps({
            'actual_exit': 0, 'export_record_sha256': tool.package.sha(record), 'export_unchanged': True}))
        self.candidate = self.base / 'candidate'
        tool.package.package(record, self.candidate, qa, runtime_report=runtime)
        self.out = self.base / 'itch'

    def tearDown(self):
        self.temp.cleanup()

    def test_zip_runs_from_root_with_exact_runtime_and_notices(self):
        source_pin = tool.package.sha(self.candidate / 'manifest.json')
        out, report = tool.bundle(self.candidate, self.out)
        with zipfile.ZipFile(out / tool.ZIP_NAME) as zipped:
            self.assertIn('index.html', zipped.namelist())
            self.assertIn('licenses/audio-provenance.md', zipped.namelist())
            self.assertIn('qa/qualification.json', zipped.namelist())
            self.assertFalse(any(name.startswith(('web/', 'operator/', 'native-')) for name in zipped.namelist()))
            for name in ['index.pck', 'index.wasm']:
                self.assertEqual(zipped.read(name), (self.candidate / 'web' / name).read_bytes())
        self.assertFalse(report['release_admitted'])
        self.assertEqual(report['qualification_result'], 'SYNTHETIC_NOT_QUALIFIED')
        tool.package.verify(self.candidate, source_pin)

    def test_launch_defaults_preserve_nested_url_invitation_and_overrides(self):
        out, _ = tool.bundle(self.candidate, self.out)
        html = (out / 'web/index.html').read_text()
        code = re.search(r'<script id="dockyard-launch-config">(.*?)</script>', html, re.S)[1]
        # Execute the actual generated bootstrap, rather than duplicating its parsing.
        javascript = '''
const vm = require('node:vm');
const assert = require('node:assert/strict');
const code = process.argv[1];
for (const value of [
  'https://html.itch.zone/html/42/index.html#keep',
  'https://html.itch.zone/html/42/index.html?invite=keep%2Bme&service=wss%3A%2F%2Fother.example&relay=0#keep'
]) {
  const location = {href:value};
  const history = {state:{preserved:true}, replaceState(state, title, url) {
    assert.deepEqual(state, {preserved:true}); location.href = String(url);
  }};
  vm.runInNewContext(code, {URL, location, history});
  const url = new URL(location.href);
  assert.equal(url.pathname, '/html/42/index.html');
  assert.equal(url.hash, '#keep');
  assert.equal(url.searchParams.get('local'), '0');
  assert.equal(url.searchParams.get('service'), value.includes('invite=') ? 'wss://other.example' : 'wss://rooms.example/dockyard');
  assert.equal(url.searchParams.get('relay'), value.includes('invite=') ? '0' : '1');
  if(value.includes('invite=')) assert.equal(url.searchParams.get('invite'), 'keep+me');
}
'''
        subprocess.run(['node', '-e', javascript, code], check=True, capture_output=True, text=True)

    def test_repeat_is_idempotent_and_zip_is_reproducible(self):
        out, report = tool.bundle(self.candidate, self.out)
        _, repeated = tool.bundle(self.candidate, self.out)
        other, _ = tool.bundle(self.candidate, self.base / 'other')
        self.assertEqual(report, repeated)
        self.assertEqual((out / tool.ZIP_NAME).read_bytes(), (other / tool.ZIP_NAME).read_bytes())
        (out / 'web/index.pck').write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'bundle bytes differ'):
            tool.bundle(self.candidate, self.out)

    def test_source_corruption_and_wrong_existing_output_are_preserved(self):
        self.out.mkdir()
        sentinel = self.out / 'keep.txt'
        sentinel.write_text('keep')
        with self.assertRaises(ValueError):
            tool.bundle(self.candidate, self.out)
        self.assertEqual(sentinel.read_text(), 'keep')
        (self.candidate / 'web/index.pck').write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'candidate package bytes differ'):
            tool.bundle(self.candidate, self.base / 'new')
        self.assertFalse((self.base / 'new').exists())

    def test_secret_or_insecure_endpoint_is_refused(self):
        for url in ['ws://localhost/room', 'wss://user:password@example/room',
                    'wss://example/room?token=secret', 'wss://example/room#secret']:
            with self.subTest(url=url), self.assertRaises(ValueError):
                tool.bundle(self.candidate, self.out, url)
        self.assertFalse(self.out.exists())

    def test_review_archive_yields_the_same_verified_bundle(self):
        source = self.base / 'review.tar.gz'
        with tarfile.open(source, 'w:gz') as archive:
            archive.add(self.candidate, arcname='Dockyard-Duo-review')
        pin = tool.package.sha(source)
        _, directory_report = tool.bundle(self.candidate, self.out)
        with tool.candidate_input(source) as candidate:
            _, archive_report = tool.bundle(candidate, self.base / 'from-archive')
        self.assertEqual(directory_report, archive_report)
        self.assertEqual(tool.package.sha(source), pin)

    def test_archive_link_and_parent_traversal_are_refused(self):
        for name, kind in [('outside', tarfile.SYMTYPE), ('../outside', tarfile.REGTYPE)]:
            source = self.base / 'bad.tar.gz'
            with tarfile.open(source, 'w:gz') as archive:
                entry = tarfile.TarInfo(name)
                entry.type = kind
                entry.linkname = '/outside'
                archive.addfile(entry, io.BytesIO())
            with self.subTest(name=name), self.assertRaises(ValueError):
                with tool.candidate_input(source):
                    self.fail('unsafe archive was accepted')

    def test_upload_only_runs_with_explicit_push_target(self):
        args = ['publish.py', '--package', str(self.candidate), '--out', str(self.out)]
        with mock.patch('sys.argv', args), mock.patch.object(tool, 'push') as upload:
            self.assertEqual(tool.main(), 0)
            upload.assert_not_called()
        with mock.patch('sys.argv', args + ['--push', 'owner/game']), mock.patch.object(tool, 'push') as upload:
            self.assertEqual(tool.main(), 0)
            upload.assert_called_once()
            self.assertEqual(upload.call_args.args[1:3], ('owner/game', 'html5'))
        with mock.patch.object(tool.shutil, 'which', return_value='/tools/butler'), \
                mock.patch.object(tool.subprocess, 'run') as command:
            tool.push(self.out, 'owner/game', 'html5', 'review-test')
            command.assert_called_once_with(['butler', 'push', str(self.out / 'web'),
                                             'owner/game:html5', '--userversion', 'review-test'], check=True)


if __name__ == '__main__':
    unittest.main()
