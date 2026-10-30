#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
web="$1";work="$2";mkdir "$work"
python3 - "$ROOT" "$web" "$work" <<'PY'
from pathlib import Path
import sys,json,hashlib,shutil
root,web,out=map(Path,sys.argv[1:]);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((web/'prepared.json').read_text()).items():assert sha(web/'project'/name)==digest,name
shutil.copy2(root/'tests/replay_cave_adoption/browser.mjs',out/'driver.mjs')
(out/'inputs.json').write_text(json.dumps({'driver':sha(out/'driver.mjs'),'export':{p.name:sha(p) for p in (web/'project/out').iterdir() if p.is_file()}},indent=2)+'\n')
PY
server_project="$ROOT/tests/replay_web_authority/server";ext=so;if [[ "$(uname -s)" == Darwin ]];then ext=dylib;fi
port=$((21000+RANDOM%9000));control=$((31000+RANDOM%9000));http="";server=""
trap 'for pid in "$http" "$server";do [[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true; };done' EXIT
bash "$ROOT/tests/web/serve.sh" "$web/project/out" "$port" >"$work/http.log" 2>&1 &http=$!
RWA_SIGNAL=1 RWA_GAME=cave RWA_PORT="$control" RWA_DB="$work/authority.sqlite" RWA_DONE="$work/done" ODIN_SCRIPTS_DLL="$server_project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$server_project" >"$work/server.log" 2>&1 &server=$!
for _ in {1..100};do if rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log";then break;fi;sleep 0.1;done
RCB_SOCIAL=1 RCB_LOBBY=1 RCB_LOGS="$work/browser" node "$ROOT/tests/replay_cave_adoption/browser.mjs" "http://127.0.0.1:$port/index.html" "ws://127.0.0.1:$control/control" planned >"$work/driver.log" 2>&1
touch "$work/done";wait "$server";server=""
if rg -q 'WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:|instances were leaked' "$work/server.log";then exit 1;fi
cat "$work/driver.log"
