#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Persistent-ols-session proof — ONE long-lived `ols` answers many completions, WARM and FAST.
#
# The `_complete_code` virtual is engine-dispatched (not callable from GDScript), so we prove the
# load-bearing logic — the persistent LSP session (bidirectional stdio, reader thread, lazy
# start, crash recovery, fallback) — by building a harness that drives the SAME
# `complete.session_complete` the core dll uses. It:
#   * COLD-completes `gd.node2d_set_p` (pays the one-time ols startup + godot-collection index),
#   * WARM-completes a few small edits and asserts each is « the cold time (resident index),
#   * asserts `node2d_set_position` is present (REAL godot procs, not a faked list),
#   * kills the live ols mid-session and proves the next call RECOVERS,
#   * proves a BOGUS ols fails FAST (ok=false) so the editor falls back instead of hanging.
# Prints LSP_HARNESS_OK.
#
# `ols` is NOT on PATH when the editor launches from Finder (nix store), so we resolve it + the
# Odin `share` dir here and pass them through — the same robust resolution the core glue does via
# the `odin_godot/ols_bin` project setting / `OLS` env.
#
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/lsp/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"

OLS="${OLS:-$(command -v ols || true)}"
if [[ -z "$OLS" ]]; then
    echo "LSP_HARNESS_FAIL: ols not found on PATH (run inside the nix dev shell)" >&2
    exit 1
fi
export OLS
ODIN_BIN="$(command -v odin || true)"
if [[ -n "$ODIN_BIN" ]]; then
    REAL_ODIN="$(readlink -f "$ODIN_BIN" 2>/dev/null || echo "$ODIN_BIN")"
    export ODIN_SHARE="$(cd "$(dirname "$REAL_ODIN")/.." && pwd)/share"
fi

OUT="$ROOT/tests/lsp/harness"
trap 'rm -f "$OUT"' EXIT

# Build the harness; `complete` resolves via the godot collection (== repo root) -> core/complete.
odin build "$ROOT/tests/lsp" \
    -collection:godot="$ROOT" \
    -out:"$OUT" \
    -debug

"$OUT" "$ROOT"
