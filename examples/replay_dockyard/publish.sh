#!/usr/bin/env bash
# Create an itch.io HTML5 ZIP from a prepared Dockyard candidate.
# Add --push USER/GAME to upload that exact bundle with Butler.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -B "$HERE/publish.py" "$@"
