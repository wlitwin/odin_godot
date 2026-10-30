#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RCB_SOCIAL=1 RCB_MODES="${RCB_MODES:-planned crash}" bash "$HERE/web_run.sh"
echo REPLAY_CAVE_SOCIAL_WEB_OK
