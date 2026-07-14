#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# SOLO gate for quickdraw. Proves the SIM-LANE loop runs headless end to end
# as host-with-no-peers: the lane anchors nothing (the host IS the timeline),
# the orbit bot strafes through gunner_tick, fires through the world pass,
# and the shot adjudicates through lane_rewound (judging live — no acked view
# to rewind to, exactly the spec). Prints QUICKDRAW_SINGLE_OK.
#
#   nix develop --command bash -c 'bash examples/quickdraw/run.sh'
# ----------------------------------------------------------------------------
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/quickdraw"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# ---- (1) editor-open smoke ----
ELOG="$(mktemp)"; trap 'rm -f "$ELOG"' EXIT
set +e
"$GODOT" --editor --headless --path "$PROJ" --quit-after 10 >"$ELOG" 2>&1
set -e
if grep -qE "signal 11|must be overridden|Required virtual" "$ELOG"; then
    echo "QUICKDRAW_SINGLE_FAIL: editor-open smoke logged a crash / missing virtual"
    tail -n 20 "$ELOG"; exit 1
fi
echo "quickdraw: editor-open smoke clean"

# ---- (2) the solo loop: one orbiting bot, shots into empty air, and THE
# SHOP: QD_GOLD seeds a one-boot purse, the bot buys at its first frame (a
# tick-scheduled verb on the authority's own seat), and a second buy never
# lands — gear guards it locally, the empty purse guards it after.
SLOG="$(mktemp)"; trap 'rm -f "$ELOG" "$SLOG"' EXIT
set +e
QD_ROLE=single QD_BOT=orbit QD_TOKEN=901 QD_GOLD=1 \
    "$GODOT" --headless --path "$PROJ" --quit-after 900 >"$SLOG" 2>&1
set -e

ok=1
for want in "QD_HOSTING" "QD_WORLD_UP" "QD_STARTED" "QD_FIRE" "QD_SHOT by=1" \
            "QD_BUY by=1 item=1" "gear=1 gold=0"; do
    grep -q "$want" "$SLOG" || { echo "missing: $want"; ok=0; }
done
if (($(grep -c "QD_BUY by=" "$SLOG" || true) != 1)); then
    echo "quickdraw: the shop sold other than exactly once"; ok=0
fi
if grep -q "gear=0 gold=1" "$SLOG" && ! grep -q "gear=1 gold=0" "$SLOG"; then
    echo "quickdraw: the purse never became boots"; ok=0
fi
if grep -qE "SCRIPT ERROR|signal 11" "$SLOG"; then
    echo "quickdraw: runtime errors in the solo log"; ok=0
fi

if ((ok==1)); then
    echo "QUICKDRAW_SINGLE_OK proved: headless sim-lane loop — tick, world pass, rewound shot, one bought boot, solo"
    exit 0
fi
tail -n 40 "$SLOG"
echo "QUICKDRAW_SINGLE_FAIL"
exit 1
