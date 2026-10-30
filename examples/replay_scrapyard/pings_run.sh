#!/usr/bin/env bash
set -euo pipefail
export RSY_PING_TEST=1
bash "$(dirname "${BASH_SOURCE[0]}")/chat_run.sh"
