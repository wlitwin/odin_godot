from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'build'))
from web_memory import resolve


class WebMemoryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.project = Path(self.temp.name)

    def presets(self, *modes):
        (self.project / 'export_presets.cfg').write_text(''.join(
            f'[preset.{i}]\nname="Web {i}"\nplatform="Web"\n[preset.{i}.options]\nvariant/thread_support={str(mode).lower()}\n'
            for i, mode in enumerate(modes)))

    def test_defaults_and_actual_preset_override_backend_default(self):
        self.assertFalse(resolve(self.project, False, None))
        self.assertTrue(resolve(self.project, True, None))
        self.presets(True)
        self.assertTrue(resolve(self.project, False, None))
        self.presets(False)
        self.assertFalse(resolve(self.project, False, None))
        with self.assertRaisesRegex(ValueError, 'Box3D.*shared memory'):
            resolve(self.project, True, None)

    def test_active_export_selects_among_different_presets(self):
        self.presets(False, True)
        with self.assertRaisesRegex(ValueError, 'different memory modes'):
            resolve(self.project, False, None)
        self.assertFalse(resolve(self.project, False, '0'))
        self.assertTrue(resolve(self.project, False, '1'))
        with self.assertRaisesRegex(ValueError, '0 or 1'):
            resolve(self.project, False, 'false')

    def test_invalid_configuration_is_not_silently_unthreaded(self):
        self.presets('invalid')
        with self.assertRaisesRegex(ValueError, 'true or false'):
            resolve(self.project, False, None)
        self.presets(True, True)
        self.assertTrue(resolve(self.project, False, None))


if __name__ == '__main__': unittest.main()
