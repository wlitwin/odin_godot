#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# THE DUEL ACID — the shot that lands at 240ms RTT, proved both ways.
#
# Three processes over real ENet, every one shimmed with 120ms of receive
# latency (QD_LATENCY): a dedicated marshal (QD_ROLE=serve), a STRAFER client
# that patrols at full speed and never fires, and a DEADEYE client that
# stands still and fires at the strafer exactly where its own screen renders
# it. At this latency the render lags server truth by ~25-30px — three body
# widths — so:
#
#   phase A (lag comp ON):   the honest-but-old aim HITS, repeatedly. The
#                            server rewinds the strafer to what the deadeye's
#                            screen was drawing (its snap ack minus the watch
#                            delay) and the ray lands. Kills and respawns
#                            follow — the delta lane carrying the sim lane's
#                            consequences.
#   phase B (QD_NOREWIND=1): the SAME duel judged against the live world —
#                            the shots all but never land. The gap between
#                            the two phases IS the feature.
#
# Prints QUICKDRAW_NATIVE_OK.
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/quickdraw"
LOGDIR="$PROJ/.qdlogs"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null || { echo "QUICKDRAW_NATIVE_FAIL (build)"; exit 1; }
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# The launch/ready/reap plumbing is the kit harness; the phase structure and
# every receipt below stay the acid's own.
FSLP_PROJ="$PROJ"
FSLP_LOGS="$LOGDIR"
source "$ROOT/build/template/test/harness.sh"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch() { # launch <role> <bot> <name> <token> <log> <port> <norewind>
    local role="$1" bot="$2" name="$3" token="$4" log="$5" port="$6" norewind="$7"
    QD_ROLE="$role" QD_BOT="$bot" QD_NAME="$name" QD_TOKEN="$token" \
    QD_PORT="$port" QD_PEERS=2 QD_LATENCY=120 QD_NOREWIND="$norewind" \
        "$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
    echo $! >>"$FSLP_PIDS"
    echo $!
}

# run_phase <label> <port> <norewind> -> hit count in $PHASE_HITS (99=setup failed)
run_phase() {
    local label="$1" port="$2" norewind="$3"
    local mlog="$LOGDIR/$label-marshal.log" slog="$LOGDIR/$label-strafer.log" dlog="$LOGDIR/$label-deadeye.log"
    : >"$mlog"; : >"$slog"; : >"$dlog"
    PHASE_HITS=99

    local mp sp dp
    : >"$FSLP_PIDS"
    mp=$(launch serve none marshal 9101 "$mlog" "$port" "$norewind")
    fslp_ready "$mlog" "QD_SERVING" 8 "$mp" || { fslp_reap; return 2; }
    sp=$(launch join strafer strafer 9102 "$slog" "$port" 0)
    fslp_ready "$slog" "QD_SEATED me=2" 15 "$sp" || { fslp_reap; return 1; }
    dp=$(launch join deadeye deadeye 9103 "$dlog" "$port" 0)

    # 60s of dueling is ~40 deadeye shots — enough statistics that a loaded
    # machine's low tail stays clear of the thresholds (35s flaked: observed
    # 6..12 hits against a >=8 bar, clean HEAD included).
    sleep 60
    fslp_reap

    for want in "QD_SERVING" "QD_WORLD_UP"; do
        grep -q "$want" "$mlog" || { echo "[$label] missing on marshal: $want"; return 1; }
    done
    grep -q "QD_STARTED" "$dlog" || { echo "[$label] deadeye never saw the world"; return 1; }
    grep -q "QD_FIRE" "$dlog" || { echo "[$label] deadeye never pulled the trigger"; return 1; }
    grep -q "QD_SHOT by=3" "$mlog" || { echo "[$label] the marshal never adjudicated a deadeye shot"; return 1; }
    # THE EVERY-SCREEN TRACER (the mine-form _fx): the strafer WATCHES the
    # deadeye — its screen must draw the deadeye's beam, delivered as a
    # SIM_FACT and fired when its watch clock reaches the shot's tick (the
    # beam on the delayed barrel). The deadeye's own log must NOT carry a
    # tracer for its own shots (the owner fired mine=true, live; the
    # authority excludes it from the broadcast).
    grep -q "QD_TRACER pid=3" "$slog" || { echo "[$label] the strafer never saw the deadeye's tracer (every-screen fx)"; return 1; }
    if grep -q "QD_TRACER pid=3" "$dlog"; then
        echo "[$label] the deadeye's own tracer echoed back (owner exclusion broken)"; return 1
    fi
    if grep -qE "SCRIPT ERROR|signal 11" "$mlog" "$slog" "$dlog"; then
        echo "[$label] runtime errors in the logs"; return 1
    fi
    PHASE_HITS=$(grep -c "QD_HIT by=3 on=2" "$mlog" || true)
    echo "[$label] deadeye shots: $(grep -c "QD_SHOT by=3" "$mlog" || true), hits on the strafer: $PHASE_HITS"
    return 0
}

