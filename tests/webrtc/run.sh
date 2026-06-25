#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# WebRTC web co-op milestone — TWO real browser peers exchange @(gd_rpc) calls over a genuine
# browser-native WebRTC data channel (no port-forwarding), brokered by a tiny WebSocket
# signaling server. The in-browser mirror of tests/rpc_net's ENet guarantees.
#
# Pipeline:
#   1. build the FULL extension into one Emscripten SIDE_MODULE wasm (build_web.sh) AND the
#      native core dll (build_scripts.sh) so the macOS export host packs the .odin script,
#   2. headless web-export the project,
#   3. start the WebSocket signaling server + the COOP/COEP static file server,
#   4. drive TWO headless-Chrome instances (drive.mjs): one hosts, one joins; they establish
#      WebRTC and exchange RPCs both directions; assert via each browser's console.
#
# Prints WEBRTC_OK on a verified two-browser run (GREEN), or WEBRTC_BUNDLED if the build+export
# succeeded but the browser step was skipped (YELLOW — no node/Chrome/puppeteer). Run inside
# the Nix dev shell:  nix develop --command bash -c 'bash tests/webrtc/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/webrtc"
PORT="${PORT:-8097}"
SIGPORT="${SIGPORT:-$(( (RANDOM % 4000) + 9080 ))}"

set -e
# 1. Build the SIDE_MODULE wasm (browser) + the native core dll (export host).
bash "$ROOT/build/build_web.sh" "$PROJ" >/dev/null
bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null

# 2. Headless web export. --import first so the extension loads + the .odin uid registers.
rm -rf "$PROJ/out"; mkdir -p "$PROJ/out"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$PROJ" --export-release "Web" "$PROJ/out/index.html" >/dev/null 2>&1 || true

if [[ ! -f "$PROJ/out/libodin_godot.wasm" || ! -f "$PROJ/out/index.side.wasm" ]]; then
    echo "WEBRTC_FAIL: export did not bundle our SIDE_MODULE + the dlink runtime"
    exit 1
fi
echo "web export bundled: libodin_godot.wasm (our module) + index.side.wasm (dlink runtime)"
set +e

# 3. In-browser verification (best effort). Needs node + a Chrome + puppeteer-core + ws.
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if ! command -v node >/dev/null 2>&1 || [[ ! -x "$CHROME" ]]; then
    echo "WEBRTC_BUNDLED: browser step skipped (no node and/or Chrome at \$CHROME)."
    echo "  Manual: start  node tests/webrtc/signal_server.mjs 9080  +  bash tests/web/serve.sh tests/webrtc/out $PORT"
    echo "  then open http://127.0.0.1:$PORT/index.html?role=host&url=ws://127.0.0.1:9080 in one browser"
    echo "  and   http://127.0.0.1:$PORT/index.html?role=join&url=ws://127.0.0.1:9080 in another."
    exit 0
fi

# puppeteer-core + ws: reuse the tests/web install (symlink) if present, else install locally.
if [[ ! -d "$PROJ/node_modules/puppeteer-core" || ! -d "$PROJ/node_modules/ws" ]]; then
    if [[ -d "$ROOT/tests/web/node_modules/puppeteer-core" && -d "$ROOT/tests/web/node_modules/ws" ]]; then
        ln -sfn "$ROOT/tests/web/node_modules" "$PROJ/node_modules"
    elif (cd "$PROJ" && npm install puppeteer-core@23 ws >/dev/null 2>&1); then :; else
        echo "WEBRTC_BUNDLED: browser step skipped (could not obtain puppeteer-core + ws)."
        exit 0
    fi
fi

# Start the signaling server + the COOP/COEP static server.
node "$PROJ/signal_server.mjs" "$SIGPORT" >"$PROJ/.signal.log" 2>&1 &
SIG=$!
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >/dev/null 2>&1 &
SRV=$!
trap 'kill $SIG $SRV 2>/dev/null || true' EXIT

# Wait for both servers to come up.
for _ in $(seq 1 30); do
    if curl -s -o /dev/null "http://127.0.0.1:$PORT/index.html"; then break; fi
    sleep 0.5
done
for _ in $(seq 1 20); do
    if grep -q "listening on" "$PROJ/.signal.log" 2>/dev/null; then break; fi
    sleep 0.25
done

# Drive the two browsers. Retry once on a flaky handshake before declaring failure.
rc=1
for try in 1 2; do
    echo "==> two-browser attempt $try (signaling ws://127.0.0.1:$SIGPORT)"
    if CHROME="$CHROME" node "$PROJ/drive.mjs" "http://127.0.0.1:$PORT/index.html" "ws://127.0.0.1:$SIGPORT"; then
        rc=0; break
    fi
done

if (( rc == 0 )); then
    echo "WEBRTC_OK"
    exit 0
fi
echo "WEBRTC_FAIL: two browsers did not exchange a WebRTC RPC"
echo "  --- signaling server log ---"; tail -n 20 "$PROJ/.signal.log" 2>/dev/null | sed 's/^/    /'
exit 1
