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
mkdir -p "$LOGDIR"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch() { # launch <role> <bot> <name> <token> <log> <port> <norewind>
    local role="$1" bot="$2" name="$3" token="$4" log="$5" port="$6" norewind="$7"
    QD_ROLE="$role" QD_BOT="$bot" QD_NAME="$name" QD_TOKEN="$token" \
    QD_PORT="$port" QD_PEERS=2 QD_LATENCY=120 QD_NOREWIND="$norewind" \
        "$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
    echo $!
}

# run_phase <label> <port> <norewind> -> hit count in $PHASE_HITS (99=setup failed)
run_phase() {
    local label="$1" port="$2" norewind="$3"
    local mlog="$LOGDIR/$label-marshal.log" slog="$LOGDIR/$label-strafer.log" dlog="$LOGDIR/$label-deadeye.log"
    : >"$mlog"; : >"$slog"; : >"$dlog"
    PHASE_HITS=99

    local mp sp dp i
    mp=$(launch serve none marshal 9101 "$mlog" "$port" "$norewind")
    i=0
    while ((i<60)); do
        grep -q "QD_SERVING" "$mlog" && break
        grep -q "QD_HOST_FAIL" "$mlog" && { kill "$mp" 2>/dev/null; wait "$mp" 2>/dev/null; return 2; }
        kill -0 "$mp" 2>/dev/null || break
        sleep 0.1; ((i++))
    done
    sp=$(launch join strafer strafer 9102 "$slog" "$port" 0)
    i=0
    while ((i<150)); do
        grep -q "QD_SEATED me=2" "$slog" && break
        kill -0 "$sp" 2>/dev/null || break
        sleep 0.1; ((i++))
    done
    dp=$(launch join deadeye deadeye 9103 "$dlog" "$port" 0)

    # 60s of dueling is ~40 deadeye shots — enough statistics that a loaded
    # machine's low tail stays clear of the thresholds (35s flaked: observed
    # 6..12 hits against a >=8 bar, clean HEAD included).
    sleep 60
    kill "$mp" "$sp" "$dp" 2>/dev/null
    wait "$mp" "$sp" "$dp" 2>/dev/null

    for want in "QD_SERVING" "QD_WORLD_UP"; do
        grep -q "$want" "$mlog" || { echo "[$label] missing on marshal: $want"; return 1; }
    done
    grep -q "QD_STARTED" "$dlog" || { echo "[$label] deadeye never saw the world"; return 1; }
    grep -q "QD_FIRE" "$dlog" || { echo "[$label] deadeye never pulled the trigger"; return 1; }
    grep -q "QD_SHOT by=3" "$mlog" || { echo "[$label] the marshal never adjudicated a deadeye shot"; return 1; }
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

        echo "QUICKDRAW_NATIVE_OK proved: at 240ms RTT the rewound duel lands ($HITS_A hits -> kill -> respawn), the live-judged control misses ($HITS_B), and the bounty shop's verb wore boots at tick $WORN — $((WORN - SENT)) ticks after issue, no round trip"
        exit 0
    fi
    echo "QUICKDRAW_NATIVE_FAIL: hits rewound=$HITS_A live=$HITS_B (want rewound>=10, live<=3, gap>6)"
    exit 1
done
echo "QUICKDRAW_NATIVE_FAIL: no free port"
exit 1
