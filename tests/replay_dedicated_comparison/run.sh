#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
if [[ ! -f "$ROOT/../scrapyard/project.godot" ]];then
 echo "REPLAY_COMPARISON_BASELINE_MISSING: requires the original sibling Scrapyard project"
 exit 0
fi
work="${REPLAY_DEDICATED_COMPARISON_OUT:-$(mktemp -d)}";mkdir -p "$work"
bash "$ROOT/tests/replay_dedicated_comparison/build.sh" "$work"
python3 "$ROOT/tests/replay_dedicated_comparison/execute.py" "$work" comparison
python3 "$ROOT/tests/replay_dedicated_comparison/report.py" "$work" comparison
echo REPLAY_DEDICATED_COMPARISON_COMPLETE_OK
