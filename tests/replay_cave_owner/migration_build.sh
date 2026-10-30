#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1";python3 "$ROOT/examples/replay_cavecrawl_owned/prepare.py" "$work"
python3 - "$ROOT" "$work" <<'PY'
from pathlib import Path
import hashlib,json,shutil,sys
root,out=map(Path,sys.argv[1:]);project=out/'project'
shutil.copy2(root/'tests/replay_cave_carrier/probe.odin',project/'scripts/carrier_probe.odin')
manifest=json.loads((out/'prepared.json').read_text());manifest['scripts/carrier_probe.odin']=hashlib.sha256((project/'scripts/carrier_probe.odin').read_bytes()).hexdigest();(out/'prepared.json').write_text(json.dumps(manifest,indent=2)+'\n')
shutil.copytree(root/'tests/replay_migration',out/'coordinator',ignore=shutil.ignore_patterns('.godot','bin','addons','*.gen.odin','*.uid'))
PY
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
for kind in project coordinator;do
 project="$work/$kind"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$kind-build.log" 2>&1
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$kind-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$kind-import.log";then tail -40 "$work/$kind-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$kind-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$kind-final-build.log" 2>&1
done
