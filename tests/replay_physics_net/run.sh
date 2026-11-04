#!/usr/bin/env bash
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
LIBRARY=${1:?pass the current absolute libogb3 archive path}
WORK=${2:?pass an owned scratch output directory}
mkdir -p "$WORK"
cd "$REPO"
odin test tests/replay_physics_net -collection:godot=. -define:ODIN_TEST_THREADS=1 "-out:$WORK/generic"
odin test tests/replay_physics_net/native -collection:godot=. -define:ODIN_TEST_THREADS=1 \
  "-define:BOX3D_LIBRARY=$LIBRARY" "-out:$WORK/native"
odin check tests/replay_physics_net/godot_check -collection:godot=. -no-entry-point
