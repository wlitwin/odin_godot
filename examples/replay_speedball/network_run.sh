#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_speedball"
work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Speedball logs: $work"; else rm -rf "$work"; fi; }
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
export RSB_PORT=$((40000 + RANDOM % 15000)) RSB_PLAYERS=2 RSB_GOALS=1 RSB_TEST=1 RSB_LATENCY=120
RSB_ROLE=server RSB_TOKEN=server-gate "$GODOT" --headless --path "$PROJ" >"$work/server.log" 2>&1 & pids+=("$!")
for _ in {1..100}; do if rg -q REPLAY_SPEEDBALL_READY "$work/server.log"; then break; fi; sleep 0.05; done
for role in striker spiker observer; do
  player_role=client; [[ "$role" == observer ]] && player_role=observer
  RSB_ROLE="$player_role" RSB_BOT="$role" RSB_TOKEN="$role" "$GODOT" --headless --path "$PROJ" >"$work/$role.log" 2>&1 & pids+=("$!")
  if [[ "$role" == striker ]]; then
    for _ in {1..150}; do if rg -q 'RSB_SEATED seat=1' "$work/striker.log"; then break; fi; sleep 0.05; done
  fi
done
deadline=$((SECONDS + 60))
while ((SECONDS < deadline)); do
  alive=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then alive=1; fi; done
  if ((alive == 0)); then break; fi
  sleep 0.1
done
cat "$work/server.log" "$work/striker.log" "$work/spiker.log" "$work/observer.log"
if ((SECONDS >= deadline)); then exit 1; fi
failed=0; for pid in "${pids[@]}"; do wait "$pid" || failed=1; done; pids=()
((failed == 0))
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_SPEEDBALL_FAIL|ObjectDB instances were leaked' "$work"/*.log; then exit 1; fi
node "$PROJ/check_network.mjs" "$work"
echo REPLAY_SPEEDBALL_NETWORK_OK
