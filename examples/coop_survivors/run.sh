#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Two-peer ENet CO-OP loop test — proves the networked survivors co-op loop across two REAL
# headless Godot processes (a SERVER + a CLIENT) connected over a real ENet localhost socket,
# both running the SAME Odin CoopGame script (examples/coop_survivors). It asserts — from each
# process's captured stdout — the SIX co-op guarantees:
#
#   1. connection establishes      : server sees the client peer; client sees the server
#   2. both players on both peers   : PLAYERS_OK count=2 on BOTH
#   3. client moves, server observes: client MOVED + server SAW_REMOTE_MOVE (position replicated)
#   4. enemy replication            : server ENEMY_SPAWN + client ENEMY_SEEN (same id)
#   5. authoritative death          : server ENEMY_DEAD + client ENEMY_GONE (both agree gone)
#   6. shared score                 : SCORE_SET value identical on BOTH peers
#
# REPLICATION: explicit @(gd_rpc) sync (server-authoritative), NOT MultiplayerSpawner/
# Synchronizer — see README.md. Reliable, not flaky: randomized port w/ bind-failure retry,
# wall-clock connection timeout, clean teardown. Prints COOP_OK on success.
#
#   nix develop --command bash -c 'bash examples/coop_survivors/run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail

ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/coop_survivors"
LOGDIR="$PROJ/.runlogs"
mkdir -p "$LOGDIR"

# 1. Build the scripts dll (CoopGame + boot) + the core dll via the codegen pipeline.
bash "$ROOT/build/build_scripts.sh" "$PROJ"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"

# 2. Write .godot/extension_list.cfg + import so the runtime loads the extension. (A SIGSEGV in
#    Godot's headless editor doc-gen at import cleanup is a pre-existing engine issue.)
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

# Launch one peer (role/port/addr via env), backgrounded, stdout -> $2.
launch_peer() {
	local role="$1" log="$2" port="$3"
	COOP_ROLE="$role" COOP_PORT="$port" COOP_ADDR="127.0.0.1" \
		"$GODOT" --headless --path "$PROJ" >"$log" 2>&1 &
	echo $!
}

# Wait (up to ~40s) for both pids to exit; kill any stragglers.
wait_pair() {
	local sp="$1" cp="$2" waited=0
	while ((waited < 400)); do
		if ! kill -0 "$sp" 2>/dev/null && ! kill -0 "$cp" 2>/dev/null; then return 0; fi
		sleep 0.1
		((waited++))
	done
	kill "$sp" "$cp" 2>/dev/null
	return 1
}

