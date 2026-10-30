#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_scrapyard"
COORD="$ROOT/tests/replay_migration"
expected_content="$(python3 -c 'import re,sys;print(re.search(r"CONTENT :: u64\(0x([0-9a-fA-F]+)\)",open(sys.argv[1]).read())[1].lower())' "$PROJ/shared/game/game.odin")"
work="$(mktemp -d)"
pids=()
cleanup() {
  for pid in "${pids[@]}"; do [[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }; done
  if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Scrapyard migration logs: $work"; else rm -rf "$work"; fi
}
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; bash "$ROOT/build/build_scripts.sh" "$COORD"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then
for project in "$PROJ" "$COORD"; do
  import_log="$work/import-${project##*/}.log"
  if ! ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$import_log" 2>&1; then cat "$import_log"; exit 1; fi
  if grep -Eq 'SCRIPT ERROR|ERROR:' "$import_log"; then cat "$import_log"; exit 1; fi
  python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/import-build-${project##*/}.json"
  bash "$ROOT/build/build_scripts.sh" "$project"
done
fi
export REPLAY_MIGRATION_GAME=scrapyard
modes=(planned crash)
if [[ "${REPLAY_MIGRATION_PHASE:-}" == crash ]]; then modes=(crash); fi
if [[ "${REPLAY_MIGRATION_PHASE:-}" == planned ]]; then modes=(planned); fi
for mode in "${modes[@]}"; do
  mkdir "$work/$mode"
  export REPLAY_MIGRATION_MODE="$mode" REPLAY_MIGRATION_DIR="$work/$mode" REPLAY_MIGRATION_DB="$work/$mode/room.sqlite3"
  export REPLAY_MIGRATION_PORT=$((40000 + RANDOM % 10000))
  ODIN_SCRIPTS_DLL="$COORD/bin/libodinscripts.$ext" "$GODOT" --headless --path "$COORD" >"$work/$mode/coordinator.log" 2>&1 &
  pids+=("$!")
  for _ in {1..100}; do if grep -q REPLAY_MIGRATION_COORDINATOR_READY "$work/$mode/coordinator.log"; then break; fi; sleep 0.05; done
  if ! rg -q "REPLAY_MIGRATION_COORDINATOR_READY room=48 content=$expected_content" "$work/$mode/coordinator.log";then
    cat "$work/$mode/coordinator.log";echo "Migration coordinator does not match current Scrapyard content; rebuild tests/replay_migration";exit 1
  fi
  for member in 1 2 3; do
    spray_source="${RSY_SPRAY:-$work/no-spray.png}"
    if [[ "${RSY_MIGRATION_SPRAYS:-0}" == 1 ]]; then
      if [[ "$member" == 1 ]]; then spray_source="$RSY_SPRAY_SOURCE"; else spray_source="$work/no-spray.png"; fi
    fi
    key="$(printf '%02x%062d' "$((member + 20))" 0)"
    ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" RSY_MEMBER="$member" RSY_INCARNATION="$((100 + member))" \
      RSY_SPRAY="$spray_source" RSY_COORD_KEY="$key" RSY_COORD_PORT="$REPLAY_MIGRATION_PORT" RSY_TOKEN="migration-$member" RSY_RUN=0 RSY_ENCOUNTER=migration RSY_LATENCY=120 RSY_ROLE=host \
      "$GODOT" --headless --path "$PROJ" --script migration_test.gd >"$work/$mode/member-$member.log" 2>&1 &
    pids+=("$!")
    sleep 0.5
  done
  for member in 1 2 3;do
    for _ in {1..100};do if rg -q RSY_PROTOCOL "$work/$mode/member-$member.log";then break;fi;sleep 0.05;done
    if ! rg -q "RSY_PROTOCOL content=$expected_content " "$work/$mode/member-$member.log";then
      cat "$work/$mode/member-$member.log";echo "Migration game binary does not match current Scrapyard content; rebuild examples/replay_scrapyard";exit 1
    fi
  done
  killed=0
  deadline=$((SECONDS + 70))
  while ((SECONDS < deadline)); do
    if [[ "$mode" == crash && "$killed" == 0 && -f "$work/$mode/kill_owner.json" ]]; then
      kill -KILL "${pids[1]}"; wait "${pids[1]}" 2>/dev/null || true; pids[1]=""; killed=1
    fi
    if grep -Eq 'RSY_COMBAT_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|REPLAY_MIGRATION_FAIL' "$work/$mode/"*.log; then cat "$work/$mode/"*.log; exit 1; fi
    if grep -q REPLAY_SCRAPYARD_COMBAT_PEER_OK "$work/$mode/member-2.log"; then break; fi
    sleep 0.05
  done
  cat "$work/$mode/"*.log
  if [[ "${RSY_MIGRATION_STAGE:-}" == lobby ]]; then
    grep -q 'RSY_COMBAT_RESTORED exact=true active=false' "$work/$mode/member-2.log"
    grep -q RSY_LOBBY_MIGRATION_RESULT "$work/$mode/member-2.log"
  else
    grep -q 'RSY_COMBAT_RESTORED exact=true active=true' "$work/$mode/member-2.log"
  fi
  if [[ "${RSY_MIGRATION_MODS:-0}" == 1 ]]; then
    grep -q RSY_MIGRATION_MOD "$work/$mode/member-2.log"
    if grep -q RSY_MODS "$work/$mode/member-2.log" "$work/$mode/member-3.log"; then exit 1; fi
  fi
  if [[ "${RSY_MIGRATION_SPRAYS:-0}" == 1 ]]; then
    grep -q RSY_MIGRATION_SPRAY "$work/$mode/member-2.log"
    grep -q RSY_ASSET_PREPARE_WAIT_OBSERVED "$work/$mode/member-2.log"
  fi
  grep -q REPLAY_SCRAPYARD_COMBAT_PEER_OK "$work/$mode/member-2.log"
  grep -q REPLAY_SCRAPYARD_COMBAT_PEER_OK "$work/$mode/member-3.log"
  if [[ "$mode" == planned ]]; then grep -q REPLAY_SCRAPYARD_COMBAT_PEER_OK "$work/$mode/member-1.log"; else ((killed == 1)); fi
  for pid in "${pids[@]:1}"; do [[ -z "$pid" ]] || wait "$pid"; done
  if grep -Eq 'SCRIPT ERROR|ERROR:|ObjectDB instances were leaked' "$work/$mode/"*.log; then exit 1; fi
  kill "${pids[0]}"; wait "${pids[0]}" 2>/dev/null || true; pids=()
  echo "REPLAY_SCRAPYARD_MIGRATION_PHASE_OK $mode"
done
if [[ "${REPLAY_MIGRATION_PHASE:-}" == crash ]]; then echo REPLAY_SCRAPYARD_CRASH_OK
elif [[ "${REPLAY_MIGRATION_PHASE:-}" == planned ]]; then echo REPLAY_SCRAPYARD_PLANNED_OK
else echo REPLAY_SCRAPYARD_MIGRATION_OK; fi
