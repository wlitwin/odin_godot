#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard";SERVICE="$ROOT/examples/replay_room_service";work="${RSY_ONLINE_OUT:-$(mktemp -d)}";mkdir -p "$work/host" "$work/guest";pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Scrapyard party logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) exit 1 ;; esac
for project in "$SERVICE" "$PROJ";do
 name="$(basename "$project")";export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-build.log" 2>&1
 "$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/$name-import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$name-import.log";then cat "$work/$name-import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$name-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-final-build.log" 2>&1
done
odin build "$ROOT/tests/replay_scrapyard/online_seed" -collection:godot="$ROOT" -out:"$work/seed"
for role in host guest;do "$work/seed" "$work/$role" "$role";done
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/key.pem" -out "$work/cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >"$work/cert.log" 2>&1
control=$((30000+RANDOM%9000));gameport=$((41000+RANDOM%8000))
REPLAY_ROOM_CONTENT=0x5253435241503048 REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$work/service.sqlite3" REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_CERT="$work/cert.pem" REPLAY_ROOM_KEY="$work/key.pem" ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$work/service.log" 2>&1 &pids+=("$!")
for _ in {1..100};do if rg -q REPLAY_ROOM_SERVICE_READY "$work/service.log";then break;fi;sleep 0.1;done
rg -q REPLAY_ROOM_SERVICE_READY "$work/service.log"
export RSY_ROLE='' RSY_ROOM_SERVICE="wss://localhost:$control" RSY_ROOM_CA="$work/cert.pem" RSY_PERSIST=1 RSY_ONLINE_WORK="$work" RSY_RUN=0 RSY_ENCOUNTER=migration RSY_AUDIO=0 RSY_SETTINGS_PATH="$work/settings" RSY_MODS_DIR="$work/no-mods"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
RSY_ONLINE_ROLE=host RSY_PORT="$gameport" RSY_ROOMS_DB="$work/host/rooms.sqlite3" RSY_PROFILE_DIR="$work/host" RSY_SPRAY="$PROJ/assets/gz2/bg_floor.png" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script online_test.gd >"$work/host.log" 2>&1 &host=$!;pids+=("$host")
RSY_ONLINE_ROLE=guest RSY_PORT=$((gameport+1)) RSY_ROOMS_DB="$work/guest/rooms.sqlite3" RSY_PROFILE_DIR="$work/guest" RSY_SPRAY="$work/absent.png" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script online_test.gd >"$work/guest.log" 2>&1 &guest=$!;pids+=("$guest")
wait "$host";rg -q RSY_ONLINE_HANDOFF_OK "$work/host.log"
RSY_ONLINE_ROLE=returned RSY_PORT="$gameport" RSY_ROOMS_DB="$work/host/rooms.sqlite3" RSY_PROFILE_DIR="$work/host" RSY_SPRAY="$PROJ/assets/gz2/bg_floor.png" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script online_test.gd >"$work/returned.log" 2>&1 &returned=$!;pids+=("$returned")
wait "$guest";touch "$work/guest-done";wait "$returned"
rg -q RSY_ONLINE_GUEST_OK "$work/guest.log";rg -q RSY_ONLINE_REJOIN_OK "$work/returned.log";rg -q RSY_ONLINE_ASSET_BARRIER_OK "$work/guest.log"
if rg -q 'RSY_ONLINE_FAIL|RSY_PROFILE_ERROR|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work"/host.log "$work"/guest.log "$work"/returned.log "$work"/service.log;then exit 1;fi
for name in host guest returned;do rg 'RSY_ONLINE_' "$work/$name.log";done
echo REPLAY_SCRAPYARD_ONLINE_OK
