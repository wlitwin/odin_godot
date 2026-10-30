#!/usr/bin/env bash
# Read-only extension/API inspection. No Steam initialization or lobby creation.
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
: "${GODOTSTEAM_ADDON:?Point to an installed GodotSteam addon directory containing godotsteam.gdextension}"
work="${REPLAY_STEAM_CAPABILITY_OUT:-$(mktemp -d)}";mkdir -p "$work/project/addons"
python3 - "$GODOTSTEAM_ADDON" "$work/project" "$ROOT/tests/replay_steam/capability_test.gd" <<'PY'
from pathlib import Path
import shutil,sys
addon,root,probe=map(Path,sys.argv[1:]);assert (addon/'godotsteam.gdextension').is_file()
shutil.copytree(addon,root/'addons/godotsteam',dirs_exist_ok=True);shutil.copy2(probe,root/'probe.gd')
(root/'project.godot').write_text('''config_version=5
[application]
config/name="Replay read-only Steam capability probe"
config/features=PackedStringArray("4.7", "GL Compatibility")
[rendering]
renderer/rendering_method="gl_compatibility"
[steam]
initialization/processes/initialize_on_startup=false
initialization/processes/embed_callbacks=false
''')
PY
"$GODOT" --headless --path "$work/project" --editor --quit-after 120 >"$work/import.log" 2>&1
"$GODOT" --headless --path "$work/project" --script probe.gd >"$work/probe.log" 2>&1
cat "$work/probe.log";rg -q REPLAY_STEAM_NATIVE_CAPABILITY_OK "$work/probe.log"
if rg -q 'SCRIPT ERROR|ERROR:|instances were leaked|resources still in use' "$work"/*.log;then exit 1;fi
echo "Steam capability logs: $work"
