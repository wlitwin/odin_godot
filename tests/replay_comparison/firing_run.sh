#!/usr/bin/env bash
set -euo pipefail
export REPLAY_COMPARISON_SCENARIO=firing
export REPLAY_COMPARISON_DIR="${REPLAY_COMPARISON_DIR:-$(mktemp -d)}"
bash "$(dirname "${BASH_SOURCE[0]}")/run.sh"
# Missing sibling projects produce an explicit SKIP without a summary.
if [[ -f "$REPLAY_COMPARISON_DIR/summary.json" ]];then
 python3 "$(dirname "${BASH_SOURCE[0]}")/verify_report.py" "$REPLAY_COMPARISON_DIR"
fi
