#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl"; SERVICE="$ROOT/examples/replay_room_service"
work="${CAVE_ONLINE_OUT:-$(mktemp -d)}"; mkdir -p "$work"; pids=()
cleanup(){ for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Cave online logs: $work"; };trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) exit 1 ;; esac
for project in "$SERVICE" "$PROJ"; do
 name="$(basename "$project")";export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-build.log" 2>&1
 "$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/$name-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$name-import.log";then cat "$work/$name-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$name-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-final-build.log" 2>&1
done
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/key.pem" -out "$work/cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >"$work/cert.log" 2>&1
control=$((30000+RANDOM%9000)); gameport=$((41000+RANDOM%8000))
REPLAY_ROOM_CONTENT=0x4341564552504c39 REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$work/service.sqlite3" REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_CERT="$work/cert.pem" REPLAY_ROOM_KEY="$work/key.pem" ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$work/service.log" 2>&1 & server=$!;pids+=("$server")
for _ in {1..100};do if rg -q REPLAY_ROOM_SERVICE_READY "$work/service.log";then break;fi;sleep 0.1;done
rg -q REPLAY_ROOM_SERVICE_READY "$work/service.log"
export REPLAY_CAVE_ROLE='' REPLAY_CAVE_ROOM_SERVICE="wss://localhost:$control" REPLAY_CAVE_ROOM_CA="$work/cert.pem" REPLAY_CAVE_PERSIST=0 CAVE_ONLINE_WORK="$work"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
CAVE_ONLINE_ROLE=host REPLAY_CAVE_PORT="$gameport" REPLAY_CAVE_ROOMS_DB="$work/host.sqlite3" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script online_test.gd >"$work/host.log" 2>&1 & host=$!;pids+=("$host")
CAVE_ONLINE_ROLE=guest REPLAY_CAVE_PORT=$((gameport+1)) REPLAY_CAVE_ROOMS_DB="$work/guest.sqlite3" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script online_test.gd >"$work/guest.log" 2>&1 & guest=$!;pids+=("$guest")
wait "$host"
rg -q CAVE_ONLINE_HANDOFF_OK "$work/host.log"
CAVE_ONLINE_ROLE=returned REPLAY_CAVE_PORT="$gameport" REPLAY_CAVE_ROOMS_DB="$work/host.sqlite3" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script online_test.gd >"$work/returned.log" 2>&1 & returned=$!;pids+=("$returned")
wait "$guest"; touch "$work/guest-done";wait "$returned"
rg -q CAVE_ONLINE_GUEST_OK "$work/guest.log";rg -q CAVE_ONLINE_REJOIN_OK "$work/returned.log"
if [[ "${CAVE_ONLINE_CHECKPOINTS:-0}" == 1 ]]; then
 rg -q CAVE_ONLINE_CHECKPOINT_HOST_OK "$work/host.log"
 rg -q CAVE_ONLINE_CHECKPOINT_SUCCESSOR_OK "$work/guest.log"
 odin build "$ROOT/tests/replay_room_save_verify" -collection:godot="$ROOT" -out:"$work/verify-checkpoint"
 "$work/verify-checkpoint" "$work/service.sqlite3" >"$work/durable-checkpoint.log"
 cat "$work/durable-checkpoint.log"
fi
if rg -q 'CAVE_ONLINE_FAIL|REPLAY_CAVE_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work"/host.log "$work"/guest.log "$work"/returned.log "$work"/service.log;then exit 1;fi
for file in host guest returned;do rg 'CAVE_ONLINE_' "$work/$file.log";done
echo REPLAY_CAVE_ONLINE_OK
