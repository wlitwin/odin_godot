#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="$1";mkdir -p "$work"
python3 - "$ROOT" "$work" <<'PY'
from pathlib import Path
import shutil,sys
root,out=map(Path,sys.argv[1:]);shutil.copytree(root/'tests/replay_migration',out/'project',ignore=shutil.ignore_patterns('.godot','bin','*.gen.odin'))
PY
project="$work/project";case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
"$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build.log" 2>&1
