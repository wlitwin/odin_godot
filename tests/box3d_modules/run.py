#!/usr/bin/env python3
"""Actual Godot SDK module ownership acceptance, with immutable evidence output.

No simulator or alternate framework is implemented by this runner. It builds
normal SDK modules, invokes their Godot scripts, and retains exact source/native/
binary/log identities. Deliberately invalid modules bypass only the production
build-time static-symbol rejection so the actual Core admission is exercised.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
SOURCE = Path(__file__).resolve().parent / "project"
ATTRS = ("gd_method", "gd_connect", "gd_rpc", "gd_command", "gd_tick", "gd_input",
         "gd_sample", "gd_step", "gd_event", "gd_half", "gd_message")
BAD_SOURCE = '''//gd:extends Node
//gd:class BadProducer
package box3d_bad_producer
import b "godot:box3d"
import gd "godot:godot"
import "core:os"
import "base:runtime"
BadProducer :: struct {owner:gd.Node}
@(init)
bad_init :: proc "contextless"(){
    context=runtime.default_context()
    buffer:[4096]u8
    path,error:=os.lookup_env(buffer[:],"BOX3D_BAD_INIT_SENTINEL")
    if error==nil && len(path)>0 {_=os.write_entire_file(path,[]u8{'i','n','i','t'})}
}
@(gd_method)
bad_producer_attempt :: proc(self:^BadProducer)->gd.Int{_,s:=b.world_create(b.World_Def{});return gd.Int(s)}
'''


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def source_inventory():
    result = {}
    for directory in ("box3d", "core", "runtime", "kit", "replay", "build", "scriptgen", "tests/box3d_modules"):
        for path in (ROOT / directory).rglob("*"):
            if (path.is_file() and path.suffix in (".odin", ".c", ".h", ".sh", ".py", ".gd", ".gdextension", ".godot", ".cfg")
                    and not path.name.endswith(".gen.odin")
                    and not any(part in path.parts for part in ("__pycache__", ".godot", "bin"))):
                result[str(path.relative_to(ROOT))] = sha(path)
    return result


class Run:
    def __init__(self, args):
        self.args = args
        self.out = args.out.resolve()
        if self.out.exists() and any(self.out.iterdir()):
            raise FileExistsError("immutable SDK output already exists: " + str(self.out))
        self.out.mkdir(parents=True, exist_ok=True)
        self.project = self.out / "project"
        shutil.copytree(SOURCE, self.project, ignore=shutil.ignore_patterns("bin", ".godot", "*.gen.odin", "*.gen.odin.uid"))
        self.ext = ".dylib" if os.uname().sysname == "Darwin" else ".so"
        self.env = dict(os.environ, ODIN_GODOT_ROOT=str(ROOT), ODIN=args.odin,
                        BOX3D_NATIVE_LIBRARY=str(args.native.resolve()))
        for key in ("SKIP_CORE", "BUILD_MODULES", "SCRIPT_BUILD_FLAGS", "BOX3D_RUNTIME_DIR"):
            self.env.pop(key, None)
        self.env["ODIN_SCRIPTS_DLL"] = str(self.project / "bin" / ("libodinscripts" + self.ext))
        self.steps = []

    def command(self, name, command, *, env=None, marker=None, expected_rejection=False):
        path = self.out / (name + ".log")
        started = time.monotonic()
        try:
            with path.open("w") as log:
                result = subprocess.run(command, cwd=ROOT, env=env or self.env,
                                        stdout=log, stderr=subprocess.STDOUT, timeout=180)
        except subprocess.TimeoutExpired:
            self.steps.append({"name": name, "command": command, "exit_code": None,
                               "timed_out": True, "log_sha256": sha(path),
                               "elapsed_seconds_observation": time.monotonic() - started})
            self.progress()
            raise
        data = path.read_text(errors="replace")
        item = {"name": name, "command": command, "exit_code": result.returncode,
                "log_sha256": sha(path), "elapsed_seconds_observation": time.monotonic() - started}
        self.steps.append(item)
        self.progress()
        assert result.returncode == 0, (name, result.returncode, str(path))
        if marker:
            assert marker in data, (name, "missing success marker")
            for bad in ("ODIN_BOX3D_SHUTDOWN_LIVE", "ODIN_BOX3D_SHUTDOWN_NOT_EMPTY",
                        "runtime assertion", "Program crashed", "SCRIPT ERROR", "ERROR:"):
                assert bad not in data, (name, bad, str(path))
        if expected_rejection:
            assert "ODIN_BOX3D_MODULE_CONTRACT_REJECTED" in data, (name, "invalid module was not rejected")
        if name in ("replay-reload", "kit-reload"):
            released = data.index("ODIN_RELOAD_GENERATION_LOADER_RELEASED")
            assert data.index("BOX3D_GODOT_RELEASE_OLD_CAPSULES_BEGIN") < released < data.index("BOX3D_GODOT_RELEASE_OLD_CAPSULES_RETURNED"), (name, "old loader reference was released outside whole capsule cleanup")
        return item

    def progress(self):
        (self.out / "progress.json").write_text(json.dumps({"steps": self.steps}, indent=2) + "\n")

    def build(self, name):
        return self.command(name, ["bash", str(ROOT / "build/build_scripts.sh"), str(self.project)])

    def godot(self, name, script, *extra):
        return self.command(name, [self.args.godot, "--headless", "--path", str(self.project),
                                  "--script", script, *extra], marker={
            "test_domain.gd": "BOX3D_GODOT_DOMAIN_OK",
            "test_surface.gd": "BOX3D_GODOT_SURFACE_OK",
            "test_capsule.gd": "BOX3D_GODOT_CAPSULE_OK",
            "test_kit_capsule.gd": "BOX3D_GODOT_KIT_CAPSULE_OK",
            "test_quota.gd": "BOX3D_GODOT_QUOTA_OK",
            "test_contexts.gd": "BOX3D_GODOT_CONTEXT_OK",
            "test_reload_capsule.gd": "BOX3D_GODOT_RELOAD_OK",
            "test_rejected_reload.gd": "BOX3D_GODOT_REJECTED_RELOAD_OK",
        }[script])

    def negative_modules(self):
        project = self.out / "invalid-project"
        shutil.copytree(self.project, project, ignore=shutil.ignore_patterns(".godot", "*.dSYM", "*.r*.dylib", "*.r*.so"))
        bad = project / "modules/bad"
        bad.mkdir(parents=True)
        (bad / "bad.odin").write_text(BAD_SOURCE)
        env = dict(self.env, ODIN_SCRIPTS_DLL=str(project / "bin" / ("libodinscripts" + self.ext)))
        self.command("invalid-project-base-build", ["bash", str(ROOT / "build/build_scripts.sh"), str(project)], env=env)
        original_main = self.out / ("invalid-original-main" + self.ext)
        shutil.copyfile(project / "bin" / ("libodinscripts" + self.ext), original_main)
        profile = json.loads((project / "bin/box3d-runtime.json").read_text())
        archive = self.args.native.resolve().parent / "libogb3.a"
        duplicate = project / "bin" / ("libogb3_duplicate" + self.ext)
        shutil.copyfile(project / "bin" / ("libogb3" + self.ext), duplicate)
        if self.ext == ".dylib":
            self.command("duplicate-install-id", ["install_name_tool", "-id", "@rpath/libogb3_duplicate.dylib", str(duplicate)])
            self.command("duplicate-sign", ["codesign", "--force", "--sign", "-", str(duplicate)])
        else:
            # A distinct SONAME makes the test a genuine second loaded image.
            self.command("duplicate-shared-link", [self.args.cc, "-shared", "-Wl,-soname,libogb3_duplicate.so",
                         "-Wl,--whole-archive", str(archive), "-Wl,--no-whole-archive", "-lm", "-lpthread",
                         "-o", str(duplicate)])
        alias = project / "bin" / ("libforeign_physics" + self.ext)
        if self.ext == ".dylib":
            shutil.copyfile(duplicate, alias)
            self.command("alias-install-id", ["install_name_tool", "-id", "@rpath/libforeign_physics.dylib", str(alias)])
            self.command("alias-sign", ["codesign", "--force", "--sign", "-", str(alias)])
        else:
            self.command("alias-shared-link", [self.args.cc, "-shared", "-Wl,-soname,libforeign_physics.so",
                         "-Wl,--whole-archive", str(archive), "-Wl,--no-whole-archive", "-lm", "-lpthread",
                         "-o", str(alias)])
        for mode, library in (("static", archive), ("duplicate", duplicate), ("alias", alias), ("expected-build", self.args.native.resolve())):
            expected = "0" * 64 if mode == "expected-build" else profile["domain"]["build"]
            output = project / "bin" / ("libodinscripts_bad" + self.ext)
            command = [self.args.odin, "build", str(bad), "-collection:godot=" + str(ROOT),
                       "-build-mode:dll", "-use-single-module", "-out:" + str(output),
                       "-define:BOX3D_REQUIRE_DOMAIN=true", "-define:BOX3D_LIBRARY=" + str(library),
                       "-define:BOX3D_EXPECTED_BUILD=sha256:" + expected,
                       "-define:BOX3D_EXPECTED_TARGET=sha256:" + profile["domain"]["target"]]
            command += ["-custom-attribute:" + name for name in ATTRS]
            if self.ext == ".dylib":
                command += ["-extra-linker-flags:-Wl,-rpath,@loader_path"]
            else:
                command += ["-extra-linker-flags:" + shlex.join(["-Wl,-Bsymbolic", "-Wl,-rpath,$ORIGIN"])]
            self.command(mode + "-invalid-build", command, env=env)
            sentinel = self.out / (mode + "-init-sentinel")
            env["BOX3D_BAD_INIT_SENTINEL"] = str(sentinel)
            self.command(mode + "-godot-rejection", [self.args.godot, "--headless", "--path", str(project),
                         "--script", "test_rejected_module.gd"], env=env,
                         marker="BOX3D_GODOT_REJECTION_OK", expected_rejection=True)
            candidate = project / "bin" / ("rejected-candidate" + self.ext)
            shutil.copyfile(output, candidate)
            env["BOX3D_REJECTED_CANDIDATE"] = str(candidate)
            self.command(mode + "-reload-rejection", [self.args.godot, "--headless", "--path", str(project),
                         "--script", "test_rejected_reload.gd"], env=env,
                         marker="BOX3D_GODOT_REJECTED_RELOAD_OK", expected_rejection=True)
            assert sentinel.exists() == (mode == "expected-build"), (mode, "pre-dlopen admission ran candidate initialization")
            self.steps[-1]["candidate_init_executed"] = sentinel.exists()
            self.steps[-1]["candidate_sha256"] = sha(candidate)
            # Restore the original main image for the next independent process.
            shutil.copyfile(original_main,
                            project / "bin" / ("libodinscripts" + self.ext))
        output.unlink()
        core = project / "bin" / ("libodin_godot" + self.ext)
        original_core = self.out / ("invalid-original-core" + self.ext)
        shutil.copyfile(core, original_core)
        for mode in ("build", "target"):
            candidate = self.out / ("bad-core-" + mode + self.ext)
            command = [self.args.odin, "build", str(ROOT / "core"), "-collection:godot=" + str(ROOT),
                       "-build-mode:dll", "-use-single-module", "-debug", "-out:" + str(candidate),
                       "-define:BOX3D_HOST_ENABLED=true",
                       "-define:BOX3D_EXPECTED_BUILD=sha256:" + ("0" * 64 if mode == "build" else profile["domain"]["build"]),
                       "-define:BOX3D_EXPECTED_TARGET=sha256:" + ("0" * 64 if mode == "target" else profile["domain"]["target"])]
            self.command("core-" + mode + "-invalid-build", command, env=env)
            shutil.copyfile(candidate, core)
            self.command("core-" + mode + "-godot-rejection", [self.args.godot, "--headless", "--path", str(project),
                         "--script", "test_rejected_core.gd"], env=env,
                         marker="BOX3D_GODOT_CORE_REJECTION_OK", expected_rejection=True)
            shutil.copyfile(original_core, core)

    def native_free(self):
        project = self.out / "native-free-project"
        (project / "scripts").mkdir(parents=True)
        for name in ("project.godot", "odin_godot.gdextension"):
            shutil.copyfile(SOURCE / name, project / name)
        (project / "scripts/pure.odin").write_text('''//gd:extends Node
//gd:class PureProbe
package pure_probe
import gd "godot:godot"
import r "godot:replay"
PureProbe :: struct {owner:gd.Node}
State :: struct {x:i64}
@(gd_method)
pure_probe_check :: proc(self:^PureProbe)->bool{return r.value_supported(State) && native_image_count()==0}
''')
        for path in (SOURCE / "modules/consumer").glob("images_*.odin"):
            (project / "scripts" / path.name).write_text(path.read_text().replace("package box3d_module_consumer", "package pure_probe"))
        (project / "test.gd").write_text('''extends SceneTree
func _init():process_frame.connect(run_test,CONNECT_ONE_SHOT)
func run_test():
 var n=Node.new()
 n.set_script(load("res://scripts/pure.odin"))
 root.add_child(n)
 if not n.call("check"):quit(1);return
 n.free()
 print("BOX3D_DEFAULT_NATIVEFREE_OK native_images=0")
 quit(0)
''')
        env = dict(self.env, ODIN_SCRIPTS_DLL=str(project / "bin" / ("libodinscripts" + self.ext)))
        env.pop("BOX3D_NATIVE_LIBRARY", None)
        self.command("native-free-build", ["bash", str(ROOT / "build/build_scripts.sh"), str(project)], env=env)
        assert not list((project / "bin").glob("*ogb3*")), "native-free build deployed a physics backend"
        # Explicit first-import preparation also works without the optional profile.
        self.command("native-free-bootstrap", ["python3", str(ROOT / "build/box3d_profile.py"), "--prepare-import", str(project)], env=env)
        self.command("native-free-godot", [self.args.godot, "--headless", "--path", str(project), "--script", "test.gd"],
                     env=env, marker="BOX3D_DEFAULT_NATIVEFREE_OK native_images=0")

    def execute(self):
        before = source_inventory()
        self.command("compiler-version", [self.args.odin, "version"])
        self.build("initial-sdk-build")
        self.command("prepared-first-import", [self.args.godot, "--headless", "--path", str(self.project), "--import"])
        for name in ("domain", "surface", "capsule", "kit_capsule", "quota", "contexts"):
            self.godot(name, "test_" + name + ".gd")
        self.build("brand-one-before-replay-reload")
        self.godot("replay-reload", "test_reload_capsule.gd")
        self.build("brand-one-before-kit-reload")
        self.godot("kit-reload", "test_reload_capsule.gd", "--", "--kit")
        self.negative_modules()
        self.native_free()
        after = source_inventory()
        assert before == after, "SDK/control sources changed during matrix; rebuild one coherent set"
        profile = json.loads((self.project / "bin/box3d-runtime.json").read_text())
        artifacts = {str(path.relative_to(self.out)): sha(path) for folder in ("project", "invalid-project", "native-free-project")
                     for path in (self.out / folder / "bin").iterdir()
                     if path.is_file() and path.suffix in (".dylib", ".so", ".json")}
        report = {"schema_version": 1, "status": "actual Godot SDK ownership matrix passed",
                  "scope": "shared domain, typed/context rejection, quota and detached owner/reload correctness",
                  "gate_b_whole_4ms": "UNMET; no whole wire correction performance acceptance",
                  "upstream_import": "prepared startup discovery; unprepared engine defect remains separate",
                  "godot": self.args.godot, "godot_sha256": sha(self.args.godot),
                  "platform": dict(zip(("sysname", "nodename", "release", "version", "machine"), os.uname())),
                  "execution_note": self.args.execution_note,
                  "compiler": self.args.odin, "compiler_sha256": sha(shutil.which(self.args.odin) or self.args.odin),
                  "native_input": str(self.args.native.resolve()), "native_input_sha256": sha(self.args.native),
                  "profile": profile, "sources": before, "artifacts": artifacts, "steps": self.steps}
        (self.out / "matrix-report.json").write_text(json.dumps(report, indent=2) + "\n")
        return report


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--native", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--godot", default=os.environ.get("GODOT"), required=os.environ.get("GODOT") is None)
    parser.add_argument("--odin", default=os.environ.get("ODIN", "odin"))
    parser.add_argument("--cc", default=os.environ.get("CC", "clang"))
    parser.add_argument("--execution-note", default="Functional host execution; throughput is not measured by this matrix")
    args = parser.parse_args()
    runner = Run(args)
    report = runner.execute()
    print(json.dumps({"status": report["status"], "steps": len(report["steps"]), "out": str(runner.out)}))


if __name__ == "__main__":
    main()
