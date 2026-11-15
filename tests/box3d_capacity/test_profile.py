from pathlib import Path
import json
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'build'))
import box3d_capacity as capacity


class CapacityProfileTests(unittest.TestCase):
    def test_generated_languages_share_the_default_profile(self):
        capacity.check_generated()
        profile = capacity.load()
        self.assertGreaterEqual(profile['max_bodies'], 1000)
        self.assertGreaterEqual(profile['max_joints'], 100)
        self.assertEqual(len(capacity.odin_flags(profile)), len(capacity.FIELDS))
        self.assertEqual(len(capacity.cmake_flags(profile)), len(capacity.FIELDS))

    def test_partial_project_profiles_do_not_change_sdk_defaults(self):
        before = (REPO / 'box3d/capacity.json').read_bytes()
        with tempfile.TemporaryDirectory() as work:
            path = Path(work) / 'physics.json'
            path.write_text(json.dumps({'max_bodies': 2048, 'max_joints': 512}))
            profile = capacity.load(path)
            self.assertEqual(profile['max_bodies'], 2048)
            self.assertEqual(profile['max_joints'], 512)
            self.assertIn('-define:BOX3D_MAX_BODIES=2048', capacity.odin_flags(profile))
        self.assertEqual(before, (REPO / 'box3d/capacity.json').read_bytes())

    def test_invalid_settings_are_rejected(self):
        for key, value in [('schema_version', True), ('max_bodies', True), ('max_joints', 0),
                           ('max_assets', -1), ('max_contacts', 1 << 31),
                           ('max_shapes', 1 << 29),
                           ('memory_bytes', 1024), ('network_bytes', 1024)]:
            profile = capacity.load()
            profile[key] = value
            with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                capacity.validate(profile)
        with tempfile.TemporaryDirectory() as work:
            path = Path(work) / 'bad.json'
            path.write_text('{"max_bodiez": 1000}')
            with self.assertRaises(ValueError):
                capacity.load(path)

    def test_each_setting_participates_in_the_binary_fingerprint(self):
        default = capacity.load()
        fingerprint = capacity.fingerprint(default)
        for key in capacity.FIELDS:
            profile = default.copy()
            profile[key] += 1
            with self.subTest(key=key):
                self.assertNotEqual(capacity.fingerprint(profile), fingerprint)

    def test_authoring_copy_uses_the_verified_selected_profile(self):
        with tempfile.TemporaryDirectory() as work:
            addon = Path(work) / 'addons/box3d_authoring'
            addon.mkdir(parents=True)
            selected = capacity.load()
            selected['max_bodies'] = 2048
            capacity.install_authoring(selected, work)
            content = (addon / 'capacity_defaults.gd').read_text()
            self.assertIn('"max_bodies": 2048', content)
            self.assertEqual(content, capacity.gd_source(selected))
        with self.assertRaises(ValueError):
            capacity.install_authoring(selected, REPO)


if __name__ == '__main__':
    unittest.main()
