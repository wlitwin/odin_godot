#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"
writer=""
cleanup() { if [[ -n "$writer" ]]; then kill "$writer" 2>/dev/null || true; wait "$writer" 2>/dev/null || true; fi; rm -rf "$work"; }
trap cleanup EXIT
"${ODIN:-odin}" test "$ROOT/tests/replay_authority_sqlite" -collection:godot="$ROOT" -define:REPLAY_SQLITE_TEST_DIR="$work" -out:"$work/store_tests"
"${ODIN:-odin}" build "$ROOT/tests/replay_authority_sqlite/crash" -collection:godot="$ROOT" -out:"$work/crash"
"$work/crash" create "$work/crash.sqlite3"
"$work/crash" uncommitted "$work/crash.sqlite3" >"$work/writer.log" 2>&1 &
writer=$!
for _ in {1..100}; do if grep -q REPLAY_SQLITE_UNCOMMITTED "$work/writer.log"; then break; fi; sleep 0.05; done
grep -q REPLAY_SQLITE_UNCOMMITTED "$work/writer.log" || { cat "$work/writer.log"; exit 1; }
kill -KILL "$writer"; wait "$writer" 2>/dev/null || true; writer=""
"$work/crash" verify "$work/crash.sqlite3"
echo REPLAY_AUTHORITY_SQLITE_OK
