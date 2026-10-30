#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="${RCB_LOGS:-$(mktemp -d)}"
RCB_LOBBY=1 RCB_SOCIAL=1 RCB_LOGS="$work" RCB_PROFILE_ROOT="$work/profiles" RCB_MODES="${RCB_MODES:-planned crash}" bash "$HERE/web_run.sh"
echo REPLAY_CAVE_LOBBY_WEB_OK
