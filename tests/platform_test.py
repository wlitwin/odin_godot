from pathlib import Path
import subprocess
import unittest

HELPER = Path(__file__).with_name('platform.sh').resolve()


class NativeFixturePlatformTests(unittest.TestCase):
    def run_helper(self, script, *arguments):
        return subprocess.run(['bash', '-c', 'source "$1"; ' + script,
                               'platform-test', str(HELPER), *arguments],
                              capture_output=True, text=True)

    def test_library_paths_follow_the_native_host(self):
        for system, platform, extension in [('Darwin', 'macos', 'dylib'),
                                            ('Linux', 'linux', 'so'),
                                            ('MINGW64_NT', 'windows', 'dll')]:
            with self.subTest(system=system):
                result = self.run_helper('odin_godot_test_platform_init "$2" && '
                    'printf "%s/%s" "$ODIN_GODOT_TEST_PLATFORM" "$ODIN_GODOT_TEST_LIB_EXT"', system)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, platform + '/' + extension)

    def test_linux_exports_use_the_requested_native_architecture(self):
        for machine, architecture in [('x86_64', 'x86_64'), ('aarch64', 'arm64')]:
            with self.subTest(machine=machine):
                result = self.run_helper('odin_godot_test_platform_init Linux && '
                    'odin_godot_test_export_paths "/tmp/project with spaces" Game MacExecutable "$2" && '
                    'printf "%s\\n%s\\n%s" "$ODIN_GODOT_TEST_EXPORT_PRESET" '
                    '"$ODIN_GODOT_TEST_EXPORTED_EXE" "$ODIN_GODOT_TEST_EXPORTED_LIBDIR"', machine)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.splitlines(), ['Linux ' + architecture,
                    '/tmp/project with spaces/out/Game.' + architecture,
                    '/tmp/project with spaces/out'])

    def test_macos_exports_preserve_bundle_layout(self):
        result = self.run_helper('odin_godot_test_platform_init Darwin && '
            'odin_godot_test_export_paths /tmp/project Game ActualExecutable arm64 && '
            'printf "%s\\n%s" "$ODIN_GODOT_TEST_EXPORTED_EXE" "$ODIN_GODOT_TEST_EXPORTED_LIBDIR"')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ['/tmp/project/out/Game.app/Contents/MacOS/ActualExecutable',
            '/tmp/project/out/Game.app/Contents/Frameworks'])

    def test_unknown_hosts_fail_explicitly(self):
        result = self.run_helper('odin_godot_test_platform_init UnknownOS')
        self.assertEqual(result.returncode, 2)
        self.assertIn('Unsupported native fixture host', result.stderr)


if __name__ == '__main__':
    unittest.main()
