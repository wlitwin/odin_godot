#!/usr/bin/env python3
"""Run current-source presentation checks; every command must actually succeed."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(root):
    result = {}
    for directory in ("box3d", "kit", "replay", "runtime", "godot", "gdext", "tests/box3d_presentation"):
        for path in sorted((root / directory).rglob("*")):
            if not path.is_file() or any(part in ("bin", ".godot", "__pycache__") for part in path.parts):
                continue
            if path.suffix in (".odin", ".py", ".tscn", ".gd", ".gdextension") or path.name == "project.godot":
                if path.name.endswith(".gen.odin") and "tests" in path.parts:
                    continue
                result[str(path.relative_to(root))] = digest(path)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--library", type=Path)
    parser.add_argument("--odin", default=os.environ.get("ODIN", "odin"))
    parser.add_argument("--wasm", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    before = inventory(root)
    results = []
    commands = [("pure", ["test", "tests/box3d_presentation/pure", "-define:ODIN_TEST_THREADS=1"])]
    if args.library:
        commands.append(("native", ["test", "tests/box3d_presentation/native", "-define:ODIN_TEST_THREADS=1", "-define:BOX3D_LIBRARY=" + str(args.library.resolve())]))
        identity_path = args.library.resolve().parent / "native-domain-identity.txt"
        identity = dict(line.split("=", 1) for line in identity_path.read_text().splitlines()[:2])
        commands.append(("strict", ["test", "tests/box3d_presentation/strict", "-define:ODIN_TEST_THREADS=1", "-define:BOX3D_LIBRARY=" + str(args.library.resolve()), "-define:BOX3D_REQUIRE_DOMAIN=true", "-define:BOX3D_EXPECTED_BUILD=sha256:" + identity["build"], "-define:BOX3D_EXPECTED_TARGET=sha256:" + identity["target"]]))
    if args.wasm:
        commands.append(("wasm", ["build", "tests/box3d_presentation/import", "-target:freestanding_wasm32", "-build-mode:obj", "-no-entry-point"]))
    for name, flags in commands:
        executable = output / (name + (".o" if name == "wasm" else "-tests"))
        command = [args.odin, *flags, *(["-keep-executable"] if flags[0] == "test" else []), "-collection:godot=" + str(root), "-out:" + str(executable)]
        log = output / (name + ".log")
        started = time.monotonic_ns()
        with log.open("wb") as stream:
            done = subprocess.run(command, cwd=root, stdout=stream, stderr=subprocess.STDOUT)
        result = {"name": name, "command": command, "exit": done.returncode, "elapsed_ns": time.monotonic_ns() - started, "log": str(log), "log_sha256": digest(log)}
        if executable.exists():
            result.update(executable=str(executable), executable_sha256=digest(executable))
        if done.returncode == 0 and not executable.exists():
            result["exit"] = -1
            result["artifact_error"] = "Compiler did not retain the requested output"
        results.append(result)
        if result["exit"]:
            break
    after = inventory(root)
    report = {"status": "PASS" if all(item["exit"] == 0 for item in results) and len(results) == len(commands) and before == after else "FAIL", "source_before": before, "source_after": after, "source_fence_equal": before == after, "results": results, "timing_scope": "test wall duration only; no performance acceptance"}
    if args.library:
        report["native_library"] = {"path": str(args.library.resolve()), "sha256": digest(args.library.resolve())}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": report["status"], "report": str(output / "report.json"), "groups": [r["name"] for r in results]}))
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
