"""Synthetic record-contract controls only; no probe, timer, Native or Godot."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import analyze
import records as r
from test_analyze import meta, sample, end, normal_meta, normal_sample


def signature_meta():
    value = meta()
    value.update(framework="kit", descriptor=dict(wire_revision=2,
                 native_recovery_read_in_operation=False))
    value["boundary"].update(receiver_entry="session_dispatch_then_lane_frame",
                             included_work=sorted(r.KIT_V2_REPAIR_WORK))
    value["sample_plan"] = dict(normal=0, repair8=19)
    return value


def signature_sample(seq=1):
    value = sample("repair8", seq)
    value.update(base_tick=154, head_before=162, head_after=162,
                 confirmed_before=154, confirmed_after=162,
                 included_work=sorted(r.KIT_V2_REPAIR_WORK),
                 accepted_packets=1, signature_packets=1,
                 signatures_before=0, signatures_after=1,
                 full_states_before=1, full_states_after=1,
                 counter_kind="model_step_callback")
    return value


class KitV2Controls(unittest.TestCase):
    def analyze_values(self, values):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "synthetic.jsonl"
            original = "".join(json.dumps(x) + "\n" for x in values)
            source.write_text(original)
            report = analyze.analyze(source, root / "out")
            self.assertEqual(source.read_text(), original)
            raw = (root / "out/samples.jsonl").read_text()
            return report, raw

    def stream(self, change=None):
        values = [signature_sample(i) for i in range(1, 20)]
        if change is not None:
            change(values[0])
        result = end(19)
        result["functional_operations"] = 20
        return [signature_meta(), *values, result]

    def test_actual_meta_is_used_and_both_profiles_retain_all19(self):
        for profile, (identity, contacts) in r.PROFILES.items():
            with self.subTest(profile=profile):
                values = self.stream()
                values[0]["fixture"].update(id=profile, profile_hex=identity,
                    reference_peak=dict(bodies=35, shapes=35, contacts=contacts, joints=1))
                report, raw = self.analyze_values(values)
                self.assertEqual(report["result"], "RECORDS_VALID")
                self.assertEqual(report["boundary_findings"], [])
                self.assertEqual(report["operation_findings_count"], 0)
                self.assertEqual(report["counts"], dict(normal=0, repair8=19))
                self.assertEqual(report["samples_retained"], 19)
                self.assertEqual(len(raw.splitlines()), 19)
                # A repair-only synthetic stream is not complete CPU coverage.
                self.assertEqual(report["cpu_candidate_acceptance"], "INCOMPLETE")

    def test_legacy_absent_wire1_and_replay_keep_native_read_requirement(self):
        original = sample("repair8", 1)
        for framework, descriptor in (("kit", None), ("kit", {"wire_revision": 1}),
                                      ("replay", {"wire_revision": 2})):
            with self.subTest(framework=framework, descriptor=descriptor):
                m = meta()
                m["framework"] = framework
                if descriptor is not None:
                    m["descriptor"] = descriptor
                self.assertEqual(r.sample_findings(original, m), r.sample_findings(original))
                self.assertEqual(r.boundary_findings(r.validate_meta(m)), [])
                m["boundary"]["included_work"] = sorted(r.KIT_V2_REPAIR_WORK)
                self.assertTrue(any("canonical_native_read" in x for x in r.boundary_findings(m)))
                self.assertTrue(any("canonical_native_read" in x for x in r.sample_findings(signature_sample(), m)))
        self.assertTrue(any("canonical_native_read" in x for x in r.sample_findings(signature_sample())))

    def test_version_selection_is_exactly_typed2_not_a_truthy_hint(self):
        for version in (None, 0, 1, 3, True, False, 2.0, "2"):
            with self.subTest(version=version):
                m = signature_meta()
                m["descriptor"]["wire_revision"] = version
                r.validate_meta(m)
                self.assertTrue(r.boundary_findings(m))
                self.assertTrue(r.sample_findings(signature_sample(), m))
        m = signature_meta()
        m["framework"] = "replay"
        self.assertTrue(r.sample_findings(signature_sample(), m))

    def test_each_required_operation_remains_inside_meta_and_sample(self):
        for work in r.KIT_V2_REPAIR_WORK:
            with self.subTest(work=work):
                m = signature_meta()
                m["boundary"]["included_work"].remove(work)
                self.assertTrue(any(work in x for x in r.boundary_findings(m)))
                s = signature_sample()
                s["included_work"].remove(work)
                r.validate_sample(signature_meta(), s, 1)
                self.assertTrue(any(work in x for x in r.sample_findings(s, signature_meta())))

    def test_no_native_read_or_full_state_increment_under_ordinary_branch(self):
        for flag in (None, True, 0, 1, "false"):
            with self.subTest(flag=flag):
                m = signature_meta()
                m["descriptor"]["native_recovery_read_in_operation"] = flag
                with self.assertRaises(r.RecordError):
                    r.validate_meta(m)
        m = signature_meta()
        m["boundary"]["included_work"].append("canonical_native_read_build_verify_reencode")
        self.assertTrue(r.boundary_findings(m))
        s = signature_sample()
        s["included_work"].append("canonical_native_read_build_verify_reencode")
        self.assertTrue(r.sample_findings(s, signature_meta()))
        for change in (lambda s: s.update(full_states_after=2),
                       lambda s: s.update(full_states_before=0, full_states_after=0),
                       lambda s: s.update(full_states_before=2, full_states_after=1)):
            s = signature_sample()
            change(s)
            self.assertTrue(r.sample_findings(s, signature_meta()))

    def test_missing_wrong_and_noninteger_packet_match_counters_fail(self):
        for name in r.KIT_V2_REPAIR_COUNTERS:
            for invalid in (None, True, 1.0, "1", -1):
                with self.subTest(name=name, invalid=invalid):
                    s = signature_sample()
                    s[name] = invalid
                    with self.assertRaises(r.RecordError):
                        r.validate_sample(signature_meta(), s, 1)
            s = signature_sample()
            del s[name]
            with self.assertRaises(r.RecordError):
                r.validate_sample(signature_meta(), s, 1)
        for change in (lambda s: s.update(accepted_packets=0),
                       lambda s: s.update(accepted_packets=2),
                       lambda s: s.update(signature_packets=0),
                       lambda s: s.update(signature_packets=2),
                       lambda s: s.update(signatures_after=0),
                       lambda s: s.update(signatures_after=2),
                       lambda s: s.update(signatures_before=2, signatures_after=1)):
            s = signature_sample()
            change(s)
            self.assertTrue(r.sample_findings(s, signature_meta()))

    def test_wrong_operation_counter_kind_or_short_step_is_not_signature_repair(self):
        for change in (lambda s: s.update(operation="normal"),
                       lambda s: s.update(counter_kind="native_engine_steps"),
                       lambda s: s.update(actual_steps_after=s["actual_steps_before"]),
                       lambda s: s.update(actual_steps_after=s["actual_steps_before"] + 7),
                       lambda s: s.update(actual_steps_after=s["actual_steps_before"] + 9),
                       lambda s: s.update(confirmed_after=161),
                       lambda s: s.update(requested_depth=7)):
            s = signature_sample()
            change(s)
            r.validate_sample(signature_meta(), s, 1)
            self.assertTrue(r.sample_findings(s, signature_meta()))
        s = signature_sample()
        del s["counter_kind"]
        with self.assertRaises(r.RecordError):
            r.validate_sample(signature_meta(), s, 1)

    def test_failed_witness_correctness_quota_and_cleanup_remain_hard(self):
        for change in (lambda s: s.update(signature_packets=0),
                       lambda s: s.update(signatures_after=0),
                       lambda s: s.update(full_states_after=2),
                       lambda s: s["proof"].update(full_state_equal=False),
                       lambda s: s["proof"].update(publication_atomic=False),
                       lambda s: s["proof"].update(quota_ok=False),
                       lambda s: s["proof"].update(actual_complete_sha256="2" * 64),
                       lambda s: s["ledger"].update(committed_peak_bytes=r.TRACKED_BYTES + 1)):
            with self.subTest(change=change):
                report, raw = self.analyze_values(self.stream(change))
                self.assertEqual(report["result"], "FAIL")
                self.assertEqual(report["operation_findings_count"], 1)
                self.assertEqual(report["samples_retained"], 19)
                self.assertEqual(len(raw.splitlines()), 19)
        for change in (lambda x: x.update(source_fence_unchanged=False),
                       lambda x: x.update(binary_fence_unchanged=False),
                       lambda x: x["cleanup"].update(native_live_bytes=1),
                       lambda x: x["cleanup"].update(core_shutdown_clean=False)):
            values = self.stream()
            change(values[-1])
            report, raw = self.analyze_values(values)
            self.assertEqual(report["result"], "FAIL")
            self.assertEqual(len(raw.splitlines()), 19)

    def test_whole_outlier_is_retained_without_threshold_or_percentile_changes(self):
        values = self.stream()
        values[1].update(whole_ns=9_000_000, outer_end_us=10_000)
        report, raw = self.analyze_values(values)
        self.assertEqual(report["result"], "RECORDS_VALID")
        self.assertEqual(report["observed_whole_ceiling_result"], "FAIL")
        self.assertEqual(report["statistics"]["repair8"]["max_ns"], 9_000_000)
        self.assertEqual(report["statistics"]["repair8"]["over_ceiling_count"], 1)
        self.assertEqual(report["outliers_discarded"], 0)
        self.assertEqual(len(raw.splitlines()), 19)
        self.assertEqual(r.CEILING_NS, 4_000_000)
        self.assertEqual(r.TRACKED_BYTES, 67_108_864)

    def test_kit_v2_normal_and_functional_keep_their_original_boundaries(self):
        for kind in r.NORMAL_ENTRIES:
            m = normal_meta(kind)
            m.update(framework="kit", descriptor=dict(wire_revision=2))
            s = normal_sample(kind)
            r.validate_meta(m)
            r.validate_sample(m, s, 1)
            self.assertEqual(r.boundary_findings(m), [])
            self.assertEqual(r.sample_findings(s, m), r.sample_findings(s))
        m = signature_meta()
        m.update(timing_mode="functional_only", sample_plan=dict(normal=0, repair8=0))
        report, raw = self.analyze_values([m, end(0)])
        self.assertEqual(report["result"], "FUNCTIONAL_PASS")
        self.assertEqual(report["cpu_candidate_acceptance"], "NOT_MEASURED")
        self.assertEqual(raw, "")


if __name__ == "__main__":
    unittest.main()
