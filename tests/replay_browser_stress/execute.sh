#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
source="${1:?Built browser stress directory}";work="${2:?Fresh runtime directory}";SERVER="$ROOT/tests/replay_web_authority/server"
[[ ! -e "$work" ]] || { echo "Runtime output must be fresh" >&2;exit 2; };mkdir -p "$work"
python3 - "$source" "$work" "$ROOT" <<'PY'
from pathlib import Path
import hashlib,json,shutil,sys
source,out,repo=map(lambda x:Path(x).resolve(),sys.argv[1:])
for name in ('kit','replay'):(out/name).symlink_to(source/name,target_is_directory=True)
for name in ('contract.json','browser-contract.json','browser-build.json','framework-source.json','source-sha256.txt'):shutil.copy2(source/name,out/name)
for line in (source/'source-sha256.txt').read_text().splitlines():
 h,name=line.split('  ',1);assert hashlib.sha256((source/name).read_bytes()).hexdigest()==h,name
for name,h in json.loads((source/'browser-build.json').read_text())['binaries'].items():assert hashlib.sha256((source/name).read_bytes()).hexdigest()==h,name
(out/'runtime-provenance.json').write_text(json.dumps({'built_source':str(source),'harness':{str(p.relative_to(repo)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (repo/'tests/replay_browser_stress').glob('*') if p.is_file()}},indent=2)+'\n')
PY
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
[[ -e "$ROOT/tests/replay_browser_stress/node_modules" ]] || ln -s "$ROOT/tests/web/node_modules" "$ROOT/tests/replay_browser_stress/node_modules"
port=$((21000+RANDOM%8000));control=$((31000+RANDOM%8000));pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Browser stress logs: $work"' EXIT
bash "$ROOT/tests/web/serve.sh" "$source/replay/project/out" "$port" >"$work/http.log" 2>&1 &pids+=("$!")
RWA_SIGNAL=1 RWA_SIGNAL_ONLY=1 RWA_SIGNAL_MEMBERS=2 RWA_GAME=scrapyard RWA_PORT="$control" RWA_DB="$work/authority.sqlite" RWA_DONE="$work/done" ODIN_SCRIPTS_DLL="$SERVER/bin/libodinscripts.$ext" "$GODOT" --headless --path "$SERVER" >"$work/server.log" 2>&1 &pids+=("$!")
for _ in {1..100};do if rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log";then break;fi;sleep .1;done
rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log"
node "$ROOT/tests/replay_browser_stress/drive.mjs" "http://127.0.0.1:$port/index.html" "ws://127.0.0.1:$control/control" "$work/browser" | tee "$work/driver.log"
touch "$work/done";wait "${pids[1]}"
if rg -q 'WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:|instances were leaked' "$work/server.log";then cat "$work/server.log";exit 1;fi
python3 "$ROOT/tests/replay_browser_stress/report.py" "$work"
