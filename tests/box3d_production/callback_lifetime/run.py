#!/usr/bin/env python3
"""One real SDK callback allocation regression. Default plan starts no jobs."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, signal, subprocess, sys
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tests/box3d_production/runner"))
from controller import module_fence

IDENTITIES = {"kit": ("kit_authoring_demo", "KitAuthoringDemo"),
              "replay": ("replay_authoring_demo", "ReplayAuthoringDemo")}
IGNORED = {".git", ".godot", "bin", "__pycache__", ".box3d-cache", ".direnv", ".venv", "node_modules"}
SUFFIXES = {".odin", ".c", ".h", ".sh", ".py", ".gd", ".json", ".cfg", ".godot", ".gdextension", ".tscn", ".tres", ".in", ".md"}

def sha(path):
    digest = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""): digest.update(block)
    return digest.hexdigest()

def save(path, value):
    with Path(path).open("x") as stream:
        json.dump(value, stream, indent=2, allow_nan=False); stream.write("\n")
        stream.flush(); os.fsync(stream.fileno())

def source_map(folder, generated=False):
    result = {}
    for current, dirs, names in os.walk(folder, followlinks=False):
        dirs[:] = sorted(d for d in dirs if d not in IGNORED and not d.endswith(".dSYM"))
        for name in sorted(names):
            path = Path(current) / name
            if path.suffix not in SUFFIXES or (not generated and name.endswith(".gen.odin")): continue
            if path.is_symlink(): raise ValueError("source symlink requires explicit scope: " + str(path))
            result[str(path.relative_to(folder))] = sha(path)
    return result

def sdk_sources(framework):
    # Selected authored/SDK roots are a fence overapproximation, not an exact
    # compiler import trace. The selected old/current module has its own map.
    folders = ["build", "core", "runtime", "godot", "box3d", "kit", "replay",
               "addons/box3d_authoring", "examples/box3d_authoring_shared",
               "examples/" + framework + "_box3d_authoring", "tests/box3d_production/callback_lifetime",
               "tests/box3d_production/runner"]
    return {str(Path(name) / leaf): digest for name in folders if (ROOT / name).is_dir()
            for leaf, digest in source_map(ROOT / name).items()}

def binaries(project):
    return {str(p.relative_to(project)): sha(p) for p in sorted(project.rglob("*"))
            if p.is_file() and p.suffix in {".dylib", ".so", ".dll"}}

def step(report, name, argv, out, env, timeout):
    log = out / (name + ".log")
    record = dict(name=name, argv=[str(x) for x in argv], log=str(log))
    report["steps"].append(record)
    with log.open("xb") as stream:
        process = subprocess.Popen(record["argv"], cwd=ROOT, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        record["pid"] = process.pid
        try: record["actual_exit"] = process.wait(timeout=timeout)
        except BaseException:
            try: os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            process.wait(timeout=10); raise
        finally: stream.flush(); os.fsync(stream.fileno())
    record["log_sha256"] = sha(log)
    return record

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--framework", choices=IDENTITIES, required=True)
    parser.add_argument("--module-source", type=Path, required=True)
    for flag in ["godot", "odin", "native-library", "out"]: parser.add_argument("--" + flag, type=Path, required=True)
    parser.add_argument("--native-sha256", required=True)
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    for name in ["module_source", "godot", "odin", "native_library", "out"]:
        if not getattr(args, name).is_absolute(): parser.error(name + " must be absolute")
    if not re.fullmatch("[0-9a-f]{64}", args.native_sha256) or not 1024 <= args.port <= 65535: parser.error("exact Native SHA and unique bounded port required")
    out = args.out.resolve()
    if out == ROOT or ROOT in out.parents: parser.error("new output must be outside repository")
    out.mkdir(parents=True, exist_ok=False)
    plan = dict(framework=args.framework, module_source=str(args.module_source), port=args.port,
                warmup_pairs=128, pairs_per_batch=10000, batches=2,
                godot=str(args.godot), odin=str(args.odin), native_library=str(args.native_library),
                native_sha256=args.native_sha256, jobs_started=0,
                scope="pre-GO real SDK callback TLS and Godot heap only; same criterion for old/current module")
    save(out / "plan.json", plan)
    if not args.execute: print(json.dumps(dict(result="STAGED_ONLY", plan=str(out / "plan.json"), jobs_started=0))); return 0
    report = dict(result="FAIL", plan=plan, steps=[], error=None)
    module = args.module_source.resolve(strict=True)
    source_before, module_before = sdk_sources(args.framework), source_map(module)
    tools = {name: sha(getattr(args, name)) for name in ["godot", "odin", "native_library"]}
    if tools["native_library"] != args.native_sha256: raise ValueError("actual Native SHA differs")
    save(out / "source-before.json", source_before); save(out / "module-source-before.json", module_before)
    env = {k: v for k, v in os.environ.items() if not k.startswith(("BOX3D_SAMPLE_", "BOX3D_PRODUCTION_", "BOX3D_CALLBACK_"))}
    env.update(ROOT=str(ROOT), ODIN_GODOT_ROOT=str(ROOT), ODIN=str(args.odin), GODOT=str(args.godot),
               BOX3D_NATIVE_LIBRARY=str(args.native_library), SCRIPT_BUILD_FLAGS="-o:speed")
    project = out / "prepared/project"
    before_binaries = None
    try:
        prepare = step(report, "prepare", [sys.executable, ROOT / "examples/box3d_authoring_shared/prepare.py",
            "--framework", args.framework, "--out", out / "prepared", "--native-library", args.native_library,
            "--native-sha256", args.native_sha256, "--odin", args.odin, "--godot", args.godot], out, env, 120)
        if prepare["actual_exit"]: raise ValueError("ordinary preparation failed")
        prepared = json.loads((out / "prepared/report.json").read_text())
        if prepared["result"] != "STAGED_ONLY" or not prepared["source_fence_unchanged"] or not prepared["native_fence_unchanged"]: raise ValueError("ordinary preparation fences failed")
        destination = project / "modules/authoring_demo"
        destination.rename(out / "ordinary-module-before-replacement")
        shutil.copytree(module, destination, ignore=shutil.ignore_patterns(*IGNORED, "*.dSYM", "*.gen.odin", "*.uid"))
        if source_map(destination) != module_before: raise ValueError("selected frozen/current module copy differs")
        package, class_name = IDENTITIES[args.framework]
        probe = (HERE / "callback_lifetime_probe.odin.in").read_text().replace("__PACKAGE__", package).replace("__PREFIX__", package).replace("__CLASS__", class_name)
        with (destination / "callback_lifetime_probe.odin").open("x") as stream: stream.write(probe)
        shutil.copyfile(HERE / "callback_lifetime_test.gd", project / "callback_lifetime_test.gd")
        authored_before = source_map(project)
        save(out / "copied-authored-source-before.json", authored_before)
        build = step(report, "build", ["bash", ROOT / "build/build_scripts.sh", project], out, env, 600)
        generated = source_map(project, generated=True); save(out / "generated-source-after-build.json", generated)
        report["generated_wrapper_sources"] = {k: v for k, v in generated.items() if k.endswith(".gen.odin")}
        if build["actual_exit"]: raise ValueError("actual coherent SDK build failed")
        extension = "dylib" if sys.platform == "darwin" else "so"
        env["ODIN_SCRIPTS_DLL"] = str(project / "bin" / ("libodinscripts." + extension))
        imported = step(report, "import", [args.godot, "--headless", "--editor", "--path", project, "--import"], out, env, 600)
        if imported["actual_exit"]: raise ValueError("actual ordinary import failed")
        before_binaries = binaries(project); save(out / "binaries-before-functional.json", before_binaries)
        native_copies = {name: digest for name, digest in before_binaries.items() if Path(name).name in {"libogb3.dylib", "libogb3.so"}}
        if not native_copies or any(v != args.native_sha256 for v in native_copies.values()): raise ValueError("actual SDK Native copies differ")
        env.update(BOX3D_SAMPLE_ROLE="host", BOX3D_SAMPLE_PORT=str(args.port), BOX3D_SAMPLE_TICKS="120",
                   BOX3D_SAMPLE_SCRIPTED="0" if args.framework=="kit" else "1", BOX3D_SAMPLE_OUTPUT=str(out / "host-output"), BOX3D_CALLBACK_FRAMEWORK=args.framework)
        (out / "host-output").mkdir()
        report["functional_environment"] = {k: v for k, v in env.items() if k.startswith(("BOX3D_SAMPLE_", "BOX3D_CALLBACK_")) or k == "ODIN_SCRIPTS_DLL"}
        functional = step(report, "functional", [args.godot, "--headless", "--path", project, "--script", "res://callback_lifetime_test.gd"], out, env, 120)
        rows = []
        for line in (out / "functional.log").read_text().splitlines():
            if line.startswith("CALLBACK_LIFETIME_RESULT "): rows.append(json.loads(line.split(" ", 1)[1]))
        report["actual_results"] = rows
        if functional["actual_exit"] or len(rows) != 1 or rows[0].get("ok") is not True: raise ValueError("actual callback allocation criterion/setup failed; retain RED")
        if authored_before != source_map(project): raise ValueError("actual copied authored project changed")
        report["copied_authored_fence"] = True
        report["result"] = "PASS"
    except Exception as exc: report["error"] = repr(exc)
    finally:
        report["source_fence_unchanged"] = source_before == sdk_sources(args.framework)
        report["module_source_fence_unchanged"] = module_before == source_map(module)
        report["tools_before"] = tools
        report["tools_fence_unchanged"] = all(sha(getattr(args, name)) == digest for name, digest in tools.items())
        if before_binaries is not None:
            after_binaries = binaries(project); save(out / "binaries-after-functional.json", after_binaries)
            pids = {x["pid"] for x in report["steps"] if x["name"] == "functional"}
            fence, prior, copies = module_fence(before_binaries, after_binaries, pids)
            report.update(binary_fence_unchanged=fence, prior_verified_copies=prior, actual_module_copies=copies)
            if not fence: report["result"] = "FAIL"
        for record in report["steps"]:
            text = Path(record["log"]).read_text(errors="replace")
            if any(x in text for x in ["SCRIPT ERROR", "ERROR:", "instances were leaked", "resources still in use", "CLEANUP_FAIL"]):
                report["result"] = "FAIL"; report.setdefault("strict_log_findings", []).append(record["name"])
        if not all(report[k] for k in ["source_fence_unchanged", "module_source_fence_unchanged", "tools_fence_unchanged"]): report["result"] = "FAIL"
        report["source_scope"] = "selected SDK/authored roots overapproximation plus exact selected module and copied/generated project maps; not exact compiler import tracing"
        report["measurement_scope"] = "actual producer TLS used/capacity/temp_count and Godot static heap; no RSS/Native admission or performance inference"
        save(out / "report.json", report)
    print(json.dumps(dict(result=report["result"], report=str(out / "report.json"), error=report["error"])))
    return 0 if report["result"] == "PASS" else 1

if __name__ == "__main__": raise SystemExit(main())
