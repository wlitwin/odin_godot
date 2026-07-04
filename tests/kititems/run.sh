#!/usr/bin/env bash
# Pure-Odin unit tests for kit/items (stack-aware slot ops used inside
# predicted commands) and kit/interact (dimension-agnostic range/facing
# gates). No Godot process needed. Prints KITITEMS_OK on success.
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/kititems/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kititems" -collection:godot="$ROOT"
echo "KITITEMS_OK"
