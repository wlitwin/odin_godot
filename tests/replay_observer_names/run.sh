#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_OBSERVER_OUT:-$(mktemp -d)}";mkdir -p "$work";project="$work/project";server="$ROOT/tests/replay_web_authority/server"
[[ -d "$project" ]] || python3 "$ROOT/tests/replay_observer_names/prepare.py" "$work" >"$work/prepare.log"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
for target in "$project" "$server";do
 label="${target##*/}"
 bash "$ROOT/build/build_scripts.sh" "$target" >"$work/$label-build.log" 2>&1
 ODIN_SCRIPTS_DLL="$target/bin/libodinscripts.$ext" "$GODOT" --headless --path "$target" --editor --quit-after 120 >"$work/$label-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$label-import.log";then cat "$work/$label-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$target" "$work/$label-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$target" >"$work/$label-final-build.log" 2>&1
done
fi
# Preserve the existing native real-game chat scenario on this same isolated copy.
mkdir -p "$work/native";pids=();port=$((40000+RANDOM%9000))
cleanup() { for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Observer logs: $work";};trap cleanup EXIT
for role in host client observer;do
 if [[ "$role" == observer ]];then
  for _ in {1..500};do [[ -f "$work/native/allow-observer.json" ]] && break;sleep .05;done
  [[ -f "$work/native/allow-observer.json" ]]
 fi
 RSY_RUN=0 RSY_MOBS=0 RSY_PERSIST=0 RSY_SEED=1337 RSY_RESULT_DIR="$work/native" RSY_PORT="$port" RSY_LATENCY=120 RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="chat-$role" ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$project" --script chat_test.gd >"$work/native/$role.log" 2>&1 &pids+=("$!")
 sleep .3
done
for pid in "${pids[@]}";do wait "$pid";done;pids=()
node "$ROOT/examples/replay_scrapyard/chat_check.mjs" "$work/native" >"$work/native/report.log"
if rg -q 'SCRIPT ERROR|ERROR:|COMBAT_FAIL|instances were leaked|resources still in use' "$work/native/"*.log;then exit 1;fi
ODIN_EXPORT_OPT=speed bash "$ROOT/build/build_web.sh" "$project" >"$work/web-build.log" 2>&1
mkdir -p "$project/out";touch "$project/out/.gdignore"
ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --export-release Web "$project/out/index.html" >"$work/export.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/export.log";then cat "$work/export.log";exit 1;fi
[[ -e "$ROOT/tests/replay_observer_names/node_modules" ]] || ln -s "$ROOT/tests/web/node_modules" "$ROOT/tests/replay_observer_names/node_modules"
port=$((21000+RANDOM%8000));control=$((31000+RANDOM%7000))
bash "$ROOT/tests/web/serve.sh" "$project/out" "$port" >"$work/http.log" 2>&1 &pids+=("$!")
RWA_SIGNAL=1 RWA_GAME=scrapyard RWA_PORT="$control" RWA_DB="$work/authority.sqlite" RWA_DONE="$work/done" ODIN_SCRIPTS_DLL="$server/bin/libodinscripts.$ext" "$GODOT" --headless --path "$server" >"$work/server.log" 2>&1 &pids+=("$!")
for _ in {1..100};do if rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log";then break;fi;sleep .1;done
rg -q WEB_AUTHORITY_SERVER_READY "$work/server.log"
node "$ROOT/tests/replay_observer_names/drive.mjs" "http://127.0.0.1:$port/index.html" "ws://127.0.0.1:$control/control" "$work/browser" >"$work/driver.log" 2>&1
touch "$work/done";wait "${pids[1]}"
if rg -q 'WEB_AUTHORITY_FAIL|SCRIPT ERROR|ERROR:|instances were leaked' "$work/server.log";then cat "$work/server.log";exit 1;fi
python3 "$ROOT/tests/replay_observer_names/report.py" "$work"
echo REPLAY_OBSERVER_NAMES_OK
