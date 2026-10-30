#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)"; writer=""
cleanup() {
    if [[ -n "$writer" ]]; then kill "$writer" 2>/dev/null || true; wait "$writer" 2>/dev/null || true; fi
    rm -rf "$work"
}
trap cleanup EXIT
odin test "$ROOT/tests/replay_p2p_provision_sqlite" -collection:godot="$ROOT" -define:REPLAY_P2P_PROVISION_TEST_DIR="$work" -out:"$work/test"
odin build "$ROOT/tests/replay_p2p_provision_sqlite/crash" -collection:godot="$ROOT" -out:"$work/crash"
for phase in uncommitted committed; do
    path="$work/$phase.sqlite3"
    "$work/crash" create "$path"
    "$work/crash" "$phase" "$path" >"$work/writer.log" 2>&1 & writer=$!
    marker="P2P_PROVISION_$(echo "$phase" | tr '[:lower:]' '[:upper:]')"
    for _ in {1..100}; do
        if rg -q "$marker" "$work/writer.log"; then break; fi
        sleep .05
    done
    rg -q "$marker" "$work/writer.log" || { cat "$work/writer.log"; exit 1; }
    kill -KILL "$writer"; wait "$writer" 2>/dev/null || true; writer=""
    "$work/crash" "verify-$phase" "$path"
done
echo REPLAY_P2P_PROVISION_SQLITE_OK
