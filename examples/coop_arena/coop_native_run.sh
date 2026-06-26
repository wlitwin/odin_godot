#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# CO-OP NATIVE (ENet) — two REAL headless Godot processes (host + client) run the unified,
# PEER-AUTHORITATIVE co-op arena (arena.tscn / ArenaGame) over ENet and prove the owner-auth
# netcode. Continuous state crosses via MultiplayerSynchronizer (each owner's pawn position,
# the host's enemy position) and spawning via MultiplayerSpawner; @(gd_rpc) carries the
# owner-broadcast events (fire + peer-authoritative damage).
#
# Asserts (from each process's stdout):
#   1. connection             : server sees client; client sees server
#   2. both pawns both peers   : PLAYERS_OK count=2 on BOTH (owner-auth pawn spawn)
#   3. owner-auth move replic  : client MOVED (writes its OWN pawn locally) + server SAW_REMOTE_MOVE
#   4. enemy spawn (spawner)    : server ENEMY_SPAWN + client ENEMY_SEEN
#   5. enemy pos sync (sync)    : client ENEMY_SYNC
#   6. OWNER-LOCAL IMMEDIACY    : the FIRER (client) has BULLET_LOCAL (its bullet exists the
#                                 same tick it fired — NO host round-trip) AND the host sees the
#                                 shot replicated as BULLET_REMOTE (broadcast, local-first)
#   7. owner-auth kill agreed   : BOTH peers log ENEMY_KILLED id=9001 killer=<client> (the firer
#                                 resolved + broadcast the kill; both trust + agree)
#   8. despawn replicated       : client ENEMY_GONE (host freed the node -> spawner despawned it)
#   9. XP to the firer          : client LEVELUP (the kill credited the firer, not the host)
#
# Reliable: randomized port + bind-retry, wall-clock timeouts, clean teardown. Prints
# ARENA_NATIVE_OK.   nix develop --command bash -c 'bash examples/coop_arena/coop_native_run.sh'
# ----------------------------------------------------------------------------
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/examples/coop_arena"
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

	grep -q "SERVER_SEES_CLIENT id=$cid"     "$slog" || { echo "  FAIL[1]: server didn't see client"; ok=0; }
	grep -q "CLIENT_SEES_SERVER"             "$clog" || { echo "  FAIL[1]: client didn't see server"; ok=0; }
	grep -q "PLAYERS_OK on=1 count=2"        "$slog" || { echo "  FAIL[2]: server lacks 2 pawns"; ok=0; }
	grep -q "PLAYERS_OK on=$cid count=2"     "$clog" || { echo "  FAIL[2]: client lacks 2 pawns"; ok=0; }
	grep -q "MOVED on=$cid"                  "$clog" || { echo "  FAIL[3]: client did not move"; ok=0; }
	grep -q "SAW_REMOTE_MOVE on=1 peer=$cid" "$slog" || { echo "  FAIL[3]: server didn't see synced move"; ok=0; }
	grep -q "ENEMY_SPAWN on=1 id=9001"       "$slog" || { echo "  FAIL[4]: server didn't spawn enemy"; ok=0; }
	grep -q "ENEMY_SEEN on=$cid id=9001"     "$clog" || { echo "  FAIL[4]: client didn't see spawned enemy"; ok=0; }
	grep -q "ENEMY_SYNC on=$cid id=9001"     "$clog" || { echo "  FAIL[5]: client didn't see enemy pos sync"; ok=0; }
	# OWNER-LOCAL IMMEDIACY: the firer (client) spawned its bullet locally; the host saw it replicated.
	grep -q "BULLET_LOCAL on=$cid shooter=$cid"  "$clog" || { echo "  FAIL[6]: firer lacks local bullet (no local-first!)"; ok=0; }
	grep -q "BULLET_REMOTE on=1 shooter=$cid"    "$slog" || { echo "  FAIL[6]: host didn't see the broadcast shot"; ok=0; }
	# OWNER-AUTH kill agreed by BOTH peers, credited to the firer.
	grep -q "ENEMY_KILLED on=$cid id=9001 killer=$cid" "$clog" || { echo "  FAIL[7]: firer didn't resolve the kill"; ok=0; }
	grep -q "ENEMY_KILLED on=1 id=9001 killer=$cid"    "$slog" || { echo "  FAIL[7]: host didn't agree on the kill"; ok=0; }
	grep -q "ENEMY_GONE on=$cid id=9001"     "$clog" || { echo "  FAIL[8]: client didn't see despawn"; ok=0; }
	grep -q "LEVELUP on=$cid"                "$clog" || { echo "  FAIL[9]: firer did not get XP/level"; ok=0; }
	grep -q "SERVER_DONE" "$slog" || { echo "  FAIL: server unclean"; ok=0; }
	grep -q "CLIENT_DONE" "$clog" || { echo "  FAIL: client unclean"; ok=0; }

	if ((ok==1)); then
		echo "  PASS on port $port (client id=$cid)"
		echo "  --- server ---"; grep -E "SERVER_SEES|PLAYERS_OK|SAW_REMOTE|ENEMY_SPAWN|BULLET_REMOTE|ENEMY_KILLED|SERVER_DONE" "$slog" | sed 's/^/    /'
		echo "  --- client ---"; grep -E "CLIENT_SEES|PLAYERS_OK|MOVED|ENEMY_SEEN|ENEMY_SYNC|BULLET_LOCAL|ENEMY_KILLED|ENEMY_GONE|LEVELUP|CLIENT_DONE" "$clog" | sed 's/^/    /'
		return 0
	fi
	echo "  --- server tail ---"; tail -n 30 "$slog" | sed 's/^/    /'
	echo "  --- client tail ---"; tail -n 30 "$clog" | sed 's/^/    /'
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
	echo "ARENA_NATIVE_OK proved: connection, both owner-auth pawns, local-first move replication, spawner enemy, enemy-pos-sync, OWNER-LOCAL bullet immediacy + broadcast, peer-authoritative kill agreed by both, despawn replication, XP to the firer"
	exit 0
else echo "ARENA_NATIVE_FAIL"; exit 1; fi
