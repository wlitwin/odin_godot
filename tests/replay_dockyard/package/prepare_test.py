"""A previous publish output must not become part of the next source export."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('dockyard_prepare', ROOT / 'examples/replay_dockyard/prepare.py')
tool = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tool)


class PrepareTests(unittest.TestCase):
    def test_publish_output_is_excluded_from_staged_project_and_source_fence(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            root = base / 'repo'
            source = root / 'examples/replay_dockyard'
            (source / 'out/itch-old/web').mkdir(parents=True)
            (source / 'out/itch-old/web/index.pck').write_bytes(b'old exported game')
            (source / 'content').mkdir()
            (source / 'view.gd').write_text('extends Node\n')
            (root / 'addons/box3d_authoring/tool_module').mkdir(parents=True)
            native = base / 'libogb3.dylib'
            native.write_bytes(b'opaque staging-only library')
            out = base / 'staged'
            args = ['prepare.py', '--out', str(out), '--native-library', str(native)]
            with mock.patch.object(tool, 'ROOT', root), mock.patch.object(tool, 'SOURCE', source), mock.patch('sys.argv', args):
                self.assertEqual(tool.main(), 0)
            self.assertFalse((out / 'project/out').exists())
            self.assertEqual((out / 'project/view.gd').read_bytes(), (source / 'view.gd').read_bytes())
            report = json.loads((out / 'report.json').read_text())
            self.assertTrue(report['source_fence_unchanged'])
            self.assertFalse(any('/out/' in name for name in report['source_before']))


if __name__ == '__main__':
    unittest.main()
