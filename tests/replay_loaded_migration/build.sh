#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${1:?Fresh build output}";mkdir -p "$work";SERVER="$work/server/project"
python3 "$ROOT/tests/replay_loaded_migration/prepare.py" "$work" >"$work/prepare.log"
python3 - "$ROOT" "$SERVER" <<'COPY'
from pathlib import Path
import shutil,sys
root,server=map(Path,sys.argv[1:]);shutil.copytree(root/'tests/replay_web_authority/server',server,ignore=shutil.ignore_patterns('.godot','bin','out','*.gen.odin','*.uid','*.import'))
COPY
PROJ="$work/replay/project";mkdir -p "$PROJ/out";touch "$PROJ/out/.gdignore"
node "$ROOT/tests/replay_loaded_migration/reliable_hold_test.mjs" >"$work/reliable-hold-test.log"
node "$ROOT/tests/replay_loaded_migration/capture_test.mjs" >"$work/capture-test.log"
node "$ROOT/tests/replay_browser_stress/faults_test.mjs" >"$work/fault-test.log"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
for project in "$SERVER" "$PROJ";do
 label=game;if [[ "$project" == "$SERVER" ]];then label=server;fi
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$label-build.log" 2>&1
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$label-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$label-import.log";then cat "$work/$label-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$label-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$label-final-build.log" 2>&1
done
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/export.log";then cat "$work/export.log";exit 1;fi
python3 - "$work" <<'PY'
from pathlib import Path
import hashlib,json,sys
w=Path(sys.argv[1]);files=[*w.glob('replay/project/bin/*.wasm'),*w.glob('replay/project/out/*'),*w.glob('replay/project/bin/*.dylib'),*w.glob('server/project/bin/*.dylib')];files=[p for p in files if p.is_file() and p.suffix in ('.wasm','.dylib','.pck','.js','.html')]
(w/'browser-build.json').write_text(json.dumps({'odin_optimization':'speed','binaries':{str(p.relative_to(w)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}},indent=2)+'\n')
PY
echo REPLAY_LOADED_MIGRATION_BUILT
