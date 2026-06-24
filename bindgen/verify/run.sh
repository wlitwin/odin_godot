#!/usr/bin/env bash
# Runtime verification of the three binding-correctness fixes (A/B/C).
# Builds bindgen/verify/verify.odin into a GDExtension shared library, loads it
# in a headless Godot, and greps for the "VERIFY:" results.
#
# Run from the repo root inside the Nix dev shell:
#     nix develop --command bash bindgen/verify/run.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$REPO/bindgen/verify"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"

echo "==> building libverify.dylib"
odin build "$VERIFY" \
    -collection:godot="$REPO" \
    -build-mode:shared \
    -define:REAL_PRECISION=single \
    -out:"$VERIFY/proj/libverify.dylib"

echo "==> running headless Godot (import pass loads + inits the extension)"
"$GODOT" --headless --path "$VERIFY/proj" --import 2>&1 | grep -E "VERIFY:" || {
    echo "no VERIFY output -- extension failed to load"; exit 1; }

# cleanup regenerable artifacts
rm -f "$VERIFY/proj/libverify.dylib"
rm -rf "$VERIFY/proj/.godot"
