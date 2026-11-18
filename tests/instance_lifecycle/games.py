"""Exercise the actual Kit games, including gameplay, reparent and script removal."""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(tempfile.mkdtemp(prefix="odin-kit-game-lifecycle-")).resolve()
GAMES = [
    ("slopball", "SLOP", "Slopball", "slopball"),
    ("slopball3d", "SLOP3", "Slopball3", "slopball3"),
    ("quickdraw", "QD", "Quickdraw", "quickdraw"),
    ("claimball", "CLB", "Claimball", "claimball"),
    ("speedball", "SPB", "Speedball", "speedball"),
    ("cavecrawl", "CAVE", "CaveLobby", "cave_lobby"),
]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--game", action="append", choices=[row[0] for row in GAMES])
args = parser.parse_args()
PROBE = '''package $PACKAGE
import gd "godot:godot"
import kboot "godot:kit/boot"

@(gd_method)
$PREFIX_lifecycle_probe :: proc(self: ^$CLASS) -> u64 {
    if !self.ses.ran || !self.ses.is_host || !self.ses.replicating ||
       kboot.boot_phase(&self.boot) != .Playing || self.boot.world == nil {
        return 0
    }
    if gd.node_get_child_count(self.boot.world, false) == 0 {return 0}
    return u64(gd.object_get_instance_id(cast(gd.Object)self.boot.world))
}
'''
base_env = {
    k: v for k, v in os.environ.items()
    if k not in ("ODIN_SCRIPTS_DLL", "ODIN_GODOT_ROOT") and not k.startswith("BOX3D_")
    and not any(k.startswith(prefix + "_") for _, prefix, _, _ in GAMES)
}
base_env["ODIN_GODOT_ROOT"] = str(ROOT)
godot = base_env.get("GODOT", "/Applications/Godot.app/Contents/MacOS/Godot")
rows = []
print("Kit game lifecycle evidence:", WORK, flush=True)

for index, (name, env_prefix, cls, proc_prefix) in enumerate(GAMES):
    if args.game and name not in args.game:
        continue
    project = WORK / name
    shutil.copytree(
        ROOT / "examples" / name, project,
        ignore=shutil.ignore_patterns(".godot", "bin", "*.gen.odin", "*.import", ".runlogs"),
    )
    shutil.copy2(Path(__file__).with_name("games.gd"), project / "lifecycle.gd")
    package = "cavecrawl_scripts" if name == "cavecrawl" else name
    probe = PROBE.replace("$PACKAGE", package).replace("$PREFIX", proc_prefix).replace("$CLASS", cls)
    (project / "scripts/lifecycle_probe.odin").write_text(probe)
    env = dict(base_env, **{
        env_prefix + "_ROLE": "single",
        env_prefix + "_PORT": str(46200 + index),
        env_prefix + "_BOT": "lifecycle-owned",
        env_prefix + "_TOKEN": "lifecycle-" + name,
        "CAVE_STEAM": "0",
        "CAVE_SAVE": str(WORK / "cave-save.fslp"),
        "LIFECYCLE_CAVE": "1" if name == "cavecrawl" else "0",
    })
    for step, args, marker in [
        ("build", ["bash", ROOT / "build/build_scripts.sh", project], "Built:"),
        # Exercise ordinary editor startup. The separate fast --import shutdown
        # race in Godot's deferred extension docs is tracked in P3-06.
        ("editor", [godot, "--headless", "--editor", "--path", project, "--quit-after", "120"], None),
        ("runtime", [godot, "--headless", "--path", project, "--script", "lifecycle.gd"], "GAME_LIFECYCLE_OK"),
    ]:
        log = WORK / (name + "-" + step + ".log")
        with log.open("w") as stream:
            result = subprocess.run(
                [str(arg) for arg in args], cwd=ROOT, env=env, stdout=stream,
                stderr=subprocess.STDOUT, timeout=180,
            )
        text = log.read_text(errors="replace")
        passed = result.returncode == 0 and (marker is None or marker in text) and not any(
            failure in text for failure in (
                "SCRIPT ERROR", "\nERROR:", "leaked at exit", "resources still in use",
                "ODIN_SCRIPT_PANIC", "ODIN_GODOT_CRASH",
            )
        )
        if step == "runtime":
            passed = passed and all(text.count("GAME_LIFECYCLE_CYCLE " + str(i)) == 1 for i in range(2))
        rows.append(dict(game=name, step=step, exit=result.returncode, passed=passed, log=str(log)))
        (WORK / "results.json").write_text(json.dumps(rows, indent=2) + "\n")
        print(name, step, "PASS" if passed else "FAIL", flush=True)
        if not passed:
            print(text[-6000:])
            raise SystemExit(1)

print("KIT_GAME_LIFECYCLE_OK", WORK)
