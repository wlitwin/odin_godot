"""Pure checks only: no compiler, exporter, Godot, process, VM or network."""
from pathlib import Path
import ast
import contextlib
import copy
import importlib.util
import io
import json
import sqlite3
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock,patch

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import controller
import evidence
import intake
import overlay
import plan


def config(**changes):
    result = dict(case="functional", target="macos-arm64", framework="kit",
                  out="/tmp/production-plan-test", godot="/abs/godot", odin="/abs/odin",
                  native_library="/abs/libogb3.dylib", native_sha256="a" * 64,
                  port=41124, pause_at=240, overlay_sha256="b" * 64)
    result.update(changes)
    return result


def status(**changes):
    result = dict(version=1, framework="kit", role="client", go=True, frames=100,
                  head=90, confirmed=85, epoch=1, recovery_available=True,
                  recoveries=0, recovery_serial=3, baseline=0, generation=None,
                  native_observed=True, native_sampled_frame=80,
                  native_live_bytes=1024, wrapper_live_bytes=2048, host_live_bytes=4096,
                  reserved_bytes=512, admitted_bytes=7680, limit_bytes=evidence.LIMIT,
                  owner_count=4, meter_observed=True, meter_sampled_frame=80,
                  meter_live_bytes=8192)
    result.update(changes)
    return result


