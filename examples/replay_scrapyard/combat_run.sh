#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
export RSY_RUN=0
PROJ="$ROOT/examples/replay_scrapyard"; work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Replay Scrapyard logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
bash "$ROOT/build/build_scripts.sh" "$PROJ"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ"
fi
export RSY_MOBS=4 RSY_REQUIRE_STOCK=1
if [[ "${RSY_ENCOUNTER:-}" == boss ]]; then export RSY_MOBS=1 RSY_BOSS_HP=36; fi
if [[ "${RSY_ENCOUNTER:-}" == barrels ]]; then export RSY_MOBS=3; fi
if [[ "${RSY_ARMORY:-}" == mend ]]; then export RSY_MOBS=1; fi
export RSY_SEED=1337 RSY_PORT=$((40000 + RANDOM % 12000)) RSY_LATENCY="${RSY_LATENCY:-120}"
export RSY_RESULT_DIR="$work"
for role in host client observer; do
  display_args=(--headless); screenshot=""
  if [[ "$role" == host && "${RSY_HEADED_HOST:-0}" == 1 ]]; then display_args=(); screenshot="${RSY_SCREENSHOT:-}"; fi
  RSY_SCREENSHOT="$screenshot" RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="rsy-$role" "$GODOT" "${display_args[@]}" --path "$PROJ" --script combat_test.gd >"$work/$role.log" 2>&1 & pids+=("$!")
  sleep 0.3
done
deadline=$((SECONDS + 60))
while ((SECONDS < deadline)); do
  live=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
  if ((live == 0)); then break; fi
  if rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
  sleep 0.05
done
cat "$work/host.log" "$work/client.log" "$work/observer.log"
if ((SECONDS >= deadline)); then exit 1; fi
failed=0; for pid in "${pids[@]}"; do wait "$pid" || failed=1; done; pids=()
((failed == 0))
if rg -q 'ObjectDB instances were leaked' "$work/"*.log; then exit 1; fi
node "$PROJ/combat_check.mjs" "$work"
echo REPLAY_SCRAPYARD_COMBAT_OK
