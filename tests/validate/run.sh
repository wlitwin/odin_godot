#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# `_validate` proof — the REAL Odin compiler surfaces a type error at the right line.
#
# The `_validate` virtual is engine-dispatched (not callable from GDScript), so we prove the
# load-bearing logic — the LIVE-buffer overlay + `odin check` + diagnostic parsing — by
# building a tiny harness that calls the SAME `diag.run_check_overlay` the core dll uses.
# It checks a clean fixture package (-> 0 errors) and a deliberately broken live buffer
# (-> 1 error at the exact line/column), then prints VALIDATE_HARNESS_OK.
#
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/validate/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"

OUT="$ROOT/tests/validate/harness"
trap 'rm -f "$OUT"' EXIT

# Build the harness; `diag` resolves via the godot collection (== repo root) -> core/diag.
odin build "$ROOT/tests/validate" \
    -collection:godot="$ROOT" \
    -out:"$OUT" \
    -debug

"$OUT" "$ROOT"
