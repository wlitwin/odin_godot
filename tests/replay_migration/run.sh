#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl"
COORD="$ROOT/tests/replay_migration"
work="$(mktemp -d)"
pids=()
cleanup() { for pid in "${pids[@]}"; do [[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Migration logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; bash "$ROOT/build/build_scripts.sh" "$COORD"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
for project in "$PROJ" "$COORD"; do
  if ! ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
  if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
done
export REPLAY_MIGRATION_PORT=$((40000 + RANDOM % 10000)) REPLAY_MIGRATION_DB="$work/room.sqlite3" REPLAY_MIGRATION_DIR="$work"
export REPLAY_MIGRATION_MODE="${REPLAY_MIGRATION_MODE:-planned}"
ODIN_SCRIPTS_DLL="$COORD/bin/libodinscripts.$ext" "$GODOT" --headless --path "$COORD" >"$work/coordinator.log" 2>&1 &
pids+=("$!")
for _ in {1..100}; do if grep -q REPLAY_MIGRATION_COORDINATOR_READY "$work/coordinator.log"; then break; fi; sleep 0.05; done
for member in 1 2 3; do
  name="";if [[ "${REPLAY_MIGRATION_SCRIPT:-}" == lobby*_migration*.gd ]];then name="Party $member";fi
  key="$(printf '%02x%062d' "$((member + 20))" 0)"
  ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" REPLAY_CAVE_NAME="$name" REPLAY_CAVE_MEMBER="$member" REPLAY_CAVE_INCARNATION="$((100 + member))" \
    REPLAY_CAVE_COORD_KEY="$key" REPLAY_CAVE_COORD_PORT="$REPLAY_MIGRATION_PORT" REPLAY_CAVE_TOKEN="migration-$member" REPLAY_CAVE_LATENCY=120 \
    "$GODOT" --headless --path "$PROJ" --script "${REPLAY_MIGRATION_SCRIPT:-migration_test.gd}" >"$work/member-$member.log" 2>&1 &
  pids+=("$!")
  sleep 0.5
done
deadline=$((SECONDS + 45))
owner_killed=0
returned_started=0
successor_killed=0
while ((SECONDS < deadline)); do
  if [[ ( "$REPLAY_MIGRATION_MODE" == crash || "$REPLAY_MIGRATION_MODE" == return ) && -f "$work/kill_owner" && "$owner_killed" == 0 ]]; then
    kill -KILL "${pids[1]}"; wait "${pids[1]}" 2>/dev/null || true; pids[1]=""; owner_killed=1
  fi
  if [[ "$REPLAY_MIGRATION_MODE" == successor_loss && -f "$work/kill_successor" && "$successor_killed" == 0 ]]; then
    kill -KILL "${pids[2]}"; wait "${pids[2]}" 2>/dev/null || true; pids[2]=""; successor_killed=1
  fi
  if [[ "$REPLAY_MIGRATION_MODE" == return && -f "$work/guest_after_migration" && "$returned_started" == 0 ]]; then
    key="$(printf '%02x%062d' 21 0)"
    ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" REPLAY_CAVE_MEMBER=1 REPLAY_CAVE_INCARNATION=101 REPLAY_MIGRATION_RETURNED=1 \
      REPLAY_CAVE_COORD_KEY="$key" REPLAY_CAVE_COORD_PORT="$REPLAY_MIGRATION_PORT" REPLAY_CAVE_TOKEN=migration-1 REPLAY_CAVE_LATENCY=120 \
      "$GODOT" --headless --path "$PROJ" --script "${REPLAY_MIGRATION_SCRIPT:-migration_test.gd}" >"$work/returned.log" 2>&1 &
    pids[1]="$!"; returned_started=1
  fi
  if grep -Eq 'REPLAY_MIGRATION_FAIL|REPLAY_CAVE_FAIL|SCRIPT ERROR' "$work"/*.log; then cat "$work"/*.log; exit 1; fi
  check_member=2; if [[ "$REPLAY_MIGRATION_MODE" == successor_loss ]]; then check_member=1; fi
  if grep -q REPLAY_MIGRATION_GUEST_OK "$work/member-3.log" && grep -q REPLAY_MIGRATION_MEMBER_OK "$work/member-$check_member.log"; then break; fi
  sleep 0.05
done
cat "$work/coordinator.log" "$work/member-1.log" "$work/member-2.log" "$work/member-3.log"
if [[ -f "$work/returned.log" ]]; then cat "$work/returned.log"; grep -q REPLAY_MIGRATION_RETURNED_OK "$work/returned.log"; fi
grep -q REPLAY_MIGRATION_GUEST_OK "$work/member-3.log"
grep -q REPLAY_MIGRATION_MEMBER_OK "$work/member-$check_member.log"
for pid in "${pids[@]:1}"; do [[ -z "$pid" ]] || wait "$pid"; done
pids=("${pids[0]}")
if grep -Eq 'SCRIPT ERROR|ERROR:|ObjectDB instances were leaked' "$work"/*.log; then exit 1; fi
echo "REPLAY_MIGRATION_OK $REPLAY_MIGRATION_MODE"
case "$REPLAY_MIGRATION_MODE" in
  planned) echo REPLAY_MIGRATION_PLANNED_OK ;;
  crash) echo REPLAY_MIGRATION_CRASH_OK ;;
  return) echo REPLAY_MIGRATION_RETURN_OK ;;
  repeat) echo REPLAY_MIGRATION_REPEAT_OK ;;
  partition) echo REPLAY_MIGRATION_PARTITION_OK ;;
  successor_loss) echo REPLAY_MIGRATION_SUCCESSOR_LOSS_OK ;;
esac
