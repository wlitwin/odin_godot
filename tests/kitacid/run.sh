#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# THE PHASE-0 ACID TEST — a new multiplayer entity in ~15 lines, zero role
# branches, correct from ALL THREE perspectives under injected latency.
#
# Launches THREE headless Godot processes over ENet localhost:
#   server    the authority: spawns the Orb, join-snapshots both clients,
#             executes commands, broadcasts per-tick delta batches — and, for
#             the orb's OWNER-STREAMED x/y, is itself just another remote:
#             it samples the owner's stream with the same role-free code.
#   owner     the issuing client: strikes are PREDICTED the same call (before
#             any round trip can land — latency-proven), then confirmed; the
#             out-of-stamina strike is rejected with embedded truth. Then it
#             DRIVES the orb: writing x/y is the whole author surface — the
#             session streams them unreliable at the net tick rate.
#   observer  a client that never issues anything and has NO role-specific
#             code — it converges purely by applying spawn + delta batches
#             (the peer Unreal makes you write "simulated proxy" code for)
#             and renders the owner's motion by delayed interpolated sampling.
#
# Every peer buffers RECEIVED packets for LATENCY_MS before applying them, so
# a round trip provably costs >= 2x latency: the owner's lat_ok asserts confirm
# could NOT have raced the prediction, and both clients' clock sync must
# measure rtt >= 1.5x latency with ~0 offset (shared monotonic base).
#
# The author surface under test is orb.odin — the WHOLE entity — plus one
# generated `orb_strike_cmd` call. session.odin is the generic wiring that
# graduates into kit/session in phase 1.
#
# Prints KITACID_OK. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/kitacid/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/kitacid"
LOGDIR="$PROJ/.runlogs"
mkdir -p "$LOGDIR"

LATENCY_MS="${LATENCY_MS:-100}"

# A failed build MUST fail the test — without this the peers launch against a
# stale dll and the whole acid silently proves yesterday's binary.
bash "$ROOT/build/build_scripts.sh" "$PROJ" || { echo "KITACID_FAIL (scripts build)"; exit 1; }
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch_peer() {
	local role="$1" log="$2" port="$3"
	ROLE="$role" PORT="$port" LATENCY_MS="$LATENCY_MS" \
		"$GODOT" --headless --path "$PROJ" --script acid_peer.gd \
		>"$log" 2>&1 &
	echo $!
}

wait_all() {
	local waited=0
	while ((waited < 450)); do
		local alive=0
		for pid in "$@"; do
			kill -0 "$pid" 2>/dev/null && alive=1
		done
		((alive == 0)) && return 0
		sleep 0.1
		((waited++))
	done
	kill "$@" 2>/dev/null
	return 1
}

