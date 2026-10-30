#!/usr/bin/env bash
set -euo pipefail
REPLAY_MIGRATION_MODE=crash bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run.sh"
