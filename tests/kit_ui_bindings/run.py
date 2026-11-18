from pathlib import Path
import os
import platform
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(tempfile.mkdtemp(prefix="odin-kit-ui-")).resolve()
PROJECT = WORK / "project"
shutil.copytree(Path(__file__).parent, PROJECT, ignore=shutil.ignore_patterns("__pycache__", "bin", ".godot", "*.gen.odin"))
shutil.copytree(ROOT / "kit/ui/templates", PROJECT / "templates")
with (PROJECT / "project.godot").open("a") as stream:
    stream.write('[editor_plugins]\nenabled=PackedStringArray("res://addons/acceptance/plugin.cfg")\n')
env = {k: v for k, v in os.environ.items() if k not in ("ODIN_SCRIPTS_DLL", "ODIN_GODOT_ROOT") and not k.startswith("BOX3D_")}
engine = WORK / "engine"
engine.mkdir()
original = Path(env.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")).resolve()
if original.parent.name == "MacOS" and original.parent.parent.name == "Contents":
    bundle = original.parents[2]
    subprocess.run(["/bin/cp", "-c", "-R", str(bundle), str(engine / bundle.name)], check=True)
    godot = engine / bundle.name / "Contents/MacOS" / original.name
else:
    godot = engine / original.name
    shutil.copy2(original, godot)
(engine / "_sc_").touch()
print("Kit UI evidence:", WORK, flush=True)

def run(name, args, marker=None, overrides=None):
    log = WORK / (name + ".log")
    with log.open("w") as stream:
        result = subprocess.run([str(a) for a in args], cwd=ROOT, env=dict(env, **(overrides or {})), stdout=stream, stderr=subprocess.STDOUT, timeout=180)
    text = log.read_text(errors="replace")
    clean = text
    if name.startswith("runtime"):
        begin, end = "KIT_UI_EXPECTED_REJECTION_BEGIN", "KIT_UI_EXPECTED_REJECTION_END"
        if text.count(begin) != 1 or text.count(end) != 1:
            raise RuntimeError(f"{name}: missing bounded rejection; {log}")
        expected = text.split(begin, 1)[1].split(end, 1)[0]
        if "Chat.input" not in expected or "Scoreboard.grid" not in expected or "Kit UI setup failed" not in expected:
            raise RuntimeError(f"{name}: wrong setup rejection; {log}")
        if expected.count("ERROR:") != 1 or "SCRIPT ERROR" in expected or "CRASH" in expected:
            raise RuntimeError(f"{name}: invalid failure path; {log}")
        clean = text.split(begin, 1)[0] + text.split(end, 1)[1]
    bad = ("SCRIPT ERROR", "\nERROR:", "ODIN_SCRIPT_PANIC", "ODIN_GODOT_CRASH", "leaked at exit", "resources still in use", "background scripts build FAILED")
    if result.returncode or (marker and marker not in text) or any(value in clean for value in bad):
        print(text[-7000:])
        raise RuntimeError(f"{name}: exit {result.returncode}; {log}")
    print(name, "PASS", flush=True)

run("build", ["bash", ROOT / "build/build_scripts.sh", PROJECT], "Built:")
run("import", [godot, "--headless", "--editor", "--path", PROJECT, "--quit-after", "80"])
# Exercise Core's private native-return writers against actual 24-byte engine
# slots without shipping a test hook or altering the shared source tree.
sdk = WORK / "probe-sdk"
shutil.copytree(ROOT / "core", sdk / "core")
(sdk / "kit").symlink_to(ROOT / "kit", target_is_directory=True)
main = sdk / "core/main.odin"
main.write_text(main.read_text().replace("    ui_bindings_register()", "    ui_bindings_register()\n    variant_slots_probe()"))
shutil.copyfile(Path(__file__).parent / "native_slots.odin.txt", sdk / "core/variant_slots_probe.odin")
ext = {"Darwin": "dylib", "Windows": "dll"}.get(platform.system(), "so")
probe_core = WORK / ("probe-core." + ext)
run("native-slots-build", [env.get("ODIN", "odin"), "build", sdk / "core", "-collection:godot=" + str(ROOT), "-build-mode:dll", "-out:" + str(probe_core)])
os.replace(probe_core, PROJECT / "bin" / ("libodin_godot." + ext))
run("runtime", [godot, "--headless", "--path", PROJECT, "--script", "runtime.gd"], "KIT_UI_RUNTIME_OK")
if "KIT_UI_NATIVE_VARIANT_SLOTS_OK" not in (WORK / "runtime.log").read_text():
    raise RuntimeError("native Variant slot probe did not execute")
run("editor", [godot, "--headless", "--editor", "--path", PROJECT], "KIT_UI_EDITOR_OK", {"KIT_UI_EDITOR_CHECK": "1"})
run("release-build", ["bash", ROOT / "build/build_scripts.sh", PROJECT], "Built:", {"SCRIPT_BUILD_FLAGS": "-o:speed -disable-assert"})
run("runtime-release", [godot, "--headless", "--path", PROJECT, "--script", "runtime.gd"], "KIT_UI_RUNTIME_OK")
print("KIT_UI_BINDINGS_OK", WORK)
