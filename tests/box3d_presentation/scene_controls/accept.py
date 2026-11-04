#!/usr/bin/env python3
"""Bounded scene-config acceptance, reusing Root's actual Godot/ENet pair gate.

Default mode writes a plan only. Each execute invocation runs one framework and
one selected phase; no physics/protocol/controller implementation lives here.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tests/box3d_slices/harness"))
from runner import Run, BAD_LOG, inventory
from evidence import EvidenceError, require, strict_json, json_bytes

VARIABLES = ("B3_LATENCY", "B3_JITTER", "B3_LOSS", "B3_DUPLICATE", "B3_REORDER")
DEFAULT = dict(zip(VARIABLES, ("0", "0", "0", "0", "0")))
LATENCY = dict(zip(VARIABLES, ("10", "1", "0", "0", "0")))
REQUEST_KEYS = {"kit": "requested", "replay": "request"}
CHANNELS = {
    "kit": {"scope": "local_receive", "reliable": "ordered_loss_adds_delay",
            "unreliable": "modeled_stream_loss_jitter", "reorder_disable_supported": False},
    "replay": {"scope": "local_receive", "reliable": "ordered_no_modeled_loss_or_dup",
               "unreliable": "modeled_loss_dup_jitter", "reorder_disable_supported": False},
}
COMMON_REJECTIONS = (
    ("invalid-decimal", "B3_LATENCY", "1.5", "Invalid"),
    ("negative", "B3_JITTER", "-1", "Invalid"),
    ("integer-overflow", "B3_LATENCY", "18446744073709551616", "Invalid"),
    ("latency-bound", "B3_LATENCY", "10001", "Invalid"),
    ("jitter-bound", "B3_JITTER", "10001", "Invalid"),
    ("loss-bound", "B3_LOSS", "101", "Invalid"),
    ("duplicate-bound", "B3_DUPLICATE", "101", "Invalid"),
    ("reorder-bound", "B3_REORDER", "2", "Invalid"),
)


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rejection_cases(framework):
    cases = [dict(name=name, environment=dict(DEFAULT, **{key: value}), status=status)
             for name, key, value, status in COMMON_REJECTIONS]
    if framework == "kit":
        cases += [dict(name="unsupported-duplicate", environment=dict(DEFAULT, B3_DUPLICATE="1"), status="Unsupported"),
                  dict(name="unsupported-reorder", environment=dict(DEFAULT, B3_JITTER="1", B3_REORDER="1"), status="Unsupported"),
                  dict(name="unsupported-loss96", environment=dict(DEFAULT, B3_LOSS="96"), status="Unsupported")]
    else:
        cases += [dict(name="unsupported-reorder-without-jitter", environment=dict(DEFAULT, B3_REORDER="1"), status="Unsupported")]
    return cases


def exact_fields(actual, expected, description):
    require(isinstance(actual, dict), (description, "missing object"))
    for key, value in expected.items():
        require(key in actual and type(actual[key]) is type(value) and actual[key] == value,
                (description, key, "expected", value, "actual", actual.get(key)))


def verify_ready(ready, framework, environment):
    """Requested env alone is insufficient: require actual effective READY data."""
    values = [int(environment.get(name, "0")) for name in VARIABLES]
    latency, jitter, loss, duplicate, reorder = values
    block = ready.get("impairment")
    require(isinstance(block, dict), "READY lacks consumed impairment settings")
    exact_fields(block.get(REQUEST_KEYS[framework]), dict(latency_ms=latency, jitter_ms=jitter,
        loss_percent=loss, duplicate_percent=duplicate, reorder=bool(reorder)), "READY request")
    if framework == "kit":
        exact_fields(block.get("effective"), {"applied": True}, "Kit actual application")
    exact_fields(block.get("effective"), dict(latency_ms=latency, jitter_ms=jitter,
        loss_permyriad=loss * 100, duplicate_permyriad=duplicate * 100,
        delay_active=any((latency, jitter, loss, duplicate)),
        unreliable_may_reorder=jitter != 0), "READY effective")
    exact_fields(block.get("channel"), CHANNELS[framework], "READY channel scope")
    return block


def records_from_log(log):
    text = log.read_text(errors="strict")
    require(len(text.encode()) <= 2 * 1024 * 1024, "preopen log bound exceeded")
    require(not any(marker in text for marker in BAD_LOG), "unexpected Godot/Core error in rejection")
    result = []
    for line in text.splitlines():
        if line.startswith("{"):
            value = strict_json(line)
            require(isinstance(value.get("event"), str), "JSON diagnostic lacks event")
            result.append((value["event"].upper(), value))
        elif line.startswith("BOX3D_SLICE_"):
            prefix, separator, body = line.partition(" ")
            require(separator and body.startswith("{"), "preopen diagnostic must be structured JSON")
            result.append((prefix[len("BOX3D_SLICE_"):], strict_json(body)))
    return result


def verify_rejection(log, code, expected_status, timed_out=False):
    require(not timed_out and code is not None and code > 0, "rejection must exit naturally nonzero")
    records = records_from_log(log)
    require(not any(kind in ("READY", "GO", "FRAME", "INPUT", "ISSUED", "FX") for kind, _ in records),
            "configuration rejected after gameplay publication")
    require(not any(kind == "BOOT" and item.get("opened") is True for kind, item in records),
            "configuration rejected after transport open")
    errors = [item for kind, item in records if kind == "ERROR"]
    require(len(errors) == 1, "expected exactly one explicit preopen rejection")
    exact_fields(errors[0], dict(where="impairment_preflight", status=expected_status,
        before_transport=True, before_physics=True), "preopen error")
    results = [item for kind, item in records if kind == "RESULT"]
    require(len(results) == 1, "rejection lacks one actual cleanup result")
    outcome = results[0]
    require(outcome.get("ok") is False, "rejection must not report a success")
    for field in ("engine_live", "wrapper_live", "meter_live"):
        require(type(outcome.get(field)) is int and outcome[field] == 0, ("rejection resource not zero", field))
    for field in ("owners_live", "managed_callbacks_live", "cleanup_errors", "callback_status"):
        if field in outcome:
            require(type(outcome[field]) is int and outcome[field] == 0, ("rejection cleanup", field))
    if "errors" in outcome:
        require(type(outcome["errors"]) is int and outcome["errors"] == 1, "expected one configuration error, not cleanup failures")
    if "native_stats_ok" in outcome:
        require(outcome["native_stats_ok"] is True, "invalid native resource query")
    if "cleanup" in outcome:
        require(outcome["cleanup"] in ("None", "Ok", "OK"), "cleanup itself rejected")
    return dict(error=errors[0], cleanup=outcome)


def tree_manifest(project):
    result = {}
    for path in sorted(project.rglob("*")):
        if not path.is_file() or any(part in (".godot", "__pycache__") for part in path.parts):
            continue
        # Core-owned per-process load copies are not authored/build inputs.
        if ".r" in path.name and ".p" in path.name and path.suffix in (".dylib", ".so"):
            continue
        result[str(path.relative_to(project))] = sha(path)
    return result



class FrozenRun(Run):
    """Reuse an explicit authored/imported binary set; keep Root's pair loop."""
    def __init__(self, options, framework, frozen_project):
        super().__init__(options, ROOT, framework)
        self.frozen_project = frozen_project.resolve()
        self.frozen_before = tree_manifest(self.frozen_project)
        self.report["build_policy"] = "Supplied frozen author build; compilation/import deliberately not executed. No optimization/performance inference."
        self.report["frozen_project"] = str(self.frozen_project)
        self.report["frozen_inputs"] = self.frozen_before

    def command(self, name, command, timeout=240):
        if name == "build":
            require((self.frozen_project / ".godot/extension_list.cfg").is_file(), "frozen imported extension metadata absent")
            shutil.rmtree(self.project)  # Only this Run's freshly copied authored tree.
            shutil.copytree(self.frozen_project, self.project,
                ignore=shutil.ignore_patterns("*.r*.p*.dylib", "*.r*.p*.so", "__pycache__"))
            require(tree_manifest(self.project) == self.frozen_before, "copied frozen build differs")
        elif name not in ("core-release", "prepared-import"):
            return super().command(name, command, timeout)
        self.steps.append(dict(name=name, requested_command=command, executed=False,
            status="REUSED_NOT_EXECUTED", source=str(self.frozen_project),
            reason="Preserve Root-selected frozen author Core/scripts/Native and imported metadata"))
        self.publish()

    def run(self):
        result = super().run()
        unchanged = tree_manifest(self.frozen_project) == self.frozen_before
        result["supplied_frozen_project_unchanged"] = unchanged
        if not unchanged:
            result.update(result="FAIL", error="supplied frozen author inputs changed")
        self.publish()
        return result

