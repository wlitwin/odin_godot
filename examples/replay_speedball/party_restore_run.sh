#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_speedball";SERVICE="$ROOT/examples/replay_room_service"
work="${RSB_PARTY_RESTORE_OUT:-$(mktemp -d)}";mkdir -p "$work"
server="";host="";guest=""
cleanup(){ for pid in "$server" "$host" "$guest";do if [[ -n "$pid" ]];then kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;fi;done;echo "Speedball restore logs: $work"; };trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) exit 1 ;; esac
for project in "$SERVICE" "$PROJ";do
 name="$(basename "$project")";export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-build.log" 2>&1
 "$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/$name-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$name-import.log";then cat "$work/$name-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$name-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-final-build.log" 2>&1
done
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/key.pem" -out "$work/cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >"$work/cert.log" 2>&1
control=$((30000+RANDOM%9000));gameport=$((41000+RANDOM%8000))
start_service(){
 REPLAY_ROOM_CONTENT=0x5253504545444234 REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$work/service.sqlite3" REPLAY_ROOM_CREATE_DB="$1" REPLAY_ROOM_CERT="$work/cert.pem" REPLAY_ROOM_KEY="$work/key.pem" ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$work/service-$1.log" 2>&1 &server=$!
 for _ in {1..150};do if rg -q REPLAY_ROOM_SERVICE_READY "$work/service-$1.log";then return;fi;if ! kill -0 "$server" 2>/dev/null;then return 1;fi;sleep 0.1;done;return 1
}
export RSB_ROLE= RSB_TOKEN= RSB_NAME= RSB_BOT=idle RSB_TEST=0 RSB_PLAYERS=1 RSB_GOALS=1 RSB_LATENCY=0 RSB_ROOM_CHECKPOINT_MS=0
export RSB_RESTORE_DIR="$work" RSB_ROOM_SERVICE="wss://localhost:$control" RSB_ROOM_CA="$work/cert.pem" ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
start_service 1
RSB_RESTORE_ROLE=source RSB_PORT="$gameport" RSB_PROFILE="$work/host-profile" RSB_ROOMS_DB="$work/host.sqlite3" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script party_restore_test.gd >"$work/source.log" 2>&1
rg -q RSB_PARTY_RESTORE_SOURCE_OK "$work/source.log"
kill -KILL "$server";wait "$server" 2>/dev/null || true;server=""
start_service 0
RSB_RESTORE_ROLE=restored RSB_PORT="$gameport" RSB_PROFILE="$work/host-profile" RSB_ROOMS_DB="$work/host.sqlite3" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script party_restore_test.gd >"$work/restored.log" 2>&1 &host=$!
RSB_RESTORE_ROLE=guest RSB_PORT=$((gameport+1)) RSB_PROFILE="$work/guest-profile" RSB_ROOMS_DB="$work/guest.sqlite3" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script party_restore_test.gd >"$work/guest.log" 2>&1 &guest=$!
wait "$host";host="";wait "$guest";guest=""
rg -q RSB_PARTY_RESTORE_RESUMED_OK "$work/restored.log";rg -q RSB_PARTY_RESTORE_CONTINUED_OK "$work/restored.log";rg -q RSB_PARTY_RESTORE_GUEST_OK "$work/guest.log"
if rg -q 'RSB_PARTY_RESTORE_FAIL|REPLAY_SPEEDBALL_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work"/source.log "$work"/restored.log "$work"/guest.log "$work"/service-*.log;then exit 1;fi
odin build "$ROOT/tests/replay_speedball/party_restore_verify" -collection:godot="$ROOT" -out:"$work/verify-match"
"$work/verify-match" "$work/service.sqlite3" >"$work/durable-match.log"
for file in source restored guest;do rg 'RSB_PARTY_RESTORE_' "$work/$file.log";done
cat "$work/durable-match.log"
echo REPLAY_SPEEDBALL_PARTY_RESTORE_OK
