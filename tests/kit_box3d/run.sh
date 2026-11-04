#!/usr/bin/env bash
# Actual Kit lane + optional Box3D provider. Requires a test-enabled static
# archive: controlled native allocation/import failpoints are intentionally used.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
LIBRARY=${1:?pass an absolute test-enabled libogb3.a path}
OUTPUT=${2:-"${TMPDIR:-/tmp}/kit-box3d-tests"}
MODE=${3:-Debug}
FLAGS=()
case "$MODE" in Debug) FLAGS+=(-debug);; Release) FLAGS+=(-o:speed);; *) exit 2;; esac
if [[ "$(uname -s)" == Darwin ]]; then FLAGS+=(-minimum-os-version:15.0); fi
cd "$REPO"
odin test tests/kit_box3d -collection:godot=. -define:ODIN_TEST_THREADS=1 \
  "-define:BOX3D_LIBRARY=$LIBRARY" "-out:$OUTPUT" "${FLAGS[@]}"
