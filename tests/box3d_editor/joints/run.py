"""Real body picker/anchor/undo and detached scene persistence acceptance."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--bake", action="store_true")
args = parser.parse_args()
WORK = Path(tempfile.mkdtemp(prefix="odin-box3d-joints-")).resolve()
PROJECT = WORK / "project"
shutil.copytree(Path(__file__).with_name("project"), PROJECT)
shutil.copytree(ROOT / "addons/box3d_authoring", PROJECT / "addons/box3d_authoring")
for label, example in [("shared", "box3d_authoring_shared"), ("dockyard", "replay_dockyard")]:
    destination = PROJECT / "legacy" / label
    shutil.copytree(ROOT / "examples" / example / "content", destination)
    for path in destination.rglob("*"):
        if path.suffix in (".tscn", ".tres"):
            path.write_text(path.read_text().replace("res://content/", "res://legacy/" + label + "/"))
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
rows = []
print("Box3D joint evidence:", WORK, flush=True)
commands = [
    ("import", ["--editor", "--quit-after", "120"], None),
    ("editor", ["--editor", "--quit-after", "900"], "BOX3D_JOINT_EDITOR_OK"),
    ("reload", ["--script", "verify.gd"], "BOX3D_JOINT_RELOAD_OK"),
    ("legacy", ["--script", "legacy.gd"], "BOX3D_JOINT_LEGACY_OK"),
]
commands = [(name, [godot, "--headless", "--path", PROJECT, *options], marker) for name, options, marker in commands]
if args.bake:
    binary = WORK / ("bake.exe" if os.name == "nt" else "bake")
    commands += [
        ("bake-build", [os.environ.get("ODIN", "odin"), "build", Path(__file__).with_name("bake"), "-collection:godot=" + str(ROOT), "-out:" + str(binary)], None),
        ("bake", [binary, PROJECT / "joint-expected.json"], "BOX3D_JOINT_BAKE_OK"),
    ]
for name, command, marker in commands:
    log = WORK / (name + ".log")
    with log.open("w") as stream:
        result = subprocess.run([str(part) for part in command], cwd=ROOT, env=dict(os.environ, BOX3D_JOINT_CHECK="1" if name == "editor" else "0"), stdout=stream, stderr=subprocess.STDOUT, timeout=120)
    text = log.read_text(errors="replace")
    passed = result.returncode == 0 and (marker is None or marker in text) and not any(value in text for value in ("SCRIPT ERROR", "\nERROR:", "leaked at exit", "resources still in use"))
    rows.append(dict(step=name, exit=result.returncode, passed=passed, log=str(log)))
    (WORK / "report.json").write_text(json.dumps(rows, indent=2) + "\n")
    print(name, "PASS" if passed else "FAIL", flush=True)
    if not passed:
        print(text[-7000:])
        raise SystemExit(1)
print("BOX3D_JOINTS_OK", WORK)
