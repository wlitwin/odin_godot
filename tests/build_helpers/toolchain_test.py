from pathlib import Path
import concurrent.futures
import json
import os
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "build"))
import toolchain


class ToolchainTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.project = Path(self.tmp.name).resolve()
        self.odin = self.project / "compiler with spaces"
        self.odin.write_text("#!/bin/sh\nexit 0\n")
        self.odin.chmod(0o755)

    def test_reopen_without_shell_uses_remembered_paths(self):
        with patch.dict(os.environ, {"PATH": ""}, clear=True):
            first = toolchain.resolved(self.project, "macos", {"ODIN": str(self.odin)})
            toolchain.remember(self.project, ROOT, first)
            second = toolchain.resolved(self.project, "macos", {})
        self.assertEqual(first, second)
        self.assertEqual(toolchain.read_cache(self.project)["root"], str(ROOT))

    def test_explicit_missing_compiler_is_actionable(self):
        with patch.dict(os.environ, {"PATH": ""}, clear=True):
            toolchain.remember(self.project, ROOT, {"odin": str(self.odin)})
            with self.assertRaisesRegex(ValueError, "ODIN executable not found"):
                toolchain.resolved(self.project, "macos", {"ODIN": "/missing/odin"})

    def test_stale_or_corrupt_cache_does_not_invent_a_compiler(self):
        path = toolchain.cache_path(self.project) / "odin"
        path.parent.mkdir(parents=True)
        with patch.dict(os.environ, {"PATH": ""}, clear=True):
            for data in ('invalid', '[]', '/missing/compiler', '\x00corrupt'):
                path.write_text(data)
                with self.subTest(data=data), self.assertRaisesRegex(ValueError, "Odin compiler not found"):
                    toolchain.resolved(self.project, "macos", {})

    def test_backend_selection_is_target_specific_and_missing_input_fails(self):
        native = self.project / "libogb3.dylib"
        web = self.project / "libogb3.a"
        native.touch()
        web.touch()
        toolchain.remember(self.project, ROOT, {"box3d_native_macos": str(native), "box3d_web": str(web)})
        cache = toolchain.read_cache(self.project)
        self.assertEqual(toolchain.resolve_backend(self.project, "native_macos", "macos", cache, {}), str(native))
        self.assertEqual(toolchain.resolve_backend(self.project, "native_linux", "linux", cache, {}), "")
        self.assertEqual(toolchain.resolve_backend(self.project, "web", "web", cache, {}), str(web))
        native.unlink()
        with self.assertRaisesRegex(ValueError, "BOX3D_NATIVE_LIBRARY"):
            toolchain.resolve_backend(self.project, "native_macos", "macos", cache, {})

    def test_existing_deployment_migrates_without_new_configuration(self):
        source = self.project / "libogb3.dylib"
        source.touch()
        record = self.project / "bin/box3d-runtime.json"
        record.parent.mkdir()
        record.write_text(json.dumps({"target": "macos", "source_library": str(source)}))
        self.assertEqual(toolchain.resolve_backend(self.project, "native_macos", "macos", {}, {}), str(source))
        self.assertEqual(toolchain.resolve_backend(self.project, "native_linux", "linux", {}, {}), "")

    def test_concurrent_successes_preserve_both_backend_selections(self):
        toolchain.cache_path(self.project).mkdir(parents=True)
        with concurrent.futures.ThreadPoolExecutor() as pool:
            futures = [pool.submit(toolchain.remember, self.project, ROOT, {key: value})
                       for key, value in [("odin", str(self.odin)), ("box3d_native_macos", "/native"), ("box3d_web", "/web")]]
            for future in futures:
                future.result()
        cache = toolchain.read_cache(self.project)
        self.assertEqual(cache["odin"], str(self.odin))
        self.assertEqual(cache["box3d_native_macos"], "/native")
        self.assertEqual(cache["box3d_web"], "/web")


if __name__ == "__main__":
    unittest.main()
