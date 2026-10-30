#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_duel"
work="${RDP_WATCH_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
if [[ -e "$work/anchor.bin" || -e "$work/listen.log" ]];then echo "Fresh spectator failover output directory required: $work" >&2;exit 2;fi
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 || -n "${RDP_WATCH_OUT:-}" ]]; then echo "P2P spectator logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
export RDP_TEST=1 RDP_WATCH=1 RDP_UNTIL=900 RDP_PORT=$((40000 + RANDOM % 12000)) RDP_LATENCY=120 RDP_JITTER=20 RDP_LOSS=1000 RDP_DUPLICATE=1000
export RDP_WATCH_BLACKOUT_MS=0 RDP_WATCH_FAILOVER=1 RDP_WATCH_CONTROL="$work/anchor.bin"
RDP_ROLE=listen "$GODOT" --headless --path "$PROJ" >"$work/listen.log" 2>&1 & pids+=("$!")
for _ in {1..100}; do if rg -q REPLAY_DUEL_LISTENING "$work/listen.log"; then break; fi; sleep 0.05; done
RDP_ROLE=dial "$GODOT" --headless --path "$PROJ" >"$work/dial.log" 2>&1 & pids+=("$!")
for _ in {1..250}; do
  if rg -q RDP_WATCH_JOIN_READY "$work/listen.log"; then break; fi
  if rg -q 'REPLAY_DUEL_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
  sleep 0.05
done
if ! rg -q RDP_WATCH_JOIN_READY "$work/listen.log"; then cat "$work/"*.log; exit 1; fi
RDP_ROLE=watch "$GODOT" --headless --path "$PROJ" >"$work/watch.log" 2>&1 & pids+=("$!")
deadline=$((SECONDS + 55))
while ((SECONDS < deadline)); do
  live=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
  if ((live == 0)); then break; fi
  if rg -q 'REPLAY_DUEL_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
  sleep 0.05
done
cat "$work/listen.log" "$work/dial.log" "$work/watch.log"
if ((SECONDS >= deadline)); then exit 1; fi
failed=0; for pid in "${pids[@]}"; do wait "$pid" || failed=1; done; pids=()
((failed == 0))
if rg -q 'ObjectDB instances were leaked' "$work/"*.log; then exit 1; fi
node "$PROJ/check.mjs" "$work" "$RDP_UNTIL"
node "$PROJ/watch_check.mjs" "$work" "$RDP_WATCH_BLACKOUT_MS"
node "$PROJ/watch_failover_check.mjs" "$work"
echo REPLAY_DUEL_SPECTATOR_FAILOVER_OK
