#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export RDP_WEB_AUTH=1
export REPLAY_WEB_MODES="${REPLAY_WEB_MODES:-rejoin creator}"
exec bash "$ROOT/examples/replay_duel/web_run.sh"
