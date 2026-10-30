#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_STORM_OUT:?Choose a fresh absolute output directory}"
python3 - "$ROOT" "$work" <<'PY'
from pathlib import Path
import shutil,sys
root,out=map(Path,sys.argv[1:]);out.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'examples/replay_scrapyard',out/'project',ignore=shutil.ignore_patterns('.godot','bin','out','addons','*.gen.odin','*.uid','*.import','node_modules','__pycache__'))
shutil.copy2(root/'tests/replay_stormcaller/probe.odin',out/'project/scripts/storm_probe.odin')
for p in (root/'tests/replay_stormcaller').glob('*.gd'):shutil.copy2(p,out/'project'/('storm_'+p.name))
PY
project="$work/project";case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
"$GODOT" --headless --path "$project" --editor --import >"$work/import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build.log" 2>&1
odin check "$project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method -custom-attribute:gd_connect >"$work/wasm.log" 2>&1
if rg -q 'ERROR:|SCRIPT ERROR' "$work/import.log";then cat "$work/import.log";exit 1;fi
echo STORMCALLER_BUILD_OK
