#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl";work="${REPLAY_LOBBY_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Lobby logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1;fi
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
export REPLAY_CAVE_ROLE='' REPLAY_CAVE_PORT=$((40000+RANDOM%10000)) REPLAY_CAVE_PERSIST=1 REPLAY_LOBBY_DIR="$work" REPLAY_CAVE_LATENCY=120 REPLAY_CAVE_JITTER=20 REPLAY_CAVE_LOSS=500 REPLAY_CAVE_DUPLICATE=500
for role in host client;do
 REPLAY_LOBBY_ROLE="$role" REPLAY_CAVE_TOKEN="lobby-$role" REPLAY_CAVE_NAME_PATH="$work/$role.name" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script lobby_test.gd >"$work/$role.log" 2>&1 &pids+=("$!");sleep 0.3
done
for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in host client;do cat "$work/$role.log";rg -q "REPLAY_CAVE_LOBBY_OK role=$role" "$work/$role.log";done
REPLAY_EXPECT_NAME='Guest Scout' REPLAY_EXPECT_ERROR=0 REPLAY_CAVE_TOKEN=lobby-client REPLAY_CAVE_NAME_PATH="$work/client.name" "$GODOT" --headless --path "$PROJ" --script lobby_profile_resume.gd >"$work/resume.log" 2>&1
rg -q REPLAY_CAVE_LOBBY_PROFILE_OK "$work/resume.log"
python3 - "$work" <<'PY'
from pathlib import Path
import sys,hashlib
root=Path(sys.argv[1]);data=bytearray((root/'client.name').read_bytes());data[2]=99
(root/'corrupt.name').write_bytes(data);(root/'corrupt.sha256').write_text(hashlib.sha256(data).hexdigest())
PY
REPLAY_EXPECT_NAME=Spelunker REPLAY_EXPECT_ERROR=1 REPLAY_CAVE_TOKEN=lobby-client REPLAY_CAVE_NAME_PATH="$work/corrupt.name" "$GODOT" --headless --path "$PROJ" --script lobby_profile_resume.gd >"$work/corrupt.log" 2>&1
rg -q REPLAY_CAVE_LOBBY_PROFILE_OK "$work/corrupt.log"
python3 - "$work" <<'PY'
from pathlib import Path
import sys,hashlib
root=Path(sys.argv[1]);assert hashlib.sha256((root/'corrupt.name').read_bytes()).hexdigest()==(root/'corrupt.sha256').read_text()
PY
if rg -q 'SCRIPT ERROR|ERROR:|CAVE_LOBBY_FAIL|CAVE_LOBBY_PROFILE_FAIL|instances were leaked|resources still in use' "$work"/*.log;then cat "$work"/*.log;exit 1;fi
echo REPLAY_CAVE_LOBBY_ALL_OK
