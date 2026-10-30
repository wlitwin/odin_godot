#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"; work="${REPLAY_CHAT_OUT:-$(mktemp -d)}"; mkdir -p "$work"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; echo "Chat logs: $work"; }
trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
  bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
  "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
  if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
  python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
  bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
fi
export RSY_RUN=0 RSY_MOBS=0 RSY_PERSIST=0 RSY_SEED=1337 RSY_RESULT_DIR="$work" RSY_PORT=$((40000 + RANDOM % 10000)) RSY_LATENCY=120
script=chat_test.gd
if [[ "${RSY_PING_TEST:-0}" == 1 ]]; then script=pings_test.gd; fi
for role in host client observer; do
  if [[ "$role" == observer ]]; then
    for _ in {1..500}; do [[ -f "$work/allow-observer.json" ]] && break; sleep 0.05; done
    if [[ ! -f "$work/allow-observer.json" ]]; then cat "$work/"*.log; exit 1; fi
  fi
  args=(--headless); capture=""
  if [[ "$role" == client && "${RSY_HEADED_CLIENT:-0}" == 1 ]]; then args=(); capture="${RSY_SCREENSHOT:-}"; fi
  if [[ -n "${RSY_AUDIO_DRIVER:-}" ]]; then args+=(--audio-driver "$RSY_AUDIO_DRIVER"); fi
  RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="chat-$role" RSY_SCREENSHOT="$capture" "$GODOT" "${args[@]}" --max-fps 60 --path "$PROJ" --script "$script" >"$work/$role.log" 2>&1 & pids+=("$!")
  sleep 0.3
done
for pid in "${pids[@]}"; do wait "$pid"; done; pids=()
cat "$work/host.log" "$work/client.log" "$work/observer.log"
if rg -q 'SCRIPT ERROR|ERROR:|COMBAT_FAIL|instances were leaked|resources still in use' "$work/"*.log; then exit 1; fi
node "$PROJ/chat_check.mjs" "$work"
if [[ "${RSY_PING_TEST:-0}" == 1 ]]; then
  for role in host client observer; do rg -q RSY_PINGS_OK "$work/$role.log"; done
  echo REPLAY_SCRAPYARD_PINGS_OK
fi
echo REPLAY_SCRAPYARD_CHAT_OK
