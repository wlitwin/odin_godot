#!/usr/bin/env python3
"""Isolated Gate C phases. Root grants each phase; stop on its first failure."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from toolchain import elf, sha

NATIVE_TESTS = {"domain_static", "domain_shared", "domain_modules", "motion", "authoring",
                "recovery", "recovery_reference", "recovery_fields", "recovery_lifecycle",
                "api_static", "api_shared", "lifecycle", "upgrade_state_fields"}
IGNORED = {".git", ".godot", "bin", "__pycache__", ".box3d-cache", ".direnv", ".venv", "node_modules"}
SOURCE_SUFFIXES = {".odin", ".c", ".h", ".py", ".sh", ".cfg", ".godot", ".gdextension",
                   ".tscn", ".tres", ".gd", ".patch", ".json", ".md", ".txt"}


def ignore_files(folder, names):
    return [n for n in names if n in IGNORED or n.endswith(".dSYM")]


def source_map(root, phase):
    if phase == "native":
        # Match the Native driver's scope, adding the domain fixture sources
        # consumed by CMake. Root's disjoint export/SDK work is not a Native
        # input and must not be falsely called a Native source-fence change.
        folders = ["box3d/native", "tests/box3d_recovery", "tests/box3d_motion/native",
                   "tests/box3d_authoring/native", "tests/box3d_modules/native",
                   "tests/box3d_soak/native_observe", "tests/box3d_native", "tests/box3d_upgrade"]
        paths = [root / "box3d/dependency.json", root / "build/build_box3d.sh",
                 root / "tests/box3d_native/lifecycle.c"]
        for folder in folders:
            paths.extend(p for p in (root / folder).rglob("*")
                         if p.is_file() and "__pycache__" not in p.parts)
        return {str(p.relative_to(root)): sha(p) for p in sorted(set(paths))}
    result = {}
    for directory, dirs, names in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in IGNORED and not d.endswith(".dSYM"))
        for name in sorted(names):
            if name in IGNORED or name.endswith(".dSYM"):
                continue
            path = Path(directory) / name
            if path.is_symlink():
                result[str(path.relative_to(root))] = {"symlink": os.readlink(path)}
            elif path.suffix in SOURCE_SUFFIXES or name == "CMakeLists.txt":
                result[str(path.relative_to(root))] = sha(path)
    return result


def stage_source(source, destination, phase):
    before = source_map(source, phase)
    shutil.copytree(source, destination, symlinks=True, ignore=ignore_files)
    copied = source_map(destination, phase)
    after = source_map(source, phase)
    if before != copied or before != after:
        raise RuntimeError("read-only source/copy identity differs; no build started")
    return before


def run(report, argv, logfile, env, timeout, strict_godot=False):
    record = {"argv": [str(x) for x in argv], "log": str(logfile),
              "environment": {k: env[k] for k in ["CC", "JOBS", "CMAKE_ARGS", "ODIN", "GODOT",
                                                  "XDG_CACHE_HOME", "XDG_DATA_HOME", "SCRIPT_BUILD_FLAGS",
                                                  "ODIN_EXPORT_OPT"] if k in env}}
    report["commands"].append(record)
    with logfile.open("xb") as output:
        try:
            result = subprocess.run(record["argv"], stdout=output, stderr=subprocess.STDOUT,
                                    env=env, timeout=timeout)
            record["actual_exit"] = result.returncode
        except subprocess.TimeoutExpired:
            record["timeout"] = True
            raise
    record["log_sha256"] = sha(logfile)
    if record["actual_exit"]:
        raise RuntimeError("actual command failed: " + json.dumps(record))
    if strict_godot:
        findings = []
        for number, line in enumerate(logfile.read_text(errors="replace").splitlines(), 1):
            upper, lower = line.upper(), line.lower()
            if ("ERROR:" in upper or "SCRIPT ERROR" in upper or "CLEANUP_FAIL" in upper or
                    "instances leaked" in lower or "instances were leaked" in lower or
                    "leaked instance" in lower or "resources still in use" in lower):
                findings.append({"line": number, "text": line[:2000]})
        record["strict_godot_log_checked"] = True
        record["strict_godot_log_findings"] = findings[:20]
        if findings:
            raise RuntimeError("strict Godot log failure despite process exit0: " + json.dumps(record))


def native(args, repo, report, env):
    cache = args.work / "native-cache"
    cache.mkdir()
    dependency = json.loads((repo / "box3d/dependency.json").read_text())["dependencies"]["box3d"]
    if sha(args.dependency_archive) != dependency["git_archive_sha256"]:
        raise RuntimeError("pinned dependency archive SHA differs")
    shutil.copyfile(args.dependency_archive, cache / "box3d.tar")
    env.update(CC="/usr/bin/clang", JOBS="2", CMAKE_ARGS=json.dumps(["-DCMAKE_C_COMPILER=/usr/bin/clang"]))
    for configuration in ["Debug", "Release"]:
        run(report, ["bash", repo / "build/build_box3d.sh", configuration, cache],
            args.out / (configuration.lower() + ".log"), env, 3600)
        build = cache / "build" / configuration
        manifest = json.loads((build / "build-manifest.json").read_text())
        if manifest.get("ctest") != "passed" or set(manifest.get("test_names", [])) != NATIVE_TESTS:
            raise RuntimeError("Native registered 12-test matrix incomplete: " + configuration)
        if manifest.get("native_observation_enabled"):
            raise RuntimeError("unexpected observation build")
        library = build / "libogb3.so"
        abi = elf(library)
        retained = args.out / configuration
        retained.mkdir()
        for name in ["libogb3.so", "libogb3.a", "build-manifest.json", "native-domain-identity.txt",
                     "CMakeCache.txt", "compile_commands.json"]:
            shutil.copyfile(build / name, retained / name)
        shutil.copytree(build / "Testing", retained / "Testing")
        report.setdefault("configurations", {})[configuration] = {
            "actual_tests": manifest["test_names"], "library": str(library), "elf": abi,
            "manifest": str(retained / "build-manifest.json"),
            "manifest_sha256": sha(retained / "build-manifest.json"),
            "native_identity": str(retained / "native-domain-identity.txt"),
            "native_identity_sha256": sha(retained / "native-domain-identity.txt"),
            "artifact_sha256": {p.name: sha(p) for p in retained.iterdir() if p.is_file()}}


def project_overlay_module(repo):
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("production_project_overlay", repo / "tests/box3d_production/runner/overlay.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def export(args, repo, report, env):
    if args.framework not in {"kit", "replay"} or not args.native_library:
        raise RuntimeError("export phase requires --framework and verified --native-library")
    elf(args.native_library)
    native_hash = sha(args.native_library)
    built = args.work / (args.framework + "-prepared")
    run(report, [sys.executable, repo / "examples/box3d_authoring_shared/prepare.py",
                 "--framework", args.framework, "--out", built, "--native-library", args.native_library,
                 "--native-sha256", native_hash, "--build", "--odin", env["ODIN"], "--godot", env["GODOT"]],
        args.out / "sdk-build.log", env, 3600)
    preparation = json.loads((built / "report.json").read_text())
    if preparation.get("result") != "PASS" or not preparation.get("source_fence_unchanged"):
        raise RuntimeError("ordinary SDK preparation/build did not pass")
    project = built / "project"
    if args.project_overlay is not None:
        report["project_overlay"] = project_overlay_module(repo).apply(project, args.project_overlay, args.project_overlay_sha256)
    env.update(ROOT=str(repo), ODIN_GODOT_ROOT=str(repo), BOX3D_NATIVE_LIBRARY=str(args.native_library))
    run(report, [env["GODOT"], "--headless", "--editor", "--path", project, "--import"],
        args.out / "import.log", env, 600, strict_godot=True)
    bundle = args.out / "export"
    bundle.mkdir()
    executable = bundle / (args.framework + "-box3d-authoring.x86_64")
    argv = [env["GODOT"], "--headless", "--path", str(project), "--export-release", "Linux x86_64", str(executable)]
    export_env = dict(env)
    export_env["SCRIPT_BUILD_FLAGS"] = "-thread-count:1"
    run(report, argv, args.out / "export.log", export_env, 3600, strict_godot=True)
    abi = elf(executable)
    libraries = sorted(bundle.rglob("libogb3.so"))
    if not libraries or any(sha(p) != native_hash for p in libraries):
        raise RuntimeError("normal export missing or changed the shared Native image")
    for path in sorted(bundle.rglob("*.so")):
        elf(path)
    for path in [executable, *sorted(bundle.rglob("*.so"))]:
        run(report, ["readelf", "-d", path], args.out / (path.name + ".dynamic.log"), env, 60)
    report["export_elf"] = abi
    report["preparation"] = {"path": str(built / "report.json"), "sha256": sha(built / "report.json")}
    report["export_record"] = {
        "result": "PASS", "framework": args.framework, "target": "linux-x86_64",
        "execution_mode": args.execution_mode,
        "bundle_root": str(bundle), "executable": str(executable), "export_argv": argv,
        "native_identity": {"source_library": str(args.native_library), "sha256": native_hash,
                            "domain_record": str(args.native_library.parent / "native-domain-identity.txt"),
                            "domain_record_sha256": sha(args.native_library.parent / "native-domain-identity.txt")},
        "artifacts": {str(p.relative_to(bundle)): sha(p) for p in sorted(bundle.rglob("*")) if p.is_file()},
        "source_fence_unchanged": False, # committed only after the final actual comparison
        "execution_scope": ("Native Linux x86_64 functional; runtime NOT YET RUN" if args.execution_mode == "native"
                            else "Rosetta-translated Linux x86_64 functional; runtime NOT YET RUN")}

    if args.project_overlay is not None:
        report["project_overlay_fence_unchanged"] = project_overlay_module(repo).verify(report["project_overlay"])
        if not report["project_overlay_fence_unchanged"]:
            raise RuntimeError("actual derived overlay changed")
        report["export_record"]["project_overlay"] = report["project_overlay"]
        report["export_record"]["project_overlay_fence_unchanged"] = True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["native", "export"])
    parser.add_argument("--repo-input", type=Path, default=Path("/input/repo"))
    parser.add_argument("--dependency-archive", type=Path, default=Path("/input/box3d.tar"))
    parser.add_argument("--work", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--framework", choices=["kit", "replay"])
    parser.add_argument("--native-library", type=Path)
    parser.add_argument("--toolchain-report", type=Path, required=True)
    parser.add_argument("--execution-mode", choices=["native", "translated-linux-x86_64"], default="translated-linux-x86_64")
    parser.add_argument("--project-overlay", type=Path)
    parser.add_argument("--project-overlay-sha256")
    args = parser.parse_args()
    if bool(args.project_overlay) != bool(args.project_overlay_sha256):
        parser.error("overlay path and exact SHA are paired")
    if args.project_overlay is not None and args.phase != "export":
        parser.error("project overlay is export-only")
    args.work.mkdir(parents=True, exist_ok=False)
    args.out.mkdir(parents=True, exist_ok=False)
    report = {"result": "FAIL", "phase": args.phase, "commands": [], "execution_mode": args.execution_mode,
              "scope": ("Native Linux x86_64 functional; no performance/cross-target equality claim" if args.execution_mode == "native"
                        else "Linux x86_64 userspace under Rosetta, not native x86 hardware or performance proof")}
    try:
        tools = json.loads(args.toolchain_report.read_text())
        if tools.get("result") != "PASS":
            raise RuntimeError("actual toolchain preflight must pass first")
        if args.execution_mode == "native":
            kernel = tools.get("kernel_uname", [])
            if (tools.get("execution_mode") != "native" or tools.get("native_x86_hardware") is not True
                    or len(kernel) < 5 or kernel[0] != "Linux" or kernel[4] not in ("x86_64", "amd64")):
                raise RuntimeError("native Linux requires explicit native-x86 preflight; translated evidence cannot be relabeled")
        elif tools.get("native_x86_hardware") is not False:
            raise RuntimeError("translated Linux requires its explicit translated toolchain report")
        report["toolchain_report"] = {"path": str(args.toolchain_report), "sha256": sha(args.toolchain_report)}
        repo = args.work / "repo"
        inputs = stage_source(args.repo_input, repo, args.phase)
        report["source_fence_scope"] = "Native source/driver/13-test inputs" if args.phase == "native" else "copied repository source inputs"
        (args.out / "source-inputs.json").write_text(json.dumps(inputs, indent=2) + "\n")
        env = os.environ.copy()
        if args.phase == "native":
            native(args, repo, report, env)
        else:
            export(args, repo, report, env)
        unchanged = inputs == source_map(repo, args.phase) == source_map(args.repo_input, args.phase)
        report["source_fence_unchanged"] = unchanged
        if not unchanged:
            raise RuntimeError("actual isolated/input source fence changed")
        if "export_record" in report:
            report["export_record"]["source_fence_unchanged"] = True
            (args.out / "export-record.json").write_text(json.dumps(report["export_record"], indent=2) + "\n")
        report["result"] = "PASS"
    except Exception as exc:
        report["error"] = repr(exc)
    finally:
        (args.out / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"result": report["result"], "report": str(args.out / "report.json")}))
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
