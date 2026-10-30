#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_duel"
work="${REPLAY_DUEL_WEB_LOGS:-$(mktemp -d)}"
mkdir -p "$work"
echo "Duel browser logs: $work"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
 bash "$ROOT/build/build_web.sh" "$PROJ" >"$work/web-build.log" 2>&1
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/native-build.log" 2>&1
fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
mkdir -p "$PROJ/out"; touch "$PROJ/out/.gdignore"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/wait-builds.json"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-native-build.log" 2>&1; fi
"$GODOT" --headless --path "$PROJ" --export-release Web "$PROJ/out/index.html" >"$work/export.log" 2>&1
[[ -f "$PROJ/out/libodin_godot.wasm" && -f "$PROJ/out/index.side.wasm" ]]
cp "$PROJ/web_lobby.html" "$PROJ/out/lobby.html"
cp "$PROJ/web_archive.js" "$PROJ/out/web_archive.js"
python3 - "$PROJ/out/index.html" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]);s=p.read_text();s=s.replace("</head>",'<script src="web_archive.js"></script></head>');p.write_text(s)
PY
[[ -d "$ROOT/tests/web/node_modules/puppeteer-core" && -d "$ROOT/tests/web/node_modules/ws" ]]
if [[ ! -e "$PROJ/node_modules" ]]; then ln -s "$ROOT/tests/web/node_modules" "$PROJ/node_modules"; fi
if [[ ! -e "$ROOT/tests/replay_p2p_admission/node_modules" ]]; then ln -s "$ROOT/tests/web/node_modules" "$ROOT/tests/replay_p2p_admission/node_modules"; fi
PORT="${PORT:-$((20000 + RANDOM % 10000))}"; SIGPORT="${SIGPORT:-$((31000 + RANDOM % 10000))}"
if [[ "${RDP_WEB_AUTH:-0}" == 1 ]];then
 AUTH_PROJ="$ROOT/tests/replay_p2p_admission/server"
 bash "$ROOT/build/build_scripts.sh" "$AUTH_PROJ" >"$work/auth-build.log" 2>&1
 ODIN_SCRIPTS_DLL="$AUTH_PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --path "$AUTH_PROJ" --editor --quit-after 90 >"$work/auth-import.log" 2>&1
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$AUTH_PROJ" "$work/auth-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$AUTH_PROJ" >"$work/auth-final-build.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/auth-import.log";then cat "$work/auth-import.log";exit 1;fi
 RDP_AUTH_PORT="$SIGPORT" RDP_AUTH_DONE="$work/auth-done" ODIN_SCRIPTS_DLL="$AUTH_PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --path "$AUTH_PROJ" >"$work/signal.log" 2>&1 & signal_pid=$!
else
 node "$ROOT/tests/replay_rtc/signal_server.mjs" "$SIGPORT" >"$work/signal.log" 2>&1 & signal_pid=$!
fi
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >"$work/http.log" 2>&1 & http_pid=$!
trap 'kill "$signal_pid" "$http_pid" 2>/dev/null || true' EXIT
for _ in {1..60}; do
 if curl -fsS -o /dev/null "http://127.0.0.1:$PORT/index.html" 2>/dev/null && rg -q REPLAY_SIGNAL_READY "$work/signal.log"; then break; fi
 sleep 0.1
done
rg -q REPLAY_SIGNAL_READY "$work/signal.log" || { cat "$work/signal.log";exit 1; }
if [[ "${REPLAY_WEB_PLAY:-0}" == 1 ]]; then
 echo "Play: http://127.0.0.1:$PORT/lobby.html?url=ws%3A%2F%2F127.0.0.1%3A$SIGPORT%2Frtc"
 wait "$http_pid"
else
 for mode in ${REPLAY_WEB_MODES:-fault watch resume rejoin interactive}; do
  REPLAY_DUEL_WEB_LOGS="$work/$mode" node "$PROJ/web_drive.mjs" "http://127.0.0.1:$PORT/index.html" "ws://127.0.0.1:$SIGPORT/rtc" "$mode" | tee "$work/$mode-driver.log"
 done
 if [[ "${RDP_WEB_AUTH:-0}" == 1 ]];then
  touch "$work/auth-done";wait "$signal_pid"
  rg -q P2P_ADMISSION_SERVICE_OK "$work/signal.log"
  if rg -q 'P2P_ADMISSION_SERVICE_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/signal.log";then cat "$work/signal.log";exit 1;fi
  echo REPLAY_DUEL_AUTHENTICATED_REJOIN_OK
 fi
 echo REPLAY_DUEL_WEB_OK
fi
