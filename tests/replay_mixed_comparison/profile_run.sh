#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
source="${1:?Pass a verified mixed cohort directory}";work="${REPLAY_MIXED_PROFILE_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
[[ -z "$(ls -A "$work")" ]] || { echo "Profile needs an empty output directory" >&2;exit 2; }
python3 "$ROOT/tests/replay_mixed_comparison/report.py" "$source" >"$work/source-verification.log"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 2;;esac
project="$source/replay/project";port=$((40000+RANDOM%10000))
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Mixed phase profile logs: $work"' EXIT
for role in host client;do
 COMPARE_PHASES=1 COMPARE_IMPL=replay COMPARE_ROLE="$role" COMPARE_DIR="$work" RSY_RESULT_DIR="$work" \
 RSY_DEV=1 RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="mixed-$role" RSY_SEED=1337 RSY_RUN=1 RSY_WAVE_BASE=0 RSY_WAVE_GROWTH=0 RSY_WAVES=1 RSY_BARRELS=0 RSY_MOBS=0 RSY_PERSIST=0 RSY_MODS_DIR="$work/no-mods" RSY_SPRAY="$work/no-spray.png" RSY_REQUIRE_STOCK=0 RSY_LATENCY=120 RSY_JITTER=0 RSY_LOSS=0 RSY_DUPLICATE=0 RSY_RESUME=0 RSY_PORT="$port" RSY_AUDIO=0 \
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$project" --script comparison.gd >"$work/$role.log" 2>&1 &pids+=("$!")
 sleep .3
done
deadline=$((SECONDS+90))
while ((SECONDS<deadline));do
 live=0;for pid in "${pids[@]}";do if kill -0 "$pid" 2>/dev/null;then live=1;fi;done
 ((live==0)) && break
 if rg -q 'MIXED_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
 sleep .1
done
((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in host client;do rg -q REPLAY_MIXED_PEER_OK "$work/$role.log";rg -q 'RSY_BENCH .* dropped=0' "$work/$role.log";test -s "$work/timing-$role.csv";done
python3 "$ROOT/tests/replay_mixed_comparison/profile_report.py" "$work"
echo REPLAY_MIXED_PHASE_PROFILE_OK
