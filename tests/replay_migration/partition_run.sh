#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPLAY_MIGRATION_MODE=partition bash "$HERE/run.sh"
REPLAY_PREBUILT=1 REPLAY_MIGRATION_MODE=successor_loss bash "$HERE/run.sh"
echo REPLAY_MIGRATION_PARTITION_LOSS_OK
