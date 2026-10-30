#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/examples/replay_hello"
work="$(mktemp -d)"
pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done; rm -rf "$work"; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export REPLAY_PORT=$((40000 + RANDOM % 20000))
export REPLAY_LATENCY="${REPLAY_LATENCY:-120}"
REPLAY_ROLE=server "$GODOT" --headless --path "$PROJ" --script network_test.gd >"$work/server.log" 2>&1 &
pids+=("$!")
for _ in {1..100}; do
    if grep -q REPLAY_NETWORK_HOST_READY "$work/server.log"; then break; fi
    sleep 0.05
done
if ! grep -q REPLAY_NETWORK_HOST_READY "$work/server.log"; then cat "$work/server.log"; exit 1; fi
for label in a b observer; do
    role=client
    if [[ "$label" == observer ]]; then role=observer; fi
    REPLAY_ROLE="$role" REPLAY_TOKEN="replay-test-$label" "$GODOT" --headless --path "$PROJ" --script network_test.gd >"$work/$label.log" 2>&1 &
    pids+=("$!")
done
deadline=$((SECONDS + 30))
while ((SECONDS < deadline)); do
    live=0
    for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
    if ((live == 0)); then break; fi
    sleep 0.05
done
if ((SECONDS >= deadline)); then cat "$work"/*.log; echo REPLAY_NETWORK_TEST_FAIL_TIMEOUT; exit 1; fi
result=0
for pid in "${pids[@]}"; do wait "$pid" || result=1; done
pids=()
cat "$work/server.log" "$work/a.log" "$work/b.log" "$work/observer.log"
((result == 0))
grep -q '^REPLAY_NETWORK_SERVER_OK' "$work/server.log"
grep -q '^REPLAY_NETWORK_CLIENT_OK' "$work/a.log"
grep -q '^REPLAY_NETWORK_CLIENT_OK' "$work/b.log"
grep -q '^REPLAY_NETWORK_OBSERVER_OK' "$work/observer.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_NETWORK.*FAIL' "$work"/*.log; then exit 1; fi
echo REPLAY_NETWORK_OK