def controlled_env():
    env = dict(os.environ)
    for name in list(env):
        if name.startswith("B3_"):
            del env[name]
    return env


def execute_positive(args, output):
    options = SimpleNamespace(out=output, native=args.native.resolve(), godot=args.godot,
        odin=args.odin, framework=args.framework, cohort="pair", end_tick=300,
        configuration="Release", ticks=240, bodies=4, seed=1, timeout=90)
    require(args.project is not None and args.project.is_dir(), "positive requires the selected frozen imported project")
    run = FrozenRun(options, args.framework, args.project)
    for name in list(run.env):
        if name.startswith("B3_"):
            del run.env[name]
    setting = DEFAULT if args.setting == "defaults" else LATENCY
    if args.setting != "defaults":
        run.env.update(setting)
    result = run.run()
    require(result["result"] == "PASS", ("Root actual pair gate failed", result.get("error")))
    observed = {}
    for process in result["processes"]:
        observed[process["role"]] = verify_ready(process["ready"], args.framework, setting)
    require(set(observed) == {"host", "client"}, "actual pair actor set differs")
    return dict(result="PASS", setting=args.setting, requested_environment=setting,
        default_variables_unset=args.setting == "defaults", ready=observed,
        root_report=str(run.out / "result.json"), root_report_sha256=sha(run.out / "result.json"),
        proof="Root actual pair state/action/provenance/FX/teardown gates plus effective READY checks")


