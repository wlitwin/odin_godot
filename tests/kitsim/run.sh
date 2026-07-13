#!/usr/bin/env bash
# Pure-Odin unit tests for kit/sim — the server-authority resim companion's
# engine-free core (predict subset, history ledger, input pipeline, sim
# ticker + lead control, reconcile). No Godot process needed. Prints
# KITSIM_OK on success. Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/kitsim/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitsim" -collection:godot="$ROOT"
echo "KITSIM_OK"