attempt() {
	local port="$1"
	local slog="$LOGDIR/server.log" wlog="$LOGDIR/owner.log" olog="$LOGDIR/observer.log"
	: >"$slog"; : >"$wlog"; : >"$olog"

	local sp; sp=$(launch_peer server "$slog" "$port")
	local i=0
	while ((i < 50)); do
		grep -q "ACID_HOST_OK" "$slog" && break
		if grep -q "HOST_FAIL" "$slog"; then
			kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null
			echo "  port $port: HOST_FAIL (bind), retrying"
			return 2
		fi
		if ! kill -0 "$sp" 2>/dev/null; then break; fi
		sleep 0.1; ((i++))
	done

	local wp op
	wp=$(launch_peer owner "$wlog" "$port")
	op=$(launch_peer observer "$olog" "$port")
	wait_all "$sp" "$wp" "$op"
	wait "$sp" 2>/dev/null; wait "$wp" 2>/dev/null; wait "$op" 2>/dev/null

	local ok=1
	# ---- server: session seating + authoritative execution ----
	grep -q "ACID_HOST_OK" "$slog" || { echo "  FAIL: host never came up"; ok=0; }
	[[ "$(grep -c "ACID_PLAYER name=" "$slog")" == "2" ]] \
		|| { echo "  FAIL: host did not seat exactly 2 players"; ok=0; }
	grep -q "ACID_PLAYER name=owner rejoin=false" "$slog" \
		|| { echo "  FAIL: the owner never joined the session"; ok=0; }
	grep -q "ACID_PLAYER name=observer rejoin=false" "$slog" \
		|| { echo "  FAIL: the observer never joined the session"; ok=0; }
	grep -qF "ACID_WORLD id=1 seated=3" "$slog" \
		|| { echo "  FAIL: world did not go live with 3 seated players"; ok=0; }
	grep -qF "ACID_EXEC ok=true hp=92 st=6" "$slog" \
		|| { echo "  FAIL: host never executed strike 1"; ok=0; }
	grep -qF "ACID_EXEC ok=true hp=84 st=2" "$slog" \
		|| { echo "  FAIL: host never executed strike 2"; ok=0; }
	grep -qF "ACID_EXEC ok=false hp=84 st=2" "$slog" \
		|| { echo "  FAIL: host never rejected the empty-stamina strike (state must be untouched)"; ok=0; }
	grep -qF "ACID_THEN cost=4 dealt=8 hp=92 by_ok=true" "$slog" \
		|| { echo "  FAIL: strike 1's consequence did not fire on the authority (issuer + wire args + payload)"; ok=0; }
	grep -qF "ACID_THEN cost=4 dealt=8 hp=84 by_ok=true" "$slog" \
		|| { echo "  FAIL: strike 2's consequence did not fire on the authority"; ok=0; }
	[[ "$(grep -c "ACID_THEN" "$slog")" == "2" ]] \
		|| { echo "  FAIL: the consequence must fire EXACTLY twice — never for the rejected strike or a retransmit"; ok=0; }
	grep -qF "ACID_STREAM ok=true" "$slog" \
		|| { echo "  FAIL: the HOST did not verify smooth sampled motion (it is a remote for owner streams)"; ok=0; }
	grep -qF "ACID_PING ok=true" "$slog" \
		|| { echo "  FAIL: the auto-fed ping stat never reflected the injected latency"; ok=0; }
	grep -q "SERVER_DONE" "$slog" || { echo "  FAIL: server did not finish cleanly"; ok=0; }

	# ---- owner: seated + optimistic prediction + confirm/reject round trips ----
	grep -q "ACID_SEATED me=" "$wlog" || { echo "  FAIL: owner was never welcomed"; ok=0; }
	grep -qF "ACID_SPAWN ok=true id=1 mine=true hp=100 st=10" "$wlog" \
		|| { echo "  FAIL: owner join snapshot (with ownership) not verified"; ok=0; }
	grep -qF "ACID_ISSUE n=1 predicted=true hp=92 st=6 pending=1" "$wlog" \
		|| { echo "  FAIL: strike 1 was not predicted instantly"; ok=0; }
	grep -qF "ACID_CONFIRM n=1 ok=true hp=92 st=6 pending=0 lat_ok=true" "$wlog" \
		|| { echo "  FAIL: confirm 1 wrong (or beat the injected latency)"; ok=0; }
	grep -qF "ACID_ISSUE n=2 predicted=true hp=84 st=2 pending=1" "$wlog" \
		|| { echo "  FAIL: strike 2 was not predicted instantly"; ok=0; }
	grep -qF "ACID_CONFIRM n=2 ok=true hp=84 st=2 pending=0 lat_ok=true" "$wlog" \
		|| { echo "  FAIL: confirm 2 wrong (or beat the injected latency)"; ok=0; }
	grep -qF "ACID_ISSUE n=3 predicted=false hp=84 st=2 pending=0" "$wlog" \
		|| { echo "  FAIL: empty-stamina strike must locally reject + revert (and still send)"; ok=0; }
	grep -qF "ACID_REJECT n=3 ok=true hp=84 st=2 pending=0" "$wlog" \
		|| { echo "  FAIL: host reject + truth did not settle the owner"; ok=0; }
	grep -qF "ACID_CLOCK ok=true" "$wlog" \
		|| { echo "  FAIL: owner clock sync did not measure the injected RTT"; ok=0; }
	grep -q "ACID_MOVING" "$wlog" || { echo "  FAIL: owner never started streaming motion"; ok=0; }
	grep -qF "ACID_STATS strikes=2 ping_ok=true" "$wlog" \
		|| { echo "  FAIL: owner scoreboard (strikes + measured ping) not verified"; ok=0; }
	grep -q "ACID_STREAM" "$wlog" \
		&& { echo "  FAIL: the owner sampled its own stream (it is authoritative for it)"; ok=0; }
	grep -q "ACID_THEN" "$wlog" \
		&& { echo "  FAIL: a PREDICTED strike fired its consequence on the issuing client"; ok=0; }
	grep -q "OWNER_DONE" "$wlog" || { echo "  FAIL: owner did not finish cleanly"; ok=0; }

	# ---- observer: converges with ZERO role-specific code ----
	grep -q "ACID_SEATED me=" "$olog" || { echo "  FAIL: observer was never welcomed"; ok=0; }
	grep -qF "ACID_SPAWN ok=true id=1 mine=false hp=100 st=10" "$olog" \
		|| { echo "  FAIL: observer join snapshot (with ownership) not verified"; ok=0; }
	grep -qF "ACID_DELTA ok=true n=1 hp=92 st=6" "$olog" \
		|| { echo "  FAIL: observer never saw strike 1's delta batch"; ok=0; }
	grep -qF "ACID_DELTA ok=true n=1 hp=84 st=2" "$olog" \
		|| { echo "  FAIL: observer never saw strike 2's delta batch"; ok=0; }
	[[ "$(grep -c "ACID_DELTA" "$olog")" == "2" ]] \
		|| { echo "  FAIL: observer saw extra delta batches — streamed fields must never dirty host deltas"; ok=0; }
	grep -qF "ACID_STREAM ok=true" "$olog" \
		|| { echo "  FAIL: observer did not verify smooth sampled motion"; ok=0; }
	grep -qF "ACID_CLOCK ok=true" "$olog" \
		|| { echo "  FAIL: observer clock sync did not measure the injected RTT"; ok=0; }
	grep -qF "ACID_STATS strikes=2 ping_ok=true" "$olog" \
		|| { echo "  FAIL: observer scoreboard (strikes + measured ping) not verified"; ok=0; }
	grep -q "ACID_ISSUE" "$olog" \
		&& { echo "  FAIL: the observer issued a command?!"; ok=0; }
	grep -q "ACID_THEN" "$olog" \
		&& { echo "  FAIL: the observer fired a consequence?!"; ok=0; }
	grep -q "OBSERVER_DONE" "$olog" || { echo "  FAIL: observer did not finish cleanly"; ok=0; }

	# ---- backup hosting: exactly ONE client holds the re-hostable snapshot ----
	local nbackup=$(( $(grep -c "ACID_BACKUP bytes=" "$wlog") > 0 ? 1 : 0 ))
	local obackup=$(( $(grep -c "ACID_BACKUP bytes=" "$olog") > 0 ? 1 : 0 ))
	[[ $((nbackup + obackup)) == 1 ]] \
		|| { echo "  FAIL: expected exactly one designated backup client (owner=$nbackup observer=$obackup)"; ok=0; }

	# ---- nothing lost, nothing torn, anywhere ----
	if grep -q "ACID_EXPIRED\|ACID_ERR\|ACID_CLOCK ok=false" "$slog" "$wlog" "$olog"; then
		echo "  FAIL: expiry/error/clock-failure sentinel present:"
		grep -n "ACID_EXPIRED\|ACID_ERR\|ACID_CLOCK ok=false" "$slog" "$wlog" "$olog" | sed 's/^/    /'
		ok=0
	fi

	if ((ok == 1)); then
		echo "  PASS on port $port (latency ${LATENCY_MS}ms each way)"
		echo "  --- server ---"; grep -E "ACID_|SERVER_DONE" "$slog" | sed 's/^/    /'
		echo "  --- owner ---"; grep -E "ACID_|OWNER_DONE" "$wlog" | sed 's/^/    /'
		echo "  --- observer ---"; grep -E "ACID_|OBSERVER_DONE" "$olog" | sed 's/^/    /'
		return 0
	fi
	echo "  --- server log tail ---"; tail -n 20 "$slog" | sed 's/^/    /'
	echo "  --- owner log tail ---"; tail -n 20 "$wlog" | sed 's/^/    /'
	echo "  --- observer log tail ---"; tail -n 20 "$olog" | sed 's/^/    /'
	return 1
}

rc=1
for try in 1 2 3 4 5; do
	PORT=$(((RANDOM % 12000) + 50000))
	echo "==> attempt $try on port $PORT"
	attempt "$PORT"; rc=$?
	if ((rc == 0)); then break; fi
	if ((rc == 2)); then continue; fi
done

if ((rc == 0)); then
	echo "KITACID_OK"
	exit 0
else
	echo "KITACID_FAIL"
	exit 1
fi
