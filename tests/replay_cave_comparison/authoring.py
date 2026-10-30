"""Mechanical source inventory; intentionally not a human ergonomics score."""
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[2];output=Path(sys.argv[1])
groups={'kit_game':['examples/cavecrawl/scripts'],'replay_common_gameplay':['examples/replay_cavecrawl/shared/cave'],'replay_common_godot':['examples/replay_cavecrawl/scripts'],'replay_owner_model':['examples/replay_cavecrawl/shared/owner_cave'],'replay_owner_preparation':['examples/replay_cavecrawl_owned/prepare.py','examples/replay_cavecrawl_owned/build.sh','examples/replay_cavecrawl_owned/play.sh'],'replay_owner_converter':['examples/replay_cavecrawl/shared/owner_upgrade','examples/replay_cavecrawl_owned/tools']}
result={}
for name,locations in groups.items():
 files=[]
 for location in locations:
  path=root/location
  files.extend([path] if path.is_file() else list(path.rglob('*.odin')))
 rows=[]
 for p in sorted(set(files)):
  if p.name.endswith('.gen.odin'):continue
  lines=p.read_text().splitlines()
  rows.append({'path':str(p.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'lines':len(lines),'nonblank_non_line_comment_lines':sum(bool(line.strip()) and not line.lstrip().startswith('//') for line in lines),'imports':sum(line.startswith('import ') for line in lines),'gd_methods':sum('@(gd_method)' in line for line in lines),'gd_commands':sum('@(gd_command' in line for line in lines),'gd_halves':sum('@(gd_half)' in line for line in lines)})
 result[name]={'files':rows,'totals':{k:sum(r[k] for r in rows) for k in ['lines','nonblank_non_line_comment_lines','imports','gd_methods','gd_commands','gd_halves']}}
output.write_text(json.dumps({'groups':result,'counting_policy':'authored files; generated code excluded; nonblank/non-// count is lexical, not semantic LOC','limits':['feature sets differ','common Godot source contains both profiles, including the owner producer','framework implementation excluded','no elapsed human authoring/debugging time measured']},indent=2)+'\n')
print('CAVE_COMPARISON_AUTHORING_INVENTORY_OK')
