#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for mode in planned crash;do
 REPLAY_MIGRATION_SCRIPT=social_migration_test.gd REPLAY_MIGRATION_MODE="$mode" bash "$HERE/run.sh"
done
echo REPLAY_CAVE_SOCIAL_MIGRATION_ALL_OK
