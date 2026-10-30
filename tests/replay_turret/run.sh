#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$ROOT"
work="${REPLAY_TURRET_OUT:-$(mktemp -d "${TMPDIR:-/tmp}/replay-turret.XXXXXX")}";export REPLAY_TURRET_OUT="$work"
mkdir -p "$work"
python3 examples/replay_scrapyard/tools/stock.py --check
odin test tests/replay_turret/model -collection:godot="$ROOT" -out:"$work/model"
bash tests/replay_turret/corpus.sh "$work/corpus"
bash tests/replay_turret/build.sh
python3 tests/replay_turret/execute.py "$work"
bash tests/replay_editor/migration_build.sh "$work/coordinator"
python3 tests/replay_turret/migration.py "$work/project" "$work/coordinator/project" "$work/migration"
echo "REPLAY_TURRET_OK $work"
