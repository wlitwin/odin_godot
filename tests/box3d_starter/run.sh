#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SDK="${BOX3D_STARTER_SDK:-}"
if [[ -z "$SDK" ]]; then
    RECEIPT="$(mktemp -t odin-box3d-starter-sdk.XXXXXX)"
    nix build "$ROOT" --no-link --json > "$RECEIPT"
    SDK="$(python3 - "$RECEIPT" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))[0]['outputs']['out'])
PY
)"
fi
if [[ -z "${BOX3D_NATIVE_LIBRARY:-}" ]]; then
    case "$(uname -s)" in
        Darwin) extension=dylib ;;
        Linux) extension=so ;;
        *) echo 'Set BOX3D_NATIVE_LIBRARY to the matching shared backend.' >&2; exit 1 ;;
    esac
    bash "$ROOT/build/build_box3d.sh" Release "$ROOT/.box3d-cache"
    export BOX3D_NATIVE_LIBRARY="$ROOT/.box3d-cache/build/Release/libogb3.$extension"
fi
python3 "$ROOT/tests/box3d_starter/run.py" --sdk "$SDK" --native-library "$BOX3D_NATIVE_LIBRARY" "$@"
