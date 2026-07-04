#!/usr/bin/env bash
# Pure-Odin unit tests for kit/combat — damage/death boundaries, ability
# gates (cooldown + cost), status-effect refresh/expiry, swept projectile
# hits (no tunneling), and auto-published combat stat columns.
# Prints KITCOMBAT_OK on success. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/kitcombat/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitcombat" -collection:godot="$ROOT"
echo "KITCOMBAT_OK"
