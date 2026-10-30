#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_speedball";work="${RSB_SAVE_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
[[ -z "$(ls -A "$work")" ]] || { echo "Output must be empty: $work" >&2;exit 2; }
trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Speedball save logs: $work"' EXIT
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]];then
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
 "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1
 python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
 bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
 if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
fi
port=$((40000+RANDOM%10000))
launch() {
 local stage="$1" role="$2" profile="$3" save="$4";local args=(--headless)
 if [[ "$stage" == solo && "${RSB_SAVE_RENDER:-0}" == 1 ]];then args=(--rendering-method gl_compatibility --audio-driver Dummy);fi
 RSB_ROLE= RSB_NAME= RSB_TOKEN= RSB_BOT=idle RSB_SAVE_STAGE="$stage" RSB_UI_ROLE="$role" RSB_UI_DIR="$work" RSB_PROFILE="$profile" RSB_PERSIST=1 RSB_SAVE="$save" RSB_PORT="$port" RSB_PLAYERS=2 RSB_GOALS=2 RSB_LATENCY=120 RSB_TEST=0 "$GODOT" "${args[@]}" --max-fps 60 --path "$PROJ" --script save_test.gd >"$work/$stage-$role.log" 2>&1 &pids+=("$!")
}
await_file() {
 local name="$1" deadline=$((SECONDS+75))
 while [[ ! -f "$work/$name" ]] && ((SECONDS<deadline));do
  if rg -q 'SPEEDBALL_UI_FAIL|SCRIPT ERROR|ERROR:|REPLAY_SPEEDBALL_FAIL' "$work/"*.log;then cat "$work/"*.log;return 1;fi
  sleep .1
 done
 [[ -f "$work/$name" ]]
}
wait_all() {
 local deadline=$((SECONDS+100))
 while ((SECONDS<deadline));do
  local live=0;for pid in "${pids[@]}";do if kill -0 "$pid" 2>/dev/null;then live=1;fi;done
  ((live==0)) && break
  if rg -q 'SPEEDBALL_UI_FAIL|SCRIPT ERROR|ERROR:|REPLAY_SPEEDBALL_FAIL' "$work/"*.log;then cat "$work/"*.log;return 1;fi
  sleep .1
 done
 ((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
}
launch write host "$work/host-identity" "$work/pitch.replay"
launch write client "$work/client-identity" "$work/guest.replay"
await_file saved-ready
rg -q RSB_FAILED_WRITE_PRESERVED "$work/write-host.log"
for pid in "${pids[@]}";do kill -KILL "$pid";wait "$pid" 2>/dev/null || true;done;pids=()
python3 - "$work" <<'PY'
from pathlib import Path
import hashlib,json,sys
p=Path(sys.argv[1]);data=(p/'pitch.replay').read_bytes();assert len(data)>52
(p/'damaged.replay').write_bytes(data[:len(data)//2])
(p/'before.json').write_text(json.dumps({name:hashlib.sha256((p/name).read_bytes()).hexdigest() for name in ('pitch.replay','damaged.replay','host-identity','client-identity')}))
assert not (p/'guest.replay').exists()
PY
for stage in wrong-owner damaged missing solo;do
 profile="$work/host-identity";save="$work/pitch.replay"
 case "$stage" in wrong-owner) profile="$work/client-identity";;damaged) save="$work/damaged.replay";;missing) save="$work/missing.replay";;esac
 launch "$stage" host "$profile" "$save";wait_all
 rg -q "REPLAY_SPEEDBALL_SAVE_CASE_OK $stage" "$work/$stage-host.log"
done
launch read host "$work/host-identity" "$work/pitch.replay"
launch read client "$work/client-identity" "$work/guest.replay"
wait_all
for role in host client;do rg -q "REPLAY_SPEEDBALL_SAVE_PEER_OK role=$role" "$work/read-$role.log";done
if rg -q 'instances were leaked|resources still in use|SCRIPT ERROR|ERROR:' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
python3 - "$work" <<'PY'
from pathlib import Path
import hashlib,json,sys
p=Path(sys.argv[1]);before=json.loads((p/'before.json').read_text())
for name,h in before.items():assert hashlib.sha256((p/name).read_bytes()).hexdigest()==h,name
saved=json.loads((p/'saved.json').read_text());restored=json.loads((p/'restored.json').read_text())
assert restored['exact'] and restored['hash']==saved['hash'] and restored['tick']==saved['tick'] and restored['epoch']==2
for role in ('host','client'):
 done=json.loads((p/f'done-{role}.json').read_text());assert done['round']==2 and done['epoch']==2 and done['left']==done['right']==0
assert not (p/'guest.replay').exists() and not (p/'missing.replay').exists()
(p/'result.json').write_text(json.dumps({'exact_restore':True,'fresh_processes':True,'saved_score':saved['left']+saved['right'],'moving':saved['moving'],'continued_spikes_and_restart':True,'files_unchanged':True},indent=2)+'\n')
PY
echo REPLAY_SPEEDBALL_SAVE_OK
