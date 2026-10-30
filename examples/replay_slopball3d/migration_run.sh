#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_slopball3d"
COORD="$ROOT/tests/replay_migration"
work="$(mktemp -d)"
pids=()
cleanup() {
  for pid in "${pids[@]}"; do [[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }; done
  if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Slopball3D migration logs: $work"; else rm -rf "$work"; fi
}
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; bash "$ROOT/build/build_scripts.sh" "$COORD"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
for project in "$PROJ" "$COORD"; do
  if ! ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
  if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
done
export REPLAY_MIGRATION_GAME=slopball3d
modes=(planned crash)
if [[ "${REPLAY_MIGRATION_PHASE:-}" == crash ]]; then modes=(crash); fi
for mode in "${modes[@]}"; do
  mkdir "$work/$mode"
  export REPLAY_MIGRATION_MODE="$mode" REPLAY_MIGRATION_DIR="$work/$mode" REPLAY_MIGRATION_DB="$work/$mode/room.sqlite3"
  export REPLAY_MIGRATION_PORT=$((40000 + RANDOM % 10000))
  ODIN_SCRIPTS_DLL="$COORD/bin/libodinscripts.$ext" "$GODOT" --headless --path "$COORD" >"$work/$mode/coordinator.log" 2>&1 &
  pids+=("$!")
  for _ in {1..100}; do if grep -q REPLAY_MIGRATION_COORDINATOR_READY "$work/$mode/coordinator.log"; then break; fi; sleep 0.05; done
  for member in 1 2 3; do
    key="$(printf '%02x%062d' "$((member + 20))" 0)"
    ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" RS3_MEMBER="$member" RS3_INCARNATION="$((100 + member))" \
      RS3_COORD_KEY="$key" RS3_COORD_PORT="$REPLAY_MIGRATION_PORT" RS3_TOKEN="migration-$member" RS3_PLAYERS=3 RS3_GOALS=3 RS3_LATENCY=120 \
      "$GODOT" --headless --path "$PROJ" --script migration_test.gd >"$work/$mode/member-$member.log" 2>&1 &
    pids+=("$!")
    sleep 0.5
  done
  killed=0
  deadline=$((SECONDS + 55))
  while ((SECONDS < deadline)); do
    if [[ "$mode" == crash && "$killed" == 0 && -f "$work/$mode/kill_owner" ]]; then
      kill -KILL "${pids[1]}"; wait "${pids[1]}" 2>/dev/null || true; pids[1]=""; killed=1
    fi
    if grep -Eq 'RS3_MIGRATION_FAIL|REPLAY_SLOPBALL3D_FAIL|SCRIPT ERROR|REPLAY_MIGRATION_FAIL' "$work/$mode/"*.log; then cat "$work/$mode/"*.log; exit 1; fi
    if grep -q RS3_MIGRATION_AUTHORITY_OK "$work/$mode/member-2.log"; then break; fi
    sleep 0.05
  done
  cat "$work/$mode/"*.log
  grep -q 'RS3_PHYSICS_RESTORED exact=true moving=true' "$work/$mode/member-2.log"
  grep -q 'RS3_RECOVERY_SEED epoch=2 exact=true' "$work/$mode/member-2.log"
  grep -q RS3_MIGRATION_AUTHORITY_OK "$work/$mode/member-2.log"
  grep -q RS3_MIGRATION_CLIENT_OK "$work/$mode/member-3.log"
  if [[ "$mode" == planned ]]; then grep -q RS3_MIGRATION_CLIENT_OK "$work/$mode/member-1.log"; else ((killed == 1)); fi
  for pid in "${pids[@]:1}"; do [[ -z "$pid" ]] || wait "$pid"; done
  if grep -Eq 'SCRIPT ERROR|ERROR:|ObjectDB instances were leaked' "$work/$mode/"*.log; then exit 1; fi
  kill "${pids[0]}"; wait "${pids[0]}" 2>/dev/null || true; pids=()
  echo "REPLAY_SLOPBALL3D_MIGRATION_PHASE_OK $mode"
done
if [[ "${REPLAY_MIGRATION_PHASE:-}" == crash ]]; then echo REPLAY_SLOPBALL3D_CRASH_OK; else echo REPLAY_SLOPBALL3D_MIGRATION_OK; fi
