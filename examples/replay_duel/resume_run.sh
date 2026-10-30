#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_duel"
work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "P2P resume logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export RDP_TEST=1 RDP_LATENCY=120 RDP_JITTER=20 RDP_LOSS=1000 RDP_DUPLICATE=1000
for stage in save resume; do
  export RDP_STAGE="$stage" RDP_PORT=$((40000 + RANDOM % 12000))
  mkdir "$work/$stage"
  for role in listen dial; do
    RDP_ROLE="$role" RDP_ARCHIVE="$work/$role.rply" "$GODOT" --headless --path "$PROJ" >"$work/$stage/$role.log" 2>&1 & pids+=("$!")
    if [[ "$role" == listen ]]; then
      for _ in {1..100}; do if grep -q REPLAY_DUEL_LISTENING "$work/$stage/listen.log"; then break; fi; sleep 0.05; done
    fi
  done
  deadline=$((SECONDS + 40))
  while ((SECONDS < deadline)); do
    if grep -Eq 'REPLAY_DUEL_FAIL|SCRIPT ERROR|ERROR:' "$work/$stage/"*.log; then cat "$work/$stage/"*.log; exit 1; fi
    if [[ "$stage" == save ]]; then
      if grep -q RDP_SAVED "$work/save/listen.log" && grep -q RDP_SAVED "$work/save/dial.log"; then break; fi
    else
      live=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
      if ((live == 0)); then break; fi
    fi
    sleep 0.05
  done
  cat "$work/$stage/"*.log
  if ((SECONDS >= deadline)); then exit 1; fi
  if [[ "$stage" == save ]]; then
    for pid in "${pids[@]}"; do kill -KILL "$pid"; wait "$pid" 2>/dev/null || true; done
  else
    for pid in "${pids[@]}"; do wait "$pid"; done
    for role in listen dial; do grep -q RDP_RESTORED "$work/resume/$role.log"; done
    node "$PROJ/check.mjs" "$work/resume"
  fi
  pids=()
done
if grep -Eq 'ObjectDB instances were leaked' "$work/resume/"*.log; then exit 1; fi
echo REPLAY_DUEL_RESUME_OK
