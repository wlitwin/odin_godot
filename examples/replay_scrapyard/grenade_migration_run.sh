#!/usr/bin/env bash
set -euo pipefail
export RSY_GRENADE_MIGRATION=1
exec bash "$(dirname "${BASH_SOURCE[0]}")/migration_run.sh"
