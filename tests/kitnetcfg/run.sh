#!/usr/bin/env bash
# Pure-Odin tests for named complete-stack network profiles and validation.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

"${ODIN:-odin}" test "$ROOT/tests/kitnetcfg" -collection:godot="$ROOT"
echo "KITNETCFG_OK"
