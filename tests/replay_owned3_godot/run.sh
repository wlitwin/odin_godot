#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_owned3_godot"; work="$(mktemp -d)"; pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Owned 3D solver logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
bash "$ROOT/build/build_scripts.sh" "$PROJ"
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" OWN3_PORT=$((40000 + RANDOM % 12000))
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
for role in host client; do
  OWN3_ROLE="$role" "$GODOT" --headless --path "$PROJ" >"$work/$role.log" 2>&1 & pids+=("$!")
  sleep 0.3
done
deadline=$((SECONDS + 25))
while ((SECONDS < deadline)); do
  live=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
  if ((live == 0)); then break; fi
  sleep 0.05
done
cat "$work/host.log" "$work/client.log"
if ((SECONDS >= deadline)); then exit 1; fi
failed=0; for pid in "${pids[@]}"; do wait "$pid" || failed=1; done; pids=()
((failed == 0))
if rg -q 'OWNED3_PROBE_FAIL|SCRIPT ERROR|ERROR:|ObjectDB instances were leaked' "$work/"*.log; then exit 1; fi
rg -q OWNED3_PROBE_OK "$work/host.log"; rg -q OWNED3_PROBE_OK "$work/client.log"; rg -q OWNED3_PROBE_SEED "$work/client.log"
echo REPLAY_OWNED3_GODOT_OK
