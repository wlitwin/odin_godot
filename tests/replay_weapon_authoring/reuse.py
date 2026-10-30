"""Reuse verified binaries when only the external GDScript test driver changed."""
from pathlib import Path
import hashlib,json,re,shutil,sys
source=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();here=Path(__file__).resolve().parent;root=here.parents[1]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
assert source!=out and not (out/'kit').exists() and not (out/'replay').exists()
assert json.loads((source/'contract.json').read_text())==json.loads((here/'contract.json').read_text())
framework=json.loads((source/'framework-source.json').read_text())
for name,expected in framework.items():assert digest(root/name)==expected,('framework changed',name)
build=json.loads((source/'build.json').read_text())
for name,expected in build['binaries'].items():assert digest(source/name)==expected,('binary changed',name)
for impl in ['kit','replay']:
 for variant in ['new','cold']:
  base=source/impl/variant;manifest=json.loads((base/'source.json').read_text())
  for name,expected in manifest.items():assert digest(base/'project'/name)==expected,('prepared source changed',impl,variant,name)
  assert digest(base/'project/scripts/weapon_authoring.odin')==digest(here/(impl+'_adapter.odin')),'Odin adapter changed; rebuild required'
  dest=out/impl/variant;shutil.copytree(base,dest)
  shutil.copy2(here/'driver.gd',dest/'project/weapon_authoring.gd')
  p=dest/'project/project.godot';s=p.read_text()
  s=re.sub(r'config/name="[^"]+"',f'config/name="weapon_authoring_{out.name}_{impl}_{variant}"',s)
  s=re.sub(r'config/custom_user_dir_name="[^"]+"',f'config/custom_user_dir_name="weapon_authoring_{out.name}_{impl}_{variant}"',s);p.write_text(s)
  manifest['weapon_authoring.gd']=digest(dest/'project/weapon_authoring.gd');manifest['project.godot']=digest(p)
  (dest/'source.json').write_text(json.dumps(manifest,indent=2)+'\n')
  before=json.loads((dest/'before.json').read_text());before['project.godot']=digest(p);(dest/'before.json').write_text(json.dumps(before,indent=2)+'\n')
for name in ['contract.json','environment.json','framework-source.json','framework-status.txt','framework-diff.patch','original-status.txt','original-diff.patch']:shutil.copy2(source/name,out/name)
build['reused_from']=str(source);(out/'build.json').write_text(json.dumps(build,indent=2)+'\n')
(out/'reuse.json').write_text(json.dumps({'source':str(source),'compiled_sources_verified':True,'binaries_verified':True,'uncompiled_changes':['weapon_authoring.gd','project.godot (isolated user namespace)']},indent=2)+'\n')
print('REPLAY_WEAPON_AUTHORING_REUSED')
