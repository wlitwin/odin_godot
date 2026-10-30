#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
source="${1:?Pass a completed full jam cohort}";work="${REPLAY_JAM_PROFILE_OUT:-$(mktemp -d)}";mkdir -p "$work";pids=();sample_pid=""
[[ -z "$(ls -A "$work")" ]] || { echo "Profile needs an empty output directory" >&2;exit 2; }
proof=();if [[ -n "${2:-}" ]];then proof+=("$2");fi
requested_interval="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1])).get("snapshot_every",1))' "$source/run-plan.json")"
export RSY_SNAPSHOT_EVERY="${RSY_SNAPSHOT_EVERY:-$requested_interval}"
python3 "$ROOT/tests/replay_jam_comparison/profile_provenance.py" "$source" "$work/provenance.json" "${proof[@]}"
case "$(uname -s)" in Darwin) ext=dylib;;Linux) ext=so;;*) exit 2;;esac
project="$source/replay/project";port=$((40000+RANDOM%10000))
trap '[[ -z "$sample_pid" ]] || { kill "$sample_pid" 2>/dev/null || true;wait "$sample_pid" 2>/dev/null || true; };for pid in "${pids[@]}";do kill "$pid" 2>/dev/null || true;wait "$pid" 2>/dev/null || true;done;echo "Jam phase profile logs: $work"' EXIT
for role in host client;do
 COMPARE_PHASES=1 COMPARE_CONDITION=delay COMPARE_REUSE_EQUAL=0 COMPARE_IMPL=replay COMPARE_ROLE="$role" COMPARE_DIR="$work" RSY_RESULT_DIR="$work" \
 RSY_TRACE=0 RSY_DEV=1 RSY_ROLE="$role" RSY_NAME="$role" RSY_TOKEN="endurance-$role" RSY_SEED=1337 RSY_RUN=1 RSY_WAVE_BASE=0 RSY_WAVE_GROWTH=0 RSY_WAVES=1 RSY_BARRELS=0 RSY_MOBS=0 RSY_PERSIST=0 RSY_MODS_DIR="$work/no-mods" RSY_SPRAY="$work/no-spray.png" RSY_REQUIRE_STOCK=0 RSY_LATENCY=120 RSY_JITTER=0 RSY_LOSS=0 RSY_DUPLICATE=0 RSY_RESUME=0 RSY_PORT="$port" RSY_AUDIO=0 \
 ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext" "$GODOT" --headless --max-fps 60 --path "$project" --script comparison.gd >"$work/$role.log" 2>&1 &pids+=("$!")
 sleep .3
done
if [[ "${REPLAY_JAM_SAMPLE:-0}" == 1 ]];then
 [[ "$(uname -s)" == Darwin ]];command -v sample >/dev/null
 python3 - "$work/sample-plan.json" "${pids[1]}" <<'SAMPLE'
from pathlib import Path
import json,sys
Path(sys.argv[1]).write_text(json.dumps({'role':'client','pid':int(sys.argv[2]),'seconds':10,'interval_ms':1,'diagnostic_only':True})+'\n')
SAMPLE
fi
printf 'role,measuring,rss_kib\n' >"$work/rss.csv"
deadline=$((SECONDS+90))
while ((SECONDS<deadline));do
 live=0
 for i in 0 1;do
  pid="${pids[$i]}";label=host;[[ "$i" == 1 ]] && label=client
  if kill -0 "$pid" 2>/dev/null;then
   live=1;measuring=0;[[ -f "$work/measuring-$label.json" && ! -f "$work/sampled-$label.json" ]] && measuring=1
   rss=$({ ps -p "$pid" -o rss= 2>/dev/null || true; } | tr -d ' ')
   [[ -z "$rss" ]] || printf '%s,%s,%s\n' "$label" "$measuring" "$rss" >>"$work/rss.csv"
  fi
 done
 if [[ "${REPLAY_JAM_SAMPLE:-0}" == 1 && -z "$sample_pid" && -f "$work/measuring-client.json" && ! -f "$work/sampled-client.json" ]];then
  sample "${pids[1]}" 10 1 -mayDie -fullPaths -file "$work/client-sample.txt" >"$work/sample.log" 2>&1 &sample_pid=$!
 fi
 ((live==0)) && break
 if rg -q 'JAM_WORKLOAD_FAIL|REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:' "$work/"*.log;then cat "$work/"*.log;exit 1;fi
 sleep .1
done
if [[ -n "$sample_pid" ]];then wait "$sample_pid";sample_pid="";test -s "$work/client-sample.txt";fi
((SECONDS<deadline));for pid in "${pids[@]}";do wait "$pid";done;pids=()
for role in host client;do rg -q REPLAY_JAM_PEER_OK "$work/$role.log";rg -q 'RSY_BENCH .* dropped=0' "$work/$role.log";test -s "$work/timing-$role.csv";done
python3 "$ROOT/tests/replay_jam_comparison/profile_provenance.py" "$source" "$work/provenance-after.json" "${proof[@]}"
cmp "$work/provenance.json" "$work/provenance-after.json"
python3 "$ROOT/tests/replay_mixed_comparison/profile_report.py" "$work"
echo REPLAY_JAM_PHASE_PROFILE_OK
