#!/usr/bin/env bash
# Pure-Odin unit tests for the `events` observer — no Godot process needed.
# Wraps `odin test tests/events -collection:godot=$ROOT` and prints EVENTS_OK on success.
# (The EVENTS_OK sentinel-grep contract lives in tests/run_all.sh.)
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/events/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/events" -collection:godot="$ROOT"
echo "EVENTS_OK"
