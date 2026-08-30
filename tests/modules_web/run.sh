#!/usr/bin/env bash
# MULTI-MODULE web test — end-to-end in a real browser.
#
# Proves the multi-dll script-modules feature on the web target, where every module is
# AOT-composed into ONE wasm SIDE_MODULE (build/build_web.sh: main scripts/ + each
# res://modules/<name>). In a real (headless) browser it asserts:
#   * the MAIN module's class runs (Player _ready -> MODWEB_MAIN_RAN),
#   * a MODULE's class runs (Enemy _ready -> MODWEB_MODULE_RAN),
#   * a CROSS-MODULE engine call works (Player.attack -> Enemy.take_hit by name ->
#     MODWEB_CROSS_OK + MODWEB_DRIVER_OK),
#   * the DELIBERATE duplicate explicit alias ("Contested" in both modules) surfaces
#     a LOUD error naming both canonical source paths; path identity stays unambiguous.
#
# Prints MODULES_WEB_OK on a verified in-browser run (GREEN), or MODULES_WEB_BUNDLED if
# the build+export succeeded but the browser step was skipped (YELLOW — run it manually,
# see below). Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/modules_web/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/modules_web"
# Random default port (like SIGPORT in tests/webrtc) so parallel/leftover servers don't collide.
PORT="${PORT:-$(( (RANDOM % 4000) + 9080 ))}"

# 1. Compose main + modules into the single SIDE_MODULE wasm and 2. headless web export.
bash "$ROOT/build/build_web.sh" "$PROJ" >/dev/null
rm -rf "$PROJ/out"; mkdir -p "$PROJ/out"
"$GODOT" --headless --path "$PROJ" --export-release "Web" "$PROJ/out/index.html" >/dev/null 2>&1 || true

if [[ ! -f "$PROJ/out/libodin_godot.wasm" || ! -f "$PROJ/out/index.side.wasm" ]]; then
    echo "MODULES_WEB_FAIL: export did not bundle our SIDE_MODULE + the dlink runtime"
    exit 1
fi
echo "web export bundled: libodin_godot.wasm (our composed module) + index.side.wasm (dlink runtime)"

# 3. In-browser verification (best effort). Needs node + a Chrome + puppeteer-core.
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if ! command -v node >/dev/null 2>&1 || [[ ! -x "$CHROME" ]]; then
    echo "MODULES_WEB_BUNDLED: browser step skipped (no node and/or Chrome at \$CHROME)."
    echo "  Manual: bash tests/web/serve.sh $PROJ/out $PORT & ; open http://127.0.0.1:$PORT/index.html ; check console for MODWEB_DRIVER_OK"
    exit 0
fi

# puppeteer-core: reuse the tests/web install (symlink) if present, else install locally.
if [[ ! -d "$PROJ/node_modules/puppeteer-core" ]]; then
    if [[ -d "$ROOT/tests/web/node_modules/puppeteer-core" ]]; then
        ln -sfn "$ROOT/tests/web/node_modules" "$PROJ/node_modules"
    elif (cd "$PROJ" && npm install puppeteer-core@23 >/dev/null 2>&1); then :; else
        echo "MODULES_WEB_BUNDLED: browser step skipped (could not obtain puppeteer-core)."
        echo "  Manual: bash tests/web/serve.sh $PROJ/out $PORT & ; open http://127.0.0.1:$PORT/index.html ; check console for MODWEB_DRIVER_OK"
        exit 0
    fi
fi

# Serve with COOP/COEP (reuse the web milestone's server), then drive a headless browser.
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
# Wait (up to ~15s) for the server to accept connections.
for _ in $(seq 1 30); do
    if curl -s -o /dev/null "http://127.0.0.1:$PORT/index.html"; then break; fi
    sleep 0.5
done

if (cd "$PROJ" && CHROME="$CHROME" node "$PROJ/drive.mjs" "http://127.0.0.1:$PORT/index.html"); then
    echo "MODULES_WEB_OK"
else
    echo "MODULES_WEB_FAIL: the multi-module build did not verify in the browser"
    exit 1
fi
