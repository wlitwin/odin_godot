#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SDK="${BOX3D_SETUP_SDK:-}"
if [[ -z "$SDK" ]]; then
    RECEIPT="$(mktemp -t odin-box3d-setup-sdk.XXXXXX)"
    nix build "$ROOT" --no-link --json > "$RECEIPT"
    SDK="$(python3 - "$RECEIPT" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))[0]['outputs']['out'])
PY
)"
fi
python3 "$ROOT/tests/box3d_editor/setup/run.py" --sdk "$SDK"
