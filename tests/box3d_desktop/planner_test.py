"""Synthetic planner/preflight metadata controls; NO tool/Native/VM execution."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

SOURCE = Path(__file__).with_name("run.py")
spec = importlib.util.spec_from_file_location("box3d_desktop_planner", SOURCE)
desktop = importlib.util.module_from_spec(spec)
spec.loader.exec_module(desktop)


def config(target="macos-arm64", framework="kit", mode=None):
    return dict(target=target, framework=framework, execution_mode=mode,
                godot="/explicit/godot", odin="/explicit/odin",
                native_library="/verified/libogb3.dylib" if target == "macos-arm64" else "/verified/libogb3.so",
                native_sha256="a" * 64, out="/new-desktop-case", port=45300,
                ticks=120, toolchain_report="/verified/toolchain.json")


class PlannerTests(unittest.TestCase):
    def test_all_declared_target_framework_modes_reuse_exact_helpers(self):
        for target, mode in (("macos-arm64", None), ("linux-x86_64", "native"),
                             ("linux-x86_64", "translated-linux-x86_64")):
            for framework in ("kit", "replay"):
                with self.subTest(target=target, mode=mode, framework=framework):
                    plan = desktop.build_plan(config(target, framework, mode))
                    self.assertEqual(plan["result"], "STAGED_ONLY")
                    self.assertEqual(plan["processes_started"], 0)
                    self.assertEqual(len(plan["steps"]), 2)
                    export, runtime = [s["argv"] for s in plan["steps"]]
                    self.assertIn("macos/export.py" if target.startswith("macos") else "linux/pipeline.py", export[1])
                    self.assertTrue(runtime[1].endswith("box3d_gate_c/run_exported.py"))
                    self.assertNotIn("--path", runtime)
                    self.assertNotIn("ODIN_SCRIPTS_DLL", plan["environment"])
                    self.assertEqual(plan["execution_mode"], mode or "native")
                    if target.startswith("linux"):
                        self.assertEqual(export[export.index("--execution-mode") + 1], mode)
                        self.assertIn("--toolchain-report", export)

    def test_default_cli_creates_only_a_plan_and_never_starts_a_process(self):
        with tempfile.TemporaryDirectory() as temporary:
            out = Path(temporary) / "fresh-plan"
            argv = ["--target", "macos-arm64", "--framework", "replay", "--godot", "/missing/godot",
                    "--odin", "/missing/odin", "--native-library", "/missing/libogb3.dylib",
                    "--native-sha256", "a" * 64, "--out", str(out), "--port", "45301"]
            with mock.patch.object(desktop.subprocess, "run", side_effect=AssertionError("process forbidden")) as run:
                with mock.patch.object(desktop.subprocess, "Popen", side_effect=AssertionError("process forbidden")) as popen:
                    with mock.patch.object(desktop, "execution_inputs", side_effect=AssertionError("execution preflight forbidden")):
                        with contextlib.redirect_stdout(io.StringIO()):
                            self.assertEqual(desktop.main(argv), 0)
                    run.assert_not_called()
                    popen.assert_not_called()
            self.assertEqual([p.name for p in out.iterdir()], ["plan.json"])
            plan = json.loads((out / "plan.json").read_text())
            self.assertEqual((plan["result"], plan["processes_started"]), ("STAGED_ONLY", 0))
            self.assertFalse((out / "report.json").exists())

    def test_invalid_target_mode_paths_digest_and_bounds_are_rejected(self):
        bad = [dict(target="windows"), dict(target="linux-x86_64", execution_mode=None),
               dict(target="macos-arm64", execution_mode="translated-linux-x86_64"),
               dict(godot="relative/godot"), dict(native_sha256="not-a-digest"), dict(port=1),
               dict(ticks=3601), dict(out=str(desktop.ROOT / "generated")),
               dict(target="linux-x86_64", execution_mode="native", toolchain_report=None)]
        for change in bad:
            values = config()
            values.update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                desktop.build_plan(values)

    def test_native_and_translated_preflight_cannot_be_interchanged_or_rebound(self):
        hashes = {"godot": "a" * 64, "odin": "b" * 64}
        base = {"result": "PASS", "elf": {name: dict(sha256=value, machine=62, **{"class": 64}, endian="little")
                                           for name, value in hashes.items()}}
        native = dict(base, execution_mode="native", native_x86_hardware=True,
                      kernel_uname=["Linux", "host", "release", "version", "x86_64", ""])
        translated = dict(base, execution="Rosetta-translated Linux x86_64 functional userspace", native_x86_hardware=False)
        desktop.validate_linux_preflight(native, "native", hashes)
        desktop.validate_linux_preflight(translated, "translated-linux-x86_64", hashes)
        with self.assertRaises(ValueError):
            desktop.validate_linux_preflight(translated, "native", hashes)
        with self.assertRaises(ValueError):
            desktop.validate_linux_preflight(native, "translated-linux-x86_64", hashes)
        with self.assertRaises(ValueError):
            desktop.validate_linux_preflight(native, "native", dict(hashes, godot="c" * 64))
        with self.assertRaises(ValueError):
            desktop.validate_linux_preflight(dict(native, result="FAIL"), "native", hashes)


if __name__ == "__main__":
    unittest.main()
