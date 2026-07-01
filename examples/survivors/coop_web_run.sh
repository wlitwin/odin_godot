#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# CO-OP WEB (WebRTC) test — TWO real headless-Chrome peers run the SAME exported coop.tscn over
# a genuine browser-native WebRTC data channel (brokered by the WebSocket signaling server) and
# prove the survivors co-op sync guarantees IN-BROWSER: both players synced/visible, a
# host->client enemy sync (MultiplayerSpawner + MultiplayerSynchronizer over WebRTC), and a
# client->host action (request_damage -> authoritative death). Same replication nodes as the
# native ENet test, now over WebRTC.
#
# Prints COOP_WEB_OK on a verified two-browser run, or COOP_WEB_BUNDLED when the build+export
# succeeded but the browser step was skipped (no node/Chrome/puppeteer) — gated like the other
# browser tests.   nix develop --command bash -c 'bash examples/survivors/coop_web_run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/survivors"
# Random default port (like SIGPORT below) so parallel/leftover servers don't collide.
PORT="${PORT:-$(( (RANDOM % 4000) + 9080 ))}"
SIGPORT="${SIGPORT:-$(( (RANDOM % 4000) + 9080 ))}"

set -e
bash "$ROOT/build/build_web.sh" "$PROJ" >/dev/null
bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
rm -rf "$PROJ/out"; mkdir -p "$PROJ/out"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$PROJ" --export-release "Web" "$PROJ/out/index.html" >/dev/null 2>&1 || true
if [[ ! -f "$PROJ/out/libodin_godot.wasm" || ! -f "$PROJ/out/index.side.wasm" ]]; then
    echo "COOP_WEB_FAIL: export did not bundle the SIDE_MODULE + dlink runtime"
    exit 1
fi
echo "web export bundled: libodin_godot.wasm + index.side.wasm"
set +e

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if ! command -v node >/dev/null 2>&1 || [[ ! -x "$CHROME" ]]; then
    echo "COOP_WEB_BUNDLED: browser step skipped (no node and/or Chrome at \$CHROME)."
    echo "  Manual: node tests/webrtc/signal_server.mjs 9080  +  bash tests/web/serve.sh examples/survivors/out $PORT"
    echo "  open  http://127.0.0.1:$PORT/index.html?role=host&url=ws://127.0.0.1:9080/rtc  in one browser (prints ROOM_CODE)"
    echo "  then  http://127.0.0.1:$PORT/index.html?role=join&url=ws://127.0.0.1:9080/rtc&room=<CODE>  in another."
    exit 0
fi

# Reuse tests/web's puppeteer-core + ws install.
if [[ ! -d "$PROJ/node_modules/puppeteer-core" || ! -d "$PROJ/node_modules/ws" ]]; then
    if [[ -d "$ROOT/tests/web/node_modules/puppeteer-core" && -d "$ROOT/tests/web/node_modules/ws" ]]; then
        ln -sfn "$ROOT/tests/web/node_modules" "$PROJ/node_modules"
    elif (cd "$PROJ" && npm install puppeteer-core@23 ws >/dev/null 2>&1); then :; else
        echo "COOP_WEB_BUNDLED: browser step skipped (could not obtain puppeteer-core + ws)."
        exit 0
    fi
fi

node "$ROOT/tests/webrtc/signal_server.mjs" "$SIGPORT" >"$PROJ/.coopsignal.log" 2>&1 &
SIG=$!
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >/dev/null 2>&1 &
SRV=$!
trap 'kill $SIG $SRV 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do curl -s -o /dev/null "http://127.0.0.1:$PORT/index.html" && break; sleep 0.5; done
for _ in $(seq 1 20); do grep -q "listening on" "$PROJ/.coopsignal.log" 2>/dev/null && break; sleep 0.25; done

rc=1
for try in 1 2; do
    echo "==> two-browser co-op attempt $try (signaling ws://127.0.0.1:$SIGPORT)"
    if CHROME="$CHROME" node "$PROJ/coop_drive.mjs" "http://127.0.0.1:$PORT/index.html" "ws://127.0.0.1:$SIGPORT"; then
        rc=0; break
    fi
done

if (( rc == 0 )); then
    echo "COOP_WEB_OK"
    exit 0
fi
echo "COOP_WEB_FAIL: two browsers did not prove the co-op sync over WebRTC"
echo "  --- signaling log ---"; tail -n 20 "$PROJ/.coopsignal.log" 2>/dev/null | sed 's/^/    /'
exit 1
