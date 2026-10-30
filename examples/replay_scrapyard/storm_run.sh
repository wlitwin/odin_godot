#!/usr/bin/env bash
set -euo pipefail
export RSY_STORM=1
bash "$(dirname "${BASH_SOURCE[0]}")/abilities_run.sh"
echo REPLAY_SCRAPYARD_STORM_OK
