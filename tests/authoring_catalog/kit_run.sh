#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
export ODIN_GODOT_ROOT="$ROOT"
if [[ ! -f "$ROOT/../scrapyard/project.godot" ]]; then echo KIT_CATALOG_GAME_MISSING; exit 0; fi
work="${KIT_CATALOG_OUT:-$(mktemp -d)}"
echo "Kit catalog logs: $work"
python3 "$ROOT/tests/replay_scrapyard/prepare_baseline.py" "$ROOT/../scrapyard" "$work/project" "$ROOT"
project="$work/project"
cp "$ROOT/tests/authoring_catalog/kit_probe.odin" "$project/scripts/catalog_probe.odin"
cp "$ROOT/tests/authoring_catalog/kit_driver.gd" "$project/catalog_test.gd"
bash "$ROOT/build/build_scripts.sh" "$project" >"$work/build.log" 2>&1
case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
source "$ROOT/tests/import_project.sh"
odin_godot_test_import "$project" "$ODIN_SCRIPTS_DLL" "$work/import.log"
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$work/wait.json"
SY_MODS_DIR="$work/no-mods" python3 - "$project" "$work/runtime.log" <<'PY'
import os,subprocess,sys
with open(sys.argv[2], 'w') as log:
 subprocess.run([os.environ['GODOT'],'--headless','--path',sys.argv[1],'--script','catalog_test.gd'],stdout=log,stderr=subprocess.STDOUT,check=True,timeout=45)
PY
rg -q KIT_CATALOG_ADMISSION_OK "$work/runtime.log"
if rg -n 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work/runtime.log"; then exit 1; fi
source "$ROOT/build/common.sh"
"$ODIN" check "$project/scripts" -collection:godot="$ROOT" -target:freestanding_wasm32 -no-entry-point "${ODIN_GD_ATTRS[@]}" >"$work/wasm.log" 2>&1
echo KIT_CATALOG_ADMISSION_OK
