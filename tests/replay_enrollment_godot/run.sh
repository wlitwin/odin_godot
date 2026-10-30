#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_enrollment_godot"; SERVER="$ROOT/tests/replay_provision_godot"
work="${REPLAY_ENROLLMENT_OUT:-$(mktemp -d)}"; mkdir -p "$work"
server=""; client=""
cleanup() { for pid in "$server" "$client"; do if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi; done; echo "Enrollment logs: $work"; }
trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
for proj in "$SERVER" "$PROJ"; do
    label="$(basename "$proj")"; export ODIN_SCRIPTS_DLL="$proj/bin/libodinscripts.$ext"
    bash "$ROOT/build/build_scripts.sh" "$proj" >"$work/$label-build.log" 2>&1
    "$GODOT" --headless --path "$proj" --editor --quit-after 90 >"$work/$label-import.log" 2>&1
    if rg -q 'SCRIPT ERROR|ERROR:' "$work/$label-import.log"; then cat "$work/$label-import.log"; exit 1; fi
    python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$proj" "$work/$label-wait.json"
    bash "$ROOT/build/build_scripts.sh" "$proj" >"$work/$label-final-build.log" 2>&1
done
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/key.pem" -out "$work/cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >"$work/certificate.log" 2>&1
export PROVISION_CERT="$work/cert.pem" PROVISION_KEY="$work/key.pem" PROVISION_PORT=$((40000+RANDOM%10000))
export PROVISION_DB="$work/server.sqlite3" PROVISION_DONE="$work/done" PROVISION_ENROLLMENT=1
export ENROLLMENT_DB="$work/client.sqlite3" ENROLLMENT_FINGERPRINT="$work/credential.sha256" ENROLLMENT_URL="wss://localhost:$PROVISION_PORT"
wait_marker() {
    for _ in {1..300}; do
        if rg -q "$2" "$1"; then return; fi
        if ! kill -0 "$3" 2>/dev/null; then cat "$1"; return 1; fi
        sleep 0.05
    done
    cat "$1"; return 1
}
PROVISION_ROLE=server ODIN_SCRIPTS_DLL="$SERVER/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVER" >"$work/server.log" 2>&1 & server=$!
wait_marker "$work/server.log" PROVISION_TLS_SERVER_READY "$server"
for stage in 1 2 3; do
    ENROLLMENT_STAGE="$stage" ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$PROJ" >"$work/client-$stage.log" 2>&1 & client=$!
    case "$stage" in 1) marker=ENROLLMENT_REQUEST_STORED ;; 2) marker=ENROLLMENT_GRANT_RECEIVED ;; 3) marker=ENROLLMENT_READY ;; esac
    wait_marker "$work/client-$stage.log" "$marker" "$client"
    python3 - "$PROVISION_DB" "$stage" <<'PY'
import sqlite3,sys
with sqlite3.connect(f'file:{sys.argv[1]}?mode=ro',uri=True) as db:
    count=db.execute('select count(*) from replay_provision').fetchone()[0]
    assert count == (0 if sys.argv[2]=='1' else 1), count
print(f'ENROLLMENT_SERVER_ROWS stage={sys.argv[2]} count={count}')
PY
    kill -KILL "$client"; wait "$client" 2>/dev/null || true; client=""
done
ENROLLMENT_STAGE=4 ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$PROJ" >"$work/client-4.log" 2>&1
wait "$server"; server=""
rg -q 'ENROLLMENT_OK revision=2 connected=false' "$work/client-4.log"
rg -q 'ENROLLMENT_SERVER_OK rooms=1 members=1' "$work/server.log"
python3 - "$work" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1])
requests=[re.search(r'request=(.*)',(p/f'client-{n}.log').read_text()).group(1) for n in [1,3,4]]
assert len(set(requests))==1, requests
fingerprints=[re.search(r'fingerprint=(.*)',(p/f'client-{n}.log').read_text()).group(1) for n in [2,3,4]]
assert len(set(fingerprints))==1, fingerprints
print('ENROLLMENT_NATIVE_CRASH_OK request_cas_before_send=true server_retry_same_credential=true ready_reload_without_network=true')
PY
if rg -q 'ENROLLMENT_FAIL|PROVISION_TLS_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work"/*.log; then exit 1; fi
echo REPLAY_ENROLLMENT_NATIVE_OK
