#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
work="$(mktemp -d)";trap 'rm -rf "$work"' EXIT
cp "$ROOT/tests/replay_scrapyard/fixtures/mod-junk.json" "$work/junk.json"
export RSY_MIGRATION_MODS=1 RSY_MODS_DIR="$work"
bash "$ROOT/examples/replay_scrapyard/migration_run.sh"
echo REPLAY_SCRAPYARD_MOD_MIGRATION_OK
