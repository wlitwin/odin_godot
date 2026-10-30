#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT" SCRIPT_BUILD_FLAGS=-o:speed
work="${REPLAY_SOLO_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Solo comparison logs: $work"' EXIT
[[ ! -e "$work/kit" && ! -e "$work/replay" ]] || { echo "Fresh output required: $work" >&2;exit 2; }
python3 "$ROOT/tests/replay_solo_comparison/prepare.py" "$work" >"$work/prepare.log"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 1;;esac
for impl in kit replay;do
 project="$work/$impl/project"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$impl/build.log" 2>&1
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --path "$project" --editor --quit-after 120 >"$work/$impl/import.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/$impl/import.log";then tail -60 "$work/$impl/import.log";exit 1;fi
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/$impl/build-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$project" >"$work/$impl/final-build.log" 2>&1
done
mkdir -p "$work/navigation-test"
cp "$ROOT/tests/replay_solo_comparison/navigation_test/"* "$work/navigation-test/"
cp "$ROOT/tests/replay_solo_comparison/navigation.gd" "$work/navigation-test/navigation.gd"
"$GODOT" --headless --path "$work/navigation-test" --script test.gd >"$work/navigation-test.log" 2>&1
rg -q SOLO_NAVIGATION_TEST_OK "$work/navigation-test.log"
status=0
for pair in 1 2 3;do
 reverse=0;[[ "$pair" == 2 ]] && reverse=1
 REPLAY_SOLO_FINALE=navigate REPLAY_SOLO_OBSTRUCTED=0 REPLAY_SOLO_REVERSE="$reverse" python3 "$ROOT/tests/replay_solo_comparison/execute.py" "$work" "$ext" "normal-$pair" || status=1
 if python3 "$ROOT/tests/replay_solo_comparison/report.py" "$work" "normal-$pair";then python3 "$ROOT/tests/replay_solo_comparison/verify_report.py" "$work" "normal-$pair";else status=1;fi
done
REPLAY_SOLO_FINALE=navigate REPLAY_SOLO_OBSTRUCTED=1 REPLAY_SOLO_REVERSE=0 python3 "$ROOT/tests/replay_solo_comparison/execute.py" "$work" "$ext" obstructed || status=1
if python3 "$ROOT/tests/replay_solo_comparison/report.py" "$work" obstructed;then python3 "$ROOT/tests/replay_solo_comparison/verify_report.py" "$work" obstructed;else status=1;fi
python3 "$ROOT/tests/replay_solo_comparison/cohort.py" "$work" || status=1
exit "$status"
