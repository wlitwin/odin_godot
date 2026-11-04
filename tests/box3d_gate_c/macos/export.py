#!/usr/bin/env python3
"""Stage or execute ONE ordinary macOS arm64 authored-sample export.

Support workers write this source only. Root explicitly selects --execute.
This never launches an exported game and never creates or repacks a PCK.
"""
import argparse
import configparser
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
PRESET = "macOS arm64"
GODOT_VERSION = "4.7.1.stable.official.a13da4feb"
NATIVE = Path("/tmp/odin-box3d-goal-t4jbbj4v/p5-motion-native-build-v2/cache/build/Release/libogb3.dylib")
SOURCE_SUFFIXES = {".odin", ".gd", ".gdextension", ".godot", ".cfg", ".tscn", ".tres", ".py", ".sh", ".json", ".h", ".c"}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def write_json(path, value):
    with path.open("x") as stream:
        json.dump(value, stream, indent=2)
        stream.write("\n")


def source_files(roots, relative_to):
    result = {}
    for root in roots:
        for path in sorted(root.rglob("*")):
            parts = path.relative_to(root).parts
            if (path.is_file() and path.suffix in SOURCE_SUFFIXES
                    and not any(x in parts for x in ("bin", ".godot", ".export_build", "__pycache__"))
                    and not path.name.endswith(".gen.odin")):
                result[str(path.relative_to(relative_to))] = sha(path)
    return dict(sorted(result.items()))


def repo_sources(framework):
    names = ["box3d", "kit", "replay", "runtime", "godot", "gdext", "core", "build",
             "addons/box3d_authoring", "examples/box3d_authoring_shared",
             "examples/" + framework + "_box3d_authoring", "tests/box3d_gate_c/macos"]
    return source_files([ROOT / name for name in names], ROOT)


def preset_record(project):
    path = project / "export_presets.cfg"
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.read(path)
    matches = [s for s in parser.sections() if re.fullmatch(r"preset\.[0-9]+", s)
               and parser[s].get("name", "").strip('"') == PRESET]
    require(len(matches) == 1, "exactly one normal macOS arm64 preset is required")
    section = matches[0]
    options = dict(parser[section + ".options"])
    require(parser[section].get("platform", "").strip('"') == "macOS", "preset platform differs")
    require(options.get("binary_format/architecture", "").strip('"') == "universal",
            "preset must use the official universal launcher; SDK/runtime remain arm64")
    require(options.get("notarization/notarization") == "0", "this local export must not request notarization")
    return {"path": str(path), "sha256": sha(path), "name": PRESET,
            "launcher_architecture": "universal", "sdk_architecture": "arm64",
            "configuration": dict(parser[section]), "options": options}


