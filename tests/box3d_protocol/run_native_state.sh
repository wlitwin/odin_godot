#!/usr/bin/env bash
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
ARCHIVE=${1:?pass coherent absolute libogb3.a}
OUTPUT=${2:-$(mktemp -d)}
mkdir -p "$OUTPUT"
flags=()
if [[ $(uname -s) == Darwin ]]; then flags+=(-minimum-os-version:15.0); fi
"${ODIN:-odin}" test "$REPO/tests/box3d_protocol/native_state" \
  "-collection:godot=$REPO" "-define:BOX3D_LIBRARY=$ARCHIVE" \
  -define:ODIN_TEST_THREADS=1 -o:speed "${flags[@]}" \
  "-out:$OUTPUT/native-state-tests" >"$OUTPUT/tests.log" 2>&1
printf 'BOX3D_NATIVE_DIAGNOSTICS_OK evidence=%s\n' "$OUTPUT"
