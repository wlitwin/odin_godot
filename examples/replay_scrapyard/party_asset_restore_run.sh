#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard";SERVICE="$ROOT/examples/replay_room_service"
work="${RSY_ASSET_RESTORE_OUT:-$(mktemp -d)}";mkdir -p "$work/host"
server=""
cleanup(){ if [[ -n "$server" ]];then kill "$server" 2>/dev/null || true;wait "$server" 2>/dev/null || true;fi;echo "Spray restore logs: $work"; };trap cleanup EXIT
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
"$work/seed" "$work/host" host
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/key.pem" -out "$work/cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >"$work/cert.log" 2>&1
control=$((30000+RANDOM%9000));gameport=$((41000+RANDOM%8000))
start_service(){
 REPLAY_ROOM_CONTENT=0x5253435241503048 REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$work/service.sqlite3" REPLAY_ROOM_CREATE_DB="$1" REPLAY_ROOM_CERT="$work/cert.pem" REPLAY_ROOM_KEY="$work/key.pem" ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$work/service-$1.log" 2>&1 &server=$!
 for _ in {1..150};do if rg -q REPLAY_ROOM_SERVICE_READY "$work/service-$1.log";then return;fi;if ! kill -0 "$server" 2>/dev/null;then return 1;fi;sleep 0.1;done;return 1
}
export RSY_ROLE='' RSY_ROOM_SERVICE="wss://localhost:$control" RSY_ROOM_CA="$work/cert.pem" RSY_PERSIST=1 RSY_RUN=0 RSY_ENCOUNTER=spray RSY_MOBS=0 RSY_AUDIO=0 RSY_SETTINGS_PATH="$work/settings" RSY_MODS_DIR="$work/no-mods"
export RSY_PORT="$gameport" RSY_ROOMS_DB="$work/host/rooms.sqlite3" RSY_PROFILE_DIR="$work/host" RSY_SPRAY_STORE="$work/absent-local.png" RSY_ASSET_RESTORE_WORK="$work" ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
start_service 1
RSY_ASSET_RESTORE_ROLE=source RSY_SPRAY="$PROJ/assets/gz2/bg_floor.png" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script party_asset_restore_test.gd >"$work/source.log" 2>&1
rg -q RSY_ASSET_RESTORE_SOURCE_OK "$work/source.log"
kill -KILL "$server";wait "$server" 2>/dev/null || true;server=""
[[ ! -e "$work/absent-local.png" ]]
start_service 0
RSY_ASSET_RESTORE_ROLE=restored RSY_SPRAY="$work/absent-input.png" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script party_asset_restore_test.gd >"$work/restored.log" 2>&1
rg -q RSY_ASSET_RESTORE_EMPTY_CACHE_OK "$work/restored.log"
rg -q RSY_ASSET_RESTORE_RESUMED_OK "$work/restored.log"
rg -q RSY_ASSET_RESTORE_CONTINUED_OK "$work/restored.log"
rg -q 'RSY_SPRAY_TEXTURE seat=1' "$work/restored.log"
if rg -q 'RSY_ASSET_RESTORE_FAIL|RSY_PROFILE_ERROR|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work"/source.log "$work"/restored.log "$work"/service-*.log;then exit 1;fi
for file in source restored;do rg 'RSY_ASSET_RESTORE_' "$work/$file.log";done
odin build "$ROOT/tests/replay_scrapyard/durable_asset_verify" -collection:godot="$ROOT" -out:"$work/verify-assets"
"$work/verify-assets" "$work/service.sqlite3" "$PROJ/assets/gz2/bg_floor.png" >"$work/durable-assets.log"
cat "$work/durable-assets.log"
echo REPLAY_SCRAPYARD_DURABLE_ASSET_RESTORE_OK
