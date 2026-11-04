#!/usr/bin/env bash
# Build a browser (HTML5) export of the offline Box3D example, zipped for itch.io.
#
#   nix develop --command bash examples/box3d_offline/export_web.sh
#
# Output: examples/box3d_offline/out/web/ and out/box3d-offline-web.zip, with index.html
# at the zip root as itch.io expects. On itch.io, tick "SharedArrayBuffer support"
# (see README.md). Try it locally first:
#
#   nix develop --command bash build/serve.sh examples/box3d_offline/out/web
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJ="$ROOT/examples/box3d_offline"
CACHE="$ROOT/.box3d-cache"
OUT="$PROJ/out"
: "${GODOT:?run inside the dev shell: nix develop --command bash $0}"
case "$(uname -s)" in
    Darwin) ext=dylib ;;
    Linux) ext=so ;;
    *) ext=dll ;;
esac
log="$(mktemp)"
trap 'rm -f "$log"' EXIT

# 1. Native build. The export runs in this machine's Godot, which loads the native
#    extension to recognise the .odin scripts and pack them into the game.
if [[ -z "${BOX3D_NATIVE_LIBRARY:-}" ]]; then
    bash "$ROOT/build/build_box3d.sh" Release "$CACHE"
    export BOX3D_NATIVE_LIBRARY="$CACHE/build/Release/libogb3.$ext"
fi

bash "$ROOT/build/build_scripts.sh" "$PROJ"

# 2. Box3D compiled for the browser (wasm32 with SIMD). The build ends with one JSON
#    line naming the archive.
bash "$ROOT/build/build_box3d.sh" WebSIMD "$CACHE" | tee "$log"
archive="$(python3 - "$log" <<'PY'
import json, sys
for line in reversed(open(sys.argv[1]).read().splitlines()):
    if line.startswith("{") and '"archive"' in line:
        print(json.loads(line)["archive"])
        break
PY
)"

if [[ ! -f "$archive" ]]; then
    echo "export_web.sh: the Box3D web build did not report an archive" >&2
    exit 1
fi

# 3. Godot's Web export. The SDK's export plugin rebuilds bin/libodin_godot.wasm with
#    build/build_web.sh: it finds the repository through ODIN_GODOT_ROOT and links Box3D
#    from BOX3D_WEB_ARCHIVE. Godot exits 0 even when the plugin fails, so check its log.
rm -rf "$OUT/web"
mkdir -p "$OUT/web"
ODIN_GODOT_ROOT="$ROOT" BOX3D_WEB_ARCHIVE="$archive" \
    "$GODOT" --headless --path "$PROJ" --export-release "Web" "$OUT/web/index.html" 2>&1 | tee "$log"

if ! grep -q "odin export: built web SIDE_MODULE" "$log" || grep -q "ERROR: odin export" "$log"; then
    echo "export_web.sh: the web export failed; see the output above" >&2
    exit 1
fi

# 4. The zip to upload.
zip="$OUT/box3d-offline-web.zip"
rm -f "$zip"
(cd "$OUT/web" && zip -q -r "$zip" .)
echo
echo "Web export: $OUT/web"
echo "Upload to itch.io: $zip ($(du -h "$zip" | cut -f1))"
