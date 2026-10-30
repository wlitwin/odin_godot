#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_speedball";SERVICE="$ROOT/examples/replay_room_service";work="${RSB_PARTY_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
[[ -z "$(ls -A "$work")" ]] || { echo "Output must be empty: $work" >&2;exit 2; }
trap 'for pid in "${pids[@]}";do [[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true; };done;echo "Speedball party logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 2;;esac
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 for project in "$SERVICE" "$PROJ";do
  label="$(basename "$project")";export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
  bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$label-build.log" 2>&1
  "$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/$label-import.log" 2>&1
  python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$label-wait.json"
  bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$label-final-build.log" 2>&1
  if rg -q 'SCRIPT ERROR|ERROR:' "$work/$label-import.log";then cat "$work/$label-import.log";exit 1;fi
 done
fi
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/key.pem" -out "$work/cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >"$work/cert.log" 2>&1
for mode in ${RSB_PARTY_MODES:-planned crash};do
 [[ "$mode" == planned || "$mode" == crash ]] || exit 2
 folder="$work/$mode";mkdir -p "$folder";control=$((30000+RANDOM%9000));gameport=$((41000+RANDOM%8000));pids=()
 REPLAY_ROOM_CONTENT=0x5253504545444234 REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$folder/service.sqlite3" REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_CERT="$work/cert.pem" REPLAY_ROOM_KEY="$work/key.pem" ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$folder/service.log" 2>&1 &pids+=("$!")
 for _ in {1..100};do rg -q REPLAY_ROOM_SERVICE_READY "$folder/service.log" && break;sleep .1;done
 rg -q REPLAY_ROOM_SERVICE_READY "$folder/service.log"
 launch() {
  local role="$1" slot="$2";local args=(--headless)
  if [[ "${RSB_PARTY_RENDER:-0}" == 1 ]];then args=(--rendering-method gl_compatibility --audio-driver Dummy);fi
  RSB_MIGRATION_RENDER="${RSB_PARTY_RENDER:-0}" RSB_ROLE= RSB_TOKEN= RSB_NAME= RSB_BOT=idle RSB_TEST=0 RSB_PLAYERS=2 RSB_GOALS=9 RSB_LATENCY=120 RSB_PARTY_ROLE="$role" RSB_PARTY_MODE="$mode" RSB_PARTY_DIR="$folder" RSB_ROOM_SERVICE="wss://localhost:$control" RSB_ROOM_CA="$work/cert.pem" RSB_PORT=$((gameport+slot)) RSB_PROFILE="$folder/identity-$slot" RSB_ROOMS_DB="$folder/rooms-$slot.sqlite3" ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" "${args[@]}" --max-fps 60 --path "$PROJ" --script online_test.gd >"$folder/$role.log" 2>&1 &pids+=("$!")
 }
 launch host 0;launch guest 1;launch watcher 2
 deadline=$((SECONDS+115));rejoined=0;killed=0
 while ((SECONDS<deadline));do
  if [[ "$killed" == 0 && "$mode" == crash && -f "$folder/kill-owner.json" ]];then kill -KILL "${pids[1]}";wait "${pids[1]}" 2>/dev/null || true;pids[1]="";killed=1;fi
  if [[ "$killed" == 1 && "$rejoined" == 0 && -f "$folder/restored.json" ]];then launch returned 0;rejoined=1;fi
  if [[ "$rejoined" == 0 && "$mode" == planned && -f "$folder/retired.json" ]] && ! kill -0 "${pids[1]}" 2>/dev/null;then wait "${pids[1]}";pids[1]="";launch returned 0;rejoined=1;fi
  if rg -q 'SPEEDBALL_MIGRATION_FAIL|REPLAY_SPEEDBALL_FAIL|SCRIPT ERROR|ERROR:' "$folder/"*.log;then cat "$folder/"*.log;exit 1;fi
  live=0;for pid in "${pids[@]:1}";do if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null;then live=1;fi;done
  ((live==0 && rejoined==1)) && break
  sleep .1
 done
 ((SECONDS<deadline));for pid in "${pids[@]:1}";do [[ -z "$pid" ]] || wait "$pid";done
 for role in guest watcher returned;do rg -q REPLAY_SPEEDBALL_MIGRATION_PEER_OK "$folder/$role.log";done
 if rg -q 'instances were leaked|resources still in use|ERROR:' "$folder/"*.log;then exit 1;fi
 kill "${pids[0]}";wait "${pids[0]}" 2>/dev/null || true;pids=()
 echo "REPLAY_SPEEDBALL_PARTY_PHASE_OK $mode"
done
echo REPLAY_SPEEDBALL_PARTY_OK
