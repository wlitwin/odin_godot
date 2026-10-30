#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_cavecrawl"
work="$(mktemp -d)"
pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done; rm -rf "$work"; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export REPLAY_CAVE_PORT=$((40000 + RANDOM % 20000))
export REPLAY_CAVE_LATENCY="${REPLAY_CAVE_LATENCY:-120}"
for role in host client; do
    REPLAY_CAVE_ROLE="$role" REPLAY_CAVE_TOKEN="cave-test-$role" "$GODOT" --headless --path "$PROJ" --script "${REPLAY_CAVE_TEST_SCRIPT:-network_test.gd}" >"$work/$role.log" 2>&1 &
    pids+=("$!")
    if [[ "$role" == host ]]; then
        for _ in {1..100}; do if grep -q REPLAY_CAVE_READY "$work/host.log"; then break; fi; sleep 0.05; done
    fi
done
deadline=$((SECONDS + 30))
while ((SECONDS < deadline)); do
    live=0
    for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
    if ((live == 0)); then break; fi
    sleep 0.05
done
if ((SECONDS >= deadline)); then cat "$work"/*.log; echo REPLAY_CAVE_NETWORK_FAIL_TIMEOUT; exit 1; fi
result=0
for pid in "${pids[@]}"; do wait "$pid" || result=1; done
pids=()
cat "$work/host.log" "$work/client.log"
((result == 0))
grep -q '^REPLAY_CAVE_NETWORK_HOST_OK' "$work/host.log"
grep -q '^REPLAY_CAVE_NETWORK_CLIENT_OK' "$work/client.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_CAVE.*FAIL|ObjectDB instances were leaked' "$work"/*.log; then exit 1; fi
echo REPLAY_CAVE_NETWORK_OK
