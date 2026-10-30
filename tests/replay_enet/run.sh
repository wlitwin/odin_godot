#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_enet"
work="${REPLAY_ENET_OUT:-$(mktemp -d)}";mkdir -p "$work"
pids=()
cleanup() {
    for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
    if [[ -n "${REPLAY_ENET_OUT:-}" ]];then echo "ENet logs: $work";else rm -rf "$work";fi
}
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
port=$((40000 + RANDOM % 20000))
REPLAY_TRANSPORT_ROLE=host REPLAY_TRANSPORT_PORT="$port" "$GODOT" --headless --path "$PROJ" >"$work/host.log" 2>&1 &
pids+=("$!")
for _ in {1..100}; do
    if grep -q 'REPLAY_ENET_HOST_READY' "$work/host.log"; then break; fi
    sleep 0.05
done
if ! grep -q 'REPLAY_ENET_HOST_READY' "$work/host.log"; then cat "$work/host.log"; exit 1; fi
for role in client observer; do
    REPLAY_TRANSPORT_ROLE="$role" REPLAY_TRANSPORT_PORT="$port" "$GODOT" --headless --path "$PROJ" >"$work/$role.log" 2>&1 &
    pids+=("$!")
done
deadline=$((SECONDS + 25))
while ((SECONDS < deadline)); do
    live=0
    for pid in "${pids[@]}"; do if kill -0 "$pid" 2>/dev/null; then live=1; fi; done
    if ((live == 0)); then break; fi
    sleep 0.05
done
if ((SECONDS >= deadline)); then
    cat "$work/host.log" "$work/client.log" "$work/observer.log"
    echo "REPLAY_ENET_FAIL process timeout"; exit 1
fi
result=0
for pid in "${pids[@]}"; do wait "$pid" || result=1; done
pids=()
cat "$work/host.log" "$work/client.log" "$work/observer.log"
((result == 0))
grep -q '^REPLAY_ENET_SERVER_OK' "$work/host.log"
grep -q '^REPLAY_ENET_CLIENT_OK' "$work/client.log"
grep -q '^REPLAY_ENET_CLIENT_OK' "$work/observer.log"
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_ENET_FAIL' "$work/host.log" "$work/client.log" "$work/observer.log"; then exit 1; fi
echo "REPLAY_ENET_OK"
