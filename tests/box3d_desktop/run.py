#!/usr/bin/env python3
"""One on-target desktop export+pair orchestration; default is a process-free plan."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TARGETS = ("macos-arm64", "linux-x86_64")
MODES = ("native", "translated-linux-x86_64")


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build_plan(config, root=ROOT, python=sys.executable):
    """Pure: no filesystem inspection, process, import hook, download or VM work."""
    target, framework = config["target"], config["framework"]
    if target not in TARGETS or framework not in ("kit", "replay"):
        raise ValueError("unsupported desktop target/framework; Windows is not qualified")
    mode = config.get("execution_mode")
    if target == "macos-arm64":
        mode = mode or "native"
        if mode != "native":
            raise ValueError("macOS target requires native selected execution")
    elif mode not in MODES:
        raise ValueError("Linux requires explicit native or translated-linux-x86_64 mode")
    for name in ("godot", "odin", "native_library", "out"):
        if not Path(config[name]).is_absolute():
            raise ValueError(name + " must be an explicit absolute path")
    output = Path(config["out"])
    if output == root or root in output.parents:
        raise ValueError("generated desktop output must be outside the source repository")
    digest = config["native_sha256"]
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("verified Native SHA256 must be exact lowercase64hex")
    port, ticks = config["port"], config.get("ticks", 120)
    if not 1024 <= port <= 65535 or not 30 <= ticks <= 3600:
        raise ValueError("invalid bounded exported-pair port/target")
    export_out = output / "export"
    if target == "macos-arm64":
        argv = [python, str(root / "tests/box3d_gate_c/macos/export.py"),
                "--framework", framework, "--out", str(export_out), "--godot", config["godot"],
                "--odin", config["odin"], "--native-library", config["native_library"],
                "--native-sha256", digest, "--execute"]
    else:
        toolchain = config.get("toolchain_report")
        if not toolchain or not Path(toolchain).is_absolute():
            raise ValueError("Linux requires an explicit absolute --toolchain-report")
        argv = [python, str(root / "tests/box3d_gate_c/linux/pipeline.py"), "export",
                "--repo-input", str(root), "--work", str(output / "linux-work"),
                "--out", str(export_out), "--framework", framework,
                "--native-library", config["native_library"], "--toolchain-report", toolchain,
                "--execution-mode", mode]
    record = export_out / "export-record.json"
    runtime = [python, str(root / "tests/box3d_gate_c/run_exported.py"),
               "--record", str(record), "--out", str(output / "runtime"),
               "--port", str(port), "--ticks", str(ticks),
               "--timeout", str(config.get("runtime_timeout", 180))]
    return {"schema": 1, "result": "STAGED_ONLY", "target": target,
            "framework": framework, "execution_mode": mode, "out": str(output),
            "inputs": {k: config[k] for k in ("godot", "odin", "native_library", "native_sha256")},
            "toolchain_report": config.get("toolchain_report"),
            "steps": [{"name": "normal_export", "argv": argv, "record": str(record)},
                      {"name": "exported_pair", "argv": runtime,
                       "record": str(output / "runtime/report.json")}],
            "environment": {"ODIN": config["odin"], "GODOT": config["godot"]},
            "processes_started": 0,
            "scope": "Declared functional desktop case; no remote CI, performance, Windows or cross-target deterministic equality claim."}


def validate_linux_preflight(report, mode, tool_hashes):
    """Pure binding check; never promote a translated report to native proof."""
    if report.get("result") != "PASS":
        raise ValueError("Linux requires an actual passing toolchain preflight")
    if mode == "native":
        kernel = report.get("kernel_uname", [])
        if (report.get("execution_mode") != "native" or report.get("native_x86_hardware") is not True
                or len(kernel) < 5 or kernel[0] != "Linux" or kernel[4] not in ("x86_64", "amd64")):
            raise ValueError("native Linux needs explicit native-x86 preflight; translated evidence is not native proof")
    elif mode == "translated-linux-x86_64":
        execution = str(report.get("execution", "")).lower()
        if (report.get("native_x86_hardware") is not False
                or not (report.get("execution_mode") == mode or "translated" in execution or "rosetta" in execution)):
            raise ValueError("translated Linux needs an explicit translated preflight")
    else:
        raise ValueError("invalid Linux mode")
    for name in ("odin", "godot"):
        recorded = report.get("elf", {}).get(name, {})
        if (recorded.get("sha256") != tool_hashes[name] or recorded.get("machine") != 62
                or recorded.get("class") != 64 or recorded.get("endian") != "little"):
            raise ValueError("actual toolchain input differs from its preflight: " + name)


def save(path, data):
    with path.open("x") as stream:
        json.dump(data, stream, indent=2)
        stream.write("\n")


def execution_inputs(plan):
    inputs = plan["inputs"]
    hashes = {}
    for name in ("godot", "odin", "native_library"):
        path = Path(inputs[name])
        if not path.is_file() or (name != "native_library" and not os.access(path, os.X_OK)):
            raise ValueError("explicit executable/Native input unavailable: " + name)
        hashes[name] = sha(path)
    if hashes["native_library"] != inputs["native_sha256"]:
        raise ValueError("actual Native library SHA differs before any export")
    if plan["target"] == "macos-arm64":
        if platform.system() != "Darwin" or platform.machine().lower() not in ("arm64", "aarch64"):
            raise ValueError("Mac desktop execution requires the actual macOS arm64 host")
    else:
        if platform.system() != "Linux":
            raise ValueError("Linux execution must run inside its selected target userspace, not a Mac VM launcher")
        if plan["execution_mode"] == "native" and platform.machine().lower() not in ("x86_64", "amd64"):
            raise ValueError("native Linux preflight does not match the actual current kernel architecture")
        report_path = Path(plan["toolchain_report"])
        preflight = json.loads(report_path.read_text())
        validate_linux_preflight(preflight, plan["execution_mode"], hashes)
        hashes["toolchain_report"] = sha(report_path)
    return hashes


def helper_sources():
    names = ("tests/box3d_desktop/run.py", "tests/box3d_gate_c/macos/export.py",
             "tests/box3d_gate_c/linux/pipeline.py", "tests/box3d_gate_c/linux/toolchain.py",
             "tests/box3d_gate_c/run_exported.py", "tests/box3d_samples/run.py")
    return {name: sha(ROOT / name) for name in names}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=TARGETS, required=True)
    parser.add_argument("--framework", choices=("kit", "replay"), required=True)
    parser.add_argument("--execution-mode", choices=MODES)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--odin", required=True)
    parser.add_argument("--native-library", required=True)
    parser.add_argument("--native-sha256", required=True)
    parser.add_argument("--toolchain-report")
    parser.add_argument("--out", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--ticks", type=int, default=120)
    parser.add_argument("--runtime-timeout", type=float, default=180)
    parser.add_argument("--export-timeout", type=float, default=7200)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args(argv)
    plan = build_plan(vars(args))
    output = Path(plan["out"])
    output.mkdir(parents=True, exist_ok=False)
    save(output / "plan.json", plan)
    if not args.execute:
        print(json.dumps({"result": "STAGED_ONLY", "plan": str(output / "plan.json"), "processes_started": 0}))
        return 0
    report = {**plan, "result": "FAIL", "error": None, "commands": [],
              "remote_ci_executed": False, "input_fence_unchanged": False, "helper_fence_unchanged": False}
    sources = helper_sources()
    hashes = None
    try:
        hashes = execution_inputs(plan)
        report["preflight"] = {"input_sha256": hashes, "host_system": platform.system(),
                               "host_machine": platform.machine(), "mode": plan["execution_mode"],
                               "scope": "Explicit installed/verified inputs; normal exporter performs its actual tool/version/Native profile checks."}
        environment = os.environ.copy()
        environment.update(plan["environment"])
        # These are parameters to the normal exporter, not runtime overrides.
        for key in list(environment):
            if key.startswith("BOX3D_SAMPLE_") or key == "ODIN_SCRIPTS_DLL":
                del environment[key]
        for step in plan["steps"]:
            row = {"name": step["name"], "argv": step["argv"], "log": str(output / (step["name"] + ".log"))}
            report["commands"].append(row)
            report["processes_started"] += 1
            with Path(row["log"]).open("xb") as log:
                completed = subprocess.run(step["argv"], cwd=ROOT, env=environment,
                                           stdout=log, stderr=subprocess.STDOUT,
                                           timeout=args.export_timeout if step["name"] == "normal_export" else args.runtime_timeout + 60)
                row["actual_exit"] = completed.returncode
                log.flush()
                os.fsync(log.fileno())
            row["log_sha256"] = sha(row["log"])
            if completed.returncode != 0:
                raise RuntimeError(step["name"] + " failed; original helper outputs remain preserved")
            path = Path(step["record"])
            actual = json.loads(path.read_text())
            row["record"] = {"path": str(path), "sha256": sha(path)}
            if (actual.get("result") != "PASS" or actual.get("target") != plan["target"]
                    or actual.get("framework") != plan["framework"]):
                raise RuntimeError("helper did not establish this exact target/framework case")
            actual_mode = actual.get("execution_mode", "native" if plan["target"] == "macos-arm64" else None)
            if actual_mode != plan["execution_mode"]:
                raise RuntimeError("helper target execution mode differs from its predeclaration")
            fence = "source_fence_unchanged" if step["name"] == "normal_export" else "bundle_fence"
            if actual.get(fence) is not True:
                raise RuntimeError("unchanged helper fence did not pass: " + fence)
        report["result"] = "PASS"
    except Exception as exc:
        report["error"] = repr(exc)
    finally:
        report["helper_sources_before"] = sources
        try:
            report["helper_fence_unchanged"] = helper_sources() == sources
            if hashes is not None:
                current = {name: sha(plan["inputs"][name]) for name in ("godot", "odin", "native_library")}
                if "toolchain_report" in hashes:
                    current["toolchain_report"] = sha(plan["toolchain_report"])
                report["input_fence_unchanged"] = hashes == current
        except OSError as exc:
            report["fence_error"] = repr(exc)
            report["helper_fence_unchanged"] = False
            report["input_fence_unchanged"] = False
        if not report["helper_fence_unchanged"] or not report["input_fence_unchanged"]:
            report["result"] = "FAIL"
        save(output / "report.json", report)
    print(json.dumps({"result": report["result"], "report": str(output / "report.json"), "error": report["error"]}))
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
