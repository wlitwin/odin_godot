#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
writer=""
cleanup() { if [[ -n "$writer" ]]; then kill "$writer" 2>/dev/null || true; wait "$writer" 2>/dev/null || true; fi; rm -rf "$work"; }
trap cleanup EXIT
"${ODIN:-odin}" test "$ROOT/tests/replay_provision_sqlite" -collection:godot="$ROOT" -define:REPLAY_PROVISION_TEST_DIR="$work" -out:"$work/store_tests"
"${ODIN:-odin}" check "$ROOT/replay/provision/checkpoint" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point
"${ODIN:-odin}" build "$ROOT/tests/replay_provision_sqlite/crash" -collection:godot="$ROOT" -out:"$work/crash"
for phase in uncommitted committed; do
    path="$work/$phase.sqlite3"
    "$work/crash" create "$path"
    "$work/crash" "$phase" "$path" >"$work/writer.log" 2>&1 &
    writer=$!
    marker="REPLAY_PROVISION_$(echo "$phase" | tr '[:lower:]' '[:upper:]')"
    for _ in {1..100}; do if rg -q "$marker" "$work/writer.log"; then break; fi; sleep 0.05; done
    rg -q "$marker" "$work/writer.log" || { cat "$work/writer.log"; exit 1; }
    kill -KILL "$writer"; wait "$writer" 2>/dev/null || true; writer=""
    "$work/crash" "verify-$phase" "$path"
done
"${ODIN:-odin}" build "$ROOT/tests/replay_provision_sqlite/publication_crash" -collection:godot="$ROOT" -out:"$work/publication_crash"
for phase in uncommitted committed; do
    path="$work/publication-$phase.sqlite3"
    "$work/publication_crash" create "$path"
    "$work/publication_crash" "$phase" "$path" >"$work/publication-writer.log" 2>&1 &
    writer=$!
    marker="REPLAY_PUBLICATION_$(echo "$phase" | tr '[:lower:]' '[:upper:]')"
    for _ in {1..100}; do if rg -q "$marker" "$work/publication-writer.log"; then break; fi; sleep 0.05; done
    rg -q "$marker" "$work/publication-writer.log" || { cat "$work/publication-writer.log"; exit 1; }
    kill -KILL "$writer"; wait "$writer" 2>/dev/null || true; writer=""
    "$work/publication_crash" "verify-$phase" "$path"
done
"${ODIN:-odin}" build "$ROOT/tests/replay_provision_sqlite/restore_crash" -collection:godot="$ROOT" -out:"$work/restore_crash"
for phase in uncommitted committed; do
    path="$work/restore-$phase.sqlite3"
    "$work/restore_crash" create "$path"
    "$work/restore_crash" "$phase" "$path" >"$work/restore-writer.log" 2>&1 &
    writer=$!
    marker="REPLAY_RESTORE_$(echo "$phase" | tr '[:lower:]' '[:upper:]')"
    for _ in {1..100}; do if rg -q "$marker" "$work/restore-writer.log"; then break; fi; sleep 0.05; done
    rg -q "$marker" "$work/restore-writer.log" || { cat "$work/restore-writer.log"; exit 1; }
    kill -KILL "$writer"; wait "$writer" 2>/dev/null || true; writer=""
    "$work/restore_crash" "verify-$phase" "$path"
done
echo REPLAY_PUBLISHED_RESTORE_SQLITE_OK
echo REPLAY_PROVISION_SQLITE_OK