class ProductionRunnerTests(unittest.TestCase):
    def test_default_cli_writes_plan_without_starting_jobs_or_resolving_tools(self):
        spec = importlib.util.spec_from_file_location("production_entry", HERE / "run.py")
        entry = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(entry)
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "new-output"
            args = ["run.py", "--target", "macos-arm64", "--framework", "kit",
                    "--godot", "/nonexistent/godot", "--odin", "/nonexistent/odin",
                    "--native-library", "/nonexistent/native", "--native-sha256", "a" * 64,
                    "--out", str(output), "--port", "41124"]
            with patch.object(sys, "argv", args), patch("subprocess.Popen", side_effect=AssertionError("job started")), contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(entry.main(), 0)
            saved = json.loads((output / "plan.json").read_text())
            self.assertEqual(saved["result"], "STAGED_ONLY")
            self.assertEqual(saved["jobs_started"], 0)
            self.assertEqual((saved["required_ticks"], saved["terminal_tick"]), (108000, 108600))
            self.assertTrue(saved["overlay"]["project_settings"]["application/run/flush_stdout_on_print"])
            self.assertFalse((output / "report.json").exists())

    def test_long_and_pause_declarations_and_production_overlay(self):
        root = HERE.parents[2]
        long = plan.build_plan(config(case="long"), root, "/python")
        self.assertEqual((long["required_ticks"], long["terminal_tick"], long["minimum_observed_seconds_after_both_GO"], long["timeout_seconds"]), (108000, 108600, 1800, 2400))
        self.assertIn("--project-overlay", long["steps"][0]["argv"])
        self.assertIn("--project-overlay", plan.build_plan(config(), root, "/python")["steps"][0]["argv"])
        with self.assertRaises(ValueError):
            plan.build_plan(config(overlay_sha256=None), root, "/python")
        with self.assertRaises(ValueError):
            plan.build_plan(config(case="long", ticks=108000), root, "/python")
        for case, milliseconds in [("pause300", 300), ("pause3000", 3000)]:
            value = plan.build_plan(config(case=case, overlay_sha256="b" * 64), root, "/python")
            self.assertEqual(value["pause_ms"], milliseconds)
            self.assertIn("--project-overlay", value["steps"][0]["argv"])
            self.assertEqual(value["terminal_tick"], 1200)
        with self.assertRaises(ValueError):
            plan.build_plan(config(case="pause3000", ticks=300, overlay_sha256="b" * 64), root, "/python")
        with self.assertRaises(ValueError):
            plan.build_plan(config(target="linux-x86_64"), root, "/python")

    def test_strict_parser_keeps_real_numbers_and_rejects_invalid_rows(self):
        row = intake.parse(b'SAMPLE_STATUS {"n":9007199254740993,"fraction":1.25,"null":null}\n')
        self.assertIs(type(row["n"]), int)
        self.assertEqual(row["n"], 9007199254740993)
        self.assertIs(type(row["fraction"]), float)
        self.assertIsNone(row["null"])
        for raw in [b'SAMPLE_STATUS {"n":1,"n":2}', b'SAMPLE_STATUS {"n":NaN}',
                    b'SAMPLE_STATUS {"event":"SAMPLE_RESULT"}', b'SCRIPT ERROR: fixture failed']:
            with self.assertRaises(ValueError):
                intake.parse(raw)

    def test_disk_event_intake_consumes_bounded_batches_without_process(self):
        with tempfile.TemporaryDirectory() as temporary:
            actor = intake.Actor.__new__(intake.Actor)
            actor.db_path = Path(temporary) / "events.sqlite"
            actor.cursor = actor.consumed = 0
            actor.error = None
            with sqlite3.connect(actor.db_path) as db:
                db.execute("create table events(seq integer primary key,body text,observed real)")
                db.executemany("insert into events values(?,?,?)", [(i, json.dumps(dict(event="SAMPLE_STATUS", n=i)), float(i)) for i in range(1, 181)])
            observed = []
            actor.consume(lambda _actor, row, _at: observed.append(row["n"]))
            self.assertEqual(observed, list(range(1, 65)))
            actor.consume(lambda _actor, row, _at: observed.append(row["n"]))
            actor.consume(lambda _actor, row, _at: observed.append(row["n"]))
            self.assertEqual(observed, list(range(1, 181)))
            self.assertEqual(actor.consumed, 180)

    def test_status_cap_and_cache_frames_are_observed_not_invented(self):
        value = evidence.Aggregate("client")
        value.status(status(), 1.0)
        value.status(status(frames=101), 2.0)
        self.assertEqual(value.memory_count, 1)
        self.assertEqual(value.meter_count, 1)
        self.assertEqual(value.peak_meter_bytes, 8192)
        self.assertEqual(value.first_go, 1.0)
        self.assertEqual(value.last_live_at, 2.0)
        value.status(status(native_observed=False, meter_observed=False, native_sampled_frame=None, meter_sampled_frame=None, admitted_bytes=None), 3.0)
        self.assertEqual(value.memory_count, 1)
        self.assertEqual(value.memory_unavailable, 1)
        with self.assertRaises(ValueError):
            value.status(status(admitted_bytes=evidence.LIMIT + 1), 4.0)
        with self.assertRaises(ValueError):
            value.status(status(native_sampled_frame=101), 4.0)
        with self.assertRaises(ValueError):
            value.status(status(head=True), 4.0)

    def test_real_ack_rows_only_and_terminal_role_identity(self):
        value = evidence.Aggregate("host")
        value.receive(dict(event="SAMPLE_TAIL", stage="final_accepted", signature_match=False), 1)
        self.assertIsNone(value.ack)
        replay = dict(event="SAMPLE_TAIL", stage="final_accepted", signature_match=True, tick=120)
        value.receive(replay, 2)
        self.assertEqual(value.ack, replay)
        kit = dict(event="SAMPLE_ACK", scope="verified_terminal_signature_ack", matched=True, tick=120)
        value.receive(kit, 3)
        self.assertEqual(value.ack, kit)
        value.status(status(role="host"), 4)
        value.receive(dict(event="SAMPLE_READY", framework="kit", role="host", native_images=1), 5)
        result = dict(event="SAMPLE_RESULT", framework="kit", role="host", ok=True, errors=[], target=120, confirmed=120,
                      cleanup=dict(native=0, wrapper=0, meter=0, owners=0, owners_before=4, owners_after=4, owners_observed=True))
        value.receive(result, 6)
        self.assertEqual(value.terminal("kit", 120)["result"], result)
        value.result = dict(result, role="client")
        with self.assertRaises(ValueError):
            value.terminal("kit", 120)

    def test_failed_result_propagates_immediately_and_retains_actual_row(self):
        failed = dict(event="SAMPLE_RESULT", framework="Replay", role="client", ok=False,
                      target=1200, head=274, confirmed=268, final_tick=0,
                      errors=["accepted.input_history unavailable"],
                      cleanup=dict(native=0, wrapper=0, meter=0, owners=0))
        for row in [failed, dict(event="SAMPLE_ERROR", error="actual error"),
                    dict(event="SAMPLE_FAILURE", error="actual failure")]:
            with self.subTest(event=row["event"]):
                value = evidence.Aggregate("client")
                subsequent = []
                with self.assertRaises(ValueError):
                    value.receive(row, 42.5)
                    subsequent.append("continued after known failure")
                self.assertEqual(subsequent, [])
                self.assertEqual(value.failure, dict(row=row, observed=42.5))
                if row["event"] == "SAMPLE_RESULT":
                    self.assertIs(value.result, failed)
                    self.assertEqual(value.result_count, 1)

    def test_unexpected_sigkill_is_immediate_but_ordinary_exit_waits_for_drain(self):
        process = Mock()
        process.poll.return_value = -9
        actor = SimpleNamespace(role="client", pid=12230, process=process,
                                eof=False, seen=1, consumed=0)
        aggregate = evidence.Aggregate("client")
        failure = controller.process_exit_failure(actor, aggregate)
        self.assertEqual((failure["role"], failure["pid"], failure["actual_exit"], failure["signal_number"]), ("client", 12230, -9, 9))
        self.assertEqual(failure["kind"], "signal_exit")
        self.assertFalse(failure["stdout_EOF_at_detection"])
        self.assertIsNone(aggregate.result)
        process.poll.return_value = 0
        self.assertIsNone(controller.process_exit_failure(actor, aggregate))
        actor.eof = True
        self.assertIsNone(controller.process_exit_failure(actor, aggregate))
        actor.consumed = actor.seen
        self.assertEqual(controller.process_exit_failure(actor, aggregate)["kind"], "ordinary_exit_missing_RESULT")
        aggregate.result_count = 1
        self.assertIsNone(controller.process_exit_failure(actor, aggregate))
        process.poll.return_value = 1
        self.assertEqual(controller.process_exit_failure(actor, aggregate)["kind"], "ordinary_nonzero_exit")

    def test_actor_finish_classifies_actual_signal_and_ordinary_nonzero_exits(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            for name in ["godot.log", "events.sqlite", "actor.json"]:
                (folder / name).write_bytes(b"")
            actor = intake.Actor.__new__(intake.Actor)
            actor.folder, actor.db_path = folder, folder / "events.sqlite"
            actor.role, actor.pid = "client", 12230
            actor.error = None
            actor.eof = True
            actor.seen = actor.consumed = actor.bytes_seen = 0
            actor.process, actor.thread = Mock(), Mock()
            actor.thread.is_alive.return_value = False
            for code, forced, natural in [(-9, False, False), (-15, False, False),
                                          (0, False, True), (1, False, True),
                                          (0, True, False), (-9, True, False)]:
                with self.subTest(code=code, forced=forced):
                    actor.process.wait.return_value = code
                    actor.forced = forced
                    fact = actor.finish()
                    self.assertIs(fact["natural"], natural)
                    self.assertEqual(fact["actual_exit"], code)
                    self.assertEqual(fact["signal_number"], -code if code < 0 else None)
                    self.assertEqual((fact["role"], fact["pid"]), ("client", 12230))
                    self.assertTrue(fact["intake_drained"])

    def test_replay_remote_controls_use_committed_two_seat_counts_not_origins(self):
        inputs = dict(controls_by_seat=[1200, 1200], nonzero_by_seat=[100, 200], nonzero=300,
                      origin_coverage_complete=False, origin_observed=10, origin_unavailable=2390,
                      sample=0, held=0, local=10, neutral=0)
        controller.require_authority_inputs("replay", inputs)
        for counts in [None, [], [1], [1, 0], [0, 1], [True, 2], [2, "1"], [-1, 2]]:
            with self.subTest(nonzero_by_seat=counts):
                with self.assertRaises(ValueError):
                    controller.require_authority_inputs("replay", dict(inputs, nonzero_by_seat=counts, sample=100, nonzero=1000, local=0))
        # Kit retains its existing two-seat criterion.
        controller.require_authority_inputs("kit", dict(nonzero_by_seat=[1, 1]))

    def test_terminal_workload_after_last_status_cadence_and_invalid_terminal(self):
        aggregates, rows = {}, {}
        for role, last_confirmed in [("host", 108), ("client", 111)]:
            value = evidence.Aggregate(role)
            value.status(status(role=role, head=last_confirmed, confirmed=last_confirmed), 1.0)
            value.receive(dict(event="SAMPLE_READY", framework="kit", role=role, native_images=1), 2.0)
            result = dict(event="SAMPLE_RESULT", framework="kit", role=role, ok=True, errors=[], target=120, confirmed=120,
                          cleanup=dict(native=0, wrapper=0, meter=0, owners=0, owners_before=4, owners_after=4, owners_observed=True))
            value.receive(result, 3.0)
            aggregates[role] = value
            rows[role] = dict(terminal=value.terminal("kit", 120), manifest=dict(tick=120))
            self.assertLess(value.max_confirmed, 120)
        controller.require_workload(aggregates, rows, 120)
        # Workload progress never extends the live-STATUS duration observation.
        self.assertEqual(aggregates["host"].last_live_at, 1.0)
        self.assertEqual(aggregates["client"].last_live_at, 1.0)
        for confirmed in [119, None, True, 120.0, "120"]:
            with self.subTest(confirmed=confirmed):
                value = aggregates["client"]
                value.result = dict(rows["client"]["terminal"]["result"], confirmed=confirmed)
                with self.assertRaises(ValueError):
                    value.terminal("kit", 120)
        rows["client"]["manifest"]["tick"] = 119
        with self.assertRaises(ValueError):
            controller.require_workload(aggregates, rows, 120)

    def test_zero_duration_preserves_nonoverlap_and_positive_minimum_still_fails(self):
        aggregates = {role: evidence.Aggregate(role) for role in ["host", "client"]}
        for at in [2324984.081279375, 2324984.081975083, 2324984.084083625]:
            aggregates["host"].status(status(role="host"), at)
        for at in [2324984.133970583, 2324984.134303875, 2324984.134608708]:
            aggregates["client"].status(status(), at)
        observation = controller.live_status_duration(aggregates)
        self.assertFalse(observation["available"])
        self.assertEqual(observation["signed_interval_seconds"], -0.04988695774227381)
        controller.require_duration(observation, 0)
        for minimum in [0.01, 1800]:
            with self.assertRaises(ValueError):
                controller.require_duration(observation, minimum)
        aggregates["host"].last_live_at = aggregates["client"].last_live_at = 2324984.133970583 + 1799
        short = controller.live_status_duration(aggregates)
        self.assertTrue(short["available"])
        with self.assertRaises(ValueError):
            controller.require_duration(short, 1800)
        aggregates["host"].last_live_at = aggregates["client"].last_live_at = 2324984.133970583 + 1800
        controller.require_duration(controller.live_status_duration(aggregates), 1800)

    def test_frozen_public_boundary_and_observed_gap(self):
        raw = status()
        marker = dict(pid=991, role="client", head=90, confirmed=85, status_json=json.dumps(raw))
        self.assertEqual(evidence.frozen_marker(marker, 991), raw)
        with self.assertRaises(ValueError):
            evidence.frozen_marker(marker, 992)
        with self.assertRaises(ValueError):
            evidence.frozen_marker(dict(marker, head=91), 991)
        self.assertEqual(evidence.gap_proof(marker, dict(head=99), 300), 9)
        self.assertEqual(evidence.gap_proof(marker, dict(head=219), 3000), 129)
        for pause, host in [(300, 98), (3000, 218)]:
            with self.assertRaises(ValueError):
                evidence.gap_proof(marker, dict(head=host), pause)

    def test_recovery_is_validated_scope_change_never_head_jump(self):
        before = status()
        # A head jump cannot become a recovery. Catchup is established separately
        # by the controller's final confirmed five-part bytes and actual controls.
        self.assertEqual(controller.scope_outcome(before, dict(before, head=1000), 3000), "same_validated_scope")
        self.assertEqual(controller.scope_outcome(before, before, 300), "same_validated_scope")
        after = dict(before, recoveries=1, recovery_serial=4, baseline=300)
        self.assertEqual(controller.scope_outcome(before, after, 3000), "validated_canonical_recovery")
        self.assertEqual(controller.scope_outcome(before, dict(after, recovery_available=False), 3000), "UNAVAILABLE")

    def test_overlay_is_exact_derived_project_binding_and_detects_change(self):
        source = HERE / "pause_overlay"
        description = overlay.describe(source)
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            original = '; preserved\n[application]\nconfig/name="fixture"\n[autoload]\nExisting="*res://existing.gd"\n'
            settings = project / "project.godot"
            settings.write_text(original)
            bound = overlay.apply(project, source, description["sha256"])
            self.assertTrue(overlay.verify(bound))
            restored = settings.read_text().replace('\nBox3DProductionPause="*res://production_pause.gd"\n', "", 1).replace('\nrun/flush_stdout_on_print=true', "", 1)
            self.assertEqual(restored, original)
            self.assertEqual((project / "production_pause.gd").read_bytes(), (source / "production_pause.gd").read_bytes())
            with self.assertRaises(ValueError):
                overlay.apply(project, source, description["sha256"])
            settings.write_text(settings.read_text() + "\n; mutation\n")
            self.assertFalse(overlay.verify(bound))

    def test_flush_setting_before_after_hash_and_explicit_false(self):
        source = HERE / "pause_overlay"
        description = overlay.describe(source)
        with tempfile.TemporaryDirectory() as temporary:
            project = Path(temporary)
            original = '[application]\nconfig/name="fixture"\nrun/flush_stdout_on_print=false ; retained\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n'
            settings = project / "project.godot"
            settings.write_text(original)
            before_sha = overlay.sha(settings)
            record = overlay.apply(project, source, description["sha256"])
            self.assertEqual(record["settings_changes"], [dict(key="application/run/flush_stdout_on_print", before_present=True, before_value=False, after_value=True)])
            self.assertEqual(record["project_settings_before_sha256"], before_sha)
            self.assertEqual(record["project_settings_after_sha256"], overlay.sha(settings))
            self.assertNotEqual(record["project_settings_before_sha256"], record["project_settings_after_sha256"])
            self.assertIn('run/flush_stdout_on_print=true ; retained\n', settings.read_text())
            self.assertTrue(overlay.verify(record))
            settings.write_text(settings.read_text().replace('run/flush_stdout_on_print=true', 'run/flush_stdout_on_print=false'))
            self.assertFalse(overlay.verify(record))

    def test_actual_module_copy_pid_and_bytes_are_bound(self):
        source = "Contents/Frameworks/libodinscripts_demo.dylib"
        before = {source: "a" * 64}
        copy_name = source + ".r1.p991.dylib"
        valid = dict(before, **{copy_name: "a" * 64})
        self.assertTrue(controller.module_fence(before, valid, {991})[0])
        self.assertFalse(controller.module_fence(before, valid, {992})[0])
        self.assertFalse(controller.module_fence(before, dict(before, **{copy_name: "b" * 64}), {991})[0])

    def test_all_owned_python_and_export_seams_parse_without_execution(self):
        root = HERE.parents[2]
        paths = list(HERE.glob("*.py")) + [root / "tests/box3d_gate_c/macos/export.py", root / "tests/box3d_gate_c/linux/pipeline.py"]
        for path in paths:
            with self.subTest(path=path):
                ast.parse(path.read_text(), filename=str(path))


if __name__ == "__main__":
    unittest.main()
