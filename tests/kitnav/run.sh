#!/usr/bin/env bash
# kit/nav adapter test: a U-shaped walkable NavigationPolygon (two arms
# joined only along the bottom) — the engine path MUST bend through the
# bottom strip, and a kit/ai walker follows it with the next_point cursor.
# Prints KITNAV_OK. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/kitnav/run.sh'
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/kitnav"
LOG="$PROJ/.runlogs/nav.log"
mkdir -p "$PROJ/.runlogs"

bash "$ROOT/build/build_scripts.sh" "$PROJ"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$PROJ" --script nav_test.gd >"$LOG" 2>&1 || true

ok=1
grep -q "NAVTEST bent=true" "$LOG" || { echo "FAIL: path never bent through the corridor"; ok=0; }
grep -q "NAVTEST_WALKED ok=true" "$LOG" || { echo "FAIL: the walker never arrived"; ok=0; }
grep -q "NAVTEST_DONE" "$LOG" || { echo "FAIL: driver did not finish"; ok=0; }

if ((ok == 1)); then
	grep -E "NAVTEST" "$LOG" | sed 's/^/  /'
	echo "KITNAV_OK"
	exit 0
fi
tail -n 20 "$LOG" | sed 's/^/  /'
echo "KITNAV_FAIL"
exit 1
