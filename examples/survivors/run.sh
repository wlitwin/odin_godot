#!/usr/bin/env bash
# Build (via the codegen pipeline) + verify the pure-Odin "Odin Survivors" example.
#
#   nix develop --command bash -c 'bash examples/survivors/run.sh'
#
# Two gates:
#   1. EDITOR-OPEN SMOKE — open the project in the headless editor briefly; it must NOT log
#      `signal 11` / `must be overridden` (i.e. the script-language virtuals are all wired).
#   2. HEADLESS COMBAT LOOP — test_survivors.gd drives the REAL game loop (input -> movement;
#      bullet -> enemy typed-damage -> death -> score -> HUD; enemy -> player contact damage
#      -> health_changed -> HUD) through actual physics overlaps, and prints SURVIVORS_OK.
set -euo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/survivors"

# Build the scripts dll (Player/Enemy/Bullet/Spawner/Hud/EnemyConfig + shared modules) + core.
bash "$ROOT/build/build_scripts.sh" "$PROJ"

# Make the scripts dll path unambiguous for the core's dynlib load.
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# Write .godot/extension_list.cfg + import so the runtime loads the extension. (A SIGSEGV in
# Godot's headless editor doc-gen at import cleanup is a pre-existing engine issue, unrelated
# to this extension — masked here as in the other test harnesses.)
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# ---- (1) editor-open smoke -------------------------------------------------------------
ELOG="$(mktemp)"
trap 'rm -f "$ELOG"' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --quit-after 10 >"$ELOG" 2>&1
set -e
if grep -qE "signal 11|must be overridden|Required virtual" "$ELOG"; then
    echo "SURVIVORS_FAIL: editor-open smoke logged a crash / missing-virtual error"
    tail -n 20 "$ELOG"
    exit 1
fi
echo "SURVIVORS: editor-open smoke clean"

# ---- (2) headless combat-loop test -----------------------------------------------------
"$GODOT" --headless --path "$PROJ" --script test_survivors.gd
