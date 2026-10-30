#!/usr/bin/env bash
set -euo pipefail
PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RSY_ARMORY=ballistic RSY_ENCOUNTER=mixed bash "$PROJ/combat_run.sh"
RSY_ARMORY=ballistic RSY_ENCOUNTER=boss REPLAY_PREBUILT=1 bash "$PROJ/combat_run.sh"
RSY_ARMORY=ballistic RSY_ENCOUNTER=barrels REPLAY_PREBUILT=1 bash "$PROJ/combat_run.sh"
echo REPLAY_SCRAPYARD_ENEMIES_OK
