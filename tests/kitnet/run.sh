#!/usr/bin/env bash
# Pure-Odin unit tests for kit/net — the friendslop toolkit's replication core
# (wire format, shadow-copy deltas, intent pipeline, dedup, tick/clock, interp).
# No Godot process needed. Prints KITNET_OK on success.
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/kitnet/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitnet" -collection:godot="$ROOT"
echo "KITNET_OK"
