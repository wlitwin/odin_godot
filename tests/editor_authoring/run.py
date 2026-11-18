from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
work = Path(tempfile.mkdtemp(prefix="odin-editor-authoring-")).resolve()
(work / "scripts").mkdir()
(work / "scripts/seed.odin").write_text('package editor_fixture\nimport gd "godot:godot"\nSeed :: struct {owner: gd.Node}\n')
(work / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Editor Authoring"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
(work / "emitter.gd").write_text('extends Node\nsignal payload(value)\nsignal body_seen(body: Node2D)\nsignal helper\n')
plugin = work / "addons/acceptance"
plugin.mkdir(parents=True)
(plugin / "plugin.cfg").write_text('[plugin]\nname="Authoring checks"\nscript="plugin.gd"\n')
(plugin / "plugin.gd").write_text('''@tool
extends EditorPlugin
func _enter_tree() -> void:
    if OS.get_environment("EDITOR_AUTHORING_CHECK") == "1":
        call_deferred("run")
func run() -> void:
    assert(EditorInterface.get_editor_paths().is_self_contained())
    add_child(load("res://editor.gd").new())
''')
with (work / "project.godot").open("a") as settings:
    settings.write('[editor_plugins]\nenabled=PackedStringArray("res://addons/acceptance/plugin.cfg")\n')
shutil.copyfile(ROOT / "examples/survivors/odin_godot.gdextension", work / "odin_godot.gdextension")
for name in ("editor.gd", "runtime.gd"):
    shutil.copyfile(Path(__file__).parent / name, work / name)
env = {key: value for key, value in os.environ.items()
       if key not in ("ODIN_SCRIPTS_DLL", "ODIN_GODOT_ROOT") and not key.startswith("BOX3D_")}
godot = env.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
# Isolate editor preferences without modifying HOME or the installed app.
# Preserve the macOS bundle: its signed executable requires the bundled plist.
engine = work / ".engine"
engine.mkdir()
original = Path(godot).resolve()
if original.parent.name == "MacOS" and original.parent.parent.name == "Contents":
    bundle = original.parents[2]
    subprocess.run(["/bin/cp", "-c", "-R", str(bundle), str(engine / bundle.name)], check=True)
    local_engine = engine / bundle.name / "Contents/MacOS" / original.name
else:
    local_engine = engine / original.name
    shutil.copy2(original, local_engine)
(engine / "_sc_").touch()
godot = str(local_engine)
print("Editor authoring evidence:", work, flush=True)
commands = [
    ("build", ["bash", str(ROOT / "build/build_scripts.sh"), str(work)], "Built:"),
    ("import", [godot, "--editor", "--headless", "--path", str(work), "--quit-after", "60"], None),
    ("editor", [godot, "--editor", "--headless", "--verbose", "--path", str(work)], "EDITOR_AUTHORING_UI_OK"),
    ("runtime", [godot, "--headless", "--path", str(work), "--script", "runtime.gd"], "EDITOR_AUTHORING_RUNTIME_OK"),
]
for name, command, marker in commands:
    with (work / (name + ".log")).open("w") as log:
        try:
            run_env = dict(env, EDITOR_AUTHORING_CHECK="1" if name == "editor" else "0")
            result = subprocess.run(command, env=run_env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
        except subprocess.TimeoutExpired:
            print((work / (name + ".log")).read_text(errors="replace")[-6000:])
            raise
    output = (work / (name + ".log")).read_text(errors="replace")
    if result.returncode or (marker and marker not in output) or any(bad in output for bad in (
        "SCRIPT ERROR:", "\nERROR:", "ODIN_SCRIPT_PANIC", "ODIN_GODOT_CRASH", "background scripts build FAILED",
    )):
        print(output[-6000:])
        raise RuntimeError(f"{name} failed (exit {result.returncode}); log: {work / (name + '.log')}")
    print(name, "PASS", flush=True)
print("EDITOR_AUTHORING_OK", work)
