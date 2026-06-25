#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# CO-OP NATIVE (ENet) test — two REAL headless Godot processes (host + client) running the
# unified co-op survivors (coop.tscn / NetGame) connect over ENet and prove the survivors
# co-op loop. Continuous state crosses via Godot's MultiplayerSynchronizer (player position,
# enemy position) and spawning via MultiplayerSpawner; @(gd_rpc) carries discrete events.
#
# Asserts (from each process's stdout):
#   1. connection            : server sees client; client sees server
#   2. both players both peers: PLAYERS_OK count=2 on BOTH (player spawn)
#   3. client move -> SYNC    : client MOVED + server SAW_REMOTE_MOVE (MultiplayerSynchronizer,
#                               client->host position replication)
#   4. enemy spawn -> SPAWNER : server ENEMY_SPAWN + client ENEMY_SEEN (MultiplayerSpawner)
#   5. enemy pos  -> SYNC     : client ENEMY_SYNC (host->client MultiplayerSynchronizer)
#   6. authoritative death    : server ENEMY_DEAD + client ENEMY_GONE
#   7. shared score           : SCORE_SET identical on both
#   8. level-up (progression) : client LEVELUP (XP from the shared kill -> level -> upgrade)
#
# Reliable: randomized port + bind-retry, wall-clock timeouts, clean teardown. Prints
# COOP_NATIVE_OK.   nix develop --command bash -c 'bash examples/survivors/coop_native_run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/survivors"
LOGDIR="$PROJ/.cooplogs"; mkdir -p "$LOGDIR"

bash "$ROOT/build/build_scripts.sh" "$PROJ" >/dev/null
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch() { COOP_ROLE="$1" COOP_PORT="$3" COOP_ADDR="127.0.0.1" "$GODOT" --headless --path "$PROJ" >"$2" 2>&1 & echo $!; }

attempt() {
	local port="$1" slog="$LOGDIR/server.log" clog="$LOGDIR/client.log"
	: >"$slog"; : >"$clog"
	local sp; sp=$(launch server "$slog" "$port")
	local i=0
	while ((i<60)); do
		grep -q "HOST_OK" "$slog" && break
		grep -q "HOST_FAIL" "$slog" && { kill "$sp" 2>/dev/null; wait "$sp" 2>/dev/null; echo "  port $port HOST_FAIL"; return 2; }
		kill -0 "$sp" 2>/dev/null || break; sleep 0.1; ((i++))
	done
	local cp; cp=$(launch client "$clog" "$port")
	local waited=0
	while ((waited<400)); do kill -0 "$sp" 2>/dev/null || kill -0 "$cp" 2>/dev/null || break; sleep 0.1; ((waited++)); done
	kill "$sp" "$cp" 2>/dev/null; wait "$sp" 2>/dev/null; wait "$cp" 2>/dev/null

	local ok=1 cid
	cid=$(grep -oE "REPORT my_id=[0-9]+" "$clog" | head -1 | grep -oE "[0-9]+$")
	[[ -z "$cid" || "$cid" == "0" ]] && { echo "  FAIL: client got no id"; ok=0; cid="?"; }

	grep -q "SERVER_SEES_CLIENT id=$cid" "$slog" || { echo "  FAIL[1]: server didn't see client"; ok=0; }
	grep -q "CLIENT_SEES_SERVER"          "$clog" || { echo "  FAIL[1]: client didn't see server"; ok=0; }
	grep -q "PLAYERS_OK on=1 count=2"      "$slog" || { echo "  FAIL[2]: server lacks 2 players"; ok=0; }
	grep -q "PLAYERS_OK on=$cid count=2"   "$clog" || { echo "  FAIL[2]: client lacks 2 players"; ok=0; }
	grep -q "MOVED on=$cid"                "$clog" || { echo "  FAIL[3]: client did not move"; ok=0; }
	grep -q "SAW_REMOTE_MOVE on=1 peer=$cid" "$slog" || { echo "  FAIL[3]: server didn't observe synced move"; ok=0; }
	grep -q "ENEMY_SPAWN on=1 id=9001"     "$slog" || { echo "  FAIL[4]: server didn't spawn enemy"; ok=0; }
	grep -q "ENEMY_SEEN on=$cid id=9001"   "$clog" || { echo "  FAIL[4]: client didn't see spawned enemy"; ok=0; }
	grep -q "ENEMY_SYNC on=$cid"           "$clog" || { echo "  FAIL[5]: client didn't see enemy position sync"; ok=0; }
	grep -q "ENEMY_DEAD on=1 id=9001"      "$slog" || { echo "  FAIL[6]: server didn't kill enemy"; ok=0; }
	grep -q "ENEMY_GONE on=$cid id=9001"   "$clog" || { echo "  FAIL[6]: client didn't see despawn"; ok=0; }
	grep -q "LEVELUP on=$cid"              "$clog" || { echo "  FAIL[8]: client did not level up"; ok=0; }
	local ss cs
	ss=$(grep -oE "SCORE_SET on=1 value=[0-9]+" "$slog" | head -1 | grep -oE "[0-9]+$")
	cs=$(grep -oE "SCORE_SET on=$cid value=[0-9]+" "$clog" | head -1 | grep -oE "[0-9]+$")
	if [[ -z "$ss" || -z "$cs" ]]; then echo "  FAIL[7]: missing SCORE_SET (s='$ss' c='$cs')"; ok=0
	elif [[ "$ss" != "$cs" ]]; then echo "  FAIL[7]: score mismatch s=$ss c=$cs"; ok=0; fi
	grep -q "SERVER_DONE" "$slog" || { echo "  FAIL: server unclean"; ok=0; }
	grep -q "CLIENT_DONE" "$clog" || { echo "  FAIL: client unclean"; ok=0; }

	if ((ok==1)); then
		echo "  PASS on port $port (client id=$cid, score=$ss)"
		echo "  --- server ---"; grep -E "SERVER_SEES|PLAYERS_OK|SAW_REMOTE|ENEMY_SPAWN|ENEMY_DEAD|SCORE_SET|SERVER_DONE" "$slog" | sed 's/^/    /'
		echo "  --- client ---"; grep -E "CLIENT_SEES|PLAYERS_OK|MOVED|ENEMY_SEEN|ENEMY_SYNC|ENEMY_GONE|LEVELUP|SCORE_SET|CLIENT_DONE" "$clog" | sed 's/^/    /'
		return 0
	fi
	echo "  --- server tail ---"; tail -n 25 "$slog" | sed 's/^/    /'
	echo "  --- client tail ---"; tail -n 25 "$clog" | sed 's/^/    /'
	return 1
}

rc=1
for try in 1 2 3 4 5; do
	PORT=$(((RANDOM % 12000) + 50000))
	echo "==> attempt $try port $PORT"
	attempt "$PORT"; rc=$?
	((rc==0)) && break
	((rc==2)) && continue
done
if ((rc==0)); then
	echo "COOP_NATIVE_OK proved: connection, both-players, synchronizer move-replication, spawner enemy, enemy-pos-sync, authoritative-death, shared-score, level-up"
	exit 0
else echo "COOP_NATIVE_FAIL"; exit 1; fi
