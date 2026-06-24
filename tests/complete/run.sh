#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# `_complete_code` proof — the REAL `ols` language server returns accurate completions.
#
# The `_complete_code` virtual is engine-dispatched (not callable from GDScript), so we prove
# the load-bearing logic — the LIVE-buffer overlay + `ols` LSP handshake + CompletionItem
# parsing — by building a tiny harness that calls the SAME `complete.run_completion` the core
# dll uses. It types `gd.node2d_set_p` inside the showcase player package and asserts the
# returned options CONTAIN `node2d_set_position` (a real proc from godot/node2d.gen.odin),
# then prints COMPLETE_HARNESS_OK.
#
# `ols` is NOT on PATH when the editor launches from Finder (it lives in the nix store), so we
# resolve it + the Odin distribution `share` dir (base/core/vendor collections) here and pass
# them through — the same robust-resolution the core glue does via the `odin_godot/ols_bin`
# project setting / `OLS` env.
#
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/complete/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"

# Resolve ols + the odin `share` collection root so the harness exercises the exact tools the
# editor would (and so the test does not silently pass when ols is missing).
OLS="${OLS:-$(command -v ols || true)}"
if [[ -z "$OLS" ]]; then
    echo "COMPLETE_HARNESS_FAIL: ols not found on PATH (run inside the nix dev shell)" >&2
    exit 1
fi
export OLS
ODIN_BIN="$(command -v odin || true)"
if [[ -n "$ODIN_BIN" ]]; then
    REAL_ODIN="$(readlink -f "$ODIN_BIN" 2>/dev/null || echo "$ODIN_BIN")"
    export ODIN_SHARE="$(cd "$(dirname "$REAL_ODIN")/.." && pwd)/share"
fi

OUT="$ROOT/tests/complete/harness"
trap 'rm -f "$OUT"' EXIT

# Build the harness; `complete` resolves via the godot collection (== repo root) -> core/complete.
odin build "$ROOT/tests/complete" \
    -collection:godot="$ROOT" \
    -out:"$OUT" \
    -debug

"$OUT" "$ROOT"
