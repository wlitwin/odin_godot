#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="${REPLAY_SCHEMA_BENCH_OUT:-$(mktemp -d)}";mkdir -p "$work"
trap 'echo "Schema benchmark: $work"' EXIT
if [[ -e "$work/current" || -e "$work/build.json" ]];then echo "Schema benchmark requires a fresh output directory";exit 2;fi
odin build "$ROOT/tests/replay_schema_bench" -collection:godot="$ROOT" -debug -o:speed -out:"$work/current"
if [[ -n "${REPLAY_SCHEMA_REFERENCE:-}" ]];then
 python3 "$ROOT/tests/replay_schema_bench/reference_root.py" "$ROOT" "$work/reference-root" "$REPLAY_SCHEMA_REFERENCE"
 odin build "$ROOT/tests/replay_schema_bench" -collection:godot="$work/reference-root" -debug -o:speed -out:"$work/reference"
fi
python3 - "$work" <<'PY'
from pathlib import Path
import json,hashlib,platform,subprocess,sys
root=Path(sys.argv[1]);paths=[p for p in [root/'current',root/'reference'] if p.exists()]
(root/'build.json').write_text(json.dumps({'platform':platform.platform(),'flags':['-debug','-o:speed'],'odin':subprocess.check_output(['odin','version'],text=True).strip(),'binaries':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}},indent=2)+'\n')
PY
for pair in 1 2 3;do
 order=current;if [[ -e "$work/reference" ]];then order='reference current';if [[ "$pair" == 2 ]];then order='current reference';fi;fi
 for version in $order;do "$work/$version" >"$work/$pair-$version.log";done
done
python3 "$ROOT/tests/replay_schema_bench/report.py" "$work"
python3 "$ROOT/tests/replay_schema_bench/verify_report.py" "$work"
odin build "$ROOT/tests/replay_schema_bench/wasm" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point -out:"$work/large.wasm"
node "$ROOT/tests/replay_schema_bench/wasm_compare.mjs" "$work/large.wasm" "$work/summary.json"
echo REPLAY_SCHEMA_BENCH_OK
