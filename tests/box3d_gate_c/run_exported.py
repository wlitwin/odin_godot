#!/usr/bin/env python3
"""Run a bound exported Host/Client pair without the editor/project loader."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import time

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "tests/box3d_samples/run.py"
spec = importlib.util.spec_from_file_location("box3d_sample_controller", HELPER)
sample = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sample)


def inventory(folder):
    return {str(p.relative_to(folder)): sample.sha(p)
            for p in sorted(folder.rglob("*")) if p.is_file()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--ticks", type=int, default=120)
    parser.add_argument("--timeout", type=float, default=180)
    args = parser.parse_args()
    record_path = args.record.resolve(strict=True)
    binding = json.loads(record_path.read_text())
    if (binding.get("result") != "PASS" or binding.get("framework") not in ["kit", "replay"]
            or binding.get("target") not in ["macos-arm64", "linux-x86_64"]
            or binding.get("source_fence_unchanged") is not True):
        raise RuntimeError("export record is not a successful bound target/framework export")
    execution_mode = binding.get("execution_mode", "native" if binding["target"] == "macos-arm64" else None)
    if execution_mode not in ["native", "translated-linux-x86_64"]:
        raise RuntimeError("export record must declare its actual target execution mode")
    if binding["target"] != "linux-x86_64" and execution_mode != "native":
        raise RuntimeError("translated Linux execution mode requires the Linux target")
    bundle = Path(binding["bundle_root"]).resolve(strict=True)
    executable = Path(binding["executable"]).resolve(strict=True)
    if not executable.is_relative_to(bundle) or not executable.is_file():
        raise RuntimeError("exported executable must be inside its bound bundle")
    for name, digest in binding["artifacts"].items():
        path = (bundle / name).resolve(strict=True)
        if not path.is_relative_to(bundle) or sample.sha(path) != digest:
            raise RuntimeError("export artifact changed: " + name)
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    before = inventory(bundle)
    source_hash, helper_hash, record_hash = sample.sha(__file__), sample.sha(HELPER), sample.sha(record_path)
    (output / "run_exported.py").write_bytes(Path(__file__).read_bytes())
    (output / "sample-controller.py").write_bytes(HELPER.read_bytes())
    (output / "bundle-before.json").write_text(json.dumps(before, sort_keys=True) + "\n")
    actors, cleanup_errors = [], []
    error, evidence = None, None
    argv = [str(executable), "--headless"]
    try:
        for role in ["host", "client"]:
            folder = output / role
            folder.mkdir()
            env = os.environ.copy()
            for name in ["ODIN_SCRIPTS_DLL", "ODIN_GODOT_ROOT", "BOX3D_NATIVE_LIBRARY"]:
                env.pop(name, None)
            env.update(BOX3D_SAMPLE_ROLE=role, BOX3D_SAMPLE_PORT=str(args.port),
                       BOX3D_SAMPLE_TICKS=str(args.ticks), BOX3D_SAMPLE_SCRIPTED="1",
                       BOX3D_SAMPLE_OUTPUT=str(folder))
            actors.append(sample.Actor(role, argv, env, folder))
        deadline = time.monotonic() + args.timeout
        for actor in actors:
            actor.process.wait(timeout=max(0.01, deadline - time.monotonic()))
            actor.thread.join(timeout=max(0.01, deadline - time.monotonic()))
            if actor.process.returncode != 0 or actor.thread.is_alive() or actor.error:
                raise RuntimeError(actor.role + ": " + str(actor.error or actor.process.returncode))
        expected_framework = "Replay" if binding["framework"] == "replay" else "kit"
        rows = {}
        for actor in actors:
            ready = [r for r in actor.rows if r.get("event") == "SAMPLE_READY"]
            result = [r for r in actor.rows if r.get("event") == "SAMPLE_RESULT"]
            if len(ready) != 1 or len(result) != 1:
                raise RuntimeError("exported actor lacks exact READY/RESULT")
            ready, result = ready[0], result[0]
            if (ready.get("framework") != expected_framework or ready.get("role") != actor.role
                    or ready.get("native_images") != 1 or result.get("framework") != expected_framework
                    or result.get("role") != actor.role or result.get("ok") is not True
                    or result.get("errors") != [] or result.get("target") != args.ticks
                    or result.get("confirmed", 0) < args.ticks):
                raise RuntimeError("exported actor readiness/confirmed result is not proven")
            cleanup = result.get("cleanup", {})
            if (any(cleanup.get(k) != 0 for k in ["native", "wrapper", "meter", "owners"])
                    or cleanup.get("owners_observed", cleanup.get("observed")) is not True
                    or not isinstance(cleanup.get("owners_before"), int)
                    or cleanup.get("owners_before") != cleanup.get("owners_after")):
                raise RuntimeError("exported sample teardown/baseline is not clean")
            manifest, parts, reference = sample.final_view(actor.folder, args.ticks)
            if manifest.get("content_sha256") != ready.get("content_sha256"):
                raise RuntimeError("exported view/content mismatch")
            rows[actor.role] = dict(ready=ready, result=result, manifest=manifest,
                                    parts=parts, view=reference)
        if (rows["host"]["ready"]["content_sha256"] != rows["client"]["ready"]["content_sha256"]
                or rows["host"]["manifest"]["epoch"] != rows["client"]["manifest"]["epoch"]
                or any(rows["host"]["parts"][p] != rows["client"]["parts"][p] for p in sample.PARTS)):
            raise RuntimeError("exported pair complete five-part bytes differ")
        inputs = [r for r in actors[0].rows if r.get("event") == "SAMPLE_INPUTS"]
        if len(inputs) != 1:
            raise RuntimeError("exported authority inputs unavailable")
        inputs = inputs[0]
        if binding["framework"] == "kit":
            counts = inputs.get("nonzero_by_seat", [])
            if len(counts) != 2 or not all(v > 0 for v in counts):
                raise RuntimeError("exported Kit nonzero seats unavailable")
        elif inputs.get("sample", 0) <= 0 or inputs.get("nonzero", 0) <= inputs.get("local", 0):
            raise RuntimeError("exported Replay nonzero remote controls unavailable")
        evidence = {role: {k: value for k, value in row.items() if k != "parts"}
                    for role, row in rows.items()}
        evidence.update(all_five_byte_equal=True, authority_inputs=inputs)
    except Exception as exc:
        error = repr(exc)
    finally:
        if error is not None:
            for actor in actors:
                try:
                    actor.kill_owned_group()
                except OSError as exc:
                    cleanup_errors.append(dict(role=actor.role, pid=actor.process.pid, error=repr(exc)))
        for actor in actors:
            try:
                actor.process.wait(timeout=10)
            except Exception as exc:
                cleanup_errors.append(dict(role=actor.role, pid=actor.process.pid, error=repr(exc)))
            actor.thread.join(timeout=10)
    after = inventory(bundle)
    (output / "bundle-after.json").write_text(json.dumps(after, sort_keys=True) + "\n")
    pattern = r"((?:.*/)?libodinscripts[^/]*\.(dylib|so|dll))\.r([0-9]+)\.p([0-9]+)\.\2"
    prior, derived = {}, {}
    for name, digest in before.items():
        match = re.fullmatch(pattern, name)
        if match and before.get(match[1]) == digest:
            prior[name] = dict(source=match[1], pid=int(match[4]), sha256=digest)
    for name in after.keys() - before.keys():
        match = re.fullmatch(pattern, name)
        if match and int(match[4]) in {a.process.pid for a in actors} and before.get(match[1]) == after[name]:
            derived[name] = dict(source=match[1], pid=int(match[4]), sha256=after[name])
    fence = (all(after.get(k) == v for k, v in before.items() if k not in prior)
             and all(k not in after or after[k] == v["sha256"] for k, v in prior.items())
             and set(after) - set(before) == set(derived)
             and sample.sha(__file__) == source_hash and sample.sha(HELPER) == helper_hash
             and sample.sha(record_path) == record_hash)
    report = dict(result="PASS" if error is None and not cleanup_errors and fence else "FAIL",
                  error=error, target=binding["target"], framework=binding["framework"],
                  execution_mode=execution_mode,
                  export_record=str(record_path), export_record_sha256=record_hash,
                  executable=str(executable), executable_sha256=sample.sha(executable),
                  argv=argv, ticks=args.ticks, evidence=evidence, bundle_fence=fence,
                  script_module_copies=derived, prior_verified_copies=prior,
                  source_sha256=source_hash, helper_sha256=helper_hash, cleanup_errors=cleanup_errors,
                  actors=[dict(role=a.role, pid=a.process.pid, actual_exit=a.process.returncode,
                               intake_drained=not a.thread.is_alive(), intake_error=a.error,
                               log=str(a.folder / "godot.log"), log_sha256=sample.sha(a.folder / "godot.log"),
                               events=a.rows) for a in actors],
                  scope="Actual exported pair; no editor --path, no scripts/Native environment override. Target execution mode explicitly bound.")
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"result": report["result"], "report": str(output / "report.json"), "error": error}), flush=True)
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
