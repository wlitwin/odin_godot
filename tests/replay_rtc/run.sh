#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_rtc"
export REPLAY_RTC_LOGS="${REPLAY_RTC_LOGS:-$(mktemp -d)}"
mkdir -p "$REPLAY_RTC_LOGS"
echo "Replay RTC logs: $REPLAY_RTC_LOGS"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
 bash "$ROOT/build/build_web.sh" "$PROJ" >"$REPLAY_RTC_LOGS/web-build.log" 2>&1
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$REPLAY_RTC_LOGS/native-build.log" 2>&1
fi
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$([[ "$(uname -s)" == Darwin ]] && echo dylib || echo so)"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$REPLAY_RTC_LOGS/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$REPLAY_RTC_LOGS/import.log"; then cat "$REPLAY_RTC_LOGS/import.log"; exit 1; fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$REPLAY_RTC_LOGS/wait-builds.json"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$REPLAY_RTC_LOGS/final-native-build.log" 2>&1;fi
mkdir -p "$PROJ/out"
touch "$PROJ/out/.gdignore"
"$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$REPLAY_RTC_LOGS/export.log" 2>&1
[[ -f "$PROJ/out/libodin_godot.wasm" && -f "$PROJ/out/index.side.wasm" ]]
if [[ ! -d "$PROJ/node_modules/puppeteer-core" || ! -d "$PROJ/node_modules/ws" ]]; then
 [[ -d "$ROOT/tests/web/node_modules/puppeteer-core" && -d "$ROOT/tests/web/node_modules/ws" ]]
 ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules"
fi
PORT="${PORT:-$((20000 + RANDOM % 10000))}"
SIGPORT="${SIGPORT:-$((31000 + RANDOM % 10000))}"
node "$PROJ/signal_server.mjs" "$SIGPORT" >"$REPLAY_RTC_LOGS/signal.log" 2>&1 &
signal_pid=$!
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >"$REPLAY_RTC_LOGS/http.log" 2>&1 &
http_pid=$!
trap 'kill "$signal_pid" "$http_pid" 2>/dev/null || true' EXIT
for _ in {1..60}; do
 if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/index.html" 2>/dev/null && rg -q REPLAY_SIGNAL_READY "$REPLAY_RTC_LOGS/signal.log"; then break; fi
 sleep 0.1
done
node "$PROJ/drive.mjs" "http://127.0.0.1:$PORT/index.html" "ws://127.0.0.1:$SIGPORT/rtc" | tee "$REPLAY_RTC_LOGS/driver.log"
REPLAY_RTC_LOGS="$REPLAY_RTC_LOGS/game" node "$PROJ/drive.mjs" "http://127.0.0.1:$PORT/index.html" "ws://127.0.0.1:$SIGPORT/rtc" game | tee "$REPLAY_RTC_LOGS/game-driver.log"
echo REPLAY_RTC_OK
