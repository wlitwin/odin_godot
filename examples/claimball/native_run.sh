#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# THE CLAIM-MODE ACID — predict-self + a claimed contested object over a real
# wire. Same soccer as speedball, the OTHER half of the contested pattern: here
# echo_inputs is OFF, so each peer predicts only its OWN kicker and the shared
# ball, and the CLAIM decides how that ball presents.
#
# Three processes, ENet, 120ms injected receive latency on every one: a
# dedicated marshal, a STRIKER client (bot), and an idle WATCHER client. The
# striker dribbles and kicks the ball ITS OWN SCREEN predicts:
#
#   - CLB_KICK prints on the STRIKER (mine, live pass) with the ball's
#     post-impulse velocity — the touch resolved locally, that tick, at
#     240ms RTT. That is the pattern: the contested object lives on every
#     peer's predicted timeline.
#   - THE CLAIM: the striker CLAIMS the ball while it drives it, so the ball
#     presents from the striker's predicted timeline (CLB_CVIEW claim near 1);
#     the idle watcher never drives it, so the same ball presents WATCHED there
#     (claim 0). One ball, two timelines, one screen each — claimball's point.
#   - the kick is a DECLARED CUE (@(gd_cue) ball_kicked_fx; the sole entity
#     parameter is its inferred anchor, and the
#     step announces through the generated ball_kicked door): the WATCHER,
#     who never simulated the striker's press, presents CLB_KICK_SEEN from
#     the authority's broadcast on its watch clock — and the striker's own
#     screen NEVER double-fires (the broadcast skips the causer).
#   - the GOAL detects inside the ball's own tick and the reset predicts
#     (every screen snaps the ball home the moment ITS sim crosses the
#     line); the SCORE is authority-only (ball_tick_then), landing on the
#     delta lane — CLB_GOAL on the marshal, CLB_SCORE edges on ALL peers.
#   - the match edge narrates from replicated bytes everywhere
#     (CLAIMBALL_DONE x3), and the marshal's final ball rests at center.
#
# Prints CLAIMBALL_NATIVE_OK.
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/claimball"
LOGDIR="$PROJ/.clblogs"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null || { echo "CLAIMBALL_NATIVE_FAIL (build)"; exit 1; }
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# The launch/ready/reap plumbing is the kit harness; every receipt below
# stays the acid's own.
FSLP_PROJ="$PROJ"
FSLP_LOGS="$LOGDIR"
source "$ROOT/build/template/test/harness.sh"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch() { # launch <role> <bot> <name> <token> <log> <port>
    local role="$1" bot="$2" name="$3" token="$4" log="$5" port="$6"
    CLB_ROLE="$role" CLB_BOT="$bot" CLB_NAME="$name" CLB_TOKEN="$token" \
    CLB_PORT="$port" CLB_PEERS=2 CLB_GOALS=1 CLB_LATENCY=120 \
        "$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
    echo $! >>"$FSLP_PIDS"
    echo $!
}

