#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPLAY_CAVE_SOURCE_VERSION=2 bash "$HERE/run.sh"
echo REPLAY_CAVE_CONTENT2_UPGRADE_OK
