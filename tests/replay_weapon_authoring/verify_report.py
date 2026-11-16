"""Exercise report rejection without mutating the prepared game projects."""
from pathlib import Path
import json,shutil,subprocess,sys,tempfile
source=Path(sys.argv[1]).resolve();here=Path(__file__).resolve().parent

def clone(root):
 for name in ['contract.json','run-plan.json','build.json','environment.json','native-stock-new.log','native-stock-cold.log']:shutil.copy2(source/name,root/name)
 shutil.copytree(source/'runs',root/'runs')
 for impl in implementations:
  for variant in ['new','cold']:
   base=root/impl/variant;base.mkdir(parents=True)
   for name in ['before.json','source.json','fixture-changes.json','inputs.json']:shutil.copy2(source/impl/variant/name,base/name)
   shutil.copytree(source/impl/variant/'feature',base/'feature')
   shutil.copytree(source/impl/variant/'catalog',base/'catalog')
   (base/'project').symlink_to(source/impl/variant/'project',target_is_directory=True)
def change(path,fn):
 v=json.loads(path.read_text());fn(v);path.write_text(json.dumps(v))
cases=['valid','missing_peer','wrong_damage','wrong_ammo','cold_presence','first_hit','missing_reload','shrunken_plan','wrong_delay','source_hash','authored_code','resource_bytes','catalog_artifact','missing_quiescence','wrong_selection','missing_declaration','missing_equipped_barrier','missing_required_implementation','missing_native_catalog','empty_binaries','missing_script_binary','missing_baker_manifest']
implementations=json.loads((source/'environment.json').read_text())['implementations']
first_impl=implementations[0]
results=[]
for case in cases:
 with tempfile.TemporaryDirectory(prefix='weapon-report-') as name:
  root=Path(name);clone(root);peer=root/('runs/1/local/shared_resource/'+first_impl+'/success-client.json')
  if case=='missing_baker_manifest':change(root/'replay/new/source.json',lambda v:v.pop('tools/stock.py'))
  elif case=='empty_binaries':change(root/'build.json',lambda v:v.update(binaries={}))
  elif case=='missing_script_binary':change(root/'build.json',lambda v:v['binaries'].pop(next(name for name in v['binaries'] if Path(name).stem=='libodinscripts')))
  elif case=='missing_required_implementation':change(root/'run-plan.json',lambda v:v.update(implementations=[]))
  elif case=='missing_native_catalog':(root/'native-stock-cold.log').unlink()
  elif case=='missing_peer':peer.unlink()
  elif case=='wrong_damage':change(peer,lambda v:v.update(damage=19))
  elif case=='wrong_ammo':change(peer,lambda v:v.update(ammo=[2,3]))
  elif case=='cold_presence':change(root/'runs/1/local/host_only_resource/replay/success-client.json',lambda v:v.update(resource_present=True))
  elif case=='first_hit':change(peer,lambda v:v['first_hit'].update(enemy_hp=18))
  elif case=='missing_reload':change(peer,lambda v:v.update(reloads=1))
  elif case=='shrunken_plan':change(root/'run-plan.json',lambda v:v.update(cases=['shared_resource']))
  elif case=='wrong_delay':change(root/'run-plan.json',lambda v:v['receive_delay_ms'].update(delayed=60))
  elif case=='source_hash':change(root/first_impl/'new/source.json',lambda v:v.update({'scripts/runner.odin':'0'*64}))
  elif case=='authored_code':change(root/'replay/new/feature/changes.json',lambda v:v.update(handwritten_gameplay_files=1))
  elif case=='resource_bytes':(root/first_impl/'new/feature/stapler.tres').write_text('forged')
  elif case=='catalog_artifact':(root/'replay/new/catalog/after-stock.rpldef').write_bytes(b'forged')
  elif case=='wrong_selection':change(peer,lambda v:v['swaps'][0].update(before=1))
  elif case=='missing_declaration':(peer.parent/'declared-client.json').unlink()
  elif case=='missing_equipped_barrier':(peer.parent/'equipped-client.json').unlink()
  elif case=='missing_quiescence':(peer.parent/'quiesced-client.json').unlink()
  result=subprocess.run([sys.executable,str(here/'report.py'),str(root)],capture_output=True,text=True)
  assert (result.returncode==0)==(case=='valid'),(case,result.stdout,result.stderr)
  assert (root/'summary.json').exists()==(case=='valid'),case
  results.append({'case':case,'accepted':result.returncode==0})
(source/'report-validation.json').write_text(json.dumps(results,indent=2)+'\n')
print('REPLAY_WEAPON_AUTHORING_REPORT_VALIDATION_OK cases='+str(len(results)))
