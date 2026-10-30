#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
out="${REPLAY_NODES_OUT:?Set a fresh absolute directory}"
python3 - "$ROOT" "$out" "${REPLAY_NODES_BASELINE:-}" <<'PY'
from pathlib import Path
import shutil,sys
root,out=map(Path,sys.argv[1:3]);out.mkdir(parents=True,exist_ok=True)
shutil.copytree(root/'tests/replay_nodes',out/'current',ignore=shutil.ignore_patterns('bin','.godot','*.gen.odin'))
if sys.argv[3]:
 collection=out/'baseline-collection';collection.mkdir()
 shutil.copytree(root/'replay',collection/'replay')
 baseline=Path(sys.argv[3]).read_text()
 baseline=baseline.replace('package replay_godot\n','package replay_godot_scene\n',1)
 (collection/'replay/godot/scene/nodes.odin').write_text(baseline)
 for name in ['core','godot','gdext','libgd','runtime','decl','flow','flowgd','events','kit','play','scriptgen','build']:
  (collection/name).symlink_to(root/name,target_is_directory=True)
 shutil.copytree(root/'tests/replay_nodes',out/'baseline',ignore=shutil.ignore_patterns('bin','.godot','*.gen.odin'))
PY
case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
modes=current;if [[ -n "${REPLAY_NODES_BASELINE:-}" ]];then modes="baseline current";fi
for mode in $modes;do
 collection="$ROOT";flags="-o:speed"
 if [[ "$mode" == baseline ]];then collection="$out/baseline-collection";flags="$flags -define:REPLAY_NODES_LEGACY=true";fi
 project="$out/$mode";export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
 ODIN_GODOT_ROOT="$collection" SCRIPT_BUILD_FLAGS="$flags" bash "$ROOT/build/build_scripts.sh" "$project" >"$out/$mode-build.log" 2>&1
 ODIN_GODOT_ROOT="$collection" SCRIPT_BUILD_FLAGS="$flags" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$out/$mode-import.log" 2>&1
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$out/$mode-wait.json"
 ODIN_GODOT_ROOT="$collection" SCRIPT_BUILD_FLAGS="$flags" bash "$ROOT/build/build_scripts.sh" "$project" >"$out/$mode-final-build.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$out/$mode-import.log";then cat "$out/$mode-import.log";exit 1;fi
done
odin check "$out/current/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -custom-attribute:gd_method >"$out/wasm.log" 2>&1
echo REPLAY_NODES_BUILD_OK
