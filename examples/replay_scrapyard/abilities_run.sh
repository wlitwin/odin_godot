#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
export RSY_RUN=0
PROJ="$ROOT/examples/replay_scrapyard"; work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Replay Scrapyard logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export RSY_MOBS=2 RSY_REQUIRE_STOCK=1 RSY_ENCOUNTER=abilities
export RSY_SEED=1337 RSY_PORT=$((40000 + RANDOM % 12000)) RSY_LATENCY="${RSY_LATENCY:-120}"
export RSY_RESULT_DIR="$work"
launch() {
  local label="$1" mode="$2"
  local display_args=(--headless) screenshot=""
  if [[ "$label" == host && "${RSY_HEADED_HOST:-0}" == 1 ]]; then display_args=(); screenshot="${RSY_SCREENSHOT:-}"; fi
  RSY_SCREENSHOT="$screenshot" RSY_ROLE="$mode" RSY_NAME="$label" RSY_TOKEN="rsy-$label" "$GODOT" "${display_args[@]}" --path "$PROJ" --script abilities_test.gd >"$work/$label.log" 2>&1 & pids+=("$!")
}
launch host host
sleep 0.3
launch client client
# Preserve seat order before the support connection joins.
for _ in {1..200}; do if rg -q 'REPLAY_SCRAPYARD_READY' "$work/client.log"; then break; fi; sleep 0.02; done
sleep 0.6
launch support client
for _ in {1..1200}; do
  if [[ -f "$work/zone-open.json" ]]; then break; fi
  if rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
  sleep 0.02
done
[[ -f "$work/zone-open.json" ]] || { cat "$work/"*.log; exit 1; }
launch observer observer
deadline=$((SECONDS + 90))
while ((SECONDS < deadline)); do
  live=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
  if ((live == 0)); then break; fi
  if rg -q 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log; then cat "$work/"*.log; exit 1; fi
  sleep 0.05
done
cat "$work/host.log" "$work/client.log" "$work/support.log" "$work/observer.log"
if ((SECONDS >= deadline)); then exit 1; fi
failed=0; for pid in "${pids[@]}"; do wait "$pid" || failed=1; done; pids=()
((failed == 0))
if rg -q 'ObjectDB instances were leaked' "$work/"*.log; then exit 1; fi
node "$PROJ/abilities_check.mjs" "$work"
echo REPLAY_SCRAPYARD_ABILITIES_OK
