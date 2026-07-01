#!/usr/bin/env bash
# Web/WASM showcase milestone — end-to-end, FULL GAME LOOP in a real browser.
#
# Proves the pure-Odin coin-collector showcase (Player/Coin/Hud + the shared game_state
# module, all compiled into ONE Emscripten SIDE_MODULE wasm) runs in a real browser: a
# GDScript driver (driver.gd, the web export's main scene) moves the Player onto a Coin and
# steps PHYSICS so the Area2D's body_entered fires NATURALLY -> Odin collect -> shared score
# increments -> `collected` signal emitted -> coin freed -> cross-script HUD updates. The
# driver prints `SHOWCASE_WEB_OK score=<n> value=<v>` to the browser console; drive.mjs
# captures it.
#
# Prints PHASEWEBSHOWCASE_OK on a verified in-browser run (GREEN), or
# PHASEWEBSHOWCASE_BUNDLED if the build+export succeeded but the browser step was skipped
# (YELLOW). Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/web_showcase/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/web_showcase"
# Random default port (like SIGPORT in tests/webrtc) so parallel/leftover servers don't collide.
PORT="${PORT:-$(( (RANDOM % 4000) + 9080 ))}"

# 1. Build the full SIDE_MODULE wasm (core + binding + the showcase scripts) for the
#    browser, AND the native core dll for the macOS export host. The host dll is what makes
#    Godot load the extension at export time so its OdinResourceFormatLoader recognizes the
#    authored `.odin` files and PACKS them — without it the scripts' base types cannot be
#    resolved in the browser (no source in the pck).
bash "$ROOT/build/build_web.sh" "$PROJ" >/dev/null
bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null

# 2. headless web export. --import first so the extension loads + `.odin` uids register.
rm -rf "$PROJ/out"; mkdir -p "$PROJ/out"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$PROJ" --export-release "Web" "$PROJ/out/index.html" >/dev/null 2>&1 || true

if [[ ! -f "$PROJ/out/libodin_godot.wasm" || ! -f "$PROJ/out/index.side.wasm" ]]; then
    echo "PHASEWEBSHOWCASE_FAIL: export did not bundle our SIDE_MODULE + the dlink runtime"
    exit 1
fi
echo "web export bundled: libodin_godot.wasm (our module) + index.side.wasm (dlink runtime)"

# 3. In-browser verification (best effort). Needs node + a Chrome + puppeteer-core.
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if ! command -v node >/dev/null 2>&1 || [[ ! -x "$CHROME" ]]; then
    echo "PHASEWEBSHOWCASE_BUNDLED: browser step skipped (no node and/or Chrome at \$CHROME)."
    echo "  Manual: bash tests/web_showcase/serve.sh & ; open http://127.0.0.1:$PORT/index.html ; check console for SHOWCASE_WEB_OK"
    exit 0
fi

# puppeteer-core: reuse the tests/web install (symlink) if present, else install locally.
if [[ ! -d "$PROJ/node_modules/puppeteer-core" ]]; then
    if [[ -d "$ROOT/tests/web/node_modules/puppeteer-core" ]]; then
        ln -sfn "$ROOT/tests/web/node_modules" "$PROJ/node_modules"
    elif (cd "$PROJ" && npm install puppeteer-core@23 >/dev/null 2>&1); then :; else
        echo "PHASEWEBSHOWCASE_BUNDLED: browser step skipped (could not obtain puppeteer-core)."
        echo "  Manual: bash tests/web_showcase/serve.sh & ; open http://127.0.0.1:$PORT/index.html ; check console for SHOWCASE_WEB_OK"
        exit 0
    fi
fi

# Serve with COOP/COEP (reuse the web milestone's server), then drive a headless browser.
bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$PORT" >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
for _ in $(seq 1 30); do
    if curl -s -o /dev/null "http://127.0.0.1:$PORT/index.html"; then break; fi
    sleep 0.5
done

if (cd "$PROJ" && CHROME="$CHROME" node "$PROJ/drive.mjs" "http://127.0.0.1:$PORT/index.html"); then
    echo "PHASEWEBSHOWCASE_OK"
else
    echo "PHASEWEBSHOWCASE_FAIL: showcase game loop did not run in the browser"
    exit 1
fi
