"""Synthetic saved-archive diagnostics only; no runtime or acceptance proof."""
import hashlib
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

from control_fidelity import audit_archive


class ControlFidelityTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.number = 0

    def control(self, framework, tick, seat):
        row = dict(epoch=1, tick=tick, seat=seat, x=-100 if seat == 1 else 100, z=0)
        if framework == "kit":
            row.update(player=11 if seat == 1 else 22, **{"class": 0}, accepted=True,
                       status=0, sequence=tick, origin=3 if seat == 1 else 1)
        else:
            row.update(origin="Local" if seat == 1 else "Sample",
                       generation=0 if seat == 1 else 1,
                       serial=0 if seat == 1 else 1, incarnation=0 if seat == 1 else 1)
        return row

    def archive(self, framework="kit", *, overrides=None, indexes=None, omit=(), extras=(), ready=True):
        self.number += 1
        path = Path(self.directory.name) / (str(self.number)+".sqlite")
        db = sqlite3.connect(path)
        db.execute("""CREATE TABLE events(id INTEGER PRIMARY KEY,role TEXT,kind TEXT,
          observed_at REAL,epoch INTEGER,indexed_tick INTEGER,seat INTEGER,sequence INTEGER,
          body TEXT,prev TEXT,hash TEXT)""")
        number = 0

        def append(role, kind, body, indexed=None):
            nonlocal number
            number += 1
            key = body if isinstance(body, dict) else {}
            key = dict(key if indexed is None else indexed)
            tick = key.get("submitted_tick") if kind in ("ISSUED", "SUBMITTED") else key.get("tick")
            db.execute("INSERT INTO events VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                       (number, role, kind, None, key.get("epoch"), tick, key.get("seat"),
                        key.get("sequence"), json.dumps(body), "synthetic", "not-chain-proof"))

        for role in ("host", "client"):
            if framework == "kit" and ready:
                append(role, "READY", dict(epoch=1, players=[11, 22]))
            for tick in range(1, 5):
                for seat in (1, 2):
                    key = role, tick, seat
                    if key in omit:
                        continue
                    original = self.control(framework, tick, seat)
                    body = (overrides or {}).get(key, original)
                    indexed = dict(original)
                    indexed.update((indexes or {}).get(key, {}))
                    append(role, "INPUT", body, indexed)
        for role, kind, body in extras:
            append(role, kind, body)
        db.commit()
        db.close()
        return path

    def inspect(self, path, framework="kit", **options):
        before = path.read_bytes()
        result = audit_archive(path, framework=framework, epoch=1, first_tick=1, last_tick=4, **options)
        self.assertEqual(path.read_bytes(), before, "diagnostic modified saved database")
        self.assertEqual(result["archive_sha256"], hashlib.sha256(before).hexdigest())
        self.assertTrue(result["diagnostic_only"])
        self.assertNotIn("result", result)
        return result

    def group(self, result, role="host", seat=2):
        return next(x for x in result["control_groups"] if x["role"] == role and x["seat"] == seat)

    def held_zero(self, framework):
        values = {}
        for role in ("host", "client"):
            for tick in range(1, 5):
                row = self.control(framework, tick, 2)
                row.update(x=0, z=0, origin=2 if framework == "kit" else "Held")
                if framework == "kit":
                    row["sequence"] = 0  # Actual Held predecessor zero is valid.
                values[role, tick, 2] = row
        return values

    def actions(self, framework="kit", *, applied=False, serial=1):
        issue = dict(epoch=1, seat=2, sequence=7, kind=6 if framework == "kit" else "Query",
                     submitted_tick=3, action_timing="Scheduled" if framework == "kit" else "Receipt")
        outcome = dict(epoch=1, seat=2, sequence=7, kind=issue["kind"], tick=3,
                       accepted=True, applied=applied)
        if framework == "replay":
            issue.update(generation=1, serial=1, incarnation=1)
            outcome.update(generation=1, serial=serial, incarnation=1, reason="Predicate" if not applied else "None")
        return issue, outcome

    def test_kit_nonzero_and_distinct_origin_runs(self):
        changes = {}
        for tick in (3, 4):
            row = self.control("kit", tick, 2)
            row.update(origin=2, sequence=2, x=100 if tick == 3 else 0)
            changes["host", tick, 2] = row
        g = self.group(self.inspect(self.archive(overrides=changes)))
        self.assertEqual(g["origin_counts"], {"Submitted": 2, "Held": 2})
        self.assertEqual((g["nonzero_count"], g["held_zero_count"]), (3, 1))
        self.assertEqual(g["runs"]["Held"], dict(count=1, longest_ticks=2))
        self.assertEqual(g["runs"]["HeldZero"], dict(count=1, longest_ticks=1))
        self.assertEqual(g["coverage"], "COMPLETE_OBSERVATIONS")
        self.assertIsNone(g["fidelity_flag"])

    def test_both_full_held_zero_schemas_are_degenerate(self):
        for framework in ("kit", "replay"):
            with self.subTest(framework=framework):
                r = self.inspect(self.archive(framework, overrides=self.held_zero(framework)), framework)
                for role in ("host", "client"):
                    g = self.group(r, role)
                    self.assertEqual(g["origin_counts"], {"Held": 4})
                    self.assertEqual((g["held_count"], g["nonzero_count"]), (4, 0))
                    self.assertEqual(g["runs"]["HeldZero"], dict(count=1, longest_ticks=4))
                    self.assertEqual(g["fidelity_flag"], "DEGENERATE_FULL_HELD_ZERO")

    def test_missing_control_does_not_complete_or_bridge_run(self):
        path = self.archive("replay", overrides=self.held_zero("replay"), omit={("host", 2, 2)})
        g = self.group(self.inspect(path, "replay"))
        self.assertEqual((g["valid_unique_controls"], g["missing_ticks"]), (3, 1))
        self.assertEqual(g["coverage"], "UNAVAILABLE")
        self.assertEqual(g["fidelity_flag"], "HELD_ZERO_ONLY_OBSERVED_COVERAGE_UNAVAILABLE")
        self.assertEqual(g["runs"]["HeldZero"], dict(count=2, longest_ticks=2))

    def test_duplicate_is_not_extra_coverage(self):
        duplicate = self.control("replay", 2, 2)
        r = self.inspect(self.archive("replay", extras=[("host", "INPUT", duplicate)]), "replay")
        g = self.group(r)
        self.assertEqual((g["valid_unique_controls"], g["duplicate_controls"]), (4, 1))
        self.assertEqual(g["coverage"], "UNAVAILABLE")

    def test_kit_malformed_values_remain_unavailable(self):
        mutations = [("x", None), ("x", True), ("z", 1.0), ("x", 32768),
                     ("origin", 0), ("origin", True), ("status", False), ("accepted", 1),
                     ("sequence", -1), ("sequence", 2**64), ("player", 99), ("class", True)]
        for field, value in mutations:
            with self.subTest(field=field, value=value):
                row = self.control("kit", 2, 2)
                row[field] = value
                g = self.group(self.inspect(self.archive(overrides={("host", 2, 2): row})))
                self.assertEqual((g["malformed_controls"], g["missing_ticks"]), (1, 1))
                self.assertEqual(g["coverage"], "UNAVAILABLE")
        for value in (None, {}, []):
            with self.subTest(body=value):
                r = self.inspect(self.archive(overrides={("host", 2, 2): value}))
                self.assertEqual(self.group(r)["malformed_controls"], 1)

    def test_replay_schema_preserves_sample_local_and_rejects_unknown(self):
        r = self.inspect(self.archive("replay"), "replay")
        self.assertEqual(self.group(r)["origin_counts"], {"Sample": 4})
        self.assertEqual(self.group(r, seat=1)["origin_counts"], {"Local": 4})
        for field, value in [("origin", "Submitted"), ("origin", None), ("generation", True),
                             ("serial", 1.0), ("incarnation", None), ("z", False)]:
            with self.subTest(field=field, value=value):
                row = self.control("replay", 2, 2)
                row[field] = value
                g = self.group(self.inspect(self.archive("replay", overrides={("host", 2, 2): row}), "replay"))
                self.assertEqual(g["malformed_controls"], 1)

    def test_missing_ready_and_index_mismatch_are_unavailable(self):
        r = self.inspect(self.archive(ready=False))
        self.assertTrue(r["unavailable"])
        self.assertTrue(all(x["coverage"] == "UNAVAILABLE" for x in r["control_groups"]))
        r = self.inspect(self.archive(indexes={("host", 2, 2): {"tick": 3}}))
        self.assertEqual(self.group(r)["malformed_controls"], 1)
        self.assertIn("index", r["unavailable_samples"][0]["detail"])

    def test_unattributed_control_never_certifies_full_coverage(self):
        r = self.inspect(self.archive("replay", overrides=self.held_zero("replay"),
                                    indexes={("host", 2, 2): {"epoch": None}}), "replay")
        self.assertEqual(r["unattributed_input_rows"], 1)
        self.assertTrue(all(x["coverage"] == "UNAVAILABLE" for x in r["control_groups"]))
        self.assertNotEqual(self.group(r)["fidelity_flag"], "DEGENERATE_FULL_HELD_ZERO")

    def test_actual_false_outcome_and_missing_outcome_are_distinct(self):
        issue, outcome = self.actions()
        matched = self.inspect(self.archive(extras=[("client", "ISSUED", issue), ("host", "APPLIED", outcome)]))
        c = matched["issue_outcome_correlation"]
        self.assertEqual((c["matched_published_decisions"], c["applied_false"]), (1, 1))
        self.assertEqual(c["reason_unavailable"], 1)
        self.assertNotIn("actual_reason", c["samples"]["LOGICAL_MATCH_ONLY_NOT_ACCEPTANCE"][0])
        missing = self.inspect(self.archive(extras=[("client", "ISSUED", issue)]))["issue_outcome_correlation"]
        self.assertEqual((missing["missing_published_counterpart"], missing["applied_false"]), (1, 0))
        self.assertEqual(missing["observations_by_status"], {"NO_PUBLISHED_COUNTERPART_OBSERVED": 1})

    def test_correlation_scope_and_actual_execution_tick_stay_visible(self):
        issue, outcome = self.actions("replay", applied=True, serial=2)
        outcome["tick"] = 4
        c = self.inspect(self.archive("replay", extras=[("client", "ISSUED", issue),
                         ("host", "APPLIED", outcome)]), "replay")["issue_outcome_correlation"]
        self.assertEqual((c["matched_published_decisions"], c["published_scope_differs"],
                          c["execution_tick_differs_from_submitted"]), (1, 1, 1))
        sample = c["samples"]["LOGICAL_MATCH_ONLY_NOT_ACCEPTANCE"][0]
        self.assertEqual((sample["authority_tick"], sample["actual_reason"]), (4, "None"))
        self.assertEqual(sample["published_scope_differences"], {"serial": [1, 2]})

    def test_ambiguous_malformed_and_wrong_kind_counterparts(self):
        issue, outcome = self.actions()
        scenarios = [("ambiguous_counterpart", [outcome, outcome]),
                     ("unavailable", [dict(outcome, applied=None)]),
                     ("kind_mismatch", [dict(outcome, kind=1)])]
        for field, rows in scenarios:
            with self.subTest(field=field):
                extras = [("client", "ISSUED", issue)]+[("host", "APPLIED", x) for x in rows]
                c = self.inspect(self.archive(extras=extras))["issue_outcome_correlation"]
                self.assertEqual(c[field], 1)
                self.assertEqual(c["matched_published_decisions"], 0)

    def test_sample_bounds_and_streamed_hash_preserve_database(self):
        path = self.archive(extras=[("controller", "PADDING", {"bytes": "x"*(2*1024*1024)})])
        r = self.inspect(path, sample_limit=0)
        self.assertTrue(all(x["nonzero_samples"] == [] and x["valid_unique_controls"] == 4
                            for x in r["control_groups"]))
        self.assertTrue(all(x["detail_samples_truncated"] for x in r["control_groups"]))

    def test_missing_archive_and_missing_schema_are_not_zero_evidence(self):
        missing = Path(self.directory.name)/"missing.sqlite"
        r = audit_archive(missing, framework="kit", epoch=1, first_tick=1, last_tick=4)
        self.assertFalse(missing.exists())
        self.assertTrue(r["unavailable"])
        self.assertTrue(all(x["missing_ticks"] == 4 and x["coverage"] == "UNAVAILABLE"
                            for x in r["control_groups"]))
        path = Path(self.directory.name)/"schema.sqlite"
        with sqlite3.connect(path) as db:
            db.execute("CREATE TABLE unrelated(value INTEGER)")
        db.close()
        r = self.inspect(path)
        self.assertTrue(r["unavailable"])


if __name__ == "__main__":
    unittest.main()
