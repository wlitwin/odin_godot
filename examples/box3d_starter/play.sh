#!/usr/bin/env bash
# Source-checkout convenience; the shipped starter uses the ordinary installed SDK.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$ROOT/examples/box3d_starter"
if [[ ! -f "$PROJECT/addons/odin_godot/odin_godot.gdextension" ]]; then
    RECEIPT="$(mktemp -t odin-box3d-starter-sdk.XXXXXX)"
    nix build "$ROOT" --no-link --json > "$RECEIPT"
    python3 - "$RECEIPT" "$PROJECT" <<'PY'
import json,pathlib,shutil,sys
sdk=pathlib.Path(json.load(open(sys.argv[1]))[0]['outputs']['out'])/'addons'
addons=pathlib.Path(sys.argv[2])/'addons'
for name in ['odin_godot','box3d_authoring']:
    if (addons/name).exists():
        raise SystemExit(f'Existing {addons/name} is preserved. Install/update both SDK addon directories explicitly.')
for name in ['odin_godot','box3d_authoring']:
    shutil.copytree(sdk/name,addons/name)
    (addons/name).chmod((addons/name).stat().st_mode | 0o200)
    for path in (addons/name).rglob('*'):
        path.chmod(path.stat().st_mode | 0o200)
PY
fi
case "$(uname -s)" in
    Darwin) target=macos; extension=dylib ;;
    Linux) target=linux; extension=so ;;
    *) echo 'Use the installed SDK PowerShell build helper on Windows.' >&2; exit 1 ;;
esac
if [[ -z "${BOX3D_NATIVE_LIBRARY:-}" &&
      ! -f "$PROJECT/.godot/odin_godot/toolchain/box3d_native_$target" &&
      ! -f "$PROJECT/addons/odin_godot/bin/$target/box3d-runtime.json" ]]; then
    bash "$ROOT/build/build_box3d.sh" Release "$ROOT/.box3d-cache"
    export BOX3D_NATIVE_LIBRARY="$ROOT/.box3d-cache/build/Release/libogb3.$extension"
fi
ODIN_GODOT_ROOT="$PROJECT/addons/odin_godot" bash "$PROJECT/addons/odin_godot/build/build_scripts.sh" "$PROJECT"
exec "$GODOT" --path "$PROJECT" "$@"