def execute_rejections(args, output):
    require(args.project is not None and args.project.is_dir(), "rejections require an existing frozen imported project")
    source = args.project.resolve()
    before = tree_manifest(source)
    sdk_before = inventory(ROOT, ROOT / "examples" / (args.framework + "_box3d"))
    (output / "sources-before.json").write_bytes(json_bytes(sdk_before) + b"\n")
    require(any(name.startswith("bin/libodinscripts.") for name in before), "frozen scripts library absent")
    cases = rejection_cases(args.framework)
    results = []
    for case in cases:
        case_dir = output / case["name"]
        case_dir.mkdir()
        project = case_dir / "project"
        shutil.copytree(source, project, ignore=shutil.ignore_patterns("*.r*.p*.dylib", "*.r*.p*.so", "__pycache__"))
        copied_before = tree_manifest(project)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        suffix = ".dylib" if sys.platform == "darwin" else ".so"
        env = controlled_env()
        env.update(case["environment"])
        env.update(ODIN_GODOT_ROOT=str(ROOT), ODIN_SCRIPTS_DLL=str(project / ("bin/libodinscripts" + suffix)),
            B3_ROLE="host", B3_PORT=str(port), B3_BODIES="4", B3_TICKS="240", B3_SEED="1",
            B3_TOKEN="101", B3_SCRIPTED="1", B3_OUTPUT=str(case_dir))
        command = [args.godot, "--headless", "--max-fps", "60", "--path", str(project)]
        log = case_dir / "godot.log"
        timed_out = False
        with log.open("wb") as stream:
            try:
                value = subprocess.run(command, cwd=project, env=env, stdin=subprocess.DEVNULL,
                    stdout=stream, stderr=subprocess.STDOUT, timeout=20)
                code = value.returncode
            except subprocess.TimeoutExpired:
                code, timed_out = None, True
        item = dict(name=case["name"], environment=case["environment"], expected_status=case["status"],
            command=command, exit=code, timed_out=timed_out, log=str(log), log_sha256=sha(log))
        try:
            item["observed"] = verify_rejection(log, code, case["status"], timed_out)
            require(tree_manifest(project) == copied_before, "rejection changed supplied source/build inputs")
            item["result"] = "PASS"
        except Exception as error:
            item.update(result="FAIL", error=repr(error))
        (case_dir / "result.json").write_bytes(json_bytes(item) + b"\n")
        results.append(item)
        print(json.dumps(dict(case=case["name"], result=item["result"])), flush=True)
        if item["result"] != "PASS":
            break
    sdk_after = inventory(ROOT, ROOT / "examples" / (args.framework + "_box3d"))
    (output / "sources-after.json").write_bytes(json_bytes(sdk_after) + b"\n")
    require(sdk_before == sdk_after, "source set changed during preopen cases")
    require(tree_manifest(source) == before, "original frozen project changed")
    require(len(results) == len(cases) and all(item["result"] == "PASS" for item in results), "rejection acceptance incomplete/failed")
    return dict(result="PASS", cases=results, frozen_project=str(source), frozen_project_inputs=before)


