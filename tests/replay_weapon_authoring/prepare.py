"""Isolated data-only weapon addition, with separately recorded training-target setup."""
from pathlib import Path
import difflib,hashlib,json,os,platform,re,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent;out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot(project):
 return {str(p.relative_to(project)):sha(p) for p in sorted(project.rglob('*')) if p.is_file() and p.suffix in ('.odin','.gd','.tscn','.tres','.png','.wav','.mp3','.godot','.gdextension') and not p.name.endswith('.gen.odin')}
for impl in ('kit','replay'):
 for variant in ('new','cold'):
  base=out/impl/variant;project=base/'project';assert not project.exists()
  if impl=='kit':
   subprocess.run([sys.executable,str(root/'tests/replay_scrapyard/prepare_baseline.py'),str(root.parent/'scrapyard'),str(project),str(root)],check=True)
   subprocess.run([sys.executable,str(root/'tests/replay_scrapyard/baseline_cleanup.py'),str(project)],check=True)
  else:shutil.copytree(root/'examples/replay_scrapyard',project,ignore=shutil.ignore_patterns('.godot','bin','out','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
  p=project/'project.godot';text=p.read_text();text=re.sub(r'config/name="[^"]+"',f'config/name="weapon_authoring_{out.name}_{impl}_{variant}"',text);text=text.replace('config/custom_user_dir_name="replay_scrapyard"',f'config/custom_user_dir_name="weapon_authoring_{out.name}_{impl}_{variant}"');p.write_text(text)
  before=snapshot(project);(base/'before.json').write_text(json.dumps(before,indent=2)+'\n')
  feature=base/'feature';feature.mkdir()
  if variant=='new':
   destination=project/'data/guns/stapler.tres';assert not destination.exists();shutil.copy2(here/'stapler.tres',destination);shutil.copy2(destination,feature/'stapler.tres')
   if impl=='replay':
    original=(project/'shared/content/stock.odin').read_text();subprocess.run([sys.executable,str(project/'tools/stock.py')],check=True)
    generated=(project/'shared/content/stock.odin').read_text();(feature/'stock-before.odin').write_text(original);(feature/'stock-after.odin').write_text(generated)
    (feature/'generated.patch').write_text(''.join(difflib.unified_diff(original.splitlines(True),generated.splitlines(True),fromfile='stock-before.odin',tofile='stock-after.odin')))
  after=snapshot(project);changes={name:{'before':before.get(name),'after':after.get(name)} for name in sorted(set(before)|set(after)) if before.get(name)!=after.get(name)}
  expected={'data/guns/stapler.tres'}|({'shared/content/stock.odin'} if impl=='replay' else set()) if variant=='new' else set();assert set(changes)==expected,changes
  (feature/'changes.json').write_text(json.dumps({'implementation':impl,'variant':variant,'changes':changes,'handwritten_gameplay_files':0,'handwritten_network_files':0,'authored_resource_files':int(variant=='new')},indent=2)+'\n')
  # A common stationary training target exercises ordinary damage and death.
  fixture_before=snapshot(project)
  for p in (project/'data/mobs').glob('*.tres'):
   if re.search(r'^id = 1$',p.read_text(),re.M):
    text=p.read_text()
    for key,value in [('speed','0.0'),('bite','0')]:text,n=re.subn(r'^'+key+r' = .+$',key+' = '+value,text,flags=re.M);assert n==1
    p.write_text(text);break
  else:raise AssertionError('heavy target not found')
  if impl=='replay':subprocess.run([sys.executable,str(project/'tools/stock.py')],check=True)
  fixture_after=snapshot(project)
  (base/'fixture-changes.json').write_text(json.dumps({name:{'before':fixture_before.get(name),'after':fixture_after.get(name)} for name in fixture_after if fixture_before.get(name)!=fixture_after[name]},indent=2)+'\n')
  shutil.copy2(here/'driver.gd',project/'weapon_authoring.gd');shutil.copy2(here/(impl+'_adapter.odin'),project/'scripts/weapon_authoring.odin')
  (base/'source.json').write_text(json.dumps(snapshot(project),indent=2)+'\n')
shutil.copy2(here/'contract.json',out/'contract.json')
metadata={'platform':platform.platform(),'machine':platform.machine(),'godot_binary':os.environ['GODOT'],'godot_version':subprocess.check_output([os.environ['GODOT'],'--version'],text=True).strip(),'framework_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'original_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root.parent/'scrapyard',text=True).strip(),'human_authoring_timed':False,'render':'headless; gl_compatibility; max-fps 60'}
if sys.platform=='darwin':
 for key,name in [('cpu','machdep.cpu.brand_string'),('memory_bytes','hw.memsize')]:metadata[key]=subprocess.check_output(['sysctl','-n',name],text=True).strip()
(out/'environment.json').write_text(json.dumps(metadata,indent=2)+'\n')
for name,repo in [('framework',root),('original',root.parent/'scrapyard')]:
 (out/(name+'-status.txt')).write_bytes(subprocess.check_output(['git','status','--short'],cwd=repo));(out/(name+'-diff.patch')).write_bytes(subprocess.check_output(['git','diff','--binary','--no-ext-diff'],cwd=repo))
paths=subprocess.check_output(['rg','--files','core','godot','gdext','runtime','kit','play','replay','build','scriptgen'],cwd=root,text=True).splitlines();(out/'framework-source.json').write_text(json.dumps({p:sha(root/p) for p in sorted(paths) if Path(p).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
print('REPLAY_WEAPON_AUTHORING_PREPARED')
