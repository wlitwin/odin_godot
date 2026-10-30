#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
project="$ROOT/tests/replay_ack_transport";work="${REPLAY_ACK_OUT:-$(mktemp -d)}";mkdir -p "$work"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) ext=dll;;esac
export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
python3 "$ROOT/tests/replay_ack_transport/proxy_test.py" >"$work/proxy-test.log" 2>&1
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
"$GODOT" --headless --path "$project" --editor --quit-after 90 >"$work/import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/final-build.log" 2>&1
if rg -q 'ERROR:|SCRIPT ERROR' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 - "$ROOT" "$project" "$work" "$ext" <<'PY'
from pathlib import Path
import hashlib,json,subprocess,sys
root,project,work=map(Path,sys.argv[1:4]);sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
sources=[root/'replay/net/snapshot.odin',root/'replay/net/client.odin',root/'replay/godot/transport/multiplayer_peer.odin',root/'replay/godot/transport/enet.odin',project/'scripts/probe.odin',project/'driver.gd',project/'proxy.py']
(work/'build-manifest.json').write_text(json.dumps({'odin':subprocess.check_output(['odin','version'],text=True).strip(),'source_sha256':{str(p.relative_to(root)):sha(p) for p in sources},'binaries':{p.name:sha(p) for p in (project/'bin').glob('*.'+sys.argv[4])}},indent=2)+'\n')
PY
read -r backend front < <(python3 - <<'PY'
import socket
s=[socket.socket(socket.AF_INET,socket.SOCK_DGRAM) for _ in range(2)]
for x in s:x.bind(('127.0.0.1',0))
print(*(x.getsockname()[1] for x in s))
PY
)
cat >"$work/config.json" <<'JSON'
{"latency_ms":120,"jitter_ms":0,"loss":0,"duplicate":0,"bytes_per_second":0,"queue_packets":128,"queue_bytes":65536,"rate_burst_bytes":1500}
JSON
pids=();proxy="";trap 'for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;if [[ -n "$proxy" ]];then kill "$proxy" 2>/dev/null || true;wait "$proxy" 2>/dev/null || true;fi;echo "ACK transport logs: $work"' EXIT
python3 "$ROOT/tests/replay_ack_transport/proxy.py" --listen "$front" --host "$backend" --config "$work/config.json" --out "$work/proxy" >"$work/proxy.log" 2>&1 &proxy=$!
for _ in {1..100};do [[ -f "$work/proxy/ready.json" ]] && break;sleep .05;done
[[ -f "$work/proxy/ready.json" ]]
for role in host client;do
 port="$front";[[ "$role" == host ]] && port="$backend"
 REPLAY_ACK_ROLE="$role" REPLAY_ACK_PORT="$port" REPLAY_ACK_DIR="$work" "$GODOT" --headless --max-fps 60 --path "$project" --script driver.gd --quit-after 2400 >"$work/$role.log" 2>&1 &pids+=("$!")
 sleep .2
done
for pid in "${pids[@]}";do wait "$pid";done;pids=()
kill "$proxy";wait "$proxy";proxy=""
if rg -q 'ERROR:|SCRIPT ERROR|instances were leaked|resources still in use' "$work/host.log" "$work/client.log";then cat "$work/host.log" "$work/client.log";exit 1;fi
python3 - "$work" <<'PY'
from pathlib import Path
import hashlib,json,os,sys
r=Path(sys.argv[1]);d=json.loads((r/'client.json').read_text());drop=json.loads((r/'proxy/dropped.json').read_text());receipt=json.loads((r/'proxy/receipt.json').read_text())
assert d['sequence']==1 and d['elapsed']<5000
assert sum(x['loss_dropped_packets'] for x in receipt['directions'].values())==1
assert all(x['capacity_dropped_packets']==x['socket_errors']==0 for x in receipt['directions'].values())
assert 11 in {x['kind'] for x in drop['envelopes']}<={4,11,15}
print('REPLAY_ACK_TRANSPORT_CAPTURED',d)
if os.environ.get('REPLAY_ACK_CAPTURE_ONLY','0')!='1':
 assert d['ack_reliable']==0 and d['ack_unreliable']>0
 assert d['elapsed']<=450,('action round trip after targeted ACK loss',d)
 print('REPLAY_ACK_TRANSPORT_OK')
PY
