#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl"
work="$(mktemp -d)"
pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; rm -rf "$work"; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export REPLAY_CAVE_PORT=$((40000 + RANDOM % 20000)) REPLAY_CAVE_SAVE="$work/cave.replay"
export REPLAY_CAVE_LATENCY="${REPLAY_CAVE_LATENCY:-120}"
unset REPLAY_CAVE_TOKEN
start_pair() {
  local stage="$1" epoch="$2" resume="$3"
  for role in host client; do
    REPLAY_CAVE_ROLE="$role" REPLAY_CAVE_PROFILE="$work/$role.token" REPLAY_CAVE_RECOVERY_STAGE="$stage" REPLAY_CAVE_EPOCH="$epoch" REPLAY_CAVE_RESUME="$([[ "$role" == host ]] && echo "$resume" || echo 0)" \
      "$GODOT" --headless --path "$PROJ" --script recovery_test.gd >"$work/$stage-$role.log" 2>&1 &
    pids+=("$!")
    if [[ "$role" == host ]]; then
      for _ in {1..100}; do if grep -q REPLAY_CAVE_READY "$work/$stage-host.log"; then break; fi; sleep 0.05; done
    fi
  done
}
start_pair save 1 0
for _ in {1..250}; do
  if grep -q '^REPLAY_CAVE_RECOVERY_SAVED' "$work/save-host.log"; then break; fi
  if ! kill -0 "${pids[0]}" 2>/dev/null || ! kill -0 "${pids[1]}" 2>/dev/null; then cat "$work"/*.log; exit 1; fi
  sleep 0.1
done
if ! grep -q '^REPLAY_CAVE_RECOVERY_SAVED' "$work/save-host.log"; then cat "$work"/*.log; exit 1; fi
# Save/resume gate: both runtime processes are replaced. Discovery and seamless
# reconnect for a surviving guest belong to the later migration driver gate.
kill -KILL "${pids[0]}"
kill "${pids[1]}" 2>/dev/null || true
for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
pids=()
start_pair resume 2 1
deadline=$((SECONDS + 30))
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
cat "$work/save-host.log" "$work/save-client.log" "$work/resume-host.log" "$work/resume-client.log"
((result == 0))
grep -q '^REPLAY_CAVE_RECOVERY_HOST_OK' "$work/resume-host.log"
grep -q '^REPLAY_CAVE_RECOVERY_CLIENT_OK' "$work/resume-client.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_CAVE_FAIL|ObjectDB instances were leaked' "$work"/*.log; then exit 1; fi
echo REPLAY_CAVE_RECOVERY_OK
