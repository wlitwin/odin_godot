#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# `_lookup_code` proof — the PURE symbol->(class,member) mapping that drives goto-definition
# (Ctrl+Cmd-click "Lookup Symbol") to Godot's BUILT-IN class docs for a `gd.<class>_<member>`.
#
# The `_lookup_code` virtual is engine-dispatched (not callable from GDScript), so we prove the
# load-bearing logic — longest-prefix class match with `_`-boundary disambiguation (`node` vs
# `node2d`), the `gd.` strip, the exact-class case, and graceful misses — by building a tiny
# harness that calls the SAME `lookup.resolve_symbol` the core dll uses, then prints LOOKUP_OK.
#
# The ClassDB classification (method/signal/constant/property) and the editor actually OPENING the
# docs page on Cmd+click can only be confirmed interactively (the virtual isn't callable headless).
#
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/lookup/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"

OUT="$ROOT/tests/lookup/harness"
trap 'rm -f "$OUT"' EXIT

# Build the harness; `lookup` resolves via the godot collection (== repo root) -> core/lookup.
odin build "$ROOT/tests/lookup" \
    -collection:godot="$ROOT" \
    -out:"$OUT" \
    -debug

"$OUT"
