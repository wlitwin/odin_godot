#!/usr/bin/env bash
# Pure-Odin unit tests for the `flow` sequencer — no Godot process needed.
# Wraps `odin test tests/flow -collection:godot=$ROOT` and prints FLOW_OK on success.
# (The FLOW_OK sentinel-grep contract lives in tests/run_all.sh.)
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/flow/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/flow" -collection:godot="$ROOT"
echo "FLOW_OK"
