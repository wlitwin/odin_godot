#!/usr/bin/env bash
set -euo pipefail
ROOT="${ODIN_GODOT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}";export ODIN_GODOT_ROOT="$ROOT"
project="$1";out="$2";mode="$3";mkdir -p "$out"
python3 - "$ROOT" "$project" "$mode" <<'PY'
from pathlib import Path
import sys,shutil
root,project=map(Path,sys.argv[1:3]);mode=sys.argv[3]
s=(root/'tests/replay_scrapyard_bridge/bench_probe.odin').read_text()
if mode=='composed':
 s=s.replace('import game "../shared/game"','import game "../shared/game"\nimport views "views"')
 s=s.replace('for _ in 0..<120 {paint(self,frame,frame,1.0/60)}','''for _ in 0..<120 {
            paint(self,frame,frame,1.0/60)
            rgd.script_archetypes_visit(&self.combat_bridge[0].mobs,self,proc(self:^ReplayScrapyard,h:r.Handle(game.Mob),view:^views.ScrapEnemyView){views.scrap_enemy_view_process(view,1.0/60)})
            for view in self.rigs {
                views.scrap_runner_view_process(view,1.0/60)
                views.scrap_weapon_view_process(view.weapon,1.0/60)
                views.scrap_equipment_view_process(view.reload_view,1.0/60)
                views.scrap_equipment_view_process(view.beacon_view,1.0/60)
            }
            replay_scrapyard_hud_process(self.hud,1.0/60)
        }''')
(project/'scripts/bridge_bench.odin').write_text(s)
shutil.copy2(root/'tests/replay_scrapyard_bridge/bench.gd',project/'bridge_bench.gd')
PY
case "$(uname -s)" in Darwin) ext=dylib;;*) ext=so;;esac
export ODIN_SCRIPTS_DLL="$project/bin/libodinscripts.$ext"
bash "$ROOT/build/build_scripts.sh" "$project" >"$out/build.log" 2>&1
"$GODOT" --headless --path "$project" --editor --import >"$out/import.log" 2>&1
python3 "$ROOT/tests/replay_comparison/wait_builds.py" "$project" "$out/wait.json"
bash "$ROOT/build/build_scripts.sh" "$project" >"$out/final-build.log" 2>&1
if rg -q 'ERROR:|SCRIPT ERROR' "$out/import.log";then cat "$out/import.log";exit 1;fi
