#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_speedball";work="${RSB_PROFILE_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=()
[[ -z "$(ls -A "$work")" ]] || { echo "Output must be empty: $work" >&2;exit 2; }
trap 'for pid in "${pids[@]}";do [[ -z "$pid" ]] || { kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true; };done;echo "Speedball profile logs: $work"' EXIT
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
 local role="$1" profile="$2" token="$3"
 RSB_ROLE= RSB_BOT=idle RSB_NAME= RSB_UI_ROLE="$role" RSB_UI_DIR="$work" RSB_PORT="$port" RSB_PROFILE="$profile" RSB_TOKEN="$token" RSB_PERSIST=1 RSB_LATENCY=120 RSB_TEST=0 "$GODOT" --headless --max-fps 60 --path "$PROJ" --script profile_test.gd >"$work/$role.log" 2>&1 &pids+=("$!")
}
await_file() {
 local target="$1" deadline=$((SECONDS+40))
 while [[ ! -f "$work/$target" ]] && ((SECONDS<deadline));do
  if rg -q 'SPEEDBALL_UI_FAIL|SCRIPT ERROR|ERROR:|REPLAY_SPEEDBALL_FAIL' "$work/"*.log;then cat "$work/"*.log;return 1;fi
  sleep .1
 done
 [[ -f "$work/$target" ]]
}
launch host "$work/unused-host" profile-host
launch writer "$work/identity" ""
await_file writer-ready
python3 - "$work" <<'PY'
from pathlib import Path
import hashlib,json,sys
p=Path(sys.argv[1]);identity=(p/'identity').read_bytes();assert len(identity)==16 and any(identity)
(p/'before.json').write_text(json.dumps({name:hashlib.sha256((p/name).read_bytes()).hexdigest() for name in ('identity','identity.name')}))
PY
kill -KILL "${pids[1]}";wait "${pids[1]}" 2>/dev/null || true;pids[1]=""
await_file writer-departed
launch reader "$work/identity" ""
await_file quiesced-reader
for pid in "${pids[@]}";do [[ -z "$pid" ]] || wait "$pid";done;pids=()
python3 - "$work" <<'PY'
from pathlib import Path
import hashlib,json,sys
p=Path(sys.argv[1]);before=json.loads((p/'before.json').read_text())
for name,h in before.items():assert hashlib.sha256((p/name).read_bytes()).hexdigest()==h
(p/'bad-identity').write_bytes(b'broken identity')
(p/'bad-name').write_bytes(bytes(range(1,17)))
(p/'bad-name.name').write_bytes(b'broken name')
(p/'corrupt-before.json').write_text(json.dumps({name:hashlib.sha256((p/name).read_bytes()).hexdigest() for name in ('bad-identity','bad-name','bad-name.name')}))
PY
for role in bad-identity bad-name override;do
 profile="$work/$role";token="";if [[ "$role" == override ]];then profile="$work/bad-identity";token=explicit-test-token;fi
 launch "$role" "$profile" "$token"
 wait "${pids[0]}";pids=()
 rg -q "REPLAY_SPEEDBALL_PROFILE_CASE_OK role=$role" "$work/$role.log"
done
for role in host reader;do rg -q "REPLAY_SPEEDBALL_PROFILE_CASE_OK role=$role" "$work/$role.log";done
if rg -q 'instances were leaked|resources still in use|SPEEDBALL_UI_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
python3 - "$work" <<'PY'
from pathlib import Path
import hashlib,json,sys
p=Path(sys.argv[1]);before=json.loads((p/'corrupt-before.json').read_text())
for name,h in before.items():assert hashlib.sha256((p/name).read_bytes()).hexdigest()==h
assert not (p/'bad-identity.name').exists() and not (p/'unused-host').exists()
(p/'result.json').write_text(json.dumps({'same_identity':True,'same_name':True,'fresh_process_seat':2,'malformed_files_unchanged':True,'explicit_token_bypasses_profile':True},indent=2)+'\n')
PY
echo REPLAY_SPEEDBALL_PROFILE_OK
