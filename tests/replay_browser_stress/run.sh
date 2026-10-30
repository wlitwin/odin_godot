#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_BROWSER_STRESS_OUT:-$(mktemp -d)}";mkdir -p "$work";SERVER="$ROOT/tests/replay_web_authority/server"
python3 "$ROOT/tests/replay_browser_stress/prepare.py" "$work" >"$work/prepare.log"
PROJ="$work/replay/project";mkdir -p "$PROJ/out";touch "$PROJ/out/.gdignore"
node "$ROOT/tests/replay_browser_stress/faults_test.mjs" >"$work/fault-test.log"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
for project in "$SERVER" "$PROJ";do
 label="$(basename "$project")"
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
w=Path(sys.argv[1]);files=[*w.glob('replay/project/bin/*.wasm'),*w.glob('replay/project/out/*.wasm'),*w.glob('replay/project/bin/*.dylib')]
(w/'browser-build.json').write_text(json.dumps({'odin_optimization':'speed','binaries':{str(p.relative_to(w)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}},indent=2)+'\n')
PY
[[ -e "$ROOT/tests/replay_browser_stress/node_modules" ]] || ln -s "$ROOT/tests/web/node_modules" "$ROOT/tests/replay_browser_stress/node_modules"
port=$((21000+RANDOM%8000));control=$((31000+RANDOM%8000));pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Browser stress logs: $work"' EXIT
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$port" >"$work/http.log" 2>&1 &pids+=("$!")
RWA_SIGNAL=1 RWA_SIGNAL_ONLY=1 RWA_SIGNAL_MEMBERS=2 RWA_GAME=scrapyard RWA_PORT="$control" RWA_DB="$work/authority.sqlite" RWA_DONE="$work/done" ODIN_SCRIPTS_DLL="$SERVER/bin/libodinscripts.$ext" "$GODOT" --headless --path "$SERVER" >"$work/server.log" 2>&1 &pids+=("$!")
for _ in {1..100};do if rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log";then break;fi;sleep .1;done
rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log"
node "$ROOT/tests/replay_browser_stress/drive.mjs" "http://127.0.0.1:$port/index.html" "ws://127.0.0.1:$control/control" "$work/browser" | tee "$work/driver.log"
touch "$work/done";wait "${pids[1]}"
if rg -q 'WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:|instances were leaked' "$work/server.log";then cat "$work/server.log";exit 1;fi
python3 "$ROOT/tests/replay_browser_stress/report.py" "$work"
