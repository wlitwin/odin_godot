#!/usr/bin/env bash
set -euo pipefail
candidate="${BOX3D_REJECTED_CANDIDATE:?test candidate required}"
destination="${ODIN_SCRIPTS_DLL:?main script path required}"
# Match the build helper's atomic publication; never truncate a mapped dylib.
cp "$candidate" "$destination.rejected-stage"
mv -f "$destination.rejected-stage" "$destination"
