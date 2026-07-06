#!/usr/bin/env bash
# The kit's scale benchmark — delta walk / join snapshot / save-resume at
# N = 100 / 500 / 2000 entities, through the in-memory pipe (no Godot process).
# Prints a STRESS table + KITSTRESS_OK. Correctness asserted hard; timing
# asserts are loose O(n^2) tripwires only. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/kitstress/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitstress" -collection:godot="$ROOT" -o:speed
echo "KITSTRESS_OK"
