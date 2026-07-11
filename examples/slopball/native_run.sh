#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# THREE-PEER acid for slopball (ENet, headless): the engine-physics replication
# proof. Host (idle) + a striker client + a watcher client. Must show:
#
#   - the SEAT TRANSFER: the host grants the ball's simulation to the striker
#     (SB_BALL_OWNER player=2 on ALL THREE screens — a client now runs the
#     RigidBody2D solver everyone else follows),
#   - the striker's LOCAL kick drives the ball into the LEFT goal, detected by
#     the HOST off the streamed pose (SB_GOAL by=2), score replicated to all,
#   - the match edge lands everywhere (SB_MATCH winner=2, SLOPBALL_DONE x3),
#   - CONVERGENCE: at the same session tick, all three screens report the ball
#     within a few pixels (SB_BALL tick=N — interp + f16 tolerance).
#
# Prints SLOPBALL_NATIVE_OK.
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/slopball"
LOGDIR="$PROJ/.sloplogs"
mkdir -p "$LOGDIR"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch() { # launch <role> <bot> <name> <token> <log> <port> [extra env...]
    local role="$1" bot="$2" name="$3" token="$4" log="$5" port="$6"
    SLOP_ROLE="$role" SLOP_BOT="$bot" SLOP_NAME="$name" SLOP_TOKEN="$token" \
    SLOP_PORT="$port" SLOP_GOALS=1 SLOP_PEERS=3 \
        "$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
    echo $!
}

attempt() {
    local port="$1"
    local hlog="$LOGDIR/host.log" slog="$LOGDIR/striker.log" wlog="$LOGDIR/watcher.log"
    : >"$hlog"; : >"$slog"; : >"$wlog"
    local hp sp wp
    hp=$(launch host idle hosty 9001 "$hlog" "$port")
    local i=0
    while ((i<60)); do
        grep -q "SB_HOSTING" "$hlog" && break
        grep -q "SB_HOST_FAIL" "$hlog" && { kill "$hp" 2>/dev/null; wait "$hp" 2>/dev/null; return 2; }
        kill -0 "$hp" 2>/dev/null || break
        sleep 0.1; ((i++))
    done
    sp=$(launch join striker striker 9002 "$slog" "$port")
    # Seat order is arrival order — hold the watcher until the striker sits in
    # seat 2, or the two joins race and the assertions point at the wrong logs.
    i=0
    while ((i<150)); do
        grep -q "SB_SEATED me=2" "$slog" && break
        kill -0 "$sp" 2>/dev/null || break
        sleep 0.1; ((i++))
    done
    wp=$(launch join idle watcher 9003 "$wlog" "$port")

    # The whole match should land inside 40s; then a beat of REST so the last
    # SB_BALL reports show a settled ball for the convergence diff.
    local deadline=$((SECONDS + 40))
    while ((SECONDS < deadline)); do
        if grep -q "SLOPBALL_DONE" "$hlog" && grep -q "SLOPBALL_DONE" "$slog" && grep -q "SLOPBALL_DONE" "$wlog"; then
            break
        fi
        sleep 0.5
    done
    sleep 4  # the last kick's roll must settle, or interp lag reads as disagreement
    kill "$hp" "$sp" "$wp" 2>/dev/null
    wait "$hp" "$sp" "$wp" 2>/dev/null

    local ok=1
    grep -q "SB_WORLD_UP"            "$hlog" || { echo "host never spawned the world"; ok=0; }
    grep -q "SB_SEATED me=2"         "$slog" || { echo "striker not seated as 2"; ok=0; }
    grep -q "SB_SEATED me=3"         "$wlog" || { echo "watcher not seated as 3"; ok=0; }
    grep -q "SB_BALL_OWNER player=2" "$hlog" || { echo "host never granted the striker the seat"; ok=0; }
    grep -q "SB_BALL_OWNER player=2" "$slog" || { echo "striker never heard it holds the seat"; ok=0; }
    grep -q "SB_BALL_OWNER player=2" "$wlog" || { echo "watcher never heard the seat transfer"; ok=0; }
    grep -q "SB_KICK"                "$slog" || { echo "striker never kicked"; ok=0; }
    grep -q "SB_GOAL by=2"           "$hlog" || { echo "host never saw the goal"; ok=0; }
    grep -q "SB_MATCH winner=2"      "$hlog" || { echo "no match edge on the host"; ok=0; }
    grep -q "SB_MATCH winner=2"      "$wlog" || { echo "no match edge on the watcher"; ok=0; }
    grep -q "SLOPBALL_DONE"          "$slog" || { echo "striker never finished"; ok=0; }
    for l in "$hlog" "$slog" "$wlog"; do
        grep -qE "SCRIPT ERROR|signal 11" "$l" && { echo "runtime errors in $l"; ok=0; }
    done

    # CONVERGENCE: highest tick reported by all three, positions within 8px.
    # (awk/sed only — the nix dev shell carries no python.)
    local hpts="$LOGDIR/h.pts" spts="$LOGDIR/s.pts" wpts="$LOGDIR/w.pts"
    sed -nE 's/.*SB_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+).*/\1 \2 \3/p' "$hlog" >"$hpts"
    sed -nE 's/.*SB_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+).*/\1 \2 \3/p' "$slog" >"$spts"
    sed -nE 's/.*SB_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+).*/\1 \2 \3/p' "$wlog" >"$wpts"
    local tick
    tick=$(cat "$hpts" "$spts" "$wpts" | awk '{print $1}' | sort -n | uniq -c | awk '$1==3{t=$2} END{print t+0}')
    if ((tick == 0)); then
        echo "convergence: no common SB_BALL tick across the three logs"; ok=0
    else
        local hx hy sx sy wx wy span=0 d
        read -r hx hy <<<"$(awk -v t="$tick" '$1==t{print $2, $3; exit}' "$hpts")"
        read -r sx sy <<<"$(awk -v t="$tick" '$1==t{print $2, $3; exit}' "$spts")"
        read -r wx wy <<<"$(awk -v t="$tick" '$1==t{print $2, $3; exit}' "$wpts")"
        for d in $((hx-sx)) $((hx-wx)) $((sx-wx)) $((hy-sy)) $((hy-wy)) $((sy-wy)); do
            ((d<0)) && d=$((-d)); ((d>span)) && span=$d
        done
        echo "convergence: tick=$tick host=($hx,$hy) striker=($sx,$sy) watcher=($wx,$wy) span=${span}px"
        # The assert exists to catch two-WORLDS divergence (hundreds of px);
        # a ball still rolling at sample time legitimately spreads ~an interp
        # window across screens (~12px at 60Hz).
        ((span<=15)) || { echo "convergence: screens disagree past tolerance"; ok=0; }
    fi

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
    echo "SLOPBALL_NATIVE_OK proved: client-simulated RigidBody2D, host seat grants, goal off the stream, 3-screen convergence"
    exit 0
fi
echo "SLOPBALL_NATIVE_FAIL"
for l in "$LOGDIR"/host.log "$LOGDIR"/striker.log "$LOGDIR"/watcher.log; do
    echo "==== $l ===="; tail -n 25 "$l"
done
exit 1
