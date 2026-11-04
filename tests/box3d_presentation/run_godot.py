#!/usr/bin/env python3
"""Build and exercise value-only presentation in an owned Godot project copy."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from run import digest, inventory


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--godot", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    project = output / "project"
    before = inventory(root)
    shutil.copytree(root / "tests/box3d_presentation/project", project, ignore=shutil.ignore_patterns("bin", ".godot", "*.gen.odin"))
    env = os.environ.copy()
    for name in ("BOX3D_NATIVE_LIBRARY", "SCRIPT_BUILD_FLAGS", "CORE_BUILD_FLAGS"):
        env.pop(name, None)
    env["ODIN_GODOT_ROOT"] = str(root)
    suffix = ".dylib" if sys.platform == "darwin" else ".so"
    env["ODIN_SCRIPTS_DLL"] = str(project / ("bin/libodinscripts" + suffix))
    commands = [
        ("build", ["bash", str(root / "build/build_scripts.sh"), str(project)]),
        ("prepare", [sys.executable, str(root / "build/box3d_profile.py"), "--prepare-import", str(project)]),
        ("import", [args.godot, "--headless", "--path", str(project), "--import"]),
        ("run", [args.godot, "--headless", "--path", str(project), "--script", "test_presentation.gd"]),
    ]
    results = []
    for name, command in commands:
        log = output / (name + ".log")
        timed_out = False
        with log.open("wb") as stream:
            try:
                result = subprocess.run(command, cwd=root, env=env, stdout=stream, stderr=subprocess.STDOUT, timeout=180)
                returncode = result.returncode
            except subprocess.TimeoutExpired:
                timed_out = True
                returncode = 124
        text = log.read_text(errors="replace")
        success = returncode == 0 and not timed_out
        if name in ("import", "run"):
            success = success and not any(bad in text for bad in ("ERROR:", "SHUTDOWN_LIVE", "NOT_EMPTY", "leaked"))
        if name == "run":
            success = success and "BOX3D_PRESENTATION_VALUES_OK" in text
        results.append({"name": name, "command": command, "exit": returncode, "timed_out": timed_out, "success": success, "log": str(log), "sha256": digest(log)})
        if not success:
            break
    after = inventory(root)
    status = "PASS" if len(results) == len(commands) and all(r["success"] for r in results) and before == after else "FAIL"
    binaries = {str(p): digest(p) for p in sorted((project / "bin").glob("*")) if p.is_file()}
    report = {"status": status, "source_before": before, "source_after": after, "source_fence_equal": before == after, "results": results, "binaries": binaries, "godot": {"path": args.godot, "sha256": digest(Path(args.godot).resolve())}, "scope": "ordinary authored mesh/label values; Native-free Core and scripts; prepared import, not an upstream cold-import fix"}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"status": status, "report": str(output / "report.json")}))
    return 0 if status == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
