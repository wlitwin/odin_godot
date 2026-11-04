#!/usr/bin/env python3
"""Synthetic Python/filesystem tests only: no real Trace decoding or Native evidence."""
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("box3d_diagnostics", ROOT / "tools/box3d_diagnostics.py")
d = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(d)


class BundleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="box3d-bundle-synthetic-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.trace = self.root / "synthetic.trace"
        self.trace.write_bytes(b"SYNTHETIC OPAQUE BYTES\x00\xff")
        self.report = self.root / "original-report.json"
        self.report.write_bytes(b'{ "success": false, "result": "FAIL", "scope": "synthetic" }\n')
        self.tool = self.script("inspector", """data=Path(sys.argv[1]).read_bytes()
print('SYNTHETIC: not a Trace decoder or Native test')
print('BOX3D_TRACE_INSPECT_OK bytes='+str(len(data)))
""")
        self.serial = 0

    def script(self, name, body):
        path = self.root / name
        path.write_text("#!" + sys.executable + "\nimport sys,time\nfrom pathlib import Path\n" + body)
        path.chmod(0o755)
        return path

    def hash(self, path):
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def output(self):
        self.serial += 1
        return self.root / ("bundle-" + str(self.serial))

    def collect(self, out=None, attachments=None, tool=None, pin=None):
        tool = tool or self.tool
        return d.collect("kit", str(self.trace), str(tool), pin or self.hash(tool),
                         str(out or self.output()), attachments if attachments is not None else ["report:original=" + str(self.report)])

    def fails(self, call, code=None):
        with self.assertRaises((d.BundleError, OSError, ValueError, TypeError, KeyError)) as caught:
            call()
        if code is not None:
            self.assertIsInstance(caught.exception, d.BundleError)
            self.assertEqual(caught.exception.code, code)

    def no_stage(self):
        self.assertFalse(list(self.root.glob(".*.staging-*")))

    def test_roundtrip_opaque_verdict_and_different_pinned_local_tool(self):
        original = self.report.read_bytes()
        collected = self.collect()
        bundle = Path(collected["bundle"])
        self.assertEqual(collected["result"], "BUNDLE_COLLECTED")
        self.assertEqual(collected["run_verdict"], "NOT_INFERRED")
        self.assertEqual((bundle / "trace.bin").read_bytes(), self.trace.read_bytes())
        self.assertEqual((bundle / "attachments/report-original").read_bytes(), original)
        self.assertEqual(self.report.read_bytes(), original)
        self.assertEqual(d.verify(str(bundle), collected["manifest_sha256"])["result"], "BUNDLE_VALID")
        other = self.script("other-target-inspector", "print('BOX3D_TRACE_INSPECT_OK synthetic-other-target')\n")
        inspected = d.inspect(str(bundle), str(other), self.hash(other), collected["manifest_sha256"])
        self.assertEqual(inspected["collect_inspector"]["sha256"], self.hash(self.tool))
        self.assertEqual(inspected["local_inspector"]["sha256"], self.hash(other))
        self.assertNotEqual(inspected["local_inspector"]["sha256"], inspected["collect_inspector"]["sha256"])
        self.assertEqual(inspected["run_verdict"], "NOT_INFERRED")
        self.no_stage()

    def test_inspector_pin_exit_marker_and_input_change_reject_atomically(self):
        bad = self.script("bad-exit", "sys.exit(7)\n")
        quiet = self.script("no-marker", "print('not a certified roundtrip')\n")
        changing = self.script("changing-trace", "Path(sys.argv[1]).write_bytes(b'changed')\nprint('BOX3D_TRACE_INSPECT_OK fake')\n")
        for tool, pin, code in [(self.tool, "0" * 64, "INSPECTOR_SHA256"),
                                (bad, self.hash(bad), "INSPECTOR_REJECTED"),
                                (quiet, self.hash(quiet), "INSPECTOR_REJECTED"),
                                (changing, self.hash(changing), "CORRUPT")]:
            with self.subTest(code=code):
                out = self.output()
                self.fails(lambda: self.collect(out=out, tool=tool, pin=pin), code)
                self.assertFalse(out.exists()); self.no_stage()
        valid = self.collect(); bundle = Path(valid["bundle"])
        self.fails(lambda: d.inspect(str(bundle), str(changing), self.hash(changing)), "CHANGED")
        self.assertEqual(d.verify(str(bundle))["result"], "BUNDLE_VALID")

    def test_paths_symlinks_duplicates_and_exclusive_publication(self):
        for attachment in ["log:../escape=" + str(self.report), "log:host=" + str(self.report.parent / ".." / self.report.name),
                           "unknown:host=" + str(self.report), "log:host=relative"]:
            self.fails(lambda: self.collect(attachments=[attachment]))
        self.fails(lambda: self.collect(attachments=["log:one=" + str(self.report), "log:two=" + str(self.report)]), "DUPLICATE")
        second = self.root / "second"; second.write_bytes(b"other")
        self.fails(lambda: self.collect(attachments=["log:same=" + str(self.report), "log:same=" + str(second)]), "DUPLICATE")
        alias = self.root / "alias"; alias.symlink_to(self.report)
        self.fails(lambda: self.collect(attachments=["report:alias=" + str(alias)]), "SYMLINK")
        existing = self.output(); existing.mkdir(); (existing / "keep").write_bytes(b"owned")
        self.fails(lambda: self.collect(out=existing), "DESTINATION_EXISTS")
        self.assertEqual((existing / "keep").read_bytes(), b"owned")
        # Exercise the atomic no-replace primitive itself, including EMPTY dst.
        staged = self.root / "atomic-stage"; staged.mkdir()
        empty = self.root / "raced-destination"; empty.mkdir()
        self.fails(lambda: d.publish_noreplace(staged, empty), "DESTINATION_EXISTS")
        self.assertTrue(staged.is_dir()); self.assertTrue(empty.is_dir())
        fifo = self.root / "fifo"
        import os
        os.mkfifo(fifo)
        self.fails(lambda: self.collect(attachments=["other:fifo=" + str(fifo)]), "NOT_REGULAR")
        self.no_stage()

    def test_count_file_aggregate_and_manifest_caps(self):
        cases = [("MAX_FILES", 4, "FILE_COUNT"), ("MAX_FILE_BYTES", 4, "FILE_LIMIT"),
                 ("MAX_TOTAL_BYTES", 4, "TOTAL_LIMIT"), ("MAX_MANIFEST_BYTES", 32, "MANIFEST_LIMIT")]
        for name, value, code in cases:
            with self.subTest(bound=name), mock.patch.object(d, name, value):
                out = self.output(); self.fails(lambda: self.collect(out=out), code)
                self.assertFalse(out.exists()); self.no_stage()
        self.trace.write_bytes(b"1234"); self.report.write_bytes(b"567")
        with mock.patch.object(d, "MAX_TOTAL_BYTES", 6):
            self.fails(self.collect, "TOTAL_LIMIT") # individually small, combined7

    def test_corrupt_manifest_payload_and_unlisted_members(self):
        result = self.collect(); bundle = Path(result["bundle"])
        manifest_path = bundle / "manifest.json"; original = manifest_path.read_bytes()
        self.fails(lambda: d.verify(str(bundle), "0" * 64), "MANIFEST_SHA256")
        manifest = json.loads(original)
        mutations = [lambda m: m.update(schema=99), lambda m: m["files"][0].update(path="../escape"),
                     lambda m: m["files"].append(dict(m["files"][0])),
                     lambda m: m["files"][0].update(size=d.MAX_FILE_BYTES + 1)]
        for mutation in mutations:
            value = json.loads(original); mutation(value); manifest_path.write_text(json.dumps(value))
            self.fails(lambda: d.verify(str(bundle)))
        manifest_path.write_bytes(b'{"schema":1,"schema":1}'); self.fails(lambda: d.verify(str(bundle)), "DUPLICATE")
        manifest_path.write_bytes(original)
        data = (bundle / "trace.bin").read_bytes(); (bundle / "trace.bin").write_bytes(b"x" * len(data))
        self.fails(lambda: d.verify(str(bundle)), "CORRUPT"); (bundle / "trace.bin").write_bytes(data)
        hidden = bundle / "unlisted"; hidden.write_bytes(b"extra")
        self.fails(lambda: d.verify(str(bundle)), "MEMBERS"); hidden.unlink()
        target = bundle / "trace.bin"; target.unlink(); target.symlink_to(self.trace)
        self.fails(lambda: d.verify(str(bundle)), "SYMLINK")

    def test_original_changes_before_publish_preserve_inputs_and_no_destination(self):
        real_run = d.run_inspector
        def mutate(*args):
            result = real_run(*args)
            self.report.write_bytes(b"changed original source")
            return result
        out = self.output()
        with mock.patch.object(d, "run_inspector", side_effect=mutate):
            self.fails(lambda: self.collect(out=out), "CHANGED")
        self.assertFalse(out.exists()); self.no_stage()
        self.assertEqual(self.report.read_bytes(), b"changed original source") # tool never rewrites it

    def test_verify_is_readonly_has_no_process_and_requires_no_original_tool(self):
        result = self.collect(); bundle = Path(result["bundle"])
        before = {str(p.relative_to(bundle)): self.hash(p) for p in bundle.rglob("*") if p.is_file()}
        self.tool.unlink()
        with mock.patch.object(d, "run_inspector", side_effect=AssertionError("verify started a process")):
            self.assertEqual(d.verify(str(bundle))["result"], "BUNDLE_VALID")
            stdout = io.StringIO()
            with contextlib.redirect_stdout(stdout):
                self.assertEqual(d.main(["verify", "--bundle", str(bundle)]), 0)
            self.assertEqual(json.loads(stdout.getvalue())["run_verdict"], "NOT_INFERRED")
        self.assertEqual(before, {str(p.relative_to(bundle)): self.hash(p) for p in bundle.rglob("*") if p.is_file()})

    def test_inspector_output_and_time_are_bounded_and_children_reaped(self):
        noisy = self.script("noisy", "print('x'*4096)\n")
        sleepy = self.script("sleepy", "time.sleep(3)\n")
        with mock.patch.object(d, "MAX_INSPECTOR_OUTPUT_BYTES", 128):
            self.fails(lambda: self.collect(tool=noisy), "INSPECTOR_OUTPUT_LIMIT")
        with mock.patch.object(d, "INSPECTOR_TIMEOUT", .05):
            self.fails(lambda: self.collect(tool=sleepy), "INSPECTOR_TIMEOUT")
        self.no_stage()


if __name__ == "__main__":
    print("SYNTHETIC bundle tests: opaque fixture bytes/Python child stubs; NO real Trace or Native claim", flush=True)
    unittest.main()
