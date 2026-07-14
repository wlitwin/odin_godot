#!/usr/bin/env bash
# Pure-Odin unit tests for kit/xfer's ALBUM — kept payloads per (player,
# kind), own-copy short circuit, supersede, and the late joiner's
# album_welcome catch-up — over the in-memory session pipe. No Godot process
# needed. Prints KITXFER_OK on success. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/kitxfer/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitxfer" -collection:godot="$ROOT"
echo "KITXFER_OK"
