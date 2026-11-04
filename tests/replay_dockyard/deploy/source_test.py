"""Snapshot input/lifetime checks; no Linux or game qualification inference."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('stage_room', ROOT/'examples/replay_dockyard/deploy/stage_room_source.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)

class SourceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.base = Path(self.temp.name)
        self.root = self.base/'source'
        self.root.mkdir()
        for relative in ['LICENSE', 'NOTICE', 'extension_api.json', 'gdextension_interface.h',
                         'tests/replay_comparison/wait_builds.py',
                         'tests/replay_dockyard/package/engine_notices.gd', 'core/current.odin']:
            p = self.root/relative
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('synthetic current working source\n')
        self.archive = self.base/'engine.tar'
        self.archive.write_bytes(b'synthetic engine bytes')
        dependency = self.root/'box3d/dependency.json'
        dependency.parent.mkdir()
        dependency.write_text(json.dumps({'dependencies': {'box3d': {
            'git_archive_sha256': hashlib.sha256(self.archive.read_bytes()).hexdigest()}}}))
        (self.root/'flake.lock').write_text(json.dumps({'nodes': {'nixpkgs': {
            'locked': {'rev': 'synthetic'}, 'original': {'ref': 'nixos-unstable'}}}}))
        self.out = self.base/'staged'

    def tearDown(self):
        self.temp.cleanup()

    def test_current_uncommitted_bytes_survive_and_generated_private_paths_do_not(self):
        for relative in ['examples/game/bin/stale.so', 'examples/game/.env', 'examples/game/.godot/state']:
            p = self.root/relative
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text('must not ship')
        record = tool.stage(self.root, self.archive, self.out)
        self.assertEqual((self.out/'core/current.odin').read_bytes(), (self.root/'core/current.odin').read_bytes())
        self.assertFalse((self.out/'examples/game/bin').exists())
        self.assertFalse((self.out/'examples/game/.env').exists())
        self.assertEqual(tool.sha(self.out/'vendor/box3d.tar'), record['engine_archive_sha256'])

    def test_wrong_engine_archive_never_publishes(self):
        self.archive.write_bytes(b'wrong engine')
        with self.assertRaisesRegex(ValueError, 'archive identity'):
            tool.stage(self.root, self.archive, self.out)
        self.assertFalse(self.out.exists())

    def test_external_source_symlink_is_refused(self):
        (self.root/'core/borrowed.odin').symlink_to(self.archive)
        with self.assertRaisesRegex(ValueError, 'source symlink'):
            tool.stage(self.root, self.archive, self.out)
        self.assertFalse(self.out.exists())

    def test_prior_snapshot_and_source_tree_are_preserved(self):
        tool.stage(self.root, self.archive, self.out)
        before = tool.sha(self.out/'source-manifest.json')
        with self.assertRaisesRegex(ValueError, 'new output'):
            tool.stage(self.root, self.archive, self.out)
        self.assertEqual(tool.sha(self.out/'source-manifest.json'), before)
        self.assertFalse((self.root/'vendor').exists())

if __name__ == '__main__':
    unittest.main()
