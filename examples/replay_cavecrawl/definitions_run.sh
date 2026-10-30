#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl";work="${REPLAY_DEFINITIONS_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Definition logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1;fi
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
export REPLAY_CAVE_ROLE=solo REPLAY_CAVE_TOKEN=definition-fixture REPLAY_CAVE_SAVE="$work/defined.replay"
for mode in create resume;do
 script=definitions_test.gd;resume=0;if [[ "$mode" == resume ]];then script=definitions_resume_test.gd;resume=1;fi
 REPLAY_CAVE_RESUME="$resume" "$GODOT" --headless --max-fps 60 --path "$PROJ" --script "$script" >"$work/$mode.log" 2>&1
 cat "$work/$mode.log"
 if rg -q 'SCRIPT ERROR|ERROR:|CAVE_DEFINITION_TEST_FAIL|instances were leaked|resources still in use' "$work/$mode.log";then exit 1;fi
done
rg -q REPLAY_CAVE_DEFINITIONS_OK "$work/create.log";rg -q REPLAY_CAVE_DEFINITION_RESUME_OK "$work/resume.log"
for invalid in counts stock geometry marker scene root;do
 code=0
 DEFINITION_INVALID="$invalid" REPLAY_CAVE_RESUME=0 "$GODOT" --headless --path "$PROJ" --script definitions_invalid_test.gd >"$work/invalid-$invalid.log" 2>&1 || code=$?
 [[ "$code" == 1 ]];rg -q REPLAY_CAVE_DEFINITION_FAIL "$work/invalid-$invalid.log"
 if rg -q 'CAVE_DEFINITION_INVALID_ACCEPTED|SCRIPT ERROR' "$work/invalid-$invalid.log";then cat "$work/invalid-$invalid.log";exit 1;fi
done
echo REPLAY_CAVE_DEFINITION_GATE_OK
