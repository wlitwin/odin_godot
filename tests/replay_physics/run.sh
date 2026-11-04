#!/usr/bin/env bash
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
LIBRARY=${1:?pass an absolute integrated libogb3 archive or shared library}
OUTPUT=${2:-"${TMPDIR:-/tmp}/replay-physics-tests"}
cd "$REPO"
odin test tests/replay_physics -collection:godot=. -define:ODIN_TEST_THREADS=1 \
  "-define:BOX3D_LIBRARY=$LIBRARY" "-out:$OUTPUT"
