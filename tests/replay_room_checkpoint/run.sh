#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
SERVICE="$ROOT/examples/replay_room_service"; PROJ="$ROOT/tests/replay_room_checkpoint"
work="${REPLAY_CHECKPOINT_OUT:-$(mktemp -d)}"; mkdir -p "$work"
server=""
cleanup(){ if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; echo "Room checkpoint logs: $work"; }
trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) exit 1 ;; esac
for project in "$SERVICE" "$PROJ"; do
    name="$(basename "$project")"; export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
    bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-build.log" 2>&1
    "$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/$name-import.log" 2>&1
    if rg -q 'SCRIPT ERROR|ERROR:' "$work/$name-import.log"; then cat "$work/$name-import.log"; exit 1; fi
    python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$name-wait.json"
    bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$name-final-build.log" 2>&1
done
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/key.pem" -out "$work/cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >"$work/certificate.log" 2>&1
export CHECKPOINT_CERT="$work/cert.pem"
for game in ${CHECKPOINT_GAMES:-cavecrawl cavecrawl-owned speedball scrapyard}; do
    case "$game" in
        cavecrawl) content=0x4341564552504c39 ;;
        cavecrawl-owned) content=0x434156454f574e33 ;;
        speedball) content=0x5253504545444234 ;;
        scrapyard) content=0x5253435241503049 ;;
        *) echo "Unknown checkpoint fixture game: $game";exit 1 ;;
    esac
    mkdir -p "$work/$game"
    export CHECKPOINT_GAME="$game" CHECKPOINT_EXPECTED="$work/$game/archive.sha256"
    export CHECKPOINT_PORT=$((30000+RANDOM%10000))
    if [[ "$game" == cavecrawl ]]; then
        if REPLAY_ROOM_CONTENT="$content" REPLAY_ROOM_CHECKPOINT_MODEL=speedball REPLAY_ROOM_DB="$work/mismatch.sqlite3" REPLAY_ROOM_CREATE_DB=1 ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --path "$SERVICE" >"$work/mismatch.log" 2>&1; then
            echo 'Mismatched checkpoint model unexpectedly started'; exit 1
        fi
        rg -q 'checkpoint model does not match deployment content' "$work/mismatch.log"
        [[ ! -e "$work/mismatch.sqlite3" ]]
    fi
    for resume in 0 1; do
        REPLAY_ROOM_CONTENT="$content" REPLAY_ROOM_CHECKPOINT_MODEL="$game" REPLAY_ROOM_PORT="$CHECKPOINT_PORT" REPLAY_ROOM_CAPACITY=2 REPLAY_ROOM_DB="$work/$game/rooms.sqlite3" REPLAY_ROOM_CREATE_DB=$((1-resume)) REPLAY_ROOM_CERT="$work/cert.pem" REPLAY_ROOM_KEY="$work/key.pem" ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$work/$game/service-$resume.log" 2>&1 &
        server=$!
        for _ in {1..150}; do
            if rg -q "REPLAY_ROOM_SERVICE_READY.*checkpoints=$game" "$work/$game/service-$resume.log"; then break; fi
            if ! kill -0 "$server" 2>/dev/null; then cat "$work/$game/service-$resume.log"; exit 1; fi
            sleep 0.1
        done
        rg -q "REPLAY_ROOM_SERVICE_READY.*checkpoints=$game" "$work/$game/service-$resume.log"
        CHECKPOINT_RESUME="$resume" ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$PROJ" >"$work/$game/client-$resume.log" 2>&1
        if [[ "$resume" == 0 ]]; then
            rg -q "ROOM_CHECKPOINT_UPLOAD_OK game=$game .*revision=1 tick=1" "$work/$game/client-0.log"
            rg -q "ROOM_CHECKPOINT_DOWNLOAD_OK game=$game resume=false revision=1 tick=1" "$work/$game/client-0.log"
            kill -KILL "$server"; wait "$server" 2>/dev/null || true
        else
            rg -q "ROOM_CHECKPOINT_DOWNLOAD_OK game=$game resume=true revision=1 tick=1 .*incarnation=2 remaining_ms=0" "$work/$game/client-1.log"
            if [[ "${CHECKPOINT_RESTORE:-0}" == 1 ]]; then rg -q "ROOM_CHECKPOINT_RESTORE_OK game=$game epoch=2 incarnation=2 tick=11 owner=1" "$work/$game/client-1.log"; fi
            kill "$server"; wait "$server" 2>/dev/null || true
        fi
        server=""
    done
    if rg -q 'ROOM_CHECKPOINT_FAIL|REPLAY_ROOM_SERVICE_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/$game"/*.log; then exit 1; fi
    rg 'ROOM_CHECKPOINT_' "$work/$game"/client-*.log
done
echo REPLAY_GAME_CHECKPOINT_SERVICE_OK
if [[ "${CHECKPOINT_RESTORE:-0}" == 1 ]]; then echo REPLAY_GAME_PUBLISHED_RESTORE_OK; fi
