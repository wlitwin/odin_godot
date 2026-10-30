#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1";python3 "$ROOT/tests/replay_cave_director/prepare.py" "$work";project="$work/project"
cp "$ROOT/tests/replay_cave_carrier/probe.odin" "$project/scripts/floor_probe.odin"
python3 - "$work" <<'PY'
from pathlib import Path
import json,hashlib,sys
out=Path(sys.argv[1]);project=out/'project';manifest=json.loads((out/'prepared.json').read_text());name='scripts/floor_probe.odin';manifest[name]=hashlib.sha256((project/name).read_bytes()).hexdigest();(out/'prepared.json').write_text(json.dumps(manifest,indent=2)+'\n')
PY
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then tail -35 "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build.log" 2>&1
odin build "$ROOT/examples/replay_cavecrawl/tools/upgrade_save" -collection:godot="$ROOT" -out:"$work/upgrade"
odin check "$project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method >"$work/wasm.log" 2>&1

coord="$ROOT/tests/replay_migration"
bash "$ROOT/build/build_scripts.sh" "$coord" >"$work/coordinator-build.log" 2>&1
ODIN_SCRIPTS_DLL="$coord/bin/libodinscripts.$ext" "$GODOT" --headless --path "$coord" --editor --quit-after 120 >"$work/coordinator-import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/coordinator-import.log";then exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$coord" "$work/coordinator-wait.json"
bash "$ROOT/build/build_scripts.sh" "$coord" >"$work/coordinator-final-build.log" 2>&1
