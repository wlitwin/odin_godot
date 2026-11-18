"""Build the ordinary tool module and exercise partial previews in the editor."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--native-library", type=Path, required=True)
parser.add_argument("--out", type=Path)
args = parser.parse_args()
WORK = (args.out or Path(tempfile.mkdtemp(prefix="odin-box3d-preview-"))).resolve()
if args.out:
    WORK.mkdir(parents=True, exist_ok=False)
PROJECT = WORK / "project"
shutil.copytree(Path(__file__).with_name("project"), PROJECT)
shutil.copytree(ROOT / "addons/box3d_authoring", PROJECT / "addons/box3d_authoring")
shutil.copytree(ROOT / "addons/box3d_authoring/tool_module", PROJECT / "modules/box3d_authoring_tools", ignore=shutil.ignore_patterns(".gdignore"))
shutil.copytree(ROOT / "tests/box3d_editor/godot/project/scripts", PROJECT / "scripts")
shutil.copy2(ROOT / "tests/box3d_editor/godot/project/odin_godot.gdextension", PROJECT)
engine = WORK / "engine"
engine.mkdir()
original = Path(os.environ.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")).resolve()
if original.parent.name == "MacOS" and original.parent.parent.name == "Contents":
    subprocess.run(["/bin/cp", "-c", "-R", str(original.parents[2]), str(engine / "Godot.app")], check=True)
    godot = engine / "Godot.app/Contents/MacOS" / original.name
else:
    godot = engine / original.name
    shutil.copy2(original, godot)
(engine / "_sc_").touch()
env = {key: value for key, value in os.environ.items() if not key.startswith("BOX3D_") and key not in ("ODIN_GODOT_ROOT", "ODIN_SCRIPTS_DLL")}
env.update(ODIN_GODOT_ROOT=str(ROOT), GODOT=str(godot), BOX3D_NATIVE_LIBRARY=str(args.native_library.resolve()))
rows = []
print("Box3D preview evidence:", WORK, flush=True)
for name, command, marker in [
    ("build", ["bash", ROOT / "build/build_scripts.sh", PROJECT], "Built:"),
    ("import", [godot, "--headless", "--editor", "--path", PROJECT, "--quit-after", "120"], None),
    ("editor", [godot, "--headless", "--editor", "--path", PROJECT, "--quit-after", "900"], "BOX3D_PARTIAL_PREVIEW_OK"),
]:
    log = WORK / (name + ".log")
    with log.open("w") as stream:
        result = subprocess.run([str(part) for part in command], cwd=ROOT, env=dict(env, BOX3D_PREVIEW_CHECK="1" if name == "editor" else "0"), stdout=stream, stderr=subprocess.STDOUT, timeout=240)
    text = log.read_text(errors="replace")
    passed = result.returncode == 0 and (marker is None or marker in text) and not any(value in text for value in ("SCRIPT ERROR", "\nERROR:", "leaked at exit", "resources still in use", "ODIN_SCRIPT_PANIC"))
    rows.append(dict(step=name, exit=result.returncode, passed=passed, log=str(log)))
    (WORK / "report.json").write_text(json.dumps(rows, indent=2) + "\n")
    print(name, "PASS" if passed else "FAIL", flush=True)
    if not passed:
        print(text[-7000:])
        raise SystemExit(1)
print("BOX3D_PREVIEW_OK", WORK)
