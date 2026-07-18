#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# THE CONTESTED-BALL ACID — predict-the-contested-object over a real wire.
#
# Three processes, ENet, 120ms injected receive latency on every one: a
# dedicated marshal, a STRIKER client (bot), and an idle WATCHER client.
# The striker dribbles and kicks the ball ITS OWN SCREEN predicts:
#
#   - SPB_KICK prints on the STRIKER (mine, live pass) with the ball's
#     post-impulse velocity — the touch resolved locally, that tick, at
#     240ms RTT. That is the pattern: the contested object lives on every
#     peer's predicted timeline.
#   - the kick is a DECLARED WORLD-PASS FACT (@(gd_fact) ball_kicked_fx; the
#     step announces through the generated ball_kicked door): the WATCHER,
#     who never simulated the striker's press, presents SPB_KICK_SEEN from
#     the authority's broadcast on its watch clock — and the striker's own
#     screen NEVER double-fires (the broadcast skips the causer).
#   - the GOAL detects inside the ball's own tick and the reset predicts
#     (every screen snaps the ball home the moment ITS sim crosses the
#     line); the SCORE is authority-only (ball_tick_then), landing on the
#     delta lane — SPB_GOAL on the marshal, SPB_SCORE edges on ALL peers.
#   - the match edge narrates from replicated bytes everywhere
#     (SPEEDBALL_DONE x3), and the marshal's final ball rests at center.
#
# Prints SPEEDBALL_NATIVE_OK.
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/speedball"
LOGDIR="$PROJ/.spblogs"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null || { echo "SPEEDBALL_NATIVE_FAIL (build)"; exit 1; }
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# The launch/ready/reap plumbing is the kit harness; every receipt below
# stays the acid's own.
FSLP_PROJ="$PROJ"
FSLP_LOGS="$LOGDIR"
source "$ROOT/build/template/test/harness.sh"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch() { # launch <role> <bot> <name> <token> <log> <port>
    local role="$1" bot="$2" name="$3" token="$4" log="$5" port="$6"
    SPB_ROLE="$role" SPB_BOT="$bot" SPB_NAME="$name" SPB_TOKEN="$token" \
    SPB_PORT="$port" SPB_PEERS=2 SPB_GOALS=1 SPB_LATENCY=120 \
        "$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
    echo $! >>"$FSLP_PIDS"
    echo $!
}

for port in 4190 4197; do
    mlog="$LOGDIR/marshal.log"; slog="$LOGDIR/striker.log"; wlog="$LOGDIR/watcher.log"
    : >"$mlog"; : >"$slog"; : >"$wlog"

    : >"$FSLP_PIDS"
    mp=$(launch serve none marshal 9201 "$mlog" "$port")
    if ! fslp_ready "$mlog" "SPB_SERVING" 8 "$mp"; then
        fslp_reap; continue
    fi
    sp=$(launch join striker striker 9202 "$slog" "$port")
    fslp_ready "$slog" "SPB_SEATED me=2" 15 "$sp" || true
    wp=$(launch join spiker watcher 9203 "$wlog" "$port")

    # One goal ends it; give the duel of one a generous minute.
    i=0
    while ((i<600)); do
        grep -q "SPEEDBALL_DONE" "$mlog" && grep -q "SPEEDBALL_DONE" "$slog" && grep -q "SPEEDBALL_DONE" "$wlog" && break
        sleep 0.1; ((i++))
    done
    sleep 2 # a beat of REST so the post-goal probes show the ball at its predicted center
    fslp_reap

    ok=1
    grep -q "SPB_SERVING" "$mlog" || { echo "marshal never served"; ok=0; }
    grep -q "SPB_WORLD_UP" "$mlog" || { echo "world never spawned"; ok=0; }
    # The pattern's proof: the striker's OWN screen kicked its OWN predicted
    # ball — locally, at 240ms RTT (the print carries post-impulse velocity).
    grep -q "SPB_KICK tick=" "$slog" || { echo "the striker never touched its predicted ball"; ok=0; }
    # The world-pass fact channel: the WATCHER presents the striker's kick
    # from the authority's SIM_FACT on its watch clock (it never simulated
    # the press), the marshal's live truth fires too, and the striker —
    # skipped by the broadcast — never double-fires its own kick.
    grep -q "SPB_KICK_SEEN" "$wlog" || { echo "the watcher never presented the striker's kick (fact channel)"; ok=0; }
    grep -q "SPB_KICK_SEEN" "$mlog" || { echo "the marshal never presented the kick (authority live fire)"; ok=0; }
    if grep -q "SPB_KICK_SEEN" "$slog"; then
        echo "the striker double-fired its own kick (broadcast echo not skipped)"; ok=0
    fi
    # The striker seats as pid 2 → team RIGHT → it scores into the LEFT goal.
    grep -q "SPB_GOAL team=2" "$mlog" || { echo "the authority never scored the goal"; ok=0; }
    for log in "$mlog" "$slog" "$wlog"; do
        grep -q "SPB_SCORE l=0 r=1" "$log" || { echo "score edge missing in $(basename "$log")"; ok=0; }
        grep -q "SPEEDBALL_DONE" "$log" || { echo "match edge missing in $(basename "$log")"; ok=0; }
    done
    # THE SPIKE — a verb on the contested ball from the WATCHER's seat (an
    # entity nobody owns; owner-only died today): its two-verb burst rides
    # the pending chain and both land on the authority; the ball answers the
    # watcher's OWN screen within a couple ticks — a round trip is ~15.
    grep -q "SPB_SPIKE_SENT" "$wlog" || { echo "the spiker never spiked"; ok=0; }
    grep -q "SPB_SPIKE_LOCAL" "$wlog" || { echo "the spike never moved the spiker's own ball"; ok=0; }
    spikes=$(grep -c "SPB_SPIKE by=3" "$mlog" || true)
    if [ "$spikes" != "2" ]; then
        echo "the burst landed $spikes times on the marshal (want exactly 2)"; ok=0
    fi
    SSENT=$(grep -m1 "SPB_SPIKE_SENT" "$wlog" | sed 's/.*tick=//')
    SWORN=$(grep -m1 "SPB_SPIKE_LOCAL" "$wlog" | sed 's/.*tick=//')
    if [ -n "$SSENT" ] && [ -n "$SWORN" ] && ((SWORN - SSENT > 4)); then
        echo "the spike waited on the wire (sent $SSENT, moved $SWORN) — speculation is broken"; ok=0
    fi
    if grep -qE "SCRIPT ERROR|signal 11|ODIN_SCRIPT_PANIC" "$mlog" "$slog" "$wlog"; then
        echo "runtime errors in the logs"; ok=0
    fi
    # Convergence: the match froze the ball at the predicted-reset center.
    last_pos=$(grep "SPB_POS" "$mlog" | tail -1)
    echo "$last_pos" | grep -q "x=320.0 y=180.0" || { echo "marshal's ball not at rest at center: $last_pos"; ok=0; }

    if ((ok==1)); then
        kicks=$(grep -c "SPB_KICK" "$slog" || true)
        echo "SPEEDBALL_NATIVE_OK proved: the striker's $kicks local touches drove a contested ball to a goal at 240ms RTT — predicted reset, delta-lane score, three screens agreeing"
        exit 0
    fi
    tail -n 20 "$mlog" "$slog" "$wlog"
    echo "SPEEDBALL_NATIVE_FAIL"
    exit 1
done
echo "SPEEDBALL_NATIVE_FAIL: no free port"
exit 1
