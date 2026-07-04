#!/usr/bin/env bash
# Pure-Odin unit tests for kit/session — player identity, join/leave/reconnect,
# roster sync (sessions wired through an in-memory pipe; the full wire path
# minus the socket). No Godot process needed. Prints KITSESSION_OK on success.
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/kitsession/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitsession" -collection:godot="$ROOT"
echo "KITSESSION_OK"
