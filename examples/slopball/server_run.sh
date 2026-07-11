#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# DEDICATED-SERVER acid for slopball (ENet, headless): the kit's dedicated
# seat, end to end. An avatarless server (SLOP_ROLE=serve → kboot.boot_serve →
# session_host_start dedicated=true) referees a match between two real
# clients. Must show:
#
#   - the server opens the pitch the moment both PLAYERS are seated — its own
#     infrastructure seat never counts toward SLOP_PEERS,
#   - every screen fields exactly TWO kickers (kick=2 in SB_BALL — the server
#     spawned none for itself, and the roster flag crossed the wire so this
#     holds on clients too),
#   - the seat-grant contract is unchanged: the striker CLIENT takes the
#     ball's simulation (SB_BALL_OWNER player=2 on all three screens) and its
#     LOCAL solver drives the goal, scored by the SERVER off the stream,
#   - the match edge lands everywhere (SLOPBALL_DONE x3).
#
# Prints SLOPBALL_SERVER_OK.
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/slopball"
LOGDIR="$PROJ/.sloplogs"
mkdir -p "$LOGDIR"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch() { # launch <role> <bot> <name> <token> <log> <port>
    local role="$1" bot="$2" name="$3" token="$4" log="$5" port="$6"
    SLOP_ROLE="$role" SLOP_BOT="$bot" SLOP_NAME="$name" SLOP_TOKEN="$token" \
    SLOP_PORT="$port" SLOP_GOALS=1 SLOP_PEERS=2 \
        "$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
    echo $!
}

attempt() {
    local port="$1"
    local vlog="$LOGDIR/server.log" slog="$LOGDIR/sv_striker.log" wlog="$LOGDIR/sv_watcher.log"
    : >"$vlog"; : >"$slog"; : >"$wlog"
    local vp sp wp
    vp=$(launch serve idle referee 9101 "$vlog" "$port")
    local i=0
    while ((i<60)); do
        grep -q "SB_SERVING" "$vlog" && break
        grep -q "SB_HOST_FAIL" "$vlog" && { kill "$vp" 2>/dev/null; wait "$vp" 2>/dev/null; return 2; }
        kill -0 "$vp" 2>/dev/null || break
        sleep 0.1; ((i++))
    done
    sp=$(launch join striker striker 9102 "$slog" "$port")
    i=0
    while ((i<150)); do
        grep -q "SB_SEATED me=2" "$slog" && break
        kill -0 "$sp" 2>/dev/null || break
        sleep 0.1; ((i++))
    done
    wp=$(launch join idle watcher 9103 "$wlog" "$port")

    local deadline=$((SECONDS + 40))
    while ((SECONDS < deadline)); do
        if grep -q "SLOPBALL_DONE" "$vlog" && grep -q "SLOPBALL_DONE" "$slog" && grep -q "SLOPBALL_DONE" "$wlog"; then
            break
        fi
        sleep 0.5
    done
    sleep 2
    kill "$vp" "$sp" "$wp" 2>/dev/null
    wait "$vp" "$sp" "$wp" 2>/dev/null

    local ok=1
    grep -q "SB_SERVING"              "$vlog" || { echo "server never opened"; ok=0; }
    grep -q "SB_WORLD_UP"             "$vlog" || { echo "server never spawned the world"; ok=0; }
    grep -q "SB_SEATED me=2"          "$slog" || { echo "striker not seated as 2"; ok=0; }
    grep -q "SB_SEATED me=3"          "$wlog" || { echo "watcher not seated as 3"; ok=0; }
    # THE dedicated-seat receipt: every screen holds exactly the two CLIENT
    # kickers — the server fielded none, and clients learned the flag off the
    # welcome roster, not local guesswork.
    for l in "$vlog" "$slog" "$wlog"; do
        grep -q "SB_BALL.* kick=2 "   "$l" || { echo "kicker count wrong in $l (want kick=2)"; ok=0; }
    done
    grep -q "SB_BALL_OWNER player=2"  "$vlog" || { echo "server never granted the striker the seat"; ok=0; }
    grep -q "SB_BALL_OWNER player=2"  "$slog" || { echo "striker never heard it holds the seat"; ok=0; }
    grep -q "SB_BALL_OWNER player=2"  "$wlog" || { echo "watcher never heard the seat transfer"; ok=0; }
    grep -q "SB_GOAL by=2"            "$vlog" || { echo "server never saw the goal"; ok=0; }
    grep -q "SB_MATCH winner=2"       "$vlog" || { echo "no match edge on the server"; ok=0; }
    grep -q "SLOPBALL_DONE"           "$slog" || { echo "striker never finished"; ok=0; }
    grep -q "SLOPBALL_DONE"           "$wlog" || { echo "watcher never finished"; ok=0; }
    for l in "$vlog" "$slog" "$wlog"; do
        grep -qE "SCRIPT ERROR|signal 11" "$l" && { echo "runtime errors in $l"; ok=0; }
    done

    ((ok==1)) && return 0 || return 1
}

rc=1
for try in 1 2 3 4 5; do
    PORT=$(((RANDOM % 12000) + 50000))
    attempt "$PORT"; rc=$?
    ((rc==0)) && break
    ((rc==2)) && { echo "port $PORT busy, retrying"; continue; }
    break
done

if ((rc==0)); then
    echo "SLOPBALL_SERVER_OK proved: avatarless dedicated seat (kit-flagged, wire-carried), player-only start gating, client-simulated ball on a server pitch"
    exit 0
fi
echo "SLOPBALL_SERVER_FAIL"
for l in "$LOGDIR"/server.log "$LOGDIR"/sv_striker.log "$LOGDIR"/sv_watcher.log; do
    echo "==== $l ===="; tail -n 25 "$l"
done
exit 1
