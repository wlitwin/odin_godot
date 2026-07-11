#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# THREE-PEER acid for slopball3d (ENet, headless): the 3D engine-physics
# replication proof. Host (idle) + a striker client + a watcher client. Must
# show the same contract the 2D pitch proved — seat transfer to the striker,
# the striker's LOCAL solver drives the goal, host scores it off the streamed
# pose, match edge everywhere — with the third axis on: gravity, lofted kicks,
# and a replicated QUATERNION orientation.
#
# CONVERGENCE: at the same session tick, all three screens report the ball
# within a few centimeters (SB3_BALL tick=N, positions in cm — interp + f16
# tolerance). Prints SLOPBALL3D_NATIVE_OK.
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/slopball3d"
LOGDIR="$PROJ/.sloplogs"
mkdir -p "$LOGDIR"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch() { # launch <role> <bot> <name> <token> <log> <port>
    local role="$1" bot="$2" name="$3" token="$4" log="$5" port="$6"
    SLOP3_ROLE="$role" SLOP3_BOT="$bot" SLOP3_NAME="$name" SLOP3_TOKEN="$token" \
    SLOP3_PORT="$port" SLOP3_GOALS=1 SLOP3_PEERS=3 \
        "$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
    echo $!
}

attempt() {
    local port="$1"
    local hlog="$LOGDIR/host.log" slog="$LOGDIR/striker.log" wlog="$LOGDIR/watcher.log"
    : >"$hlog"; : >"$slog"; : >"$wlog"
    local hp sp wp
    hp=$(launch host idle hosty 9301 "$hlog" "$port")
    local i=0
    while ((i<60)); do
        grep -q "SB3_HOSTING" "$hlog" && break
        grep -q "SB3_HOST_FAIL" "$hlog" && { kill "$hp" 2>/dev/null; wait "$hp" 2>/dev/null; return 2; }
        kill -0 "$hp" 2>/dev/null || break
        sleep 0.1; ((i++))
    done
    sp=$(launch join striker striker 9302 "$slog" "$port")
    # Seat order is arrival order — hold the watcher until the striker sits in
    # seat 2, or the two joins race and the assertions point at the wrong logs.
    i=0
    while ((i<150)); do
        grep -q "SB3_SEATED me=2" "$slog" && break
        kill -0 "$sp" 2>/dev/null || break
        sleep 0.1; ((i++))
    done
    wp=$(launch join idle watcher 9303 "$wlog" "$port")

    # The whole match should land inside 40s; then a beat of REST so the last
    # SB3_BALL reports show a settled ball for the convergence diff.
    local deadline=$((SECONDS + 40))
    while ((SECONDS < deadline)); do
        if grep -q "SLOPBALL3D_DONE" "$hlog" && grep -q "SLOPBALL3D_DONE" "$slog" && grep -q "SLOPBALL3D_DONE" "$wlog"; then
            break
        fi
        sleep 0.5
    done
    sleep 4  # the last kick's roll must settle, or interp lag reads as disagreement
    kill "$hp" "$sp" "$wp" 2>/dev/null
    wait "$hp" "$sp" "$wp" 2>/dev/null

    local ok=1
    grep -q "SB3_WORLD_UP"            "$hlog" || { echo "host never spawned the world"; ok=0; }
    grep -q "SB3_SEATED me=2"         "$slog" || { echo "striker not seated as 2"; ok=0; }
    grep -q "SB3_SEATED me=3"         "$wlog" || { echo "watcher not seated as 3"; ok=0; }
    grep -q "SB3_BALL_OWNER player=2" "$hlog" || { echo "host never granted the striker the seat"; ok=0; }
    grep -q "SB3_BALL_OWNER player=2" "$slog" || { echo "striker never heard it holds the seat"; ok=0; }
    grep -q "SB3_BALL_OWNER player=2" "$wlog" || { echo "watcher never heard the seat transfer"; ok=0; }
    grep -q "SB3_KICK"                "$slog" || { echo "striker never kicked"; ok=0; }
    grep -q "SB3_GOAL by=2"           "$hlog" || { echo "host never saw the goal"; ok=0; }
    grep -q "SB3_MATCH winner=2"      "$hlog" || { echo "no match edge on the host"; ok=0; }
    grep -q "SB3_MATCH winner=2"      "$wlog" || { echo "no match edge on the watcher"; ok=0; }
    grep -q "SLOPBALL3D_DONE"         "$slog" || { echo "striker never finished"; ok=0; }
    for l in "$hlog" "$slog" "$wlog"; do
        grep -qE "SCRIPT ERROR|signal 11" "$l" && { echo "runtime errors in $l"; ok=0; }
    done

    # CONVERGENCE: highest tick reported by all three, positions within 40cm
    # (x and z; y is gravity-parked and comes along for free in the diff), and
    # the QUATERNION within 0.05 per sampled component — the settled ball's
    # orientation is the end-to-end receipt for the .Quat wire+nlerp path
    # (a corrupted rotation cannot show up in the position diff).
    local hpts="$LOGDIR/h.pts" spts="$LOGDIR/s.pts" wpts="$LOGDIR/w.pts"
    sed -nE 's/.*SB3_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+) z=(-?[0-9]+) qx=(-?[0-9]+) qw=(-?[0-9]+).*/\1 \2 \3 \4 \5 \6/p' "$hlog" >"$hpts"
    sed -nE 's/.*SB3_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+) z=(-?[0-9]+) qx=(-?[0-9]+) qw=(-?[0-9]+).*/\1 \2 \3 \4 \5 \6/p' "$slog" >"$spts"
    sed -nE 's/.*SB3_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+) z=(-?[0-9]+) qx=(-?[0-9]+) qw=(-?[0-9]+).*/\1 \2 \3 \4 \5 \6/p' "$wlog" >"$wpts"
    local tick
    tick=$(cat "$hpts" "$spts" "$wpts" | awk '{print $1}' | sort -n | uniq -c | awk '$1==3{t=$2} END{print t+0}')
    if ((tick == 0)); then
        echo "convergence: no common SB3_BALL tick across the three logs"; ok=0
    else
        local hx hy hz hqx hqw sx sy sz sqx sqw wx wy wz wqx wqw span=0 qspan=0 d
        read -r hx hy hz hqx hqw <<<"$(awk -v t="$tick" '$1==t{print $2, $3, $4, $5, $6; exit}' "$hpts")"
        read -r sx sy sz sqx sqw <<<"$(awk -v t="$tick" '$1==t{print $2, $3, $4, $5, $6; exit}' "$spts")"
        read -r wx wy wz wqx wqw <<<"$(awk -v t="$tick" '$1==t{print $2, $3, $4, $5, $6; exit}' "$wpts")"
        for d in $((hx-sx)) $((hx-wx)) $((sx-wx)) $((hy-sy)) $((hy-wy)) $((sy-wy)) $((hz-sz)) $((hz-wz)) $((sz-wz)); do
            ((d<0)) && d=$((-d)); ((d>span)) && span=$d
        done
        for d in $((hqx-sqx)) $((hqx-wqx)) $((sqx-wqx)) $((hqw-sqw)) $((hqw-wqw)) $((sqw-wqw)); do
            ((d<0)) && d=$((-d)); ((d>qspan)) && qspan=$d
        done
        echo "convergence: tick=$tick host=($hx,$hy,$hz) striker=($sx,$sy,$sz) watcher=($wx,$wy,$wz) span=${span}cm qspan=$qspan"
        # The assert exists to catch two-WORLDS divergence (meters); a ball
        # still rolling at sample time legitimately spreads ~an interp window
        # across screens (~30cm at 60Hz mid-kick).
        ((span<=40)) || { echo "convergence: screens disagree past tolerance"; ok=0; }
        # Quat tolerance derives from residual SLOW ROLL, not the wire: the ball
        # settles positionally long before its spin fully dies, and a rolling
        # quat churns ~ω/2 per second — an interp-window sampling skew spreads
        # ~10-25 units. Corruption (garbage decode, hemisphere flip) shows as
        # 70-200. 40 splits the two decisively.
        ((qspan<=40)) || { echo "convergence: quaternions disagree past tolerance (wire/nlerp)"; ok=0; }
        # And the decisive receipt that rotation CROSSED the wire at all: every
        # peer must have seen the ball's quat leave identity during the match
        # (a dead rot field pins qw at 100 on watchers forever).
        for f in "$hpts" "$spts" "$wpts"; do
            awk 'BEGIN{m=999} {v=$6; if(v<0)v=-v; if(v<m)m=v} END{exit !(m<=50)}' "$f" \
                || { echo "quat receipt: $f never left identity — rotation not replicating"; ok=0; }
        done
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
    echo "SLOPBALL3D_NATIVE_OK proved: client-simulated RigidBody3D under gravity, quaternion stream, host seat grants, goal off the stream, 3-screen convergence"
    exit 0
fi
echo "SLOPBALL3D_NATIVE_FAIL"
for l in "$LOGDIR"/host.log "$LOGDIR"/striker.log "$LOGDIR"/watcher.log; do
    echo "==== $l ===="; tail -n 25 "$l"
done
exit 1
