#!/usr/bin/env python3
"""Bounded real Host/Client check for one frozen authored SDK sample project."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import threading
import time
import re

PARTS = ["Solver", "Game", "Side", "Observations", "Occurrences"]


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def project_files(project):
    return {str(p.relative_to(project)): sha(p)
            for p in sorted(project.rglob("*"))
            if p.is_file() and ".godot" not in p.relative_to(project).parts
            and p.suffix in {".odin", ".gd", ".cfg", ".godot", ".gdextension",
                             ".tscn", ".tres", ".dylib", ".so", ".dll", ".json"}}


class Actor:
    def __init__(self, role, argv, environment, folder):
        self.role = role
        self.folder = folder
        self.rows = []
        self.error = None
        self.process = subprocess.Popen(argv, env=environment, cwd=folder,
                                        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                        start_new_session=True)
        (folder / "actor.json").write_text(json.dumps(dict(role=role, pid=self.process.pid,
            owned_pgid=self.process.pid, argv=argv,
            sample_environment={k: v for k, v in environment.items() if k.startswith("BOX3D_SAMPLE_")}),
            indent=2) + "\n")
        self.thread = threading.Thread(target=self.drain, daemon=True)
        self.thread.start()

    def drain(self):
        try:
            with (self.folder / "godot.log").open("xb") as output:
                for line in iter(self.process.stdout.readline, b""):
                    output.write(line)
                    if len(line) > 1024 * 1024:
                        self.error = "stdout line exceeds bounded functional intake"
                        continue
                    text = line.decode("utf-8", errors="replace").strip()
                    if any(x in text for x in ["SCRIPT ERROR", "ERROR:",
                                               "instances were leaked", "resources still in use",
                                               "CLEANUP_FAIL"]):
                        self.error = "strict runtime log error"
                    # Samples emit a literal SAMPLE_* prefix followed by JSON.
                    # Preserve the raw line and derive only its explicit kind.
                    prefix = None
                    payload = text
                    if text.startswith("SAMPLE_") and " " in text:
                        prefix, payload = text.split(" ", 1)
                    try:
                        row = json.loads(payload)
                    except (ValueError, TypeError):
                        continue
                    if isinstance(row, dict) and prefix is not None:
                        if "event" in row and row["event"] != prefix:
                            self.error = "sample prefix/event mismatch"
                            continue
                        row = dict(row, event=prefix)
                    if isinstance(row, dict) and row.get("event", "").startswith("SAMPLE_"):
                        if len(self.rows) >= 10000:
                            self.error = "functional event cap exceeded"
                        else:
                            self.rows.append(row)
                output.flush()
                os.fsync(output.fileno())
        except Exception as exc:
            self.error = repr(exc)

    def kill_owned_group(self):
        try:
            os.killpg(self.process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def final_view(folder, target):
    manifest_path = folder / "final-frame.json"
    data = json.loads(manifest_path.read_text())
    if data.get("epoch", 0) <= 0 or data.get("tick") != target:
        raise RuntimeError("final complete view does not name the actual target")
    if set(data.get("parts", {})) != set(PARTS):
        raise RuntimeError("five complete parts are required")
    payloads, references = {}, {}
    for name in PARTS:
        part = data["parts"][name]
        path = (folder / part["file"]).resolve(strict=True)
        if not path.is_relative_to(folder.resolve()) or not path.is_file():
            raise RuntimeError("part path escapes the owned output")
        payload = path.read_bytes()
        if hashlib.sha256(payload).hexdigest() != part["sha256"]:
            raise RuntimeError("complete part hash mismatch: " + name)
        payloads[name] = payload
        references[name] = {"path": str(path), "sha256": part["sha256"], "bytes": len(payload)}
    return data, payloads, {"manifest": str(manifest_path), "sha256": sha(manifest_path),
                            "parts": references}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--framework", choices=["kit", "replay"], required=True)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--build-record", type=Path, required=True)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--ticks", type=int, default=120)
    parser.add_argument("--timeout", type=float, default=120)
    args = parser.parse_args()
    project = args.project.resolve(strict=True)
    build = args.build_record.resolve(strict=True)
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    controller_source = Path(__file__).resolve()
    controller_before = sha(controller_source)
    (output / "controller.py").write_bytes(controller_source.read_bytes())
    if not 1024 <= args.port <= 65535 or not 30 <= args.ticks <= 3600:
        raise RuntimeError("invalid bounded sample port/target")
    before = project_files(project)
    build_before, godot_before = sha(build), sha(args.godot)
    binding = json.loads(build.read_text())
    if (binding.get("result") != "PASS" or binding.get("framework") != args.framework
            or Path(binding.get("project", "")).resolve() != project
            or binding.get("build_requested") is not True
            or binding.get("actual_build_exit") != 0
            or binding.get("source_fence_unchanged") is not True
            or binding.get("native_fence_unchanged") is not True
            or binding.get("copied_content_byteexact") is not True):
        raise RuntimeError("successful ordinary build is not bound to this framework/project/content")
    for name, expected in binding.get("actual_binaries_sha256", {}).items():
        if sha(project / name) != expected:
            raise RuntimeError("actual SDK binary differs from its build record: " + name)
    (output / "project-before.json").write_text(json.dumps(before, sort_keys=True) + "\n")
    actors = []
    error = None
    cleanup_errors = []
    views = None
    import_step = None
    argv = [args.godot, "--headless", "--path", str(project)]
    try:
        import_argv = [args.godot, "--headless", "--editor", "--path", str(project),
                       "--quit-after", "120"]
        import_env = os.environ.copy()
        extension = "dylib" if os.uname().sysname == "Darwin" else "so"
        import_env["ODIN_SCRIPTS_DLL"] = str(project / "bin" / ("libodinscripts." + extension))
        with (output / "import.log").open("x") as log:
            imported = subprocess.run(import_argv, env=import_env, cwd=output,
                                      stdout=log, stderr=subprocess.STDOUT, timeout=180)
        import_text = (output / "import.log").read_text()
        import_step = dict(argv=import_argv, actual_exit=imported.returncode,
                           log=str(output / "import.log"), sha256=sha(output / "import.log"))
        if imported.returncode or any(x in import_text for x in
                ["SCRIPT ERROR", "ERROR:", "instances were leaked", "resources still in use", "CLEANUP_FAIL"]):
            raise RuntimeError("ordinary sample editor import failed")
        for role in ["host", "client"]:
            folder = output / role
            folder.mkdir()
            env = os.environ.copy()
            env.update(BOX3D_SAMPLE_ROLE=role, BOX3D_SAMPLE_PORT=str(args.port),
                       BOX3D_SAMPLE_TICKS=str(args.ticks), BOX3D_SAMPLE_SCRIPTED="1",
                       BOX3D_SAMPLE_OUTPUT=str(folder))
            extension = "dylib" if os.uname().sysname == "Darwin" else "so"
            env["ODIN_SCRIPTS_DLL"] = str(project / "bin" / ("libodinscripts." + extension))
            actors.append(Actor(role, argv, env, folder))
        deadline = time.monotonic() + args.timeout
        # Both actors start concurrently and use their real Session readiness.
        # This waits for processes, never substitutes a timer for protocol ACKs.
        for actor in actors:
            actor.process.wait(timeout=max(0.01, deadline - time.monotonic()))
            actor.thread.join(timeout=max(0.01, deadline - time.monotonic()))
            if actor.thread.is_alive() or actor.error or actor.process.returncode != 0:
                raise RuntimeError(actor.role + ": " + str(actor.error or actor.process.returncode))
        ready, results = {}, {}
        reported_framework = "Replay" if args.framework == "replay" else "kit"
        for actor in actors:
            ready_rows = [r for r in actor.rows if r.get("event") == "SAMPLE_READY"]
            result_rows = [r for r in actor.rows if r.get("event") == "SAMPLE_RESULT"]
            if len(ready_rows) != 1 or len(result_rows) != 1:
                raise RuntimeError(actor.role + " needs exactly one READY and one RESULT")
            rdy, result = ready_rows[0], result_rows[0]
            if rdy.get("framework") != reported_framework or rdy.get("role") != actor.role or rdy.get("native_images") != 1:
                raise RuntimeError("actual framework/role/Native image binding missing")
            if result.get("framework") != reported_framework or result.get("role") != actor.role or result.get("ok") is not True or result.get("errors") != []:
                raise RuntimeError("sample reported failure or unavailable result")
            if result.get("target") != args.ticks or result.get("confirmed", 0) < args.ticks:
                raise RuntimeError("actual confirmed target not reached")
            cleanup = result.get("cleanup", {})
            if any(cleanup.get(k) != 0 for k in ["native", "wrapper", "meter", "owners"]):
                raise RuntimeError("actual ordered teardown not proven clean")
            if (cleanup.get("owners_observed", cleanup.get("observed")) is not True
                    or not isinstance(cleanup.get("owners_before"), int)
                    or cleanup.get("owners_before") != cleanup.get("owners_after")):
                raise RuntimeError("sample owner delta lacks an actual pre-setup/post-teardown baseline")
            ready[actor.role], results[actor.role] = rdy, result
        if ready["host"].get("content_sha256") != ready["client"].get("content_sha256") or not ready["host"].get("content_sha256"):
            raise RuntimeError("authored content identity differs")
        input_rows = [row for row in actors[0].rows if row.get("event") == "SAMPLE_INPUTS"]
        if len(input_rows) != 1:
            raise RuntimeError("actual authority input evidence is unavailable")
        inputs = input_rows[0]
        if args.framework == "kit":
            counts = inputs.get("nonzero_by_seat", [])
            if len(counts) != 2 or not all(isinstance(v, int) and v > 0 for v in counts):
                raise RuntimeError("Kit authority did not observe nonzero controls from both seats")
        elif inputs.get("sample", 0) <= 0 or inputs.get("nonzero", 0) <= inputs.get("local", 0):
            raise RuntimeError("Replay authority did not observe nonzero remote controls")
        host, hp, href = final_view(output / "host", args.ticks)
        client, cp, cref = final_view(output / "client", args.ticks)
        if host["epoch"] != client["epoch"] or any(hp[p] != cp[p] for p in PARTS):
            raise RuntimeError("actual complete five-part bytes differ")
        if host.get("content_sha256") != ready["host"]["content_sha256"] or client.get("content_sha256") != ready["client"]["content_sha256"]:
            raise RuntimeError("final view content binding differs")
        views = {"host": href, "client": cref, "all_five_byte_equal": True,
                 "ready": ready, "results": results, "authority_inputs": inputs}
    except Exception as exc:
        error = repr(exc)
    finally:
        if error is not None:
            for actor in actors:
                # Also terminate descendants if their leader has already exited.
                try:
                    actor.kill_owned_group()
                except OSError as exc:
                    # Preserve the original failure and report OS cleanup refusal.
                    cleanup_errors.append(dict(role=actor.role, pid=actor.process.pid,
                                               operation="killpg", error=repr(exc)))
        for actor in actors:
            try:
                actor.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                pass
            actor.thread.join(timeout=10)
    after = project_files(project)
    (output / "project-after.json").write_text(json.dumps(after, sort_keys=True) + "\n")
    # Core loads an exact per-process copy of each script module. Keep the
    # actual names/PIDs and verify bytes against its unchanged source binary.
    derived_modules = {}
    prior_modules = {}
    actor_pids = {a.process.pid for a in actors}
    module_pattern = r"(bin/libodinscripts[^/]*\.(dylib|so|dll))\.r([0-9]+)\.p([0-9]+)\.\2"
    for name, value in before.items():
        match = re.fullmatch(module_pattern, name)
        if match and before.get(match[1]) == value:
            prior_modules[name] = dict(source=match[1], pid=int(match[4]), sha256=value)
    for name in after.keys() - before.keys():
        match = re.fullmatch(module_pattern, name)
        if match and int(match[4]) in actor_pids and before.get(match[1]) == after[name]:
            derived_modules[name] = dict(source=match[1], pid=int(match[4]),
                                         sha256=after[name], source_sha256=before[match[1]])
    # The existing Core loader sweeps verified copies from dead prior sessions.
    # They may disappear; base binaries and every other prepared file may not.
    baseline_unchanged = all(after.get(name) == value for name, value in before.items()
                             if name not in prior_modules)
    prior_copies_unchanged_or_removed = all(name not in after or after[name] == row["sha256"]
                                           for name, row in prior_modules.items())
    additions_bound = set(after) - set(before) == set(derived_modules)
    fence = (baseline_unchanged and prior_copies_unchanged_or_removed and additions_bound
             and sha(build) == build_before and sha(args.godot) == godot_before
             and sha(controller_source) == controller_before)
    report = dict(result="PASS" if error is None and fence else "FAIL", error=error,
                  framework=args.framework, target=args.ticks, port=args.port,
                  controller_source=str(output / "controller.py"), controller_sha256=controller_before,
                  argv=argv, build_record=str(build), build_sha256=build_before,
                  import_step=import_step,
                  project_fence=fence, godot_sha256=godot_before, complete_views=views,
                  derived_script_module_copies=derived_modules,
                  prior_verified_script_module_copies=prior_modules,
                  removed_stale_script_module_copies=[name for name in prior_modules if name not in after],
                  module_copy_contract="Existing core/scripts_native.odin cleanup_stale_reload_copies; exact source binary/hash checked, actual PID names retained.",
                  cleanup_errors=cleanup_errors,
                  actors=[dict(role=a.role, pid=a.process.pid, actual_exit=a.process.returncode,
                               intake_drained=not a.thread.is_alive(), intake_error=a.error,
                               log=str(a.folder / "godot.log"), log_sha256=sha(a.folder / "godot.log"),
                               events=a.rows) for a in actors],
                  scope="Bounded authored Host/Client sample; local reference correctness, not a soak/performance/export Gate C claim.")
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"result": report["result"], "report": str(output / "report.json"), "error": error}), flush=True)
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