def plan():
    return dict(scope="bounded P4.3 scene configuration, not soak/performance", jobs_started=False,
        positive=[dict(framework=f, phase="positive", setting=s, actors="Host+Client", bodies=4, ticks=240)
                  for f in ("kit", "replay") for s in ("defaults", "latency")],
        latency_environment=LATENCY, default_environment="all five variables unset",
        rejects={f:rejection_cases(f) for f in ("kit", "replay")},
        request_parent_keys=REQUEST_KEYS, channel_metadata=CHANNELS,
        scheduling="Each positive is separately selected; wait author freeze and Root scheduling. Rejections reuse that frozen imported project, no rebuild/controller truth.",
        finish_gate="P4.2 r_03e61e9cd6ce4325 confirmed; P4.3 still requires actual controls evidence and Root review. GateB/4ms remain unmet.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--phase", choices=("plan", "positive", "reject"), default="plan")
    parser.add_argument("--framework", choices=("kit", "replay"))
    parser.add_argument("--setting", choices=("defaults", "latency"), default="latency")
    parser.add_argument("--execute", action="store_true", help="explicitly run selected actual jobs after author freeze/Root scheduling")
    parser.add_argument("--native", type=Path)
    parser.add_argument("--project", type=Path)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--odin", default="odin")
    args = parser.parse_args()
    if args.phase != "plan" and (not args.execute or args.framework is None):
        parser.error("execution requires --execute and one --framework")
    if args.phase == "positive" and (args.native is None or args.project is None):
        parser.error("positive requires --native and --project frozen author inputs")
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    report = dict(plan=plan(), phase=args.phase, framework=args.framework,
        script_sha256=sha(Path(__file__)), status="PLANNED_ONLY", whole_call_4ms="UNMET/separate GateB")
    try:
        if args.phase == "positive":
            report["acceptance"] = execute_positive(args, output)
            report["status"] = "PASS"
        elif args.phase == "reject":
            report["acceptance"] = execute_rejections(args, output)
            report["status"] = "PASS"
    except Exception as error:
        report.update(status="FAIL", error=repr(error))
    (output / "report.json").write_bytes(json_bytes(report) + b"\n")
    print(json.dumps(dict(status=report["status"], report=str(output / "report.json"))))
    return 1 if report["status"] == "FAIL" else 0


if __name__ == "__main__":
    raise SystemExit(main())
