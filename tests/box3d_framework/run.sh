#!/usr/bin/env bash
# Run actual Kit/Replay paired ownership tests and the pending-end native probe.
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../.." && pwd)
LIBRARY=${1:?pass the coherent absolute libogb3.a path}
OUTPUT=${2:-$(mktemp -d)}
MODE=${3:-Debug}
mkdir -p "$OUTPUT"
case "$MODE" in
  Debug) odin_flags=(-debug) ;;
  Release) odin_flags=(-o:speed) ;;
  *) printf 'mode must be Debug or Release\n' >&2; exit 2 ;;
esac
system_libraries=()
if [[ $(uname -s) == Darwin ]]; then
  # The currently observed alpha target is macOS 15.8, not a claim for older OSes.
  odin_flags+=("-minimum-os-version:${BOX3D_FRAMEWORK_MIN_MACOS:-15.0}")
else
  system_libraries+=(-lm)
fi
if ! "${ODIN:-odin}" test "$REPO/tests/box3d_framework" \
  "-collection:godot=$REPO" -define:ODIN_TEST_THREADS=1 \
  "-define:BOX3D_LIBRARY=$LIBRARY" "${odin_flags[@]}" \
  "-out:$OUTPUT/framework-tests" >"$OUTPUT/odin.log" 2>&1; then
  cat "$OUTPUT/odin.log"
  exit 1
fi
"${CC:-cc}" -std=c17 -UNDEBUG -I"$REPO/box3d/native" \
  "$REPO/tests/box3d_framework/pending_end_probe.c" "$LIBRARY" \
  "${system_libraries[@]}" -o "$OUTPUT/pending-end-probe" \
  >"$OUTPUT/probe-build.log" 2>&1
"$OUTPUT/pending-end-probe" >"$OUTPUT/probe.log" 2>&1
printf 'BOX3D_FRAMEWORK_OK mode=%s evidence=%s\n' "$MODE" "$OUTPUT"
