#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_provision_godot"
work="${REPLAY_PROVISION_OUT:-$(mktemp -d)}"; mkdir -p "$work"
server=""; stalled=""
cleanup() { for pid in "$server" "$stalled"; do if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; fi; done; echo "Provision TLS logs: $work"; }
trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
"$GODOT" --headless --path "$PROJ" --editor --quit-after 90 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/build-wait.json"
# Resolve any import-triggered compiler before the final fixture binary is used.
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/key.pem" -out "$work/cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >"$work/certificate.log" 2>&1
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/wrong-key.pem" -out "$work/wrong-cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >>"$work/certificate.log" 2>&1
export PROVISION_CERT="$work/cert.pem" PROVISION_KEY="$work/key.pem" PROVISION_WRONG_CERT="$work/wrong-cert.pem"
export PROVISION_DB="$work/rooms.sqlite3" PROVISION_FINGERPRINT="$work/credentials.sha256" PROVISION_PORT=$((40000+RANDOM%10000))
wait_marker() {
    for _ in {1..200}; do
        if rg -q "$2" "$1"; then return; fi
        if ! kill -0 "$server" 2>/dev/null; then cat "$1"; return 1; fi
        sleep 0.05
    done
    cat "$1"; return 1
}
for resume in 0 1; do
    export PROVISION_RESUME="$resume" PROVISION_DONE="$work/done-$resume"
    PROVISION_ROLE=server "$GODOT" --headless --max-fps 120 --path "$PROJ" >"$work/server-$resume.log" 2>&1 & server=$!
    wait_marker "$work/server-$resume.log" PROVISION_TLS_SERVER_READY
    if [[ "$resume" == 0 ]]; then
        for negative in trust hostname options; do
            PROVISION_ROLE=client PROVISION_NEGATIVE="$negative" "$GODOT" --headless --max-fps 120 --path "$PROJ" >"$work/negative-$negative.log" 2>&1
            rg -q PROVISION_TLS_REJECT_OK "$work/negative-$negative.log"
        done
        python3 - "$PROVISION_DB" <<'PY'
import sqlite3,sys
with sqlite3.connect(f'file:{sys.argv[1]}?mode=ro',uri=True) as db:
    assert db.execute('select count(*) from replay_provision').fetchone()[0] == 0
print('PROVISION_TLS_NEGATIVES_NO_ROOMS')
PY
    else
        python3 - "$PROVISION_PORT" >"$work/pending-tls.log" 2>&1 <<'PY' &
import socket,sys,time
with socket.create_connection(('127.0.0.1',int(sys.argv[1]))) as peer:
    print('PROVISION_PENDING_TLS',flush=True)
    time.sleep(10)
PY
        stalled=$!
        wait_marker "$work/pending-tls.log" PROVISION_PENDING_TLS
    fi
    PROVISION_ROLE=client "$GODOT" --headless --max-fps 120 --path "$PROJ" >"$work/client-$resume.log" 2>&1
    rg -q PROVISION_TLS_CLIENT_OK "$work/client-$resume.log"
    wait_marker "$work/server-$resume.log" PROVISION_TLS_SERVER_OK
    if [[ "$resume" == 0 ]]; then kill -KILL "$server"; wait "$server" 2>/dev/null || true
    else wait "$server"; kill "$stalled" 2>/dev/null || true; wait "$stalled" 2>/dev/null || true; stalled=""; fi
    server=""
done
if rg -q 'PROVISION_TLS_FAIL|SCRIPT ERROR|instances were leaked|resources still in use' "$work"/*.log; then exit 1; fi
if rg -q 'ERROR:' "$work"/client-*.log; then exit 1; fi
for log in "$work"/client-*.log "$work"/server-*.log; do rg 'PROVISION_TLS_' "$log"; done
if [[ "${PROVISION_CHECKPOINT:-0}" == 1 ]]; then
    rg -q 'PROVISION_CHECKPOINT_UPLOAD_OK publication=1 tick=1' "$work/client-0.log"
    rg -q 'PROVISION_CHECKPOINT_DOWNLOAD_OK resume=false publication=1 tick=1 value=8 incarnation=1' "$work/client-0.log"
    rg -q 'PROVISION_CHECKPOINT_DOWNLOAD_OK resume=true publication=1 tick=1 value=8 incarnation=2 remaining_ms=0' "$work/client-1.log"
    for resume in 0 1; do rg -q 'PROVISION_CHECKPOINT_SERVER_OK' "$work/server-$resume.log"; done
    echo REPLAY_CHECKPOINT_TLS_OK
fi
echo REPLAY_PROVISION_TLS_OK
