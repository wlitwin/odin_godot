#!/usr/bin/env bash
# THE PHASE-4 INTEGRATION TEST: combat over the session pipeline (in-memory
# pipe). Predicted casts (gate bites instantly, host refuses identically),
# host-simulated rocks with swept hits, chill effects wearing off, death +
# owner-side respawn, and the damage/kills/deaths ledger on every peer.
# Prints KITARENA_OK on success. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/kitarena/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitarena" -collection:godot="$ROOT"
echo "KITARENA_OK"