for port in 4190 4197; do
    mlog="$LOGDIR/marshal.log"; slog="$LOGDIR/striker.log"; wlog="$LOGDIR/watcher.log"
    : >"$mlog"; : >"$slog"; : >"$wlog"

    : >"$FSLP_PIDS"
    mp=$(launch serve none marshal 9201 "$mlog" "$port")
    if ! fslp_ready "$mlog" "CLB_SERVING" 8 "$mp"; then
        fslp_reap; continue
    fi
    sp=$(launch join striker striker 9202 "$slog" "$port")
    fslp_ready "$slog" "CLB_SEATED me=2" 15 "$sp" || true
    # The watcher is IDLE on purpose: in predict-self only its OWN kicker is
    # predicted, so a watcher that touched the ball would surprise the striker's
    # prediction (the striker doesn't simulate the watcher) and drive up resims.
    # Idle, it is the clean control — it NEVER drives the ball, so it presents
    # the ball purely WATCHED (claim 0) while the striker claims it. That
    # contrast is exactly what the acid checks.
    wp=$(launch join idle watcher 9203 "$wlog" "$port")

    # One goal ends it; give the duel of one a generous minute.
    i=0
    while ((i<600)); do
        grep -q "CLAIMBALL_DONE" "$mlog" && grep -q "CLAIMBALL_DONE" "$slog" && grep -q "CLAIMBALL_DONE" "$wlog" && break
        sleep 0.1; ((i++))
    done
    sleep 2 # a beat of REST so the post-goal probes show the ball at its predicted center
    fslp_reap

    ok=1
    grep -q "CLB_SERVING" "$mlog" || { echo "marshal never served"; ok=0; }
    grep -q "CLB_WORLD_UP" "$mlog" || { echo "world never spawned"; ok=0; }
    # The pattern's proof: the striker's OWN screen kicked its OWN predicted
    # ball — locally, at 240ms RTT (the print carries post-impulse velocity).
    grep -q "CLB_KICK tick=" "$slog" || { echo "the striker never touched its predicted ball"; ok=0; }
    # The world-pass fact channel: the WATCHER presents the striker's kick
    # from the authority's SIM_FACT on its watch clock (it never simulated
    # the press), the marshal's live truth fires too, and the striker —
    # skipped by the broadcast — never double-fires its own kick.
    grep -q "CLB_KICK_SEEN" "$wlog" || { echo "the watcher never presented the striker's kick (fact channel)"; ok=0; }
    grep -q "CLB_KICK_SEEN" "$mlog" || { echo "the marshal never presented the kick (authority live fire)"; ok=0; }
    if grep -q "CLB_KICK_SEEN" "$slog"; then
        echo "the striker double-fired its own kick (broadcast echo not skipped)"; ok=0
    fi
    # The striker seats as pid 2 → team RIGHT → it scores into the LEFT goal.
    grep -q "CLB_GOAL team=2" "$mlog" || { echo "the authority never scored the goal"; ok=0; }
    for log in "$mlog" "$slog" "$wlog"; do
        grep -q "CLB_SCORE l=0 r=1" "$log" || { echo "score edge missing in $(basename "$log")"; ok=0; }
        grep -q "CLAIMBALL_DONE" "$log" || { echo "match edge missing in $(basename "$log")"; ok=0; }
    done
    if grep -qE "SCRIPT ERROR|signal 11|ODIN_SCRIPT_PANIC" "$mlog" "$slog" "$wlog"; then
        echo "runtime errors in the logs"; ok=0
    fi
    # THE CLAIM — claimball's whole point (speedball, predict-world, has no claim
    # dance). The STRIKER is constantly on the ball, so it PRESENTS the ball from
    # its OWN predicted timeline: its claim rides at 1 (lane_claim every tick it is
    # in reach, held through the flight its kick starts). The WATCHER, which is not
    # driving the ball, presents the WATCHED view: claim 0. That contrast IS the
    # model — the shared ball draws predicted for whoever caused its motion, and
    # watched for everyone else, on one screen at the same time.
    # claim rides just under 1: the probe samples tr.claim AFTER lane_present's
    # one-frame decay and BEFORE this tick re-sets it, so a held claim reads
    # ~0.92-0.95 — "strongly presenting predicted", which is the assertion.
    grep -qE "CLB_CVIEW .*claim=(1\.00|0\.[5-9][0-9])" "$slog" || { echo "the striker never claimed its predicted ball (the ball never presented from its timeline)"; ok=0; }
    grep -qE "CLB_CVIEW .*claim=0\.00" "$wlog" || { echo "the watcher never presented the ball watched (claim never released to 0)"; ok=0; }
    # Convergence: the match froze the ball at the predicted-reset center.
    last_pos=$(grep "CLB_POS" "$mlog" | tail -1)
    echo "$last_pos" | grep -q "x=320.0 y=180.0" || { echo "marshal's ball not at rest at center: $last_pos"; ok=0; }

    if ((ok==1)); then
        kicks=$(grep -c "CLB_KICK" "$slog" || true)
        echo "CLAIMBALL_NATIVE_OK proved: the striker's $kicks local touches drove a contested ball to a goal at 240ms RTT — predicted reset, delta-lane score, three screens agreeing"
        exit 0
    fi
    tail -n 20 "$mlog" "$slog" "$wlog"
    echo "CLAIMBALL_NATIVE_FAIL"
    exit 1
done
echo "CLAIMBALL_NATIVE_FAIL: no free port"
exit 1
