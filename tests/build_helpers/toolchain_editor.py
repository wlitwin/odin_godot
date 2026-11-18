"""Exercise editor reopen/save recovery with no compiler on its inherited PATH."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
work = Path(tempfile.mkdtemp(prefix="odin-toolchain-editor-")).resolve()
(work / "scripts").mkdir()
shutil.copyfile(ROOT / "tests/reload_exports/scripts/widget.odin", work / "scripts/widget.odin")
(work / "modules/extras").mkdir(parents=True)
(work / "modules/extras/extra.odin").write_text('''//gd:extends Node
package extra_scripts
import gd "godot:godot"
Extra :: struct {
    owner: gd.Node,
    speed: gd.Float `gd:"export"`,
    //NEW_FIELD_HERE
}
''')
shutil.copyfile(ROOT / "tests/build_helpers/toolchain_editor.gd", work / "driver.gd")
shutil.copyfile(ROOT / "examples/survivors/odin_godot.gdextension", work / "odin_godot.gdextension")
(work / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Toolchain Recovery"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
(work / "quit.gd").write_text('extends Node\nfunc _ready() -> void: get_tree().quit()\n')
(work / "main.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://quit.gd" id="1"]\n[node name="Main" type="Node"]\nscript=ExtResource("1")\n')
env = {key: value for key, value in os.environ.items()
       if key not in ("ODIN_GODOT_ROOT", "ODIN_SCRIPTS_DLL") and not key.startswith("BOX3D_")}
godot = env.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
with (work / "build.log").open("w") as log:
    subprocess.run(["bash", str(ROOT / "build/build_scripts.sh"), str(work)], env=env,
                   stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
env = {key: value for key, value in env.items()
       if key not in ("ODIN", "OLS", "ODINFMT", "EMCC", "DEVELOPER_DIR", "SDKROOT", "IN_NIX_SHELL")
       and not key.startswith("NIX_")}
env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
for name, args in (("import", ["--quit-after", "60"]), ("recovery", ["--script", "driver.gd"])):
    with (work / (name + ".log")).open("w") as log:
        result = subprocess.run([godot, "--headless", "--editor", "--path", str(work), *args],
                                env=env, stdout=log, stderr=subprocess.STDOUT, timeout=60)
    output = (work / (name + ".log")).read_text(errors="replace")
    print(name, "exit", result.returncode, "logs", work, flush=True)
    if result.returncode or any(word in output for word in ("SCRIPT ERROR:", "ODIN_SCRIPT_PANIC", "ODIN_GODOT_CRASH")):
        print(output[-5000:])
        raise SystemExit(1)
    if name == "recovery" and "TOOLCHAIN_EDITOR_RECOVERY_OK" not in output:
        print(output[-5000:])
        raise SystemExit(1)
    if name == "recovery" and "saved scripts could not be built because Odin was not found" not in output:
        raise AssertionError("Play did not exercise the missing-compiler gate")
print("TOOLCHAIN_EDITOR_OK", work)
