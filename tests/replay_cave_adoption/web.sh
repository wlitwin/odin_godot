#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
native="$1";work="$2";mkdir -p "$work"
python3 - "$native" "$work" <<'PY'
from pathlib import Path
import shutil,sys,json,hashlib
native,out=map(Path,sys.argv[1:]);project=out/'project';shutil.copytree(native/'project',project,ignore=shutil.ignore_patterns('.godot','out'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'prepared.json').write_text(json.dumps({str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file() and 'bin' not in p.parts and not p.name.endswith('.gen.odin')},indent=2)+'\n')
PY
project="$work/project";server_project="$ROOT/tests/replay_web_authority/server"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$project" >"$work/build.log" 2>&1
bash "$ROOT/build/build_scripts.sh" "$server_project" >"$work/server-build.log" 2>&1
ODIN_SCRIPTS_DLL="$server_project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$server_project" --editor --quit-after 90 >"$work/server-import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$server_project" "$work/server-wait.json"
bash "$ROOT/build/build_scripts.sh" "$server_project" >"$work/server-final-build.log" 2>&1
mkdir -p "$project/out";touch "$project/out/.gdignore"
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/server-import.log" "$work/export.log";then exit 1;fi
bash "$ROOT/tests/replay_cave_adoption/execute_web.sh" "$work" "$work/run"