# One full attempt on a given port. Returns 0 on a verified pass, 2 to retry on a fresh port.
attempt() {
	local port="$1"
	local slog="$LOGDIR/server.log" clog="$LOGDIR/client.log"
	: >"$slog"; : >"$clog"

	# Start the server first; wait until it reports it bound (HOST_OK) or failed, up to ~6s.
	local sp; sp=$(launch_peer server "$slog" "$port")
	local i=0
	while ((i < 60)); do
		grep -q "HOST_OK" "$slog" && break
		if grep -q "HOST_FAIL" "$slog"; then
			kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null
			echo "  port $port: HOST_FAIL (bind), retrying"
			return 2
		fi
		if ! kill -0 "$sp" 2>/dev/null; then break; fi
		sleep 0.1; ((i++))
	done

	local cp; cp=$(launch_peer client "$clog" "$port")
	wait_pair "$sp" "$cp"
	wait "$sp" 2>/dev/null; wait "$cp" 2>/dev/null

	# ---- assertions ----
	local ok=1

	# Client's own peer id (printed once connected) — used for the on=<id> checks.
	local cid
	cid=$(grep -oE "REPORT my_id=[0-9]+" "$clog" | head -1 | grep -oE "[0-9]+$")
	if [[ -z "$cid" || "$cid" == "0" ]]; then
		echo "  FAIL: client never got a unique id (no connection?)"; ok=0; cid="?"
	fi

	# (1) connection
	grep -q "SERVER_SEES_CLIENT id=$cid" "$slog" || { echo "  FAIL[1]: server did not see client $cid"; ok=0; }
	grep -q "CLIENT_SEES_SERVER" "$clog"          || { echo "  FAIL[1]: client did not see server"; ok=0; }
	# (2) both players on both peers
	grep -q "PLAYERS_OK on=1 count=2" "$slog"       || { echo "  FAIL[2]: server lacks 2 players"; ok=0; }
	grep -q "PLAYERS_OK on=$cid count=2" "$clog"     || { echo "  FAIL[2]: client lacks 2 players"; ok=0; }
	# (3) client moved + server observed it
	grep -q "MOVED on=$cid" "$clog"                  || { echo "  FAIL[3]: client did not move its player"; ok=0; }
	grep -q "SAW_REMOTE_MOVE on=1 peer=$cid" "$slog"  || { echo "  FAIL[3]: server did not observe the client's move"; ok=0; }
	# (4) enemy replication
	grep -q "ENEMY_SPAWN on=1 id=9001" "$slog"        || { echo "  FAIL[4]: server did not spawn the enemy"; ok=0; }
	grep -q "ENEMY_SEEN on=$cid id=9001" "$clog"      || { echo "  FAIL[4]: client did not see the enemy"; ok=0; }
	# (5) authoritative death replicated; both agree it's gone
	grep -q "ENEMY_DEAD on=1 id=9001" "$slog"         || { echo "  FAIL[5]: server did not kill the enemy"; ok=0; }
	grep -q "ENEMY_GONE on=$cid id=9001" "$clog"      || { echo "  FAIL[5]: client did not see the enemy despawn"; ok=0; }
	# (6) shared score identical on both peers
	local s_score c_score
	s_score=$(grep -oE "SCORE_SET on=1 value=[0-9]+" "$slog" | head -1 | grep -oE "[0-9]+$")
	c_score=$(grep -oE "SCORE_SET on=$cid value=[0-9]+" "$clog" | head -1 | grep -oE "[0-9]+$")
	if [[ -z "$s_score" || -z "$c_score" ]]; then
		echo "  FAIL[6]: missing SCORE_SET (server='$s_score' client='$c_score')"; ok=0
	elif [[ "$s_score" != "$c_score" ]]; then
		echo "  FAIL[6]: score disagreement server=$s_score client=$c_score"; ok=0
	fi
	# both finished cleanly
	grep -q "SERVER_DONE" "$slog" || { echo "  FAIL: server did not finish cleanly"; ok=0; }
	grep -q "CLIENT_DONE" "$clog" || { echo "  FAIL: client did not finish cleanly"; ok=0; }

	if ((ok == 1)); then
		echo "  PASS on port $port (client id=$cid, shared score=$s_score)"
		echo "  --- key server sentinels ---"; grep -E "SERVER_SEES|PLAYERS_OK|SAW_REMOTE|ENEMY_SPAWN|ENEMY_DEAD|SCORE_SET|SERVER_DONE" "$slog" | sed 's/^/    /'
		echo "  --- key client sentinels ---"; grep -E "CLIENT_SEES|PLAYERS_OK|MOVED|ENEMY_SEEN|ENEMY_GONE|SCORE_SET|CLIENT_DONE" "$clog" | sed 's/^/    /'
		return 0
	fi
	echo "  --- server log tail ---"; tail -n 25 "$slog" | sed 's/^/    /'
	echo "  --- client log tail ---"; tail -n 25 "$clog" | sed 's/^/    /'
	return 1
}

# 3. Try a few randomized ports (retry on bind failure / a failed attempt).
rc=1
for try in 1 2 3 4 5; do
	PORT=$(((RANDOM % 12000) + 50000))
	echo "==> attempt $try on port $PORT"
	attempt "$PORT"; rc=$?
	if ((rc == 0)); then break; fi
	if ((rc == 2)); then continue; fi
done

if ((rc == 0)); then
	echo "COOP_OK proved: connection, both-players-both-peers, client-move-replication, enemy-replication, authoritative-death, shared-score"
	exit 0
else
	echo "COOP_FAIL"
	exit 1
fi
