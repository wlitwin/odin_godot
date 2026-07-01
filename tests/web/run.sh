#!/usr/bin/env bash
# Web/WASM milestone — end-to-end.
#
# Proves the FULL odin_godot extension (core + binding + the project's compiled scripts)
# builds into ONE Emscripten SIDE_MODULE wasm, that Godot 4.6.2's headless web export
# bundles it, and (if a browser + puppeteer-core are available) that an Odin script's
# `_ready` actually RUNS in the browser (prints WEB_RAN + WEB_ASSERT_OK to the JS console).
#
# Prints PHASEWEB_OK on a verified in-browser run (GREEN), or PHASEWEB_BUNDLED if the
# build+export succeeded but the browser step was skipped (YELLOW — run it manually, see
# below). Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/web/run.sh'
#
# Pin emscripten 4.0.20 (the engine's exact version) with EMCC=/path/to/4.0.20/emcc; the
# dev shell's emcc also produces a browser-loadable module (verified — see docs/exporting.md
# and docs/design/web-internals.md).
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/web"
# Random default port (like SIGPORT in tests/webrtc) so parallel/leftover servers don't collide.
PORT="${PORT:-$(( (RANDOM % 4000) + 9080 ))}"

# 1. Build the full SIDE_MODULE wasm and 2. headless web export.
bash "$ROOT/build/build_web.sh" "$PROJ" >/dev/null
rm -rf "$PROJ/out"; mkdir -p "$PROJ/out"
"$GODOT" --headless --path "$PROJ" --export-release "Web" "$PROJ/out/index.html" >/dev/null 2>&1 || true

if [[ ! -f "$PROJ/out/libodin_godot.wasm" || ! -f "$PROJ/out/index.side.wasm" ]]; then
    echo "PHASEWEB_FAIL: export did not bundle our SIDE_MODULE + the dlink runtime"
    exit 1
fi
echo "web export bundled: libodin_godot.wasm (our module) + index.side.wasm (dlink runtime)"

# 3. In-browser verification (best effort). Needs node + a Chrome + puppeteer-core.
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if ! command -v node >/dev/null 2>&1 || [[ ! -x "$CHROME" ]]; then
    echo "PHASEWEB_BUNDLED: browser step skipped (no node and/or Chrome at \$CHROME)."
    echo "  Manual: bash tests/web/serve.sh & ; open http://127.0.0.1:$PORT/index.html ; check console for WEB_RAN"
    exit 0
fi

# puppeteer-core lives next to this script (npm i puppeteer-core) or globally.
DRIVE_DIR="$PROJ"
if [[ ! -d "$PROJ/node_modules/puppeteer-core" ]]; then
    if (cd "$PROJ" && npm install puppeteer-core@23 >/dev/null 2>&1); then :; else
        echo "PHASEWEB_BUNDLED: browser step skipped (could not install puppeteer-core)."
        echo "  Manual: bash tests/web/serve.sh & ; open http://127.0.0.1:$PORT/index.html ; check console for WEB_RAN"
        exit 0
    fi
fi

# Serve with COOP/COEP, then drive a headless browser.
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
# Wait (up to ~15s) for the server to accept connections.
for _ in $(seq 1 30); do
    if curl -s -o /dev/null "http://127.0.0.1:$PORT/index.html"; then break; fi
    sleep 0.5
done

if (cd "$DRIVE_DIR" && CHROME="$CHROME" node "$ROOT/tests/web/drive.mjs" "http://127.0.0.1:$PORT/index.html"); then
    echo "PHASEWEB_OK"
else
    echo "PHASEWEB_FAIL: extension did not run in the browser"
    exit 1
fi
