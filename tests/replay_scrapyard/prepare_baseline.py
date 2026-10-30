"""Copy only authored baseline inputs into an isolated runnable project."""
from pathlib import Path
import sys,shutil,json,hashlib,subprocess
source=Path(sys.argv[1]).resolve();target=Path(sys.argv[2]).resolve();framework=Path(sys.argv[3]).resolve()
assert not target.exists(), target
target.mkdir(parents=True)
for name in ['assets','data','entities','ui','scripts','fx']:
 shutil.copytree(source/name,target/name,ignore=shutil.ignore_patterns('*.gen.odin','*.import','*.uid'))
for name in ['main.tscn','project.godot','scrapyard_test.gd']:shutil.copyfile(source/name,target/name)
config=(target/'project.godot').read_text().replace('config/name="scrapyard"','config/name="replay_baseline_stress_'+target.parent.name+'"')
config=config.replace('[rendering]','[rendering]\n\nrenderer/rendering_method="gl_compatibility"\nrenderer/rendering_method.mobile="gl_compatibility"')
(target/'project.godot').write_text(config)
shutil.copyfile(framework/'examples/replay_scrapyard/odin_godot.gdextension',target/'odin_godot.gdextension')
files=[p for p in source.rglob('*') if p.is_file() and 'addons' not in p.parts and '.git' not in p.parts and '.godot' not in p.parts and p.suffix in ('.odin','.tscn','.tres','.gd') and not p.name.endswith('.gen.odin')]
(target.parent/'baseline-source-sha256.txt').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(source))+'\n' for p in sorted(files)))
(target.parent/'baseline-environment.json').write_text(json.dumps({'game_revision':subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip(),'framework':str(framework),'project_overrides':['isolated application name/user data','gl_compatibility renderer','project-local extension/binaries'],'run_sh_executed':False},indent=2)+'\n')
print(target)
