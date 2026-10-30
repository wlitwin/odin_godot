#!/usr/bin/env bash
set -euo pipefail
umask 077
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_TURN_OUT:-$(mktemp -d)}";mkdir -p "$work";work="$(cd "$work" && pwd)"
turnserver="${TURNSERVER:-}"
if [[ -z "$turnserver" ]];then turnserver="$(command -v turnserver || true)";fi
[[ -n "$turnserver" && -x "$turnserver" ]] || { echo 'Set TURNSERVER to a coturn executable; see tests/replay_turn/README.md.' >&2;exit 1; }
turnserver="$(cd "$(dirname "$turnserver")" && pwd)/$(basename "$turnserver")"
transport="${REPLAY_TURN_PROTOCOL:-udp}";game="${REPLAY_TURN_GAME:-cave}"
scenario="${REPLAY_TURN_SCENARIO:-game}"
[[ "$transport" == udp || "$transport" == tcp ]] || exit 1
[[ "$game" == cave || "$game" == scrapyard ]] || exit 1
[[ "$scenario" == game || "$scenario" == auth || "$scenario" == outage ]] || exit 1
port=$((41000+RANDOM%7000))
python3 - "$work" "$port" "$transport" "${REPLAY_TURN_PROVIDER:-0}" <<'PY'
from pathlib import Path
import secrets,json,sys
root=Path(sys.argv[1]);port=int(sys.argv[2]);transport=sys.argv[3]
password=secrets.token_hex(24)
config=['listening-ip=127.0.0.1','relay-ip=127.0.0.1',f'listening-port={port}','min-port=53000','max-port=53100','realm=replay.invalid','fingerprint','lt-cred-mech',f'user=replay-fixture:{password}','no-tls','no-dtls','no-cli','cli-password='+secrets.token_hex(16),'allow-loopback-peers','no-multicast-peers','relay-threads=1','user-quota=16','total-quota=32','max-bps=2000000','log-file=stdout','simple-log','verbose','pidfile='+str(root/'turn.pid')]
if transport=='tcp':config.append('no-udp')
if sys.argv[4]=='1':
 secret=secrets.token_hex(32)
 config=[item for item in config if item!='lt-cred-mech' and not item.startswith('user=')]
 config += ['use-auth-secret','static-auth-secret='+secret]
 (root/'provider-secret').write_text(secret)
(root/'turn.conf').write_text('\n'.join(config)+'\n')
ice={'iceTransportPolicy':'relay','iceServers':[{'urls':[f'turn:127.0.0.1:{port}?transport={transport}'],'username':'replay-fixture','credential':password}]}
(root/'ice.json').write_text(json.dumps(ice))
PY
(cd "$work" && exec "$turnserver" -c "$work/turn.conf") >"$work/turn.log" 2>&1 & relay=$!
trap 'kill "$relay" 2>/dev/null || true;wait "$relay" 2>/dev/null || true;echo "TURN logs: $work"' EXIT
for _ in {1..100};do if rg -q 'Total auth threads|Total General servers' "$work/turn.log";then break;fi;if ! kill -0 "$relay" 2>/dev/null;then cat "$work/turn.log";exit 1;fi;sleep 0.1;done
export REPLAY_ICE_CONFIG="$work/ice.json" REPLAY_TURN_PROTOCOL="$transport"
if [[ "${REPLAY_TURN_PROVIDER:-0}" == 1 ]];then
 export REPLAY_ROOM_TURN_SECRET_FILE="$work/provider-secret" REPLAY_ROOM_TURN_URLS="turn:127.0.0.1:$port?transport=$transport" REPLAY_ROOM_TURN_TTL="${REPLAY_TURN_TTL:-12}" REPLAY_ROOM_TURN_RELAY_ONLY=1
fi
if [[ "$scenario" == auth || "$scenario" == outage ]];then
 [[ "$game" == cave ]]
 PROJ="$ROOT/examples/replay_cavecrawl";SERVICE="$ROOT/examples/replay_room_service"
 [[ -f "$PROJ/out/libodin_godot.wasm" ]] || { echo 'Run the Cavecrawl relay gate before the authentication scenario.' >&2;exit 1; }
 case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) exit 1 ;; esac
 control=$((31000+RANDOM%9000));http=$((21000+RANDOM%9000));helpers=()
 REPLAY_ROOM_CONTENT=0x4341564552504c39 REPLAY_ROOM_PORT="$control" REPLAY_ROOM_DB="$work/service.sqlite3" REPLAY_ROOM_CREATE_DB=1 REPLAY_ROOM_LOCAL_DEVELOPMENT=1 ODIN_SCRIPTS_DLL="$SERVICE/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 120 --path "$SERVICE" >"$work/service.log" 2>&1 &helpers+=("$!")
 bash "$ROOT/tests/web/serve.sh" "$PROJ/out" "$http" >"$work/http.log" 2>&1 &helpers+=("$!")
 trap 'for pid in "$relay" "${helpers[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "TURN logs: $work"' EXIT
 for _ in {1..100};do if curl -fsS -o /dev/null "http://127.0.0.1:$http/index.html" 2>/dev/null && rg -q REPLAY_ROOM_SERVICE_READY "$work/service.log";then break;fi;sleep 0.1;done
 REPLAY_TURN_PID="$relay" REPLAY_TURN_EXECUTABLE="$turnserver" REPLAY_TURN_CONFIG="$work/turn.conf" REPLAY_TURN_WORK="$work" node "$ROOT/tests/replay_turn/$scenario.mjs" "http://127.0.0.1:$http/index.html" "ws://127.0.0.1:$control" "$work/$scenario" | tee "$work/game.log"
 echo "REPLAY_TURN_${scenario^^}_GATE_OK"
 exit 0
elif [[ "$game" == cave ]];then
 CAVE_ONLINE_WEB_OUT="$work/game" bash "$ROOT/examples/replay_cavecrawl/online_web_run.sh" >"$work/game.log" 2>&1
else
 RSY_ONLINE_WEB_OUT="$work/game" bash "$ROOT/examples/replay_scrapyard/online_web_run.sh" >"$work/game.log" 2>&1
fi
python3 - "$work" "$transport" <<'PY'
from pathlib import Path
import json,sys
root=Path(sys.argv[1]);events=json.loads((root/'game/browser/relay.json').read_text())
assert len(events)>=5,events
for event in events:
    assert event['rows'],event
    for row in event['rows']:
        assert row['local']==row['remote']=='relay' and row['policy']=='relay',row
        assert row['relayProtocol']==sys.argv[2] and row['bytesSent']>0 and row['bytesReceived']>0,row
text=(root/'turn.log').read_text()
assert 'ALLOCATE processed, success' in text or 'allocation' in text.lower(),text[-2000:]
(root/'result.json').write_text(json.dumps({'transport':sys.argv[2],'stages':events,'relay_only':True},indent=2)+'\n')
print('REPLAY_TURN_SELECTED_PAIRS_OK',sys.argv[2],len(events))
PY
echo "REPLAY_TURN_OK $game $transport"
