#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
REPLAY_CAVE_TEST_SCRIPT=replication_test.gd REPLAY_CAVE_BACKUP=1 \
REPLAY_CAVE_LATENCY=120 REPLAY_CAVE_JITTER=20 REPLAY_CAVE_LOSS=1000 REPLAY_CAVE_DUPLICATE=1000 \
  bash "$ROOT/examples/replay_cavecrawl/network_run.sh"
echo REPLAY_CAVE_REPLICATION_OK
