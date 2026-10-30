#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
RCB_CONTEST=1 RCB_TEST_GOALS=3 bash "$ROOT/examples/replay_claimball/network_run.sh"
