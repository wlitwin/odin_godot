#!/usr/bin/env bash
# THE PHASE-3 INTEGRATION TEST: chests/bags/doors over the full session
# pipeline (in-memory pipe). Two spelunkers race for one gem — the winner's
# prediction stands, the loser reverts, gems are conserved on every peer.
# Also: range gates (same proc client+host), door toggle prediction, overflow
# returning to the chest, the host looting via the authority path.
# Prints KITLOOT_OK on success. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/kitloot/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitloot" -collection:godot="$ROOT"
echo "KITLOOT_OK"
