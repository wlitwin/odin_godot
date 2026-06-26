#!/usr/bin/env bash
# Regression test for the gdext.godot_allocator zeroing bug (the temp-arena
# `assert(block.used == 0)` crash that aborted the editor on big `gd.`
# completions). Builds a tiny harness that exercises the REAL
# `gdext.godot_allocator` with a poisoned (non-zeroing) backing malloc, forcing
# both a direct `.Alloc` zeroing check and a multi-block Arena grow. Prints
# GDEXT_ALLOC_OK on success; aborts (no sentinel) if the bug is present.
#
# Usage (from repo root, inside the nix dev shell):
#   nix develop --command bash tests/gdext_alloc/run.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/tests/gdext_alloc/harness"
trap 'rm -f "$OUT"' EXIT

# `gdext` resolves via the godot collection (== repo root).
odin build "$ROOT/tests/gdext_alloc" \
	-collection:godot="$ROOT" \
	-out:"$OUT" \
	-debug

"$OUT"
