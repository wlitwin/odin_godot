#!/usr/bin/env bash
# Build a third scripts generation after deleting one authored class. ProcHolder is
# still compiled but intentionally lacks a reload hook; both cases must pin only v2.
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
rm -f "$ROOT/tests/phase4/scripts/removed_class.odin"
cp "$ROOT/tests/phase4/fixtures/lifecycle_toggle_v2.odin" \
   "$ROOT/tests/phase4/scripts/lifecycle_toggle.odin"
export SCRIPT_BUILD_FLAGS="-define:RELOAD_V=3"
export SKIP_CORE=1
bash "$ROOT/build/build_scripts.sh" "$ROOT/tests/phase4"
