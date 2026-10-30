#!/usr/bin/env bash
set -euo pipefail
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSY_ARMORY=ordnance bash "$PROJ/combat_run.sh"
RSY_ARMORY=mend REPLAY_PREBUILT=1 bash "$PROJ/combat_run.sh"
echo REPLAY_SCRAPYARD_WEAPONS_OK
