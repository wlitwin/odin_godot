"""Build a differential oracle in an isolated copy, preserving original validators."""
from pathlib import Path
import argparse,re,shutil,json,hashlib
p=argparse.ArgumentParser();p.add_argument('before',type=Path);p.add_argument('out',type=Path);a=p.parse_args();root=Path(__file__).resolve().parents[2]
shared=a.out/'shared';shutil.copytree(root/'examples/replay_scrapyard/shared',shared)
files=['game.odin','combat.odin','abilities.odin','run.odin','ordnance.odin','effects.odin'];names=['state_valid','combat_valid','abilities_valid','run_valid','ordnance_valid','effects_valid'];imports={};bodies=[]
for file,name in zip(files,names):
 text=(a.before/file).read_text()
 for line in text.splitlines():
  if line.startswith('import '):imports[line]=True
 start=text.index(name+' :: proc(w: World) -> bool {');at=text.index('{',start);end=at+1;depth=1
 while depth:
  if text[end]=='{':depth+=1
  elif text[end]=='}':depth-=1
  end+=1
 body=text[start:end]
 for n in names:body=re.sub(r'\b'+n+r'\b','before_'+n,body)
 bodies.append(body)
(shared/'game/before_validation.odin').write_text('package scrapyard_game\n'+'\n'.join(imports)+'\n\n'+'\n\n'.join(bodies)+'\n')
shutil.copyfile(Path(__file__).with_name('differential.odin'),shared/'game/differential_test.odin')
(a.out/'source.json').write_text(json.dumps({str(p.relative_to(a.out)):hashlib.sha256(p.read_bytes()).hexdigest() for p in a.out.rglob('*.odin')},indent=2)+'\n')
print('VALIDATION_ORACLE_PREPARED')
