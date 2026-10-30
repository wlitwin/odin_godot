#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
source="${1:?Built fixture directory}";work="${2:?Fresh output directory}";server="$ROOT/tests/replay_web_authority/server"
[[ ! -e "$work" ]] || { echo 'Use a fresh output directory' >&2;exit 2; };mkdir -p "$work"
python3 - "$source" "$work" <<'PY'
from pathlib import Path
import hashlib,json,shutil,sys
source,out=map(lambda x:Path(x).resolve(),sys.argv[1:])
for name in ['source.json','framework.json']:shutil.copy2(source/name,out/name)
for name,h in json.loads((source/'source.json').read_text()).items():assert hashlib.sha256((source/'project'/name).read_bytes()).hexdigest()==h,name
(out/'project').symlink_to(source/'project',target_is_directory=True);(out/'native').symlink_to(source/'native',target_is_directory=True)
(out/'builds.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (source/'project/out').iterdir() if p.is_file() and p.suffix in ('.wasm','.pck','.js')},indent=2)+'\n')
PY
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
port=$((21000+RANDOM%8000));control=$((31000+RANDOM%7000));pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Observer recovery logs: $work"' EXIT
bash "$ROOT/tests/web/serve.sh" "$source/project/out" "$port" >"$work/http.log" 2>&1 &pids+=("$!")
RWA_SIGNAL=1 RWA_GAME=scrapyard RWA_PORT="$control" RWA_DB="$work/authority.sqlite" RWA_DONE="$work/done" ODIN_SCRIPTS_DLL="$server/bin/libodinscripts.$ext" "$GODOT" --headless --path "$server" >"$work/server.log" 2>&1 &pids+=("$!")
for _ in {1..100};do if rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log";then break;fi;sleep .1;done
rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log"
node "$ROOT/tests/replay_observer_names/drive.mjs" "http://127.0.0.1:$port/index.html" "ws://127.0.0.1:$control/control" "$work/browser" >"$work/driver.log" 2>&1
touch "$work/done";wait "${pids[1]}"
if rg -q 'WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:|instances were leaked' "$work/server.log";then cat "$work/server.log";exit 1;fi
python3 "$ROOT/tests/replay_observer_names/report.py" "$work"
