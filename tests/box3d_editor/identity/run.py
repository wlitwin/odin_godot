"""Real editor identity/UndoRedo/persistence gate; no Odin/native backend required."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--bake", action="store_true", help="also compile and run the shared Odin baker against the actual editor output")
args = parser.parse_args()
WORK = Path(tempfile.mkdtemp(prefix="odin-box3d-identity-")).resolve()
PROJECT = WORK / "project"
shutil.copytree(Path(__file__).with_name("project"), PROJECT)
shutil.copytree(ROOT / "addons/box3d_authoring", PROJECT / "addons/box3d_authoring")
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
print("Box3D identity evidence:", WORK, flush=True)
rows = []
def run(name, command, marker=None):
    log = WORK / (name + ".log")
    with log.open("w") as stream:
        result = subprocess.run(
            [str(part) for part in command], cwd=ROOT,
            env=dict(os.environ, BOX3D_IDENTITY_CHECK="1" if name == "editor" else "0"),
            stdout=stream, stderr=subprocess.STDOUT, timeout=120,
        )
    text = log.read_text(errors="replace")
    passed = result.returncode == 0 and (marker is None or marker in text) and not any(
        failure in text for failure in ("SCRIPT ERROR", "\nERROR:", "leaked at exit", "resources still in use")
    )
    rows.append(dict(step=name, exit=result.returncode, passed=passed, log=str(log)))
    (WORK / "report.json").write_text(json.dumps(rows, indent=2) + "\n")
    print(name, "PASS" if passed else "FAIL", flush=True)
    if not passed:
        print(text[-7000:])
        raise SystemExit(1)

for name, options, marker in [
    ("import", ["--editor", "--quit-after", "120"], None),
    ("editor", ["--editor", "--quit-after", "900"], "BOX3D_IDENTITY_EDITOR_OK"),
    ("reload", ["--script", "verify.gd"], "BOX3D_IDENTITY_RELOAD_OK"),
]:
    run(name, [godot, "--headless", "--path", PROJECT, *options], marker)
if args.bake:
    binary = WORK / ("bake.exe" if os.name == "nt" else "bake")
    run("bake-build", [os.environ.get("ODIN", "odin"), "build", Path(__file__).with_name("bake"), "-collection:godot=" + str(ROOT), "-out:" + str(binary)])
    run("bake", [binary, PROJECT / "definition-before.json", PROJECT / "definition.json"], "BOX3D_IDENTITY_BAKE_OK")
print("BOX3D_IDENTITY_OK", WORK)
