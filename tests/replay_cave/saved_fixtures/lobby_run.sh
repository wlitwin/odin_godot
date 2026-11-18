#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPLAY_CAVE_SAVED_CASE=lobby bash "$HERE/run.sh"
echo REPLAY_CAVE_LOBBY_SAVE_OK
