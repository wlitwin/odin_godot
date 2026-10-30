#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_speedball";COORD="$ROOT/tests/replay_migration";work="${RSB_MIGRATION_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
if [[ -n "$(ls -A "$work")" ]];then echo "Migration output must be empty: $work" >&2;exit 2;fi
render_args=(--headless)
if [[ "${RSB_MIGRATION_RENDER:-0}" == 1 ]];then render_args=(--rendering-method gl_compatibility --audio-driver Dummy --resolution 680x510);fi
trap 'for pid in "${pids[@]}";do [[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true; };done;echo "Speedball migration logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 for project in "$PROJ" "$COORD";do
  label="$(basename "$project")"
  bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build-$label.log" 2>&1
  ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/import-$label.log" 2>&1
  if rg -q 'SCRIPT ERROR|ERROR:' "$work/import-$label.log";then cat "$work/import-$label.log";exit 1;fi
  python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/wait-$label.json"
  bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-$label.log" 2>&1
 done
fi
for mode in ${RSB_MIGRATION_MODES:-planned crash};do
 [[ "$mode" == planned || "$mode" == crash ]] || { echo "Invalid migration mode: $mode" >&2;exit 2; }
 folder="$work/$mode";mkdir -p "$folder";port=$((40000+RANDOM%10000));pids=()
 REPLAY_MIGRATION_GAME=speedball REPLAY_MIGRATION_PORT="$port" REPLAY_MIGRATION_DB="$folder/room.sqlite" ODIN_SCRIPTS_DLL="$COORD/bin/libodinscripts.$ext" "$GODOT" --headless --path "$COORD" >"$folder/coordinator.log" 2>&1 &pids+=("$!")
 for _ in {1..100};do rg -q 'REPLAY_MIGRATION_COORDINATOR_READY room=49 content=5253504545444234' "$folder/coordinator.log" && break;sleep .05;done
 rg -q 'REPLAY_MIGRATION_COORDINATOR_READY room=49 content=5253504545444234' "$folder/coordinator.log"
 for member in 1 2 3;do
  key="$(printf '%02x%062d' "$((member+20))" 0)";role=client;[[ "$member" == 1 ]] && role=host
  REPLAY_MIGRATION_MODE="$mode" REPLAY_MIGRATION_DIR="$folder" RSB_ROLE="$role" RSB_MEMBER="$member" RSB_INCARNATION="$((100+member))" RSB_COORD_PORT="$port" RSB_COORD_KEY="$key" RSB_TOKEN="migration-$member" RSB_NAME="member-$member" RSB_PLAYERS=3 RSB_GOALS=9 RSB_LATENCY=120 RSB_TEST=0 RSB_BOT=idle ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" "${render_args[@]}" --max-fps 60 --path "$PROJ" --script migration_test.gd >"$folder/member-$member.log" 2>&1 &pids+=("$!")
  sleep .4
 done
 deadline=$((SECONDS+85));killed=0
 while ((SECONDS<deadline));do
  if [[ "$mode" == crash && "$killed" == 0 && -f "$folder/kill-owner.json" ]];then kill -KILL "${pids[1]}";wait "${pids[1]}" 2>/dev/null || true;pids[1]="";killed=1;fi
  live=0;for pid in "${pids[@]:1}";do if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null;then live=1;fi;done
  ((live==0)) && break
  if rg -q 'SPEEDBALL_MIGRATION_FAIL|REPLAY_SPEEDBALL_FAIL|SCRIPT ERROR|ERROR:' "$folder/"*.log;then cat "$folder/"*.log;exit 1;fi
  sleep .1
 done
 ((SECONDS<deadline));for pid in "${pids[@]:1}";do [[ -z "$pid" ]] || wait "$pid";done
 for member in 2 3;do rg -q "REPLAY_SPEEDBALL_MIGRATION_PEER_OK member=$member" "$folder/member-$member.log";done
 if [[ "$mode" == planned ]];then rg -q 'REPLAY_SPEEDBALL_MIGRATION_PEER_OK member=1' "$folder/member-1.log";else ((killed==1));fi
 if rg -q 'instances were leaked|resources still in use|ERROR:' "$folder/"*.log;then exit 1;fi
 kill "${pids[0]}";wait "${pids[0]}" 2>/dev/null || true;pids=()
 echo "REPLAY_SPEEDBALL_MIGRATION_PHASE_OK $mode"
done
echo REPLAY_SPEEDBALL_MIGRATION_OK
