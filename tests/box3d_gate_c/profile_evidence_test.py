"""Synthetic metadata checks; these do not execute or certify Native tests."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location(
    "box3d_profile", Path(__file__).resolve().parents[2] / "build/box3d_profile.py")
profile = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(profile)

NAMES = ["domain_static", "domain_shared", "domain_modules", "motion", "authoring",
         "recovery", "recovery_reference", "recovery_fields", "recovery_lifecycle",
         "api_static", "api_shared", "lifecycle"]


class ProfileEvidence(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.source = self.root / "libogb3.so"
        self.source.write_bytes(b"synthetic library identity")
        self.manifest = {"ctest": "not_run", "test_supervision": "direct_registered_commands_v1",
                         "native_sources": {"synthetic.c": "source hash"}, "test_names": NAMES}
        inputs = self.root / "source-inputs.json"
        inputs.write_text(json.dumps(self.manifest["native_sources"]))
        registered, tests = [], []
        for name in NAMES:
            argv = [str(self.source), name]
            registered.append({"name": name, "command": argv, "properties": []})
            log = self.root / (name + ".log")
            log.write_text("synthetic exit record\n")
            tests.append({"name": name, "argv": argv, "cwd": str(self.root), "properties": {},
                          "actual_exit": 0, "log": str(log), "log_sha256": profile.sha(log)})
        registration = self.root / "registered-tests.json"
        registration.write_text(json.dumps({"tests": registered}))
        binaries = {self.source.name: profile.sha(self.source)}
        self.report = {"result": "DIRECT_REGISTERED_TEST_COMMANDS_PASS", "actual_ctest_run_pass": False,
                       "source_fence_unchanged": True, "binary_fence_unchanged": True,
                       "actual_passed_commands": 12, "tests": tests, "build_dir": str(self.root),
                       "binary_sha256_before": binaries, "binary_sha256_after": binaries.copy(),
                       "native_source_inputs": {"path": str(inputs), "sha256": profile.sha(inputs)},
                       "registration": {"exit": 0, "path": str(registration),
                                        "sha256": profile.sha(registration)}}

    def check_report(self):
        path = self.root / "report.json"
        path.write_text(json.dumps(self.report))
        self.manifest["direct_test_report"] = {"path": str(path), "sha256": profile.sha(path)}
        return profile.native_test_evidence(self.source, self.manifest)

    def test_complete_direct_evidence_and_legacy_ctest(self):
        self.assertEqual(self.check_report()["runner"], "direct_registered_commands_v1")
        self.assertEqual(profile.native_test_evidence(self.source, {"ctest": "passed"}),
                         {"runner": "ctest"})

    def test_claimed_pass_does_not_hide_missing_or_failed_test(self):
        self.report["tests"][0]["actual_exit"] = 1
        with self.assertRaises(profile.ProfileError):
            self.check_report()
        self.report["tests"].pop(0)
        with self.assertRaises(profile.ProfileError):
            self.check_report()

    def test_changed_registered_command_rejected(self):
        self.report["tests"][0]["argv"] = ["different command"]
        with self.assertRaises(profile.ProfileError):
            self.check_report()

    def test_changed_library_rejected_despite_claimed_fence(self):
        self.source.write_bytes(b"replacement")
        with self.assertRaises(profile.ProfileError):
            self.check_report()

    def test_changed_source_or_log_rejected(self):
        self.manifest["native_sources"] = {"other.c": "other hash"}
        with self.assertRaises(profile.ProfileError):
            self.check_report()
        self.manifest["native_sources"] = {"synthetic.c": "source hash"}
        Path(self.report["tests"][0]["log"]).write_text("replacement log")
        with self.assertRaises(profile.ProfileError):
            self.check_report()


if __name__ == "__main__":
    unittest.main()
