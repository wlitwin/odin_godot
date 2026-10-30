#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPLAY_CAVE_LOBBY=1 REPLAY_MIGRATION_SCRIPT=lobby_migration_test.gd REPLAY_MIGRATION_MODE=planned bash "$HERE/run.sh"
REPLAY_CAVE_LOBBY=1 REPLAY_MIGRATION_SCRIPT=lobby_waiting_migration.gd REPLAY_MIGRATION_MODE=crash bash "$HERE/run.sh"
echo REPLAY_CAVE_LOBBY_MIGRATION_OK
