#!/usr/bin/env bash
# De-risking spike: MultiplayerSpawner + MultiplayerSynchronizer with Odin scripts over ENet.
# Host spawns an Odin-scripted scene (mob.tscn) via the spawner; the client must SEE it appear
# (spawner replication) and observe its synced position + Odin @export hp (synchronizer).
set -uo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJ="$ROOT/tests/repl_spike"
LOGDIR="$PROJ/.runlogs"; mkdir -p "$LOGDIR"

bash "$ROOT/build/build_scripts.sh" "$PROJ"
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.dylib"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true

launch() { ROLE="$1" PORT="$3" "$GODOT" --headless --path "$PROJ" >"$2" 2>&1 & echo $!; }

attempt() {
	local port="$1" slog="$LOGDIR/server.log" clog="$LOGDIR/client.log"
	: >"$slog"; : >"$clog"
	local sp; sp=$(launch server "$slog" "$port")
	local i=0
	while ((i<60)); do grep -q "HOST_OK" "$slog" && break; grep -q "HOST_FAIL" "$slog" && { kill "$sp" 2>/dev/null; return 2; }; kill -0 "$sp" 2>/dev/null || break; sleep 0.1; ((i++)); done
	local cp; cp=$(launch client "$clog" "$port")
	local waited=0
	while ((waited<300)); do kill -0 "$sp" 2>/dev/null || kill -0 "$cp" 2>/dev/null || break; sleep 0.1; ((waited++)); done
	kill "$sp" "$cp" 2>/dev/null; wait "$sp" 2>/dev/null; wait "$cp" 2>/dev/null
	echo "--- server ---"; cat "$slog"; echo "--- client ---"; cat "$clog"
	if grep -q "SPIKE_HOST_SPAWNED" "$slog" && grep -q "SPIKE_SYNC_OK" "$clog"; then return 0; fi
	return 1
}

rc=1
for try in 1 2 3; do
	PORT=$(((RANDOM % 12000) + 50000))
	echo "==> attempt $try port $PORT"
	attempt "$PORT"; rc=$?
	((rc==0)) && break
	((rc==2)) && continue
done
((rc==0)) && { echo "SPIKE_OK"; exit 0; } || { echo "SPIKE_FAIL"; exit 1; }
