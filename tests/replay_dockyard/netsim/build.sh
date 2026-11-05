#!/usr/bin/env bash
# Build the Dockyard network harness. Run inside `nix develop`.
#   build.sh /abs/libogb3.dylib /abs/definition.json /abs/out-dir
set -euo pipefail
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
LIBRARY=${1:?absolute libogb3.dylib}
DEFINITION=${2:?absolute definition.json extracted by tests/replay_dockyard/rounds/extract.gd}
OUT=${3:?output directory}
mkdir -p "$OUT"
cp "$LIBRARY" "$OUT/"
attrs=()
for name in gd_method gd_connect gd_rpc gd_command gd_tick gd_input gd_sample gd_step gd_event gd_half gd_message; do
  attrs+=("-custom-attribute:$name")
done
odin build "$REPO/tests/replay_dockyard/netsim" "-collection:godot=$REPO" \
  "-define:BOX3D_LIBRARY=$LIBRARY" "-define:DOCKYARD_DEFINITION=$DEFINITION" \
  -o:speed "${attrs[@]}" "-out:$OUT/netsim"
