#!/usr/bin/env bash
# Run explicitly on each of two logged-in Steam accounts/devices. This is a live
# Steam app session; the normal contract gate never initializes Valve's service.
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
: "${STEAM_APP_ID:?Set your Steam app ID (480 only when intentionally using the Steamworks test app)}"
role="${STEAM_TEST_ROLE:-host}";case "$role" in host|client) ;; *) echo 'STEAM_TEST_ROLE must be host or client';exit 2;; esac
if [[ "$role" == client ]];then : "${STEAM_HOST_ID:?Use the host ID printed by the first process}";fi
work="${REPLAY_STEAM_LIVE_OUT:-$(mktemp -d)}";mkdir -p "$work/project"
python3 - "$ROOT/tests/replay_steam" "$work/project" <<'PY'
from pathlib import Path
import shutil,sys,os
src,dst=map(Path,sys.argv[1:])
for name in ['scripts','fake_steam.gd','fake_peer.gd','main.tscn','session.tscn','project.godot','odin_godot.gdextension']:
 p=src/name
 if p.is_dir():shutil.copytree(p,dst/name,ignore=shutil.ignore_patterns('*.gen.odin'),dirs_exist_ok=True)
 else:shutil.copy2(p,dst/name)
if addon:=os.environ.get('GODOTSTEAM_ADDON'):shutil.copytree(addon,dst/'addons/godotsteam',dirs_exist_ok=True)
p=dst/'project.godot';p.write_text(p.read_text()+'\n[steam]\ninitialization/processes/initialize_on_startup=false\ninitialization/processes/embed_callbacks=false\n')
PY
bash "$ROOT/build/build_scripts.sh" "$work/project" >"$work/build.log" 2>&1
case "$(uname -s)" in Darwin) ext=dylib ;; Linux) ext=so ;; *) ext=dll ;; esac
export ODIN_SCRIPTS_DLL="$work/project/bin/libodinscripts.$ext"
"$GODOT" --headless --path "$work/project" --editor --quit-after 120 >"$work/import.log" 2>&1
if rg -q 'SCRIPT ERROR|ERROR:' "$work/import.log";then cat "$work/import.log";exit 1;fi
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$work/project" "$work/build-wait.json"
echo "Live Steam logs: $work"
STEAM_LIVE=1 STEAM_TEST_ROLE="$role" "$GODOT" --headless --max-fps 60 --path "$work/project" session.tscn | tee "$work/$role.log"
rg -q "REPLAY_STEAM_LIVE_OK role=$role" "$work/$role.log"
