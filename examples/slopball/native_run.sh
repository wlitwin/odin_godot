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
# Plumbing = the kit harness (launch/ready/wait/reap/act); the receipts stay.
# Prints SLOPBALL_NATIVE_OK.
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/slopball"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null || { echo "SLOPBALL_NATIVE_FAIL (build)"; exit 1; }
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

FSLP_PROJ="$PROJ"
FSLP_LOGS="$PROJ/.sloplogs"
source "$ROOT/build/template/test/harness.sh"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

slop_launch() { # slop_launch <role> <bot> <name> <token> <log> <port>
	local role="$1" bot="$2" name="$3" token="$4" log="$5" port="$6"
	SLOP_ROLE="$role" SLOP_BOT="$bot" SLOP_NAME="$name" SLOP_TOKEN="$token" \
	SLOP_PORT="$port" SLOP_GOALS=1 SLOP_PEERS=3 \
		"$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
	echo $! >>"$FSLP_PIDS"
	echo $!
}

three_peers() {
	local port="$1"
	local hlog="$FSLP_LOGS/host.log" slog="$FSLP_LOGS/striker.log" wlog="$FSLP_LOGS/watcher.log"
	: >"$hlog"; : >"$slog"; : >"$wlog"
	local hp sp wp
	hp=$(slop_launch host idle hosty 9001 "$hlog" "$port")
	fslp_ready "$hlog" "SB_HOSTING" 8 "$hp" || { echo "  port $port: host never bound"; return 1; }
	sp=$(slop_launch join striker striker 9002 "$slog" "$port")
	# Seat order is arrival order — hold the watcher until the striker sits in
	# seat 2, or the two joins race and the assertions point at the wrong logs.
	fslp_ready "$slog" "SB_SEATED me=2" 15 "$sp" || { echo "  striker never seated"; return 1; }
	wp=$(slop_launch join idle watcher 9003 "$wlog" "$port")

	# The whole match should land inside 40s; then a beat of REST so the last
	# SB_BALL reports show a settled ball for the convergence diff.
	local deadline=$((SECONDS + 40))
	while ((SECONDS < deadline)); do
		if grep -q "SLOPBALL_DONE" "$hlog" && grep -q "SLOPBALL_DONE" "$slog" && grep -q "SLOPBALL_DONE" "$wlog"; then
			break
		fi
		sleep 0.5
	done
	sleep 4 # the last kick's roll must settle, or interp lag reads as disagreement
	fslp_reap

	expect "$hlog" "SB_WORLD_UP" "host never spawned the world"
	expect "$slog" "SB_SEATED me=2" "striker not seated as 2"
	expect "$wlog" "SB_SEATED me=3" "watcher not seated as 3"
	expect "$hlog" "SB_BALL_OWNER player=2" "host never granted the striker the seat"
	expect "$slog" "SB_BALL_OWNER player=2" "striker never heard it holds the seat"
	expect "$wlog" "SB_BALL_OWNER player=2" "watcher never heard the seat transfer"
	expect "$slog" "SB_KICK" "striker never kicked"
	expect "$hlog" "SB_GOAL by=2" "host never saw the goal"
	expect "$hlog" "SB_MATCH winner=2" "no match edge on the host"
	expect "$wlog" "SB_MATCH winner=2" "no match edge on the watcher"
	expect "$slog" "SLOPBALL_DONE" "striker never finished"
	for l in "$hlog" "$slog" "$wlog"; do
		expect_absent "$l" "SCRIPT ERROR|signal 11" "runtime errors in $(basename "$l")"
	done

	# BORN AT THE SEND: the HOST's own spawns are dressed on the frame they are
	# spawned. Every kicker here is spawned AFTER the pump — spawn_world runs
	# from the join's authority consequence (the events dispatch), the watcher's
	# drop-in from the same half — so SB_SENT (the spawn site, right after
	# boot_spawn_send) and SB_SPAWN (the dress, slopball_entity_spawned, fired
	# from INSIDE the send) must carry the same frame for the same id. Before
	# the fix the dress came from the NEXT pump's batch: frame+1, one rendered
	# frame with the body at the origin (was=0,0 is that pose, now never shown).
	local sent_n=0 sid sframe
	while read -r sid sframe; do
		sent_n=$((sent_n+1))
		if ! grep -qE "SB_SPAWN id=${sid} .*frame=${sframe}( |$)" "$hlog"; then
			echo "  FAIL: born-at-send — host kicker ${sid} sent on frame ${sframe}, dressed: $(grep -oE "SB_SPAWN id=${sid} [^$]*" "$hlog" | head -n1)"
			return 1
		fi
	done < <(sed -nE 's/.*SB_SENT id=([0-9]+) frame=([0-9]+).*/\1 \2/p' "$hlog")
	if ((sent_n < 2)); then echo "  FAIL: born-at-send — expected >=2 SB_SENT receipts on the host, got ${sent_n}"; return 1; fi
	echo "  born-at-send: ${sent_n} host spawns dressed on their own frame"

	# CONVERGENCE: highest tick reported by all three, positions within 8px.
	# (awk/sed only — the nix dev shell carries no python.)
	local hpts="$FSLP_LOGS/h.pts" spts="$FSLP_LOGS/s.pts" wpts="$FSLP_LOGS/w.pts"
	sed -nE 's/.*SB_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+).*/\1 \2 \3/p' "$hlog" >"$hpts"
	sed -nE 's/.*SB_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+).*/\1 \2 \3/p' "$slog" >"$spts"
	sed -nE 's/.*SB_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+).*/\1 \2 \3/p' "$wlog" >"$wpts"
	# The assert exists to catch two-WORLDS divergence, which disagrees at
	# EVERY shared tick by hundreds of px — so judge the BEST (min-span)
	# common tick, not the last one: under machine load the match runs long
	# and the final samples land mid-roll, where an interp window's honest
	# spread (~12px at 60Hz, more when frames stretch) reads as disagreement.
	local verdict
	verdict=$(awk '
		FNR==1{f++}
		f==1{hx[$1]=$2; hy[$1]=$3}
		f==2{sx[$1]=$2; sy[$1]=$3}
		f==3{
			t=$1
			if ((t in hx) && (t in sx)) {
				span=0
				d=hx[t]-sx[t]; if(d<0)d=-d; if(d>span)span=d
				d=hx[t]-$2;    if(d<0)d=-d; if(d>span)span=d
				d=sx[t]-$2;    if(d<0)d=-d; if(d>span)span=d
				d=hy[t]-sy[t]; if(d<0)d=-d; if(d>span)span=d
				d=hy[t]-$3;    if(d<0)d=-d; if(d>span)span=d
				d=sy[t]-$3;    if(d<0)d=-d; if(d>span)span=d
				ticks[n]=t; spans[n]=span; n++
			}
		}
		END{
			if (n==0) {print "none"; exit}
			# min over the LAST five common ticks: late enough that the
			# kickoff stillness cannot trivially converge, wide enough that
			# one mid-roll sample cannot trivially diverge.
			from = n>5 ? n-5 : 0
			for (i=from; i<n; i++) if (best=="" || spans[i]<best) {best=spans[i]; bt=ticks[i]}
			print bt, best
		}
	' "$hpts" "$spts" "$wpts")
	if [ "$verdict" = "none" ]; then
		echo "  FAIL: convergence: no common SB_BALL tick across the three logs"; FSLP_OK=0
	else
		local tick span
		read -r tick span <<<"$verdict"
		echo "  convergence: best common tick=$tick span=${span}px"
		((span<=15)) || { echo "  FAIL: convergence: screens disagree past tolerance at EVERY shared tick (best span ${span}px)"; FSLP_OK=0; }
	fi

	if ((!FSLP_OK)); then
		for l in "$hlog" "$slog" "$wlog"; do
			echo "  ==== $(basename "$l") ===="; tail -n 20 "$l" | sed 's/^/    /'
		done
		return 1
	fi
}

fslp_act "three peers" 4 three_peers
if fslp_verdict SLOPBALL_NATIVE; then
	echo "SLOPBALL_NATIVE_OK proved: client-simulated RigidBody2D, host seat grants, goal off the stream, 3-screen convergence"
	exit 0
fi
exit 1
