#!/usr/bin/env bash
# Pure-Odin unit tests for kit/save's versioned envelope — THE SAVE SAGA
# (save a live run, everything dies, resume from bytes under the saved
# identity, a player rejoins by token and reclaims everything, and the
# resumed host still answers commands) plus corrupt/foreign-save refusal.
# Prints KITSAVE_OK on success. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/kitsave/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitsave" -collection:godot="$ROOT"
echo "KITSAVE_OK"
