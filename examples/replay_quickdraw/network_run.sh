#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_quickdraw"
work="$(mktemp -d)"
pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; if [[ "${REPLAY_KEEP_LOGS:-0}" == 1 ]]; then echo "Quickdraw logs: $work"; else rm -rf "$work"; fi; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
phases=(rewound live lobs)
if [[ "${REPLAY_QUICKDRAW_LOBS_ONLY:-0}" == 1 ]]; then phases=(lobs); fi
for phase in "${phases[@]}"; do
  port=$((40000 + RANDOM % 20000))
  norewind=0; [[ "$phase" == live ]] && norewind=1
  seconds=30; attacker=deadeye; nolob=1; gold=0
  if [[ "$phase" == lobs ]]; then seconds=12; attacker=lobber; nolob=0; gold=1; fi
  RQ_ROLE=server RQ_PORT="$port" RQ_LATENCY=120 RQ_NOREWIND="$norewind" RQ_GOLD="$gold" RQ_TEST_SECONDS="$seconds" \
    "$GODOT" --headless --path "$PROJ" >"$work/$phase-server.log" 2>&1 &
  pids+=("$!")
  for _ in {1..100}; do if grep -q REPLAY_QUICKDRAW_READY "$work/$phase-server.log"; then break; fi; sleep 0.05; done
  for bot in strafer "$attacker"; do
    RQ_ROLE=client RQ_BOT="$bot" RQ_TOKEN="$bot" RQ_PORT="$port" RQ_LATENCY=120 RQ_NOLOB="$nolob" RQ_TEST_SECONDS="$seconds" \
      "$GODOT" --headless --path "$PROJ" >"$work/$phase-$bot.log" 2>&1 &
    pids+=("$!")
    if [[ "$bot" == strafer ]]; then
      for _ in {1..150}; do if grep -q 'RQ_SEATED seat=1' "$work/$phase-strafer.log"; then break; fi; sleep 0.05; done
    fi
  done
  deadline=$((SECONDS + 40))
  while ((SECONDS < deadline)); do
    alive=0; for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then alive=1; fi; done
    if ((alive == 0)); then break; fi
    sleep 0.1
  done
  if ((SECONDS >= deadline)); then cat "$work"/*.log; exit 1; fi
  failed=0; for pid in "${pids[@]}"; do wait "$pid" || failed=1; done; pids=()
  cat "$work/$phase-server.log" "$work/$phase-strafer.log" "$work/$phase-$attacker.log"
  ((failed == 0))
  for role in server strafer "$attacker"; do grep -q REPLAY_QUICKDRAW_PROCESS_OK "$work/$phase-$role.log"; done
  if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_QUICKDRAW_FAIL|ObjectDB instances were leaked' "$work/$phase-"*.log; then exit 1; fi
  node "$PROJ/check_network.mjs" "$phase" "$work/$phase-server.log" "$work/$phase-strafer.log" "$work/$phase-$attacker.log"
  if [[ "$phase" == lobs ]]; then continue; fi
  hits="$(grep -c 'RQ_HIT by=2 on=1' "$work/$phase-server.log" || true)"
  if [[ "$phase" == rewound ]]; then hits_a="$hits"; else hits_b="$hits"; fi
done
if [[ "${REPLAY_QUICKDRAW_LOBS_ONLY:-0}" == 1 ]]; then echo REPLAY_QUICKDRAW_LOBS_OK; exit 0; fi
if ((hits_a < 6 || hits_b > 3 || hits_a < hits_b + 4)); then echo "REPLAY_QUICKDRAW_FAIL rewind=$hits_a live=$hits_b"; exit 1; fi
echo "REPLAY_QUICKDRAW_NETWORK_OK rewind=$hits_a live=$hits_b"
