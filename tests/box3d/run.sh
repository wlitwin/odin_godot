#!/usr/bin/env bash
# Usage: nix develop --command bash tests/box3d/run.sh /absolute/libogb3.a [output]
# The engine/allocator/world domain and the initial wrapper are single-caller.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
LIBRARY=${1:?pass an absolute integrated libogb3.a path}
OUTPUT=${2:-"${TMPDIR:-/tmp}/ogb3-odin-lifecycle"}
cd "$REPO"
odin test tests/box3d -collection:godot=. -define:ODIN_TEST_THREADS=1 \
  "-define:BOX3D_LIBRARY=$LIBRARY" "-out:$OUTPUT"
