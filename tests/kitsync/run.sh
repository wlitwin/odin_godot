#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Two-peer kit/net SYNC + COMMAND test — the friendslop toolkit's replication
# stack over a real socket. Launches a SERVER + CLIENT (headless Godot, ENet
# localhost; harness mirrors tests/rpc_net) and proves, end to end:
#
#   STATE:    gd:"replicate" tag -> scriptgen's generated Entity_Desc -> kit/net
#             shadow diff / full snapshot -> kit/netgd send_bytes -> ENet ->
#             peer_packet -> kit/net apply -> verified fields on the remote peer.
#   COMMANDS: typed predicted @(gd_command) -> generated `<proc>_cmd` wrapper (the only
#             role branch lives in generated code) -> optimistic local run ->
#             wire -> host dedup + authoritative execute -> CONFIRM (prediction
#             stands, pending drains) and, against silently-diverged host state,
#             REJECT whose embedded truth snapshot corrects the stale client.
#
# Asserts (from captured stdout):
#   server: HOST_OK, SYNC_SENT_FULL, SYNC_SENT_DELTA mask=3,
#           SYNC_CMD_EXEC ok=true hp=48, SYNC_CMD_EXEC ok=false hp=48, SERVER_DONE
#   client: SYNC_GOT_FULL ok=true (all fields), SYNC_GOT_DELTA ok=true mask=3,
#           SYNC_CMD_ISSUED predicted=Predicted hp=48 pending=1,
#           SYNC_CMD_CONFIRM ok=true hp=48 pending=0,
#           SYNC_CMD_ISSUED predicted=Predicted hp=53 pending=1,
#           SYNC_CMD_REJECT ok=true hp=48 locked=1 pending=0, CLIENT_DONE
#
# Prints KITSYNC_OK. Run inside the Nix dev shell:
#   nix develop --command bash -c 'bash tests/kitsync/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/kitsync"
LOGDIR="$PROJ/.runlogs"
mkdir -p "$LOGDIR"

bash "$ROOT/build/build_scripts.sh" "$PROJ"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch_peer() {
	local role="$1" log="$2" port="$3"
	ROLE="$role" PORT="$port" "$GODOT" --headless --path "$PROJ" --script sync_peer.gd \
		>"$log" 2>&1 &
	echo $!
}

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

attempt() {
	local port="$1"
	local slog="$LOGDIR/server.log" clog="$LOGDIR/client.log"
	: >"$slog"; : >"$clog"

	local sp; sp=$(launch_peer server "$slog" "$port")
	local i=0
	while (( i < 50 )); do
		grep -q "HOST_OK" "$slog" && break
		if grep -q "HOST_FAIL" "$slog"; then
			kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null
			echo "  port $port: HOST_FAIL (bind), retrying"
			return 2
		fi
		if ! kill -0 "$sp" 2>/dev/null; then break; fi
		sleep 0.1; (( i++ ))
	done

	local cp; cp=$(launch_peer client "$clog" "$port")
	wait_pair "$sp" "$cp"
	wait "$sp" 2>/dev/null; wait "$cp" 2>/dev/null

	local ok=1
	grep -q "SYNC_SENT_FULL" "$slog" || { echo "  FAIL: server never sent the full snapshot"; ok=0; }
	grep -q "SYNC_SENT_DELTA mask=3" "$slog" \
		|| { echo "  FAIL: server delta mask wrong (want 3 = hp+x dirty only)"; ok=0; }
	grep -qE "SYNC_GOT_FULL ok=true hp=42 x=3.5 y=-1.25 state=7" "$clog" \
		|| { echo "  FAIL: client full-snapshot apply not verified"; ok=0; }
	grep -qE "SYNC_GOT_DELTA ok=true mask=3 hp=43 x=4" "$clog" \
		|| { echo "  FAIL: client delta apply not verified (subset fields, others untouched)"; ok=0; }
	grep -qF "SYNC_CMD_EXEC ok=true hp=48" "$slog" \
		|| { echo "  FAIL: host never executed the confirmed command"; ok=0; }
	grep -qF "SYNC_CMD_EXEC ok=false hp=48" "$slog" \
		|| { echo "  FAIL: host never rejected the stale command (hp must be untouched)"; ok=0; }
	grep -qF "SYNC_CMD_ISSUED predicted=Predicted hp=48 pending=1" "$clog" \
		|| { echo "  FAIL: first bump was not predicted optimistically"; ok=0; }
	grep -qF "SYNC_CMD_CONFIRM ok=true hp=48 pending=0" "$clog" \
		|| { echo "  FAIL: confirm did not drain pending / keep the prediction"; ok=0; }
	grep -qF "SYNC_CMD_ISSUED predicted=Predicted hp=53 pending=1" "$clog" \
		|| { echo "  FAIL: stale second bump was not predicted (client must not know locked)"; ok=0; }
	grep -qF "SYNC_CMD_REJECT ok=true hp=48 locked=1 pending=0" "$clog" \
		|| { echo "  FAIL: reject did not snap the client to the embedded truth"; ok=0; }
	grep -q "SERVER_DONE" "$slog" || { echo "  FAIL: server did not finish cleanly"; ok=0; }
	grep -q "CLIENT_DONE" "$clog" || { echo "  FAIL: client did not finish cleanly"; ok=0; }

	if (( ok == 1 )); then
		echo "  PASS on port $port"
		echo "  --- key server sentinels ---"; grep -E "SYNC_|SERVER_DONE" "$slog" | sed 's/^/    /'
		echo "  --- key client sentinels ---"; grep -E "SYNC_|CLIENT_DONE" "$clog" | sed 's/^/    /'
		return 0
	fi
	echo "  --- server log tail ---"; tail -n 20 "$slog" | sed 's/^/    /'
	echo "  --- client log tail ---"; tail -n 20 "$clog" | sed 's/^/    /'
	return 1
}

rc=1
for try in 1 2 3 4 5; do
	PORT=$(( (RANDOM % 12000) + 50000 ))
	echo "==> attempt $try on port $PORT"
	attempt "$PORT"; rc=$?
	if (( rc == 0 )); then break; fi
	if (( rc == 2 )); then continue; fi
done

if (( rc == 0 )); then
	echo "KITSYNC_OK"
	exit 0
else
	echo "KITSYNC_FAIL"
	exit 1
fi
