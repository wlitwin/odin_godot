#!/usr/bin/env bash
# Barrage WEB export smoke test — build the AOT SIDE_MODULE wasm (all five script
# modules composed into one), export the Web preset headless, then verify in a real
# browser: the title scene boots (BARRAGE_TITLE_READY) and clicking Play enters the
# game scene (BARRAGE_FIELD_READY). See drive_web.mjs.
#
# Prints BARRAGE_WEB_OK on a verified in-browser run (GREEN), or BARRAGE_WEB_BUNDLED
# if the build+export succeeded but the browser step was skipped (YELLOW).
# Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash examples/barrage/web_run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/barrage"
PORT="${PORT:-$(( (RANDOM % 4000) + 9080 ))}"

# 1. Build the SIDE_MODULE wasm + the native core dll (the macOS export host needs the
#    extension loaded at export time so `.odin` files are recognized and packed).
bash "$ROOT/build/build_web.sh" "$PROJ" >/dev/null
bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null

# 2. Headless web export. --import first so the extension loads + `.odin` uids register.
rm -rf "$PROJ/out"; mkdir -p "$PROJ/out"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$PROJ" --export-release "Web" "$PROJ/out/index.html" >/dev/null 2>&1 || true

if [[ ! -f "$PROJ/out/libodin_godot.wasm" || ! -f "$PROJ/out/index.side.wasm" ]]; then
    echo "BARRAGE_WEB_FAIL: export did not bundle our SIDE_MODULE + the dlink runtime"
    exit 1
fi
echo "web export bundled: libodin_godot.wasm (5 script modules) + index.side.wasm (dlink runtime)"

# 3. In-browser verification (best effort). Needs node + a Chrome + puppeteer-core.
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if ! command -v node >/dev/null 2>&1 || [[ ! -x "$CHROME" ]]; then
    echo "BARRAGE_WEB_BUNDLED: browser step skipped (no node and/or Chrome at \$CHROME)."
    exit 0
fi

# puppeteer-core: reuse the tests/web install (symlink) if present, else install locally.
if [[ ! -d "$PROJ/node_modules/puppeteer-core" ]]; then
    if [[ -d "$ROOT/tests/web/node_modules/puppeteer-core" ]]; then
        ln -sfn "$ROOT/tests/web/node_modules" "$PROJ/node_modules"
    elif (cd "$PROJ" && npm install puppeteer-core@23 >/dev/null 2>&1); then :; else
        echo "BARRAGE_WEB_BUNDLED: browser step skipped (could not obtain puppeteer-core)."
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

if (cd "$PROJ" && CHROME="$CHROME" node "$PROJ/drive_web.mjs" "http://127.0.0.1:$PORT/index.html"); then
    echo "BARRAGE_WEB_OK"
else
    echo "BARRAGE_WEB_FAIL: barrage did not boot/play in the browser"
    exit 1
fi
