#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_EDITOR_OUT:?Choose a fresh absolute output directory}"
python3 - "$ROOT" "$work" <<'PY'
from pathlib import Path
import shutil,sys,os
root,out=map(Path,sys.argv[1:]);out.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'examples/replay_scrapyard',out/'project',ignore=shutil.ignore_patterns('.godot','bin','out','addons','*.gen.odin','*.uid','*.import','node_modules','__pycache__'))
shutil.copy2(root/'tests/replay_editor/probe.odin',out/'project/scripts/editor_probe.odin')
for p in (root/'tests/replay_editor').glob('*.gd'):shutil.copy2(p,out/'project'/('editor_'+p.name))
if os.environ.get('REPLAY_ADAPTER_PROBES')=='1':
 shutil.copy2(root/'tests/replay_adapter/probe.odin',out/'project/scripts/adapter_probe.odin')
 for p in (root/'tests/replay_adapter').glob('*.gd'):shutil.copy2(p,out/'project'/('adapter_'+p.name))
(out/'project/dev/invalid_enemy.tscn').write_text('[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://entities/mob.tscn" id="enemy"]\n[node name="InvalidEnemy" instance=ExtResource("enemy")]\npreview = true\nappearance = null\n')
PY
project="$work/project";case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
"$GODOT" --headless --path "$project" --editor --import >"$work/import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build.log" 2>&1
odin check "$project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method -custom-attribute:gd_connect >"$work/wasm.log" 2>&1
if rg -q 'ERROR:|SCRIPT ERROR' "$work/import.log";then cat "$work/import.log";exit 1;fi
echo REPLAY_EDITOR_BUILD_OK
