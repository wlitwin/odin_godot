#!/usr/bin/env bash
set -euo pipefail
export RSY_MIGRATION_STAGE=lobby
exec bash "$(dirname "${BASH_SOURCE[0]}")/migration_run.sh"
