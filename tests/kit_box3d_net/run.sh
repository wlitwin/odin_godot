#!/usr/bin/env bash
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
LIBRARY=${1:?pass current recovery-enabled archive}
OUTPUT=${2:-"${TMPDIR:-/tmp}/kit-box3d-network"}
MODE=${3:-Debug}
FLAGS=()
case "$MODE" in Debug) FLAGS+=(-debug);; Release) FLAGS+=(-o:speed);; *) exit 2;; esac
if [[ "$(uname -s)" == Darwin ]]; then FLAGS+=(-minimum-os-version:15.0); fi
cd "$REPO"
odin test tests/kit_box3d_net -collection:godot=. -define:ODIN_TEST_THREADS=1 -define:KIT_PHYSICS_TEST_HOOKS=true -keep-executable \
 "-define:BOX3D_LIBRARY=$LIBRARY" "-define:KIT_NETWORK_TRACE_PATH=$OUTPUT.trace" "-out:$OUTPUT" "${FLAGS[@]}"
