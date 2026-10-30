#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
out="${REPLAY_P2P_PARTY_OUT:-$(mktemp -d)}"; export REPLAY_P2P_PARTY_OUT="$out"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/tests/replay_p2p_party/build.sh"; fi
run="${REPLAY_P2P_PARTY_RUN:-$out/runtime}"; mkdir -p "$run"
case "$(uname -s)" in Darwin) ext=dylib;; Linux) ext=so;; *) ext=dll;; esac
export ODIN_SCRIPTS_DLL="$out/service/bin/libodinscripts.$ext"
signal=$((31000+RANDOM%10000));http=$((20000+RANDOM%10000))
server="";web=""
cleanup() {
    for pid in "$server" "$web"; do if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi; done
    echo "P2P party logs: $run"
}
trap cleanup EXIT
DUEL_SERVICE_PORT="$signal" DUEL_SERVICE_DB="$run/rooms.sqlite3" DUEL_SERVICE_CREATE=1 DUEL_SERVICE_LOCAL=1 DUEL_SERVICE_STOP_FILE="$run/stop" "$GODOT" --headless --max-fps 120 --path "$out/service" >"$run/service.log" 2>&1 & server=$!
bash "$ROOT/tests/web/serve.sh" "$out/duel/out" "$http" >"$run/http.log" 2>&1 & web=$!
for _ in {1..200}; do
    if rg -q REPLAY_DUEL_SERVICE_READY "$run/service.log" && curl -fsS -o /dev/null "http://127.0.0.1:$http/index.html"; then break; fi
    if ! kill -0 "$server" 2>/dev/null; then cat "$run/service.log"; exit 1; fi
    sleep .05
done
rg -q REPLAY_DUEL_SERVICE_READY "$run/service.log"
node "$ROOT/tests/replay_p2p_party/browser.mjs" "http://127.0.0.1:$http/index.html" "ws://127.0.0.1:$signal" "$run/browser" "${REPLAY_P2P_PARTY_MODE:-guest}" >"$run/driver.log" 2>&1
touch "$run/stop"; wait "$server"; server=""
if rg -q 'REPLAY_DUEL_SERVICE_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$run/service.log"; then cat "$run/service.log"; exit 1; fi
rg -q REPLAY_P2P_PARTY_BROWSER_OK "$run/driver.log"
echo REPLAY_P2P_PARTY_OK