class Steps:
    def __init__(self, output, environment, timeout):
        self.output, self.environment, self.timeout = output, environment, timeout
        self.rows = []

    def run(self, name, argv, *, cwd=ROOT, godot=False):
        log = self.output / (name + ".log")
        row = {"name": name, "argv": [str(x) for x in argv], "cwd": str(cwd), "log": str(log)}
        self.rows.append(row)
        with log.open("xb") as stream:
            process = subprocess.Popen(row["argv"], cwd=cwd, env=self.environment,
                                       stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            row["pid"] = process.pid
            row["owned_pgid"] = process.pid
            try:
                row["actual_exit"] = process.wait(timeout=self.timeout)
            except subprocess.TimeoutExpired:
                row["timeout"] = True
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except OSError as exc:
                    row["cleanup_error"] = repr(exc)
                    try:
                        process.kill()
                    except OSError as leader_exc:
                        row["leader_cleanup_error"] = repr(leader_exc)
                try:
                    row["actual_exit"] = process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    row["actual_exit"] = None
            stream.flush()
            os.fsync(stream.fileno())
        row["log_sha256"] = sha(log)
        require(row["actual_exit"] == 0 and not row.get("timeout"), name + " failed; preserve " + str(log))
        text = log.read_text(errors="replace")
        if godot:
            bad = [line for line in text.splitlines() if "SCRIPT ERROR" in line or "ERROR:" in line
                   or "instances were leaked" in line or "resources still in use" in line]
            row["strict_error_lines"] = bad[:32]
            require(not bad, name + " reported an actual Godot error")
        return text


def load_profile():
    spec = importlib.util.spec_from_file_location("gate_c_box3d_profile", ROOT / "build/box3d_profile.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def bundle_files(bundle):
    files, symlinks = {}, {}
    for path in sorted(bundle.rglob("*")):
        if path.is_symlink():
            require(path.resolve().is_relative_to(bundle.resolve()), "exported symlink escapes bundle: " + str(path))
            symlinks[str(path.relative_to(bundle))] = os.readlink(path)
        if path.is_file():
            files[str(path.relative_to(bundle))] = sha(path)
    return files, symlinks


def inspect_bundle(bundle, project, output, steps, native_input):
    plist_path = bundle / "Contents/Info.plist"
    require(plist_path.is_file(), "Godot did not create a real .app Info.plist")
    with plist_path.open("rb") as stream:
        info = plistlib.load(stream)
    leaf = info.get("CFBundleExecutable")
    require(isinstance(leaf, str) and Path(leaf).name == leaf, "invalid actual bundle executable")
    executable = bundle / "Contents/MacOS" / leaf
    require(executable.is_file() and os.access(executable, os.X_OK), "exported executable missing/not executable")
    expected_id = "org.odingodot.box3d." + ("kitauthoring" if "Kit" in bundle.name else "replayauthoring")
    require(info.get("CFBundleIdentifier") == expected_id, "actual bundle ID differs from declared sample")
    libraries = {}
    for name in ("libodin_godot.dylib", "libodinscripts.dylib", "libodinscripts_authoring_demo.dylib",
                 "libodinscripts_box3d_authoring_tools.dylib", "libogb3.dylib"):
        candidates = list(bundle.rglob(name))
        require(len(candidates) == 1, "bundle needs exactly one " + name)
        libraries[name] = candidates[0]
    directory = libraries["libodin_godot.dylib"].parent
    require(all(p.parent == directory for p in libraries.values()), "ordinary Core/scripts/modules/Native sibling deployment differs")
    native_candidates = {p.resolve() for p in bundle.rglob("*libogb3*.dylib")}
    require(native_candidates == {libraries["libogb3.dylib"].resolve()}, "multiple Native images packaged")
    binaries = {"executable": executable, **libraries}
    metadata = {}
    profile = load_profile()
    for index, (name, path) in enumerate(binaries.items()):
        architectures = steps.run("inspect-arch-" + str(index), ["/usr/bin/lipo", "-archs", path]).strip()
        architecture_list = architectures.split()
        if name == "executable":
            require("arm64" in architecture_list, "official Godot launcher lacks arm64: " + str(path))
        else:
            require(architecture_list == ["arm64"], "actual SDK/Native binary is not exact arm64: " + str(path))
        dependencies = steps.run("inspect-loads-" + str(index), ["/usr/bin/otool", "-L", path])
        commands = steps.run("inspect-rpaths-" + str(index), ["/usr/bin/otool", "-l", path])
        metadata[name] = {"path": str(path), "sha256": sha(path), "architectures": architectures,
                          "architecture_list": architecture_list,
                          "dependencies": dependencies, "load_commands": commands}
        if name.startswith("libodin"):
            defined = steps.run("inspect-defined-symbols-" + str(index), ["/usr/bin/nm", "-gU", path])
            undefined = steps.run("inspect-undefined-symbols-" + str(index), ["/usr/bin/nm", "-gu", path])
            native_defined = [line.split()[-1] for line in defined.splitlines()
                              if line.split() and line.split()[-1].lstrip("_").startswith("ogb3_")]
            native_refs = sorted({line.split()[-1] for line in undefined.splitlines()
                                  if line.split() and line.split()[-1].lstrip("_").startswith("ogb3_")})
            require(not native_defined, "SDK DSO embeds Native engine definitions: " + name)
            shared_import = "@rpath/libogb3.dylib" in dependencies
            if name == "libodin_godot.dylib":
                # Core deliberately resolves/pins the sibling Native API through
                # its stable host service, rather than a mandatory LC import.
                classification = "dynamic_host_api"
                runtime_proof = "PENDING: exported pair must prove one Native image and typed owner/world/codec/domain handshakes"
            elif name == "libodinscripts_authoring_demo.dylib":
                require(shared_import and bool(native_refs), "gameplay module lacks actual shared Native use: " + name)
                classification = "native_consumer"
                runtime_proof = "PENDING: exported sample execution"
            elif native_refs or shared_import:
                require(shared_import, "SDK DSO references Native without canonical shared import: " + name)
                classification = "native_consumer"
                runtime_proof = "PENDING: exported sample execution"
            else:
                # This is determined from BOTH actual loads and actual undefined
                # symbols, not from an exemption list of boot/editor names.
                classification = "native_free"
                runtime_proof = "Not a Native consumer; actual no-import/no-Native-reference observation"
            if classification == "native_consumer":
                require("@loader_path" in commands, "SDK Native consumer lacks loader-relative rpath: " + name)
            metadata[name].update(native_classification=classification,
                                  shared_native_import=shared_import,
                                  native_undefined_symbols=native_refs,
                                  native_defined_symbols=native_defined,
                                  runtime_proof=runtime_proof)
            profile.inspect_consumer(path, "macos")
    deployed_record = project / ".export_build/box3d-runtime.json"
    require(deployed_record.is_file(), "normal Odin exporter did not deploy its verified Native profile")
    deployed = json.loads(deployed_record.read_text())
    require(deployed["domain"] == native_input["domain"], "export profile Native identity differs from input")
    require(sha(project / ".export_build/libogb3.dylib") == deployed["deployed_library_sha256"], "export-build Native changed")
    core_record = project / "bin/box3d-runtime.json"
    require(core_record.is_file(), "Core dynamic host lacks its actual ordinary SDK Native profile")
    core_profile = json.loads(core_record.read_text())
    require(core_profile["domain"] == deployed["domain"], "Core/export Native ABI/build/target profile differs")
    require(sha(project / "bin/libogb3.dylib") == core_profile["deployed_library_sha256"], "Core's build-time Native deployment changed")
    metadata["libodin_godot.dylib"]["profile_binding"] = {
        "core_runtime_record": str(core_record), "core_runtime_record_sha256": sha(core_record),
        "domain": core_profile["domain"], "sibling_packaged_native": str(libraries["libogb3.dylib"]),
        "binding_scope": "Normal SDK dynamic_host_api source/profile and packaged ABI/build/target inspection; runtime proof remains PENDING."}
    # Isolate the actual packaged-library query, so an input library already
    # loaded by metadata inspection cannot satisfy a second path by dlopen alias.
    code = ("import importlib.util,json,sys;"
            "s=importlib.util.spec_from_file_location('p',sys.argv[1]);"
            "m=importlib.util.module_from_spec(s);s.loader.exec_module(m);"
            "print(json.dumps(m.query_domain(__import__('pathlib').Path(sys.argv[2])),sort_keys=True))")
    domain_text = steps.run("inspect-packaged-native-domain", [sys.executable, "-c", code,
                            ROOT / "build/box3d_profile.py", libraries["libogb3.dylib"]])
    actual_domain = json.loads(domain_text)
    require(actual_domain == native_input["domain"], "actual packaged Native build/target/API metadata differs")
    steps.run("verify-local-codesign", ["/usr/bin/codesign", "--verify", "--deep", "--strict", "--verbose=2", bundle])
    signing = steps.run("inspect-local-codesign", ["/usr/bin/codesign", "-d", "--verbose=4", bundle])
    require("Signature=adhoc" in signing and "Authority=" not in signing, "export is not the declared local ad-hoc signature")
    write_json(output / "binary-metadata.json", metadata)
    return executable, {"input": native_input, "export_runtime_record": str(deployed_record),
                        "export_runtime_record_sha256": sha(deployed_record), "domain": actual_domain,
                        "packaged_library": str(libraries["libogb3.dylib"]),
                        "packaged_library_sha256": sha(libraries["libogb3.dylib"])}, info


def project_overlay_module():
    sys.dont_write_bytecode = True
    path = ROOT / "tests/box3d_production/runner/overlay.py"
    spec = importlib.util.spec_from_file_location("production_project_overlay", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--framework", choices=("kit", "replay"), required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--godot", type=Path, default=Path("/Applications/Godot.app/Contents/MacOS/Godot"))
    parser.add_argument("--odin", default=os.environ.get("ODIN", "odin"))
    parser.add_argument("--native-library", type=Path, default=NATIVE)
    parser.add_argument("--native-sha256")
    parser.add_argument("--preset", choices=(PRESET,), default=PRESET)
    parser.add_argument("--timeout", type=float, default=1200)
    parser.add_argument("--project-overlay", type=Path)
    parser.add_argument("--project-overlay-sha256")
    parser.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    require(bool(args.project_overlay) == bool(args.project_overlay_sha256), "overlay path and exact SHA are paired")
    overlay_api = project_overlay_module() if args.project_overlay else None
    overlay_input = overlay_api.describe(args.project_overlay, args.project_overlay_sha256) if overlay_api else None
    output = args.out.resolve()
    output.mkdir(parents=True, exist_ok=False)
    godot, native = args.godot.resolve(strict=True), args.native_library.resolve(strict=True)
    templates = Path.home() / "Library/Application Support/Godot/export_templates/4.7.1.stable"
    require((templates / "version.txt").read_text().strip() == "4.7.1.stable", "matching official template version is unavailable")
    require((templates / "macos.zip").is_file(), "matching official macOS template archive is missing")
    preset = preset_record(ROOT / "examples" / (args.framework + "_box3d_authoring"))
    before = repo_sources(args.framework)
    write_json(output / "source-before.json", before)
    native_sha, godot_sha = sha(native), sha(godot)
    if args.native_sha256:
        require(args.native_sha256 == native_sha, "declared Native SHA differs")
    prepared = output / "prepared"
    project = prepared / "project"
    app_name = "KitBox3DAuthoring.app" if args.framework == "kit" else "ReplayBox3DAuthoring.app"
    bundle = output / "export" / app_name
    prepare_argv = [sys.executable, str(ROOT / "examples/box3d_authoring_shared/prepare.py"),
                    "--framework", args.framework, "--out", str(prepared), "--native-library", str(native),
                    "--native-sha256", native_sha, "--odin", args.odin, "--godot", str(godot), "--build"]
    import_argv = [str(godot), "--headless", "--editor", "--path", str(project), "--quit-after", "120"]
    export_argv = [str(godot), "--headless", "--path", str(project), "--export-release", args.preset, str(bundle)]
    plan = {"result": "STAGED_ONLY", "framework": args.framework, "target": "macos-arm64",
            "project": str(project), "bundle_root": str(bundle), "preset": preset,
            "prepare_argv": prepare_argv, "import_argv": import_argv, "export_argv": export_argv,
            "native_library": str(native), "native_sha256": native_sha, "godot": str(godot), "godot_sha256": godot_sha,
            "templates": {"directory": str(templates), "version_sha256": sha(templates / "version.txt"),
                          "macos_zip_sha256": sha(templates / "macos.zip")},
            "runtime_jobs_started": 0, "scope": "Normal SDK export only; runtime correctness is a separate Root run."}
    if overlay_input is not None:
        plan["project_overlay_input"] = overlay_input
    write_json(output / "plan.json", plan)
    if not args.execute:
        print(json.dumps({"result": "STAGED_ONLY", "plan": str(output / "plan.json")}))
        return 0
    environment = os.environ.copy()
    for key in list(environment):
        if key.startswith("BOX3D_SAMPLE_") or key in ("ODIN_SCRIPTS_DLL", "SCRIPT_BUILD_FLAGS"):
            del environment[key]
    environment.update(ROOT=str(ROOT), ODIN_GODOT_ROOT=str(ROOT), BOX3D_NATIVE_LIBRARY=str(native))
    steps = Steps(output, environment, args.timeout)
    report = {**plan, "result": "FAIL", "error": None, "executable": None, "artifacts": {},
              "native_identity": None, "source_fence_unchanged": False, "steps": steps.rows,
              "environment": {key: environment[key] for key in ("ROOT", "ODIN_GODOT_ROOT", "BOX3D_NATIVE_LIBRARY")}}
    project_before = None
    try:
        require(sys.platform == "darwin" and platform.machine().lower() in ("arm64", "aarch64"), "this workflow requires native macOS arm64")
        odin = shutil.which(args.odin)
        require(odin is not None, "actual Odin compiler is unavailable")
        report["odin"] = {"path": odin, "sha256": sha(odin), "version": steps.run("odin-version", [odin, "version"]).strip()}
        require(steps.run("godot-version", [godot, "--version"]).strip() == GODOT_VERSION, "actual official Godot version differs")
        native_input = load_profile().native_input(native, ROOT, "macos")
        require(native_input["configuration"] == "Release", "Gate C input must be the selected Native Release")
        steps.run("prepare-build", prepare_argv)
        build_record = prepared / "report.json"
        build = json.loads(build_record.read_text())
        require(build["result"] == "PASS" and build["source_fence_unchanged"] and build["native_fence_unchanged"] and build["copied_content_byteexact"], "ordinary prepared SDK build failed its fences")
        report["build_record"] = {"path": str(build_record), "sha256": sha(build_record)}
        if overlay_api is not None:
            report["project_overlay"] = overlay_api.apply(project, args.project_overlay, args.project_overlay_sha256)
        project_before = source_files([project], project)
        write_json(output / "project-source-before.json", project_before)
        require(not (project / ".export_build").exists(), "fresh project already contains export artifacts")
        steps.run("ordinary-import", import_argv, godot=True)
        bundle.parent.mkdir()
        steps.run("godot-export-release", export_argv, godot=True)
        executable, identity, plist = inspect_bundle(bundle, project, output, steps, native_input)
        binaries = json.loads((output / "binary-metadata.json").read_text())
        report.update(executable=str(executable), native_identity=identity, bundle_info=plist,
                      launcher_architectures=binaries["executable"]["architecture_list"],
                      sdk_architecture="arm64", execution_architecture="arm64",
                      architecture_scope="Official universal Godot launcher; ARM64 SDK/Native consumers and selected execution only, no Intel/universal SDK claim.")
        report["artifacts"], report["bundle_symlinks"] = bundle_files(bundle)
        require(bool(report["artifacts"]), "actual exported bundle is empty")
        report["result"] = "PASS"
    except Exception as exc:
        report["error"] = repr(exc)
    finally:
        after = repo_sources(args.framework)
        write_json(output / "source-after.json", after)
        report["source_fence_unchanged"] = before == after
        report["native_fence_unchanged"] = sha(native) == native_sha
        report["godot_fence_unchanged"] = sha(godot) == godot_sha
        report["templates_fence_unchanged"] = (sha(templates / "macos.zip") == plan["templates"]["macos_zip_sha256"]
                                                  and sha(templates / "version.txt") == plan["templates"]["version_sha256"])
        if project_before is not None:
            project_after = source_files([project], project)
            write_json(output / "project-source-after.json", project_after)
            report["project_source_fence_unchanged"] = project_before == project_after
        if not all(report.get(key) is True for key in ("source_fence_unchanged", "native_fence_unchanged", "godot_fence_unchanged", "templates_fence_unchanged", "project_source_fence_unchanged")):
            report["result"] = "FAIL"
        if overlay_api is not None:
            report["project_overlay_fence_unchanged"] = "project_overlay" in report and overlay_api.verify(report["project_overlay"])
            if not report["project_overlay_fence_unchanged"]:
                report["result"] = "FAIL"
        report["host"] = {"system": platform.system(), "machine": platform.machine(), "release": platform.release()}
        report["source_scope"] = "Declared SDK/compiler/native/authoring source roots; generated project output recorded separately, not an exact compiler import trace."
        write_json(output / "export-record.json", report)
    print(json.dumps({"result": report["result"], "record": str(output / "export-record.json"), "error": report["error"]}))
    return 0 if report["result"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
