#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -z "${BOX3D_NATIVE_LIBRARY:-}" ]]; then
    case "$(uname -s)" in Darwin) extension=dylib ;; Linux) extension=so ;; *) exit 1 ;; esac
    bash "$ROOT/build/build_box3d.sh" Release "$ROOT/.box3d-cache"
    export BOX3D_NATIVE_LIBRARY="$ROOT/.box3d-cache/build/Release/libogb3.$extension"
fi
ARCHIVE="$(dirname "$BOX3D_NATIVE_LIBRARY")/libogb3.a"
OUTPUT="$(mktemp -d -t odin-complete-owner-units.XXXXXX)"
cd "$ROOT"
"${ODIN:-odin}" test box3d/godot/meter/tests -collection:godot="$ROOT" -define:ODIN_TEST_THREADS=1 -out:"$OUTPUT/meter"
"${ODIN:-odin}" test tests/replay_physics_net/native -collection:godot="$ROOT" -define:ODIN_TEST_THREADS=1 -define:BOX3D_LIBRARY="$ARCHIVE" -out:"$OUTPUT/replay"
bash tests/kit_box3d/run.sh "$ARCHIVE" "$OUTPUT/kit" Release
python3 tests/complete_physics_owner/run.py --native-library "$BOX3D_NATIVE_LIBRARY"
