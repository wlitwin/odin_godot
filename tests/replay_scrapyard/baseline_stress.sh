#!/usr/bin/env bash
set -euo pipefail
PROJ="${1:?Pass the isolated project produced by prepare_baseline.py}"
export ODIN_GODOT_ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
if ! rg -q 'config/name="replay_baseline_stress_' "$PROJ/project.godot";then echo 'Refusing a non-isolated baseline project';exit 1;fi
work="$(mktemp -d)";pids=()
cleanup() { for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]];then echo "Baseline stress logs: $work";else rm -rf "$work";fi; }
trap cleanup EXIT
if [[ -f "$PROJ/bin/.odin_crash.prev.log" ]];then mv "$PROJ/bin/.odin_crash.prev.log" "$work/prior-crash-report.txt";fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
port=$((40000+RANDOM%10000))
for role in stresshost stressguest;do
 ROLE="$role" SY_PORT="$port" SY_NAME="$role" SY_TOKEN="isolated-$role-${work##*/}" SY_MODS_DIR="$work/no-mods" SY_SPRAY="$work/no-spray.png" \
 SY_FRESH=1 SY_SEED=1337 SY_HZ=60 SY_MOBS=40 SY_WAVES=1 SY_BARRELS=0 SY_MAG=255 SY_NOJAM=1 SY_LATENCY="${SY_LATENCY:-120}" \
 "$GODOT" --headless --path "$PROJ" --script scrapyard_test.gd >"$work/$role.log" 2>&1 &pids+=("$!")
 sleep 2
done
deadline=$((SECONDS+150))
while ((SECONDS<deadline));do
 live=0;for pid in "${pids[@]}";do if kill -0 "$pid" 2>/dev/null;then live=1;fi;done
 if ((live==0));then break;fi
 if rg -q 'STRESSHOST_FAIL|STRESSGUEST_FAIL|SCRIPT ERROR|signal 11' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
 sleep 0.1
done
cat "$work/stresshost.log" "$work/stressguest.log"
((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
rg -q 'STRESSHOST_PEAK peak=(3[0-9]|4[0-9])' "$work/stresshost.log"
rg -q 'STRESSGUEST_PEAK peak=(3[0-9]|4[0-9])' "$work/stressguest.log"
rg -q SY_SLIMED "$work/stresshost.log";rg -q SY_BURNED "$work/stresshost.log"
rg -q STRESSHOST_DONE "$work/stresshost.log";rg -q STRESSGUEST_DONE "$work/stressguest.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/"*.log;then exit 1;fi
echo REPLAY_SCRAPYARD_BASELINE_STRESS_OK
