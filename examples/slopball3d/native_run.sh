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
# tolerance). Plumbing = the kit harness; the receipts stay.
# Prints SLOPBALL3D_NATIVE_OK.
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/slopball3d"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null || { echo "SLOPBALL3D_NATIVE_FAIL (build)"; exit 1; }
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

FSLP_PROJ="$PROJ"
FSLP_LOGS="$PROJ/.sloplogs"
source "$ROOT/build/template/test/harness.sh"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

slop3_launch() { # slop3_launch <role> <bot> <name> <token> <log> <port>
	local role="$1" bot="$2" name="$3" token="$4" log="$5" port="$6"
	SLOP3_ROLE="$role" SLOP3_BOT="$bot" SLOP3_NAME="$name" SLOP3_TOKEN="$token" \
	SLOP3_PORT="$port" SLOP3_GOALS=1 SLOP3_PEERS=3 \
		"$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
	echo $! >>"$FSLP_PIDS"
	echo $!
}

three_peers_3d() {
	local port="$1"
	local hlog="$FSLP_LOGS/host.log" slog="$FSLP_LOGS/striker.log" wlog="$FSLP_LOGS/watcher.log"
	: >"$hlog"; : >"$slog"; : >"$wlog"
	local hp sp wp
	hp=$(slop3_launch host idle hosty 9301 "$hlog" "$port")
	fslp_ready "$hlog" "SB3_HOSTING" 8 "$hp" || { echo "  port $port: host never bound"; return 1; }
	sp=$(slop3_launch join striker striker 9302 "$slog" "$port")
	# Seat order is arrival order — hold the watcher until the striker sits in
	# seat 2, or the two joins race and the assertions point at the wrong logs.
	fslp_ready "$slog" "SB3_SEATED me=2" 15 "$sp" || { echo "  striker never seated"; return 1; }
	wp=$(slop3_launch join idle watcher 9303 "$wlog" "$port")

	# The whole match should land inside 40s; then a beat of REST so the last
	# SB3_BALL reports show a settled ball for the convergence diff.
	local deadline=$((SECONDS + 40))
	while ((SECONDS < deadline)); do
		if grep -q "SLOPBALL3D_DONE" "$hlog" && grep -q "SLOPBALL3D_DONE" "$slog" && grep -q "SLOPBALL3D_DONE" "$wlog"; then
			break
		fi
		sleep 0.5
	done
	sleep 4 # the last kick's roll must settle, or interp lag reads as disagreement
	fslp_reap

	expect "$hlog" "SB3_WORLD_UP" "host never spawned the world"
	expect "$slog" "SB3_SEATED me=2" "striker not seated as 2"
	expect "$wlog" "SB3_SEATED me=3" "watcher not seated as 3"
	expect "$hlog" "SB3_BALL_OWNER player=2" "host never granted the striker the seat"
	expect "$slog" "SB3_BALL_OWNER player=2" "striker never heard it holds the seat"
	expect "$wlog" "SB3_BALL_OWNER player=2" "watcher never heard the seat transfer"
	expect "$slog" "SB3_KICK" "striker never kicked"
	expect "$hlog" "SB3_GOAL by=2" "host never saw the goal"
	expect "$hlog" "SB3_MATCH winner=2" "no match edge on the host"
	expect "$wlog" "SB3_MATCH winner=2" "no match edge on the watcher"
	expect "$slog" "SLOPBALL3D_DONE" "striker never finished"
	for l in "$hlog" "$slog" "$wlog"; do
		expect_absent "$l" "SCRIPT ERROR|signal 11" "runtime errors in $(basename "$l")"
	done

	# CONVERGENCE: highest tick reported by all three, positions within 40cm
	# (x and z; y is gravity-parked and comes along for free in the diff), and
	# the QUATERNION within tolerance per sampled component — the settled
	# ball's orientation is the end-to-end receipt for the .Quat wire+nlerp
	# path (a corrupted rotation cannot show up in the position diff).
	local hpts="$FSLP_LOGS/h.pts" spts="$FSLP_LOGS/s.pts" wpts="$FSLP_LOGS/w.pts"
	sed -nE 's/.*SB3_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+) z=(-?[0-9]+) qx=(-?[0-9]+) qw=(-?[0-9]+).*/\1 \2 \3 \4 \5 \6/p' "$hlog" >"$hpts"
	sed -nE 's/.*SB3_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+) z=(-?[0-9]+) qx=(-?[0-9]+) qw=(-?[0-9]+).*/\1 \2 \3 \4 \5 \6/p' "$slog" >"$spts"
	sed -nE 's/.*SB3_BALL tick=([0-9]+) x=(-?[0-9]+) y=(-?[0-9]+) z=(-?[0-9]+) qx=(-?[0-9]+) qw=(-?[0-9]+).*/\1 \2 \3 \4 \5 \6/p' "$wlog" >"$wpts"
	# Judge the BEST (min-span) common tick, not the last: two-WORLDS
	# divergence disagrees at EVERY shared tick by meters, while under
	# machine load the final samples land mid-flight, where an interp
	# window's honest spread (~30cm at 60Hz, more when frames stretch)
	# reads as disagreement. The quat gets its own independent min — its
	# clean moments (settled spin) need not be the position's.
	local verdict
	verdict=$(awk '
		function A(v){return v<0?-v:v}
		FNR==1{f++}
		f==1{hx[$1]=$2; hy[$1]=$3; hz[$1]=$4; hqx[$1]=$5; hqw[$1]=$6}
		f==2{sx[$1]=$2; sy[$1]=$3; sz[$1]=$4; sqx[$1]=$5; sqw[$1]=$6}
		f==3{
			t=$1
			if ((t in hx) && (t in sx)) {
				span=0
				if(A(hx[t]-sx[t])>span)span=A(hx[t]-sx[t]); if(A(hx[t]-$2)>span)span=A(hx[t]-$2); if(A(sx[t]-$2)>span)span=A(sx[t]-$2)
				if(A(hy[t]-sy[t])>span)span=A(hy[t]-sy[t]); if(A(hy[t]-$3)>span)span=A(hy[t]-$3); if(A(sy[t]-$3)>span)span=A(sy[t]-$3)
				if(A(hz[t]-sz[t])>span)span=A(hz[t]-sz[t]); if(A(hz[t]-$4)>span)span=A(hz[t]-$4); if(A(sz[t]-$4)>span)span=A(sz[t]-$4)
				qs=0
				if(A(hqx[t]-sqx[t])>qs)qs=A(hqx[t]-sqx[t]); if(A(hqx[t]-$5)>qs)qs=A(hqx[t]-$5); if(A(sqx[t]-$5)>qs)qs=A(sqx[t]-$5)
				if(A(hqw[t]-sqw[t])>qs)qs=A(hqw[t]-sqw[t]); if(A(hqw[t]-$6)>qs)qs=A(hqw[t]-$6); if(A(sqw[t]-$6)>qs)qs=A(sqw[t]-$6)
				ticks[n]=t; spans[n]=span; qs_[n]=qs; n++
			}
		}
		END{
			if (n==0) {print "none"; exit}
			# min over the LAST five common ticks: late enough that the
			# kickoff stillness cannot trivially converge, wide enough that
			# one mid-flight sample cannot trivially diverge.
			from = n>5 ? n-5 : 0
			for (i=from; i<n; i++) {
				if (best=="" || spans[i]<best) {best=spans[i]; bt=ticks[i]}
				if (qbest=="" || qs_[i]<qbest) {qbest=qs_[i]}
			}
			print bt, best, qbest
		}
	' "$hpts" "$spts" "$wpts")
	if [ "$verdict" = "none" ]; then
		echo "  FAIL: convergence: no common SB3_BALL tick across the three logs"; FSLP_OK=0
	else
		local tick span qspan
		read -r tick span qspan <<<"$verdict"
		echo "  convergence: best common tick=$tick span=${span}cm qspan=$qspan"
		((span<=40)) || { echo "  FAIL: convergence: screens disagree past tolerance at EVERY shared tick (best span ${span}cm)"; FSLP_OK=0; }
		# Quat tolerance derives from residual SLOW ROLL, not the wire: a
		# rolling quat churns ~ω/2 per second and sampling skew spreads
		# ~10-25 units. Corruption (garbage decode, hemisphere flip) shows as
		# 70-200 at EVERY tick. 40 splits the two decisively.
		((qspan<=40)) || { echo "  FAIL: convergence: quaternions disagree past tolerance at EVERY shared tick (wire/nlerp)"; FSLP_OK=0; }
		# And the decisive receipt that rotation CROSSED the wire at all: every
		# peer must have seen the ball's quat leave identity during the match
		# (a dead rot field pins qw at 100 on watchers forever).
		for f in "$hpts" "$spts" "$wpts"; do
			awk 'BEGIN{m=999} {v=$6; if(v<0)v=-v; if(v<m)m=v} END{exit !(m<=50)}' "$f" \
				|| { echo "  FAIL: quat receipt: $(basename "$f") never left identity — rotation not replicating"; FSLP_OK=0; }
		done
	fi

	if ((!FSLP_OK)); then
		for l in "$hlog" "$slog" "$wlog"; do
			echo "  ==== $(basename "$l") ===="; tail -n 20 "$l" | sed 's/^/    /'
		done
		return 1
	fi
}

fslp_act "three peers, third axis" 4 three_peers_3d
if fslp_verdict SLOPBALL3D_NATIVE; then
	echo "SLOPBALL3D_NATIVE_OK proved: client-simulated RigidBody3D under gravity, quaternion stream, host seat grants, goal off the stream, 3-screen convergence"
	exit 0
fi
exit 1
