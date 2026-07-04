#!/usr/bin/env bash
# Pure-Odin unit tests for kit/comms — chat relayed in host order, positional
# markers, system lines, drop-in catchup — plus the session's SES_APP routing
# contract they ride on. No Godot process needed. Prints KITCOMMS_OK on success.
# Run inside the Nix dev shell, e.g.:
#   nix develop --command bash -c 'bash tests/kitcomms/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitcomms" -collection:godot="$ROOT"
echo "KITCOMMS_OK"
