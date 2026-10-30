#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
web="$1";files="$2";out="$3"
python3 - "$ROOT" "$web" "$files" "$out" <<'PY'
from pathlib import Path
import hashlib,json,shutil,sys
root,web,files,out=map(Path,sys.argv[1:]);out.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((web/'prepared.json').read_text()).items():assert sha(web/'project'/name)==digest,name
shutil.copy2(root/'tests/replay_recording/playback.mjs',out/'driver.mjs')
(out/'inputs.json').write_text(json.dumps({'driver':sha(out/'driver.mjs'),'files':{p.name:sha(p) for p in files.glob('*.rplrec')},'export':{p.name:sha(p) for p in (web/'project/out').iterdir() if p.is_file()}},indent=2)+'\n')
PY
port=$((20000+RANDOM%9000));server=""
trap '[[ -z "$server" ]] || { kill "$server" 2>/dev/null || true;wait "$server" 2>/dev/null || true; };echo "Playback browser logs: $out"' EXIT
bash "$ROOT/tests/web/serve.sh" "$web/project/out" "$port" >"$out/server.log" 2>&1 &server=$!
node "$ROOT/tests/replay_recording/playback.mjs" "http://127.0.0.1:$port/index.html" "$files" "$out/browser" >"$out/driver.log" 2>&1
cat "$out/driver.log"
