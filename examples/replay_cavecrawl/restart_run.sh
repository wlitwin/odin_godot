#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPLAY_CAMPAIGN_RESTART=1 bash "$HERE/campaign_run.sh"
