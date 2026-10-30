#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl";SERVICE="$ROOT/examples/replay_room_service"
work="${CAVE_RESTORE_CONTENTION_OUT:-$(mktemp -d)}";mkdir -p "$work"
server="";one="";two=""
cleanup(){ for pid in "$server" "$one" "$two";do if [[ -n "$pid" ]];then kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;fi;done;echo "Restore contention logs: $work"; };trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) exit 1 ;; esac
for project in "$SERVICE" "$PROJ";do
 label="$(basename "$project")";export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$label-build.log" 2>&1
 "$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/$label-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$label-import.log";then cat "$work/$label-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$label-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$label-final-build.log" 2>&1
done
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/key.pem" -out "$work/cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >"$work/cert.log" 2>&1
odin build "$ROOT/tests/replay_restore_contention_verify" -collection:godot="$ROOT" -out:"$work/verify"
for mode in simultaneous guest_first;do
 folder="$work/$mode";mkdir -p "$folder"
 control=$((30000+RANDOM%9000));gameport=$((41000+RANDOM%8000))
 start_service(){
  REPLAY_ROOM_CONTENT=0x4341564552504c39 REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$folder/service.sqlite3" REPLAY_ROOM_CREATE_DB="$1" REPLAY_ROOM_CERT="$work/cert.pem" REPLAY_ROOM_KEY="$work/key.pem" ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$folder/service-$1.log" 2>&1 &server=$!
  for _ in {1..150};do if rg -q REPLAY_ROOM_SERVICE_READY "$folder/service-$1.log";then return;fi;if ! kill -0 "$server" 2>/dev/null;then return 1;fi;sleep .1;done;return 1
 }
 launch(){
  CAVE_CONTENTION_PHASE="$1" CAVE_CONTENTION_SLOT="$2" CAVE_CONTENTION_DIR="$folder" REPLAY_CAVE_PORT=$((gameport+$2)) REPLAY_CAVE_ROOMS_DB="$folder/member-$2.sqlite3" REPLAY_CAVE_NAME_PATH="$folder/name-$2" ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script restore_contention_test.gd >"$folder/$1-$2.log" 2>&1 &launched=$!
 }
 await_file(){
  for _ in {1..650};do
   if [[ -f "$folder/$1" ]];then return;fi
   if rg -q 'CAVE_RESTORE_CONTENTION_FAIL|REPLAY_CAVE_FAIL|SCRIPT ERROR|ERROR:' "$folder"/*.log;then cat "$folder"/*.log;return 1;fi
   if [[ -n "$one" ]] && ! kill -0 "$one" 2>/dev/null;then return 1;fi
   if [[ -n "$two" ]] && ! kill -0 "$two" 2>/dev/null;then return 1;fi
   sleep .1
  done;return 1
 }
 export REPLAY_CAVE_ROLE='' REPLAY_CAVE_ROOM_SERVICE="wss://localhost:$control" REPLAY_CAVE_ROOM_CA="$work/cert.pem" REPLAY_CAVE_PERSIST=0 REPLAY_CAVE_ROOM_CHECKPOINT_MS=0
 start_service 1
 launch source 1;one=$launched;launch source 2;two=$launched
 wait "$one";one="";wait "$two";two=""
 [[ -f "$folder/saved.json" ]]
 kill -KILL "$server";wait "$server" 2>/dev/null || true;server=""
 start_service 0
 launch returning 1;one=$launched;launch returning 2;two=$launched
 await_file prepared-1;await_file prepared-2
 if [[ "$mode" == guest_first ]];then touch "$folder/release-2";await_file granted-2;touch "$folder/release-1";else touch "$folder/release";fi
 wait "$one";one="";wait "$two";two=""
 "$work/verify" "$folder/service.sqlite3" >"$folder/durable.log"
 python3 - "$folder" "$mode" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]);a=json.loads((p/'ready-1').read_text());b=json.loads((p/'ready-2').read_text())
assert a['epoch']==b['epoch']==2 and int(a['winner'])+int(b['winner'])==1
if sys.argv[2]=='guest_first':assert b['winner']
print('REPLAY_RESTORE_CONTENTION_ROLES_OK mode='+sys.argv[2]+' winner='+str(a['slot'] if a['winner'] else b['slot']))
PY
 if rg -q 'CAVE_RESTORE_CONTENTION_FAIL|REPLAY_CAVE_FAIL|REPLAY_ROOM_SERVICE_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$folder"/*.log;then exit 1;fi
 for role in 1 2;do rg 'CAVE_RESTORE_CONTENTION_' "$folder/returning-$role.log";done
 cat "$folder/durable.log"
 kill "$server";wait "$server" 2>/dev/null || true;server=""
done
echo REPLAY_CAVE_RESTORE_CONTENTION_OK
