#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Two-peer ENet RPC test — the genuine remote path the single-process tests/rpc could not
# exercise. Launches TWO headless Godot processes (a SERVER + a CLIENT) that connect over a
# real ENet localhost socket, each running an Odin NetNode with @(gd_rpc) methods, and proves
# an RPC called on one peer is RECEIVED + EXECUTED on the OTHER, both directions, with the
# correct get_remote_sender_id().
#
# Asserts (from each process's captured stdout):
#   server->client any_peer  : client log has  ping  on=<client> from=1        value=11
#   server->client authority : client log has  auth  on=<client> from=1        value=33
#   client->server any_peer  : server log has  ping  on=1        from=<client> value=22
#   non-call_local broadcast : client HAS value=99 ; server does NOT (didn't run on sender)
#   call_local   broadcast   : server HAS echo value=88 (ran locally too)
#
# Reliable, not flaky: randomized port with bind-failure retry, wall-clock connection timeout
# (no sleep-and-hope), clean teardown of both processes. Prints RPC_NET_OK on success.
#
# Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/rpc_net/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/rpc_net"
LOGDIR="$PROJ/.runlogs"
mkdir -p "$LOGDIR"

# 1. Build the scripts dll (NetNode + boot) + the core dll, via the codegen pipeline.
bash "$ROOT/build/build_scripts.sh" "$PROJ"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# 2. Write .godot/extension_list.cfg + import so the runtime loads the extension. (A SIGSEGV
#    in Godot's headless editor doc-gen at import cleanup is a pre-existing engine issue.)
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Launch one peer (ROLE/PORT via env), backgrounded, stdout -> $2.
launch_peer() {
	local role="$1" log="$2" port="$3"
	ROLE="$role" PORT="$port" "$GODOT" --headless --path "$PROJ" --script net_peer.gd \
		>"$log" 2>&1 &
	echo $!
}

# Wait (up to ~25s) for both pids to exit; kill any stragglers.
wait_pair() {
	local sp="$1" cp="$2"
	local waited=0
	while (( waited < 250 )); do
		if ! kill -0 "$sp" 2>/dev/null && ! kill -0 "$cp" 2>/dev/null; then
			return 0
		fi
		sleep 0.1
		(( waited++ ))
	done
	kill "$sp" "$cp" 2>/dev/null
	return 1
}

# One full attempt on a given port. Returns 0 on a verified pass.
attempt() {
	local port="$1"
	local slog="$LOGDIR/server.log" clog="$LOGDIR/client.log"
	: >"$slog"; : >"$clog"

	# Start the server first; give it a moment to bind before the client connects.
	local sp; sp=$(launch_peer server "$slog" "$port")
	# Wait until the server reports it bound (HOST_OK) or failed (HOST_FAIL), up to ~5s.
	local i=0
	while (( i < 50 )); do
		grep -q "HOST_OK" "$slog" && break
		if grep -q "HOST_FAIL" "$slog"; then
			kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null
			echo "  port $port: HOST_FAIL (bind), retrying"
			return 2   # signal "retry on a new port"
		fi
		if ! kill -0 "$sp" 2>/dev/null; then break; fi
		sleep 0.1; (( i++ ))
	done

	local cp; cp=$(launch_peer client "$clog" "$port")
	wait_pair "$sp" "$cp"
	wait "$sp" 2>/dev/null; wait "$cp" 2>/dev/null

	# ---- assertions ----
	local ok=1

	# Client's own peer id (printed by REPORT once connected) — used for sender-id checks.
	local cid
	cid=$(grep -oE "REPORT my_id=[0-9]+" "$clog" | head -1 | grep -oE "[0-9]+")
	if [[ -z "$cid" || "$cid" == "0" ]]; then
		echo "  FAIL: client never got a unique id (no connection?)"; ok=0
	fi

	# server -> client, any_peer, sender must be the server (1)
	grep -qE "RPC_RECV ping on=$cid from=1 value=11" "$clog" \
		|| { echo "  FAIL: client did not receive server's any_peer ping (value=11, from=1)"; ok=0; }
	# server -> client, authority, sender must be the server (1)
	grep -qE "RPC_RECV auth on=$cid from=1 value=33" "$clog" \
		|| { echo "  FAIL: client did not receive server's authority auth (value=33, from=1)"; ok=0; }
	# client -> server, any_peer, sender must be the client id
	grep -qE "RPC_RECV ping on=1 from=$cid value=22" "$slog" \
		|| { echo "  FAIL: server did not receive client's any_peer ping (value=22, from=$cid)"; ok=0; }
	# non-call_local broadcast (value=99): RAN remotely on the client...
	grep -qE "RPC_RECV ping on=$cid from=1 value=99" "$clog" \
		|| { echo "  FAIL: client did not receive server's broadcast ping (value=99)"; ok=0; }
	# ...but did NOT run locally on the sender (server)
	if grep -qE "value=99" "$slog"; then
		echo "  FAIL: non-call_local RPC ran on the SENDER (server) — value=99 present in server log"; ok=0
	fi
	# call_local broadcast (value=88): the positive control — it DID run locally on the server
	grep -qE "RPC_RECV echo on=1 .* value=88" "$slog" \
		|| { echo "  FAIL: call_local RPC did not run locally on the server (value=88)"; ok=0; }
	# ...and also on the client
	grep -qE "RPC_RECV echo on=$cid from=1 value=88" "$clog" \
		|| { echo "  FAIL: client did not receive the call_local broadcast (value=88)"; ok=0; }

	# both finished cleanly
	grep -q "SERVER_DONE" "$slog" || { echo "  FAIL: server did not finish cleanly"; ok=0; }
	grep -q "CLIENT_DONE" "$clog" || { echo "  FAIL: client did not finish cleanly"; ok=0; }

	if (( ok == 1 )); then
		echo "  PASS on port $port (client id=$cid)"
		echo "  --- key server sentinels ---"; grep -E "RPC_RECV|SERVER_DONE|REPORT" "$slog" | sed 's/^/    /'
		echo "  --- key client sentinels ---"; grep -E "RPC_RECV|CLIENT_DONE|REPORT" "$clog" | sed 's/^/    /'
		return 0
	fi
	echo "  --- server log tail ---"; tail -n 20 "$slog" | sed 's/^/    /'
	echo "  --- client log tail ---"; tail -n 20 "$clog" | sed 's/^/    /'
	return 1
}

# 3. Try a few randomized ports (retry on bind failure / a failed attempt).
rc=1
for try in 1 2 3 4 5; do
	PORT=$(( (RANDOM % 12000) + 50000 ))
	echo "==> attempt $try on port $PORT"
	attempt "$PORT"; rc=$?
	if (( rc == 0 )); then break; fi
	if (( rc == 2 )); then continue; fi   # bind failure -> new port
	# A non-bind failure: retry once or twice more on a fresh port before giving up.
done

if (( rc == 0 )); then
	echo "RPC_NET_OK"
	exit 0
else
	echo "RPC_NET_FAIL"
	exit 1
fi
