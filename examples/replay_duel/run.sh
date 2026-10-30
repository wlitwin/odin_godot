#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_duel"
work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "P2P duel logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export RDP_TEST=1 RDP_PORT=$((40000 + RANDOM % 12000)) RDP_LATENCY=120 RDP_JITTER=20 RDP_LOSS=1000 RDP_DUPLICATE=1000
RDP_ROLE=listen "$GODOT" --headless --path "$PROJ" >"$work/listen.log" 2>&1 & pids+=("$!")
for _ in {1..100}; do if grep -q REPLAY_DUEL_LISTENING "$work/listen.log"; then break; fi; sleep 0.05; done
RDP_ROLE=dial "$GODOT" --headless --path "$PROJ" >"$work/dial.log" 2>&1 & pids+=("$!")
deadline=$((SECONDS + 40))
while ((SECONDS < deadline)); do
  alive=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then alive=1; fi; done
  if ((alive == 0)); then break; fi
  sleep 0.1
done
cat "$work/listen.log" "$work/dial.log"
if ((SECONDS >= deadline)); then exit 1; fi
failed=0; for pid in "${pids[@]}"; do wait "$pid" || failed=1; done; pids=()
((failed == 0))
if grep -Eq 'REPLAY_DUEL_FAIL|SCRIPT ERROR|ERROR:|ObjectDB instances were leaked' "$work/"*.log; then exit 1; fi
node "$PROJ/check.mjs" "$work"
echo REPLAY_DUEL_P2P_OK
