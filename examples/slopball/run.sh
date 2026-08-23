#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# SOLO gate for slopball. Proves the ENGINE-PHYSICS loop runs headless end to
# end as host-with-no-peers: a real RigidBody2D ball (play.Puppet), a real
# CharacterBody2D striker driven through move_and_slide, a kick, a goal off
# the replicated pose, and the match edge. Prints SLOPBALL_SINGLE_OK.
#
#   nix develop --command bash -c 'bash examples/slopball/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/slopball"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# ---- (1) editor-open smoke: no missing-virtual / crash from the wiring ----
ELOG="$(mktemp)"; trap 'rm -f "$ELOG"' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --quit-after 10 >"$ELOG" 2>&1
set -e
if grep -qE "signal 11|must be overridden|Required virtual" "$ELOG"; then
    echo "SLOPBALL_SINGLE_FAIL: editor-open smoke logged a crash / missing virtual"
    tail -n 20 "$ELOG"; exit 1
fi
echo "slopball: editor-open smoke clean"

# ---- (2) the solo loop: striker bot vs an empty pitch, first goal ends it ----
SLOG="$(mktemp)"; trap 'rm -f "$ELOG" "$SLOG"' EXIT
set +e
SLOP_ROLE=single SLOP_BOT=striker SLOP_GOALS=1 SLOP_TOKEN=901 \
    "$GODOT" --headless --path "$PROJ" --quit-after 3000 >"$SLOG" 2>&1
set -e

ok=1
for want in "SB_HOSTING" "SB_WORLD_UP" "SB_STARTED" "SB_KICK" "SB_GOAL by=1" "SB_MATCH winner=1" "SLOPBALL_DONE"; do
    grep -q "$want" "$SLOG" || { echo "missing: $want"; ok=0; }
done
if grep -qE "SCRIPT ERROR|signal 11" "$SLOG"; then
    echo "slopball: runtime errors in the solo log"; ok=0
fi


if ((ok==1)); then
    echo "SLOPBALL_SINGLE_OK proved: headless RigidBody2D ball + move_and_slide striker, kick -> goal -> match, solo"
    exit 0
fi
tail -n 40 "$SLOG"
echo "SLOPBALL_SINGLE_FAIL"
exit 1
