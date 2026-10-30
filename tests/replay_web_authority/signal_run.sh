#!/usr/bin/env bash
set -euo pipefail
export RWA_SIGNAL=1
bash "$(dirname "${BASH_SOURCE[0]}")/run.sh"
