#!/usr/bin/env bash
# Pure-Odin unit tests for kit/ai — perception (range + LoS gate), steering
# (seek/flee/patrol), and the wave director. No Godot process needed.
# Prints KITAI_OK on success. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/kitai/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitai" -collection:godot="$ROOT"
echo "KITAI_OK"
