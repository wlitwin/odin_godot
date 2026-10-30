#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1";project="$work/project";mkdir -p "$work"
python3 - "$ROOT" "$project" <<'PY'
from pathlib import Path
import shutil,sys,json,hashlib
root,project=map(Path,sys.argv[1:]);shutil.copytree(root/'examples/replay_room_service',project,ignore=shutil.ignore_patterns('.godot','bin','out','addons','*.gen.odin','*.uid','*.import'))
(project.parent/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in project.rglob('*') if p.is_file()},indent=2)+'\n')
PY
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then tail -40 "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build.log" 2>&1
