#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; export ODIN_GODOT_ROOT="$ROOT"
work="${REPLAY_P2P_PROVISION_OUT:-$(mktemp -d)}"; mkdir -p "$work"
PROJ="$work/app"; mkdir -p "$PROJ/scripts"
cp "$ROOT/tests/replay_p2p_provision_service/"{project.godot,main.tscn,odin_godot.gdextension} "$PROJ/"
cp "$ROOT/tests/replay_p2p_provision_service/scripts/probe.odin" "$PROJ/scripts/"
server=""
cleanup() {
    if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi
    echo "P2P provisioning service logs: $work"
}
trap cleanup EXIT
case "$(uname -s)" in Darwin) ext=dylib;; Linux) ext=so;; *) ext=dll;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/build.log" 2>&1
"$GODOT" --headless --path "$PROJ" --editor --quit-after 90 >"$work/import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$PROJ" "$work/wait.json"
bash "$ROOT/build/build_scripts.sh" "$PROJ" >"$work/final-build.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$work/key.pem" -out "$work/cert.pem" -days 1 -subj /CN=localhost -addext subjectAltName=DNS:localhost >"$work/certificate.log" 2>&1
export RPP_CERT="$work/cert.pem" RPP_KEY="$work/key.pem" RPP_DB="$work/rooms.sqlite3" RPP_FINGERPRINT="$work/credentials.sha256" RPP_PORT=$((30000+RANDOM%10000))
for resume in 0 1; do
    export RPP_RESUME="$resume" RPP_DONE="$work/done-$resume"
    RPP_ROLE=server "$GODOT" --headless --max-fps 120 --path "$PROJ" >"$work/server-$resume.log" 2>&1 & server=$!
    for _ in {1..200}; do
        if rg -q P2P_PROVISION_SERVICE_READY "$work/server-$resume.log"; then break; fi
        if ! kill -0 "$server" 2>/dev/null; then cat "$work/server-$resume.log"; exit 1; fi
        sleep .05
    done
    rg -q P2P_PROVISION_SERVICE_READY "$work/server-$resume.log"
    "$GODOT" --headless --max-fps 120 --path "$PROJ" >"$work/client-$resume.log" 2>&1
    rg -q P2P_PROVISION_CLIENT_OK "$work/client-$resume.log"
    wait "$server"; server=""
    rg -q P2P_PROVISION_SERVICE_OK "$work/server-$resume.log"
done
if rg -q 'P2P_PROVISION_FAIL|SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work"/{server,client}-*.log; then exit 1; fi
cat "$work"/client-*.log "$work"/server-*.log
echo REPLAY_P2P_PROVISION_SERVICE_OK
