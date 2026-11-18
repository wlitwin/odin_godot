"""Verify the shipped starter surfaces the actual Session setup failure."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[2]
work = Path(tempfile.mkdtemp(prefix="replay-setup-ui-")).resolve()
shutil.copytree(root / "build/template/replay", work, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns("*.gen.odin", "*.uid", "bin", ".godot"))
shutil.copyfile(root / "examples/survivors/odin_godot.gdextension", work / "odin_godot.gdextension")
shutil.copyfile(Path(__file__).parent / "driver.gd", work / "driver.gd")
game = work / "shared/game/game.odin"
text = game.read_text()
assert "control_valid = control_valid," in text
game.write_text(text.replace("control_valid = control_valid,", "control_valid = nil,"))
env = {key: value for key, value in os.environ.items()
       if key not in ("ODIN_GODOT_ROOT", "ODIN_SCRIPTS_DLL") and not key.startswith("BOX3D_")}
env["REPLAY_STARTER_ROLE"] = "solo"
godot = env.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
print("Replay setup UI evidence:", work, flush=True)
for name, command, marker in (
    ("build", ["bash", str(root / "build/build_scripts.sh"), str(work)], "Built:"),
    ("import", [godot, "--headless", "--editor", "--path", str(work), "--quit-after", "60"], None),
    ("run", [godot, "--headless", "--path", str(work), "--script", "driver.gd"], "REPLAY_SETUP_UI_OK"),
):
    with (work / (name + ".log")).open("w") as log:
        result = subprocess.run(command, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
    output = (work / (name + ".log")).read_text(errors="replace")
    if result.returncode or (marker and marker not in output) or any(error in output for error in (
        "SCRIPT ERROR:", "\nERROR:", "ODIN_SCRIPT_PANIC", "ODIN_GODOT_CRASH", "leaked at exit",
    )):
        print(output[-5000:])
        raise RuntimeError(f"{name} failed ({result.returncode}); {work}")
    print(name, "PASS", flush=True)
print("REPLAY_SETUP_GODOT_OK", work)
