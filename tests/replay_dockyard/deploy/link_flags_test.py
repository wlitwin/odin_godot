"""Exercise the real shared helper's linker arguments without compiling a game."""
from pathlib import Path
import os
import shlex
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[3]

class LinkFlagsTests(unittest.TestCase):
    def options(self, extension, runtime):
        code = 'source "$1"; _ODIN_GD_BOX3D_RUNTIME="$2"; odin_gd_dll_link_options "$3" "$4"'
        result = subprocess.run(['bash', '-c', code, 'test', str(ROOT/'build/common.sh'),
                                 runtime, '/tmp/consumer path/library.'+extension, extension],
                                text=True, capture_output=True, check=True, env=os.environ.copy())
        return shlex.split(result.stdout)

    def test_linux_search_path_is_exact_and_origin_remains_literal(self):
        options = self.options('so', '/tmp/backend path/bin')
        self.assertIn('-L/tmp/backend path/bin', options)
        self.assertIn('-Wl,-rpath,$ORIGIN', options)
        self.assertIn('-Wl,-rpath,$ORIGIN/../backend path/bin', options)

    def test_darwin_install_name_and_loader_path_are_preserved(self):
        options = self.options('dylib', '/tmp/backend path/bin')
        self.assertIn('-Wl,-install_name,/tmp/consumer path/library.dylib', options)
        self.assertIn('-Wl,-rpath,@loader_path', options)
        self.assertFalse(any(x.startswith('-L') for x in options))

    def test_no_backend_introduces_no_linux_library_search(self):
        self.assertEqual(self.options('so', ''), [])

if __name__ == '__main__':
    unittest.main()
