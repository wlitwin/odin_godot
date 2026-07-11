#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# SOLO gate for slopball3d. Proves the 3D ENGINE-PHYSICS loop runs headless end
# to end as host-with-no-peers: a real RigidBody3D ball under gravity
# (play.Puppet3, quaternion rotation), a real CharacterBody3D striker driven
# through move_and_slide on the XZ plane, a lofted kick, a goal off the
# replicated pose, and the match edge. Prints SLOPBALL3D_SINGLE_OK.
#
#   nix develop --command bash -c 'bash examples/slopball3d/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/slopball3d"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# ---- (1) editor-open smoke: no missing-virtual / crash from the wiring ----
ELOG="$(mktemp)"; trap 'rm -f "$ELOG"' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --quit-after 10 >"$ELOG" 2>&1
set -e
if grep -qE "signal 11|must be overridden|Required virtual" "$ELOG"; then
    echo "SLOPBALL3D_SINGLE_FAIL: editor-open smoke logged a crash / missing virtual"
    tail -n 20 "$ELOG"; exit 1
fi
echo "slopball3d: editor-open smoke clean"

# ---- (2) the solo loop: striker bot vs an empty pitch, first goal ends it ----
SLOG="$(mktemp)"; trap 'rm -f "$ELOG" "$SLOG"' EXIT
set +e
SLOP3_ROLE=single SLOP3_BOT=striker SLOP3_GOALS=1 SLOP3_TOKEN=903 \
    "$GODOT" --headless --path "$PROJ" --quit-after 3000 >"$SLOG" 2>&1
set -e

ok=1
for want in "SB3_HOSTING" "SB3_WORLD_UP" "SB3_STARTED" "SB3_KICK" "SB3_GOAL by=1" "SB3_MATCH winner=1" "SLOPBALL3D_DONE"; do
    grep -q "$want" "$SLOG" || { echo "missing: $want"; ok=0; }
done
if grep -qE "SCRIPT ERROR|signal 11" "$SLOG"; then
    echo "slopball3d: runtime errors in the solo log"; ok=0
fi

if ((ok==1)); then
    echo "SLOPBALL3D_SINGLE_OK proved: headless RigidBody3D ball under gravity + move_and_slide striker, lofted kick -> goal -> match, solo"
    exit 0
fi
tail -n 40 "$SLOG"
echo "SLOPBALL3D_SINGLE_FAIL"
exit 1
