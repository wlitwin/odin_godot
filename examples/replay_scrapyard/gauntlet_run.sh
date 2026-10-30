#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
export RSY_RUN=1 RSY_WAVE_BASE=4 RSY_WAVE_GROWTH=0 RSY_WAVES=3 RSY_REST=300 RSY_BARRELS=0 RSY_DEV=1
PROJ="$ROOT/examples/replay_scrapyard"; work="$(mktemp -d)"; pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done
  if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Scrapyard gauntlet logs: $work"; else rm -rf "$work"; fi
}
trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
bash "$ROOT/build/build_scripts.sh" "$PROJ"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ"
fi
export RSY_REQUIRE_STOCK=1 RSY_SEED=1337 RSY_PORT=$((40000 + RANDOM % 12000)) RSY_LATENCY="${RSY_LATENCY:-120}" RSY_RESULT_DIR="$work"
for role in host client observer; do
  RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="gauntlet-$role" "$GODOT" --headless --path "$PROJ" --script gauntlet_test.gd >"$work/$role.log" 2>&1 & pids+=("$!")
  sleep 0.3
done
deadline=$((SECONDS + 180))
while ((SECONDS < deadline)); do
  live=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
  if ((live == 0)); then break; fi
  if rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
  sleep 0.05
done
cat "$work/host.log" "$work/client.log" "$work/observer.log"
if ((SECONDS >= deadline)); then exit 1; fi
for pid in "${pids[@]}"; do wait "$pid"; done; pids=()
for role in host client observer; do rg -q REPLAY_SCRAPYARD_COMBAT_PEER_OK "$work/$role.log"; rg -q 'waves=3 rests=3 spawned=13 clears=1' "$work/$role.log"; rg -q 'RSY_GAUNTLET_CHAIN.*booms=2 pulls=1' "$work/$role.log"; done
rg -q RSY_GAUNTLET_DEV_DENIED "$work/client.log"
if rg -q 'ObjectDB instances were leaked' "$work/"*.log; then exit 1; fi
echo REPLAY_SCRAPYARD_GAUNTLET_OK
