#!/usr/bin/env bash
# Pure-Odin unit tests for kit/fx — the trauma shake: legacy zero-value feel,
# the knobs (max_offset/decay/exponent/noise/max_roll), coherence, and the
# tick/sample split behind the rotation channels. No Godot process needed.
# Prints KITFX_OK on success. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/kitfx/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitfx" -collection:godot="$ROOT"
echo "KITFX_OK"
