#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_slopball3d"
work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Replay Slopball3D network logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
export RS3_TEST=1 RS3_PLAYERS=2 RS3_GOALS=1 RS3_PROBE_TICK=600 RS3_PORT=$((40000 + RANDOM % 12000))
export RS3_LATENCY="${RS3_LATENCY:-120}" RS3_JITTER="${RS3_JITTER:-0}" RS3_LOSS="${RS3_LOSS:-0}" RS3_DUPLICATE="${RS3_DUPLICATE:-0}"
for role in host client observer; do
  bot=idle; if [[ "$role" == client ]]; then bot=striker; fi
  RS3_ROLE="$role" RS3_BOT="$bot" RS3_TOKEN="slop-$role" "$GODOT" --headless --path "$PROJ" >"$work/$role.log" 2>&1 & pids+=("$!")
  sleep 0.3
done
deadline=$((SECONDS + 50))
while ((SECONDS < deadline)); do
  live=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
  if ((live == 0)); then break; fi
  if rg -q 'REPLAY_SLOPBALL3D_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
  sleep 0.05
done
cat "$work/host.log" "$work/client.log" "$work/observer.log"
if ((SECONDS >= deadline)); then exit 1; fi
failed=0; for pid in "${pids[@]}"; do wait "$pid" || failed=1; done; pids=()
((failed == 0))
if rg -q 'ObjectDB instances were leaked' "$work/"*.log; then exit 1; fi
node "$PROJ/check.mjs" "$work"
echo REPLAY_SLOPBALL3D_NETWORK_OK
