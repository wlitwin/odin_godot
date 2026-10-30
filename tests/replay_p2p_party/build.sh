#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
out="${REPLAY_P2P_PARTY_OUT:?Set a fresh absolute output directory}"
mkdir -p "$out"
python3 - "$ROOT" "$out" <<'PY'
from pathlib import Path
import shutil,sys
root,out=map(Path,sys.argv[1:])
for source,name in [('replay_duel','duel'),('replay_duel_service','service')]:
    target=out/name
    shutil.copytree(root/'examples'/source,target,ignore=shutil.ignore_patterns('bin','out','.godot','node_modules','*.gen.odin'),dirs_exist_ok=False)
PY
case "$(uname -s)" in Darwin) ext=dylib;; Linux) ext=so;; *) ext=dll;; esac
for name in duel service; do
    project="$out/$name"; export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
    bash "$ROOT/build/build_scripts.sh" "$project" >"$out/$name-build.log" 2>&1
    "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$out/$name-import.log" 2>&1
    python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$out/$name-wait.json"
    bash "$ROOT/build/build_scripts.sh" "$project" >"$out/$name-final-build.log" 2>&1
    if rg -q 'SCRIPT ERROR|ERROR:' "$out/$name-import.log"; then cat "$out/$name-import.log"; exit 1; fi
done
project="$out/duel"; export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
bash "$ROOT/build/build_web.sh" "$project" >"$out/duel-web-build.log" 2>&1
mkdir -p "$project/out"; touch "$project/out/.gdignore"
"$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$out/duel-export.log" 2>&1
cp "$project/web_lobby.html" "$project/out/lobby.html"
cp "$project/web_archive.js" "$project/out/web_archive.js"
python3 - "$project/out/index.html" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);p.write_text(p.read_text().replace('</head>','<script src="web_archive.js"></script></head>'))
PY
echo REPLAY_P2P_PARTY_BUILD_OK
