#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
PROJ="$ROOT/tests/replay_authority_service"
work="$(mktemp -d)"
pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; done; rm -rf "$work"; }
trap cleanup EXIT
if [[ "${REPLAY_PREBUILT:-0}" != 1 ]]; then bash "$ROOT/build/build_scripts.sh" "$PROJ"; fi
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$PROJ/bin/libodinscripts.$ext"
if ! "$GODOT" --headless --path "$PROJ" --editor --quit-after 120 >"$work/import.log" 2>&1; then cat "$work/import.log"; exit 1; fi
if grep -Eq 'SCRIPT ERROR|ERROR:' "$work/import.log"; then cat "$work/import.log"; exit 1; fi
export REPLAY_SERVICE_PORT=$((40000 + RANDOM % 10000)) REPLAY_SERVICE_DB="$work/room.sqlite3"
REPLAY_SERVICE_ROLE=coordinator REPLAY_SERVICE_CREATE=1 "$GODOT" --headless --path "$PROJ" >"$work/service.log" 2>&1 &
coordinator=$!; pids+=("$coordinator")
for _ in {1..100}; do if grep -q REPLAY_SERVICE_READY "$work/service.log"; then break; fi; sleep 0.05; done
for role in owner successor; do
  REPLAY_SERVICE_ROLE="$role" "$GODOT" --headless --path "$PROJ" >"$work/$role.log" 2>&1 &
  pids+=("$!")
done
for _ in {1..300}; do
  if grep -q REPLAY_SERVICE_TRANSFER_READY "$work/successor.log"; then break; fi
  if grep -q REPLAY_SERVICE_FAIL "$work"/*.log; then cat "$work"/*.log; exit 1; fi
  sleep 0.05
done
if ! grep -q REPLAY_SERVICE_TRANSFER_READY "$work/successor.log"; then cat "$work"/*.log; exit 1; fi
# Let the old owner independently observe the new grant before crashing the service.
for _ in {1..100}; do if grep -q REPLAY_SERVICE_OLD_OWNER_FENCED "$work/owner.log"; then break; fi; sleep 0.05; done
grep -q REPLAY_SERVICE_OLD_OWNER_FENCED "$work/owner.log" || { cat "$work"/*.log; exit 1; }
kill -KILL "$coordinator"; wait "$coordinator" 2>/dev/null || true
pids[0]=""
REPLAY_SERVICE_ROLE=coordinator REPLAY_SERVICE_CREATE=0 "$GODOT" --headless --path "$PROJ" >"$work/restarted.log" 2>&1 &
coordinator=$!; pids[0]="$coordinator"
deadline=$((SECONDS + 30))
while ((SECONDS < deadline)); do
  if grep -q REPLAY_SERVICE_RESTART_OK "$work/successor.log"; then break; fi
  if grep -q REPLAY_SERVICE_FAIL "$work"/*.log; then cat "$work"/*.log; exit 1; fi
  sleep 0.05
done
cat "$work/service.log" "$work/owner.log" "$work/successor.log" "$work/restarted.log"
grep -q REPLAY_SERVICE_RESTART_OK "$work/successor.log"
grep -q 'generation=2 epoch=2' "$work/restarted.log"
for pid in "${pids[@]:1}"; do wait "$pid"; done
pids=("$coordinator")
if grep -Eq 'SCRIPT ERROR|ERROR:|REPLAY_SERVICE_FAIL|ObjectDB instances were leaked' "$work"/*.log; then exit 1; fi
record_bytes="$(sqlite3 "$REPLAY_SERVICE_DB" 'SELECT length(value) FROM replay_authority;')"
[[ "$record_bytes" -gt 0 ]]
echo REPLAY_AUTHORITY_SERVICE_OK
