#!/usr/bin/env bash
set -euo pipefail
PROJ="${1:?Pass the isolated project produced by prepare_baseline.py}"
export ODIN_GODOT_ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
if ! rg -q 'config/name="replay_baseline_stress_' "$PROJ/project.godot";then echo 'Refusing a non-isolated baseline project';exit 1;fi
work="${BASELINE_GAUNTLET_LOGS:-$(mktemp -d)}";mkdir -p "$work";pid=""
trap 'if [[ -n "$pid" ]];then kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;fi' EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
ROLE=gauntlet SY_PORT=$((40000+RANDOM%10000)) SY_NAME=stoker SY_TOKEN=sy-host-token SY_MODS_DIR="$work/no-mods" SY_SPRAY="$work/no-spray.png" \
 SY_FRESH=1 SY_SEED=1337 SY_HZ=60 SY_MOBS=4 SY_WAVES=3 SY_BARRELS=0 SY_MAG=255 SY_NOJAM=1 SY_LATENCY=120 \
 "$GODOT" --headless --path "$PROJ" --script scrapyard_test.gd >"$work/gauntlet.log" 2>&1 &pid=$!
deadline=$((SECONDS+200))
while kill -0 "$pid" 2>/dev/null;do
 if ((SECONDS>=deadline));then cat "$work/gauntlet.log";exit 1;fi
 if rg -q 'SCRIPT ERROR|GAUNTLET_FAIL|signal 11' "$work/gauntlet.log";then cat "$work/gauntlet.log";exit 1;fi
 sleep 0.1
done
wait "$pid";pid="";cat "$work/gauntlet.log"
for receipt in 'SY_WAVE n=4 floor=1' 'SY_WAVE_PLAN waves=3' 'SY_WAVE_UP wave=2' 'SY_WAVE_UP wave=3' 'SY_FLOOR_CLEAR n=1' 'GAUNTLET_DONE';do rg -q "$receipt" "$work/gauntlet.log";done
[[ $(rg -c SY_BARREL_BOOM "$work/gauntlet.log") -ge 2 ]]
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/gauntlet.log";then exit 1;fi
echo REPLAY_SCRAPYARD_BASELINE_GAUNTLET_OK
