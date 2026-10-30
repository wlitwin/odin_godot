#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPLAY_MIGRATION_MODE=return bash "$HERE/run.sh"
REPLAY_PREBUILT=1 REPLAY_MIGRATION_MODE=repeat bash "$HERE/run.sh"
echo REPLAY_MIGRATION_EXTENDED_OK
