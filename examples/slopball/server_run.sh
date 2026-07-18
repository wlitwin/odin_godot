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
# Plumbing = the kit harness; the receipts stay. Prints SLOPBALL_SERVER_OK.
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/slopball"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null || { echo "SLOPBALL_SERVER_FAIL (build)"; exit 1; }
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

FSLP_PROJ="$PROJ"
FSLP_LOGS="$PROJ/.sloplogs"
source "$ROOT/build/template/test/harness.sh"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

slop_launch() { # slop_launch <role> <bot> <name> <token> <log> <port>
	local role="$1" bot="$2" name="$3" token="$4" log="$5" port="$6"
	SLOP_ROLE="$role" SLOP_BOT="$bot" SLOP_NAME="$name" SLOP_TOKEN="$token" \
	SLOP_PORT="$port" SLOP_GOALS=1 SLOP_PEERS=2 \
		"$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
	echo $! >>"$FSLP_PIDS"
	echo $!
}

server_pitch() {
	local port="$1"
	local vlog="$FSLP_LOGS/server.log" slog="$FSLP_LOGS/sv_striker.log" wlog="$FSLP_LOGS/sv_watcher.log"
	: >"$vlog"; : >"$slog"; : >"$wlog"
	local vp sp wp
	vp=$(slop_launch serve idle referee 9101 "$vlog" "$port")
	fslp_ready "$vlog" "SB_SERVING" 8 "$vp" || { echo "  port $port: server never bound"; return 1; }
	sp=$(slop_launch join striker striker 9102 "$slog" "$port")
	fslp_ready "$slog" "SB_SEATED me=2" 15 "$sp" || { echo "  striker never seated"; return 1; }
	wp=$(slop_launch join idle watcher 9103 "$wlog" "$port")

	local deadline=$((SECONDS + 40))
	while ((SECONDS < deadline)); do
		if grep -q "SLOPBALL_DONE" "$vlog" && grep -q "SLOPBALL_DONE" "$slog" && grep -q "SLOPBALL_DONE" "$wlog"; then
			break
		fi
		sleep 0.5
	done
	sleep 2
	fslp_reap

	expect "$vlog" "SB_SERVING" "server never opened"
	expect "$vlog" "SB_WORLD_UP" "server never spawned the world"
	expect "$slog" "SB_SEATED me=2" "striker not seated as 2"
	expect "$wlog" "SB_SEATED me=3" "watcher not seated as 3"
	# THE dedicated-seat receipt: every screen holds exactly the two CLIENT
	# kickers — the server fielded none, and clients learned the flag off the
	# welcome roster, not local guesswork.
	for l in "$vlog" "$slog" "$wlog"; do
		expect "$l" "SB_BALL.* kick=2 " "kicker count wrong in $(basename "$l") (want kick=2)"
	done
	expect "$vlog" "SB_BALL_OWNER player=2" "server never granted the striker the seat"
	expect "$slog" "SB_BALL_OWNER player=2" "striker never heard it holds the seat"
	expect "$wlog" "SB_BALL_OWNER player=2" "watcher never heard the seat transfer"
	expect "$vlog" "SB_GOAL by=2" "server never saw the goal"
	expect "$vlog" "SB_MATCH winner=2" "no match edge on the server"
	expect "$slog" "SLOPBALL_DONE" "striker never finished"
	expect "$wlog" "SLOPBALL_DONE" "watcher never finished"
	for l in "$vlog" "$slog" "$wlog"; do
		expect_absent "$l" "SCRIPT ERROR|signal 11" "runtime errors in $(basename "$l")"
	done

	if ((!FSLP_OK)); then
		for l in "$vlog" "$slog" "$wlog"; do
			echo "  ==== $(basename "$l") ===="; tail -n 20 "$l" | sed 's/^/    /'
		done
		return 1
	fi
}

fslp_act "the server pitch" 4 server_pitch
if fslp_verdict SLOPBALL_SERVER; then
	echo "SLOPBALL_SERVER_OK proved: avatarless dedicated seat (kit-flagged, wire-carried), player-only start gating, client-simulated ball on a server pitch"
	exit 0
fi
exit 1
