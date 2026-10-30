#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_recovery_enet"
work="$(mktemp -d)"
pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; rm -rf "$work"; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export REPLAY_REPLICA_PORT=$((40000 + RANDOM % 20000)) REPLAY_REPLICA_KEY="fixture-$RANDOM-$RANDOM"
for role in host successor; do
  REPLAY_REPLICA_ROLE="$role" "$GODOT" --headless --path "$PROJ" >"$work/$role.log" 2>&1 &
  pids+=("$!")
  if [[ "$role" == host ]]; then
    for _ in {1..100}; do if grep -q REPLAY_REPLICA_HOST_READY "$work/host.log"; then break; fi; sleep 0.05; done
  fi
done
deadline=$((SECONDS + 35))
while ((SECONDS < deadline)); do
  live=0
  for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
  if ((live == 0)); then break; fi
  sleep 0.05
done
if ((SECONDS >= deadline)); then cat "$work"/*.log; exit 1; fi
result=0
for pid in "${pids[@]}"; do wait "$pid" || result=1; done
pids=()
cat "$work/host.log" "$work/successor.log"
((result == 0))
grep -q '^REPLAY_REPLICA_SENDER_OK' "$work/host.log"
grep -q '^REPLAY_REPLICA_SUCCESSOR_OK' "$work/successor.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_REPLICA_FAIL|ObjectDB instances were leaked' "$work"/*.log; then exit 1; fi
"${ODIN:-odin}" check "$PROJ/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
echo REPLAY_REPLICA_ENET_OK
