#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# SOLO gate for claimball. Proves the contested-object loop runs headless as
# host-with-no-peers: the striker bot dribbles its PREDICTED ball (contact +
# kick in the world pass), the goal detects inside the ball's own tick, the
# score lands via ball_tick_then, and the match edge narrates from replicated
# bytes. Prints CLAIMBALL_SINGLE_OK.
#
#   nix develop --command bash -c 'bash examples/claimball/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/claimball"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

ELOG="$(mktemp)"; trap 'rm -f "$ELOG"' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --quit-after 10 >"$ELOG" 2>&1
set -e
if grep -qE "signal 11|must be overridden|Required virtual" "$ELOG"; then
    echo "CLAIMBALL_SINGLE_FAIL: editor-open smoke logged a crash / missing virtual"
    tail -n 20 "$ELOG"; exit 1
fi
echo "claimball: editor-open smoke clean"

SLOG="$(mktemp)"; trap 'rm -f "$ELOG" "$SLOG"' EXIT
set +e
CLB_ROLE=single CLB_BOT=striker CLB_GOALS=1 CLB_TOKEN=901 \
    "$GODOT" --headless --path "$PROJ" --quit-after 3000 >"$SLOG" 2>&1
set -e

ok=1
for want in "CLB_HOSTING" "CLB_WORLD_UP" "CLB_STARTED" "CLB_KICK" "CLB_GOAL team=1" "CLB_MATCH winner=1" "CLAIMBALL_DONE"; do
    grep -q "$want" "$SLOG" || { echo "missing: $want"; ok=0; }
done
if grep -qE "SCRIPT ERROR|signal 11|ODIN_SCRIPT_PANIC" "$SLOG"; then
    echo "claimball: runtime errors in the solo log"; ok=0
fi

if ((ok==1)); then
    echo "CLAIMBALL_SINGLE_OK proved: headless contested-ball loop — dribble, kick, predicted goal reset, delta-lane score, solo"
    exit 0
fi
tail -n 40 "$SLOG"
echo "CLAIMBALL_SINGLE_FAIL"
exit 1
