#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_claimball"
work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Claimball logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export RCB_PORT=$((40000 + RANDOM % 15000)) RCB_PLAYERS=2 RCB_GOALS="${RCB_TEST_GOALS:-1}" RCB_TEST=1 RCB_LATENCY=120
RCB_ROLE=server "$GODOT" --headless --path "$PROJ" >"$work/server.log" 2>&1 & pids+=("$!")
for _ in {1..100}; do if grep -q REPLAY_CLAIMBALL_READY "$work/server.log"; then break; fi; sleep 0.05; done
opponent=idle
if [[ "${RCB_CONTEST:-0}" == 1 ]]; then opponent=challenger; fi
for role in striker "$opponent" observer; do
  player_role=client; [[ "$role" == observer ]] && player_role=observer
  bot="$role"; [[ "$role" == challenger ]] && bot=striker
  RCB_ROLE="$player_role" RCB_BOT="$bot" RCB_TOKEN="$role" "$GODOT" --headless --path "$PROJ" >"$work/$role.log" 2>&1 & pids+=("$!")
  if [[ "$role" == striker ]]; then
    for _ in {1..150}; do if grep -q 'RCB_SEATED seat=1' "$work/striker.log"; then break; fi; sleep 0.05; done
  fi
done
deadline=$((SECONDS + 60))
while ((SECONDS < deadline)); do
  alive=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then alive=1; fi; done
  if ((alive == 0)); then break; fi
  sleep 0.1
done
cat "$work/server.log" "$work/striker.log" "$work/$opponent.log" "$work/observer.log"
if ((SECONDS >= deadline)); then exit 1; fi
failed=0; for pid in "${pids[@]}"; do wait "$pid" || failed=1; done; pids=()
((failed == 0))
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_CLAIMBALL_FAIL|ObjectDB instances were leaked' "$work"/*.log; then exit 1; fi
if [[ "${RCB_CONTEST:-0}" == 1 ]]; then
  node "$PROJ/check_compete.mjs" "$work"
  echo REPLAY_CLAIMBALL_COMPETE_OK
else
  node "$PROJ/check_network.mjs" "$work"
  echo REPLAY_CLAIMBALL_NETWORK_OK
fi
