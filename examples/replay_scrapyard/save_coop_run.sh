#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"; work="$(mktemp -d)"; pids=()
cleanup() {
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done
  if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Scrapyard co-op save logs: $work"; else rm -rf "$work"; fi
}
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export RSY_SAVE="$work/run.replay" RSY_RESULT_DIR="$work" RSY_RUN=0 RSY_ENCOUNTER=migration RSY_LATENCY=120 RSY_PERSIST=0
export RSY_PORT=$((40000 + RANDOM % 10000))
for phase in save resume; do
  export RSY_EPOCH=1
  if [[ "$phase" == resume ]]; then export RSY_EPOCH=2; fi
  for role in host client observer; do
    restore=0; if [[ "$phase" == resume && "$role" == host ]]; then restore=1; fi
    RSY_ROLE="$role" RSY_TOKEN="save-coop-$role" RSY_RESUME="$restore" RSY_SAVE_PHASE="$phase" \
      "$GODOT" --headless --path "$PROJ" --script save_coop_test.gd >"$work/$phase-$role.log" 2>&1 &
    pids+=("$!")
    sleep 0.5
  done
  deadline=$((SECONDS + 60))
  while ((SECONDS < deadline)); do
    if rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR' "$work/$phase-"*.log; then cat "$work/$phase-"*.log; exit 1; fi
    if [[ "$phase" == save ]] && rg -q '^RSY_COOP_SAVE_READY' "$work/save-host.log"; then break; fi
    if [[ "$phase" == resume ]] && rg -q '^REPLAY_SCRAPYARD_COMBAT_PEER_OK' "$work/resume-host.log"; then break; fi
    sleep 0.05
  done
  cat "$work/$phase-"*.log
  if [[ "$phase" == save ]]; then
    rg -q '^RSY_COOP_SAVE_READY' "$work/save-host.log"
    for pid in "${pids[@]}"; do kill -KILL "$pid"; wait "$pid" 2>/dev/null || true; done
  else
    for pid in "${pids[@]}"; do wait "$pid"; done
    for role in host client observer; do rg -q '^REPLAY_SCRAPYARD_COMBAT_PEER_OK' "$work/resume-$role.log"; done
  fi
  pids=()
  if rg -q 'SCRIPT ERROR|ERROR:|ObjectDB instances were leaked' "$work/$phase-"*.log; then exit 1; fi
done
echo REPLAY_SCRAPYARD_COOP_SAVE_OK