for port in 4189 4196; do
    run_phase rewound "$port" 0; rc=$?
    ((rc==2)) && continue
    ((rc!=0)) && { echo "QUICKDRAW_NATIVE_FAIL (phase A setup)"; tail -20 "$LOGDIR"/rewound-*.log; exit 1; }
    HITS_A=$PHASE_HITS

    run_phase live "$((port+1))" 1; rc=$?
    ((rc!=0)) && { echo "QUICKDRAW_NATIVE_FAIL (phase B setup)"; tail -20 "$LOGDIR"/live-*.log; exit 1; }
    HITS_B=$PHASE_HITS

    # The claim, both directions: rewound aim lands repeatedly on the
    # crossing target; live-judged aim (the identical duel) almost never
    # does. INTERPOLATED rewind reconstructs the exact bracket blend the
    # shooter's screen drew (the render offset rides the input packet),
    # so most aimable shots land — the misses left are dead-window shots
    # after each kill and the strafer's brief direction flips. Observed
    # across runs at 60s: rewound ~15-20 of ~40, live 0-3; the thresholds
    # sit under the loaded-machine low tail, not the mean.
    if ((HITS_A >= 10)) && ((HITS_B <= 3)) && ((HITS_A > HITS_B + 6)); then
        grep -q "QD_KILL by=3" "$LOGDIR/rewound-marshal.log" || { echo "hits never became a kill"; exit 1; }
        grep -q "QD_RESPAWN" "$LOGDIR/rewound-marshal.log" || { echo "the kill never respawned"; exit 1; }

        # THE SHOP, mid-duel: the kill's bounty reaches the deadeye as delta
        # state, its buy is a tick-scheduled verb — and the boots go on at
        # the CLIENT'S next tick, ~15 ticks before the server's word can
        # return at this RTT. That local flip is the whole point.
        DLOG="$LOGDIR/rewound-deadeye.log"
        grep -q "QD_BUY_SENT" "$DLOG" || { echo "the deadeye never bought"; exit 1; }
        grep -q "QD_GEAR_LOCAL gear=1" "$DLOG" || { echo "the boots never went on locally"; exit 1; }
        grep -q "QD_BUY by=3 item=1" "$LOGDIR/rewound-marshal.log" || { echo "the marshal never honored the buy"; exit 1; }
        if (($(grep -c "QD_BUY by=" "$LOGDIR/rewound-marshal.log" || true) != 1)); then
            echo "the shop sold other than exactly once"; exit 1
        fi
        SENT=$(grep -m1 "QD_BUY_SENT" "$DLOG" | sed 's/.*tick=//')
        WORN=$(grep -m1 "QD_GEAR_LOCAL gear=1" "$DLOG" | sed 's/.*tick=//')
        if ((WORN - SENT > 3)); then
            echo "the buy waited on the wire (sent tick $SENT, worn tick $WORN) — speculation is broken"
            exit 1
        fi

        # THE LOB — a PREDICTED SPAWN. The deadeye's slow projectile leaves its
        # muzzle on the client's OWN tick (a local predicted entity, born-gated
        # and reconciled), and the authority spawns the real one at the SAME sim
        # tick — no round trip. The authority's flight then rekeys the very
        # bullet the client predicted (no duplicate, no crash) and lands its arc.
        MLOG="$LOGDIR/rewound-marshal.log"
        grep -q "QD_LOB_LOCAL" "$DLOG" || { echo "the deadeye never predicted a lob"; exit 1; }
        grep -q "QD_LOB_HOST" "$MLOG" || { echo "the authority never spawned a lob bullet"; exit 1; }
        grep -q "QD_LOB_LAND" "$MLOG" || { echo "the authority's lob never completed its flight"; exit 1; }
        LOCAL_N=$(grep -c "QD_LOB_LOCAL" "$DLOG" || true)
        HOST_N=$(grep -c "QD_LOB_HOST" "$MLOG" || true)
        if ((LOCAL_N < 4)) || ((HOST_N < 4)); then
            echo "the lob barely fired (predicted $LOCAL_N, authoritative $HOST_N)"; exit 1
        fi
        LSENT=$(grep -m1 "QD_LOB_LOCAL" "$DLOG" | sed 's/.*tick=//')
        LHOST=$(grep -m1 "QD_LOB_HOST" "$MLOG" | sed 's/.*tick=//')
        if [ -z "$LSENT" ] || [ -z "$LHOST" ]; then echo "lob ticks unreadable"; exit 1; fi
        LGAP=$((LSENT - LHOST)); LGAP=${LGAP#-}
        if ((LGAP > 2)); then
            echo "the predicted lob didn't leave on the client's own tick (local $LSENT, authority $LHOST) — it round-tripped"
            exit 1
        fi

        # THE DRONE — a SECOND INPUT CLASS. Every duelist drives a gunner AND a
        # drone on the SAME tick from two different input structs; each ships its
        # own window on the one upstream packet (count=2), the host de-jitters
        # each into its own buffer, and each entity's tick reads only its own.
        # The drone is steered on a pure HORIZONTAL sweep, ORTHOGONAL to the
        # strafer's VERTICAL gunner patrol — so a drone whose x swept wide while
        # its y never budged is a fingerprint of its OWN input class, a motion
        # the avatar's stick could not have produced. If the two classes crossed,
        # the drone would track the gunner instead.
        grep -q "QD_DRONE_LOCAL" "$DLOG" || { echo "the deadeye never predicted its own drone (the second input class never reached the client)"; exit 1; }
        grep -q "QD_DRONE " "$MLOG" || { echo "the authority never tracked a drone"; exit 1; }
        # The horizontal-sweep fingerprint, per drone, on the authority: some
        # drone's x must span > 80px while its y stays pinned (< 3px) — steer.y
        # is always 0, so any y drift would mean a crossed input.
        DRONE_FP=$(awk '
            /QD_DRONE / {
                for (i=1;i<=NF;i++) {
                    if ($i ~ /^id=/)      { id=substr($i,4) }
                    else if ($i ~ /^x=/)  { x=substr($i,3)+0 }
                    else if ($i ~ /^y=/)  { y=substr($i,3)+0 }
                }
                if (!(id in seen)) { seen[id]=1; xmin[id]=x; xmax[id]=x; ymin[id]=y; ymax[id]=y }
                if (x<xmin[id]) xmin[id]=x; if (x>xmax[id]) xmax[id]=x
                if (y<ymin[id]) ymin[id]=y; if (y>ymax[id]) ymax[id]=y
            }
            END {
                for (id in seen) {
                    dx=xmax[id]-xmin[id]; dy=ymax[id]-ymin[id]
                    if (dx>80 && dy<3) { print id": dx="dx" dy="dy; found=1 }
                }
                exit found?0:1
            }' "$MLOG")
        if [ -z "$DRONE_FP" ]; then
            echo "no drone swept its own input class (want a drone with x-span > 80 and y-span < 3 on the authority):"
            grep "QD_DRONE " "$MLOG" | tail -6
            exit 1
        fi
        DLOC=$(grep -m1 "QD_DRONE_LOCAL" "$DLOG")

        echo "QUICKDRAW_NATIVE_OK proved: at 240ms RTT the rewound duel lands ($HITS_A hits -> kill -> respawn), the live-judged control misses ($HITS_B), the bounty shop's verb wore boots at tick $WORN ($((WORN - SENT)) ticks after issue), the lob's PREDICTED bullet left the muzzle on the client's own tick $LSENT (authority spawned + rekeyed at $LHOST, no round trip), and the drone's SECOND INPUT CLASS flowed the whole distance — the client predicted its own drone ($DLOC) and on the authority it swept its own steer while its gunner strafed the other way ($DRONE_FP)"
        exit 0
    fi
    echo "QUICKDRAW_NATIVE_FAIL: hits rewound=$HITS_A live=$HITS_B (want rewound>=10, live<=3, gap>6)"
    exit 1
done
echo "QUICKDRAW_NATIVE_FAIL: no free port"
exit 1
