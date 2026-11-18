"""Prepare a required Replay authoring test and an optional Kit comparison."""
from pathlib import Path
import hashlib,json,os,platform,re,shutil,subprocess,sys
from fixture import CATALOG_FILES,digest,snapshot

root=Path(__file__).resolve().parents[2];here=Path(__file__).resolve().parent
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
implementations=['kit','replay'] if (root.parent/'scrapyard/project.godot').is_file() else ['replay']
for impl in implementations:
 for variant in ('new','cold'):
  base=out/impl/variant;project=base/'project';assert not project.exists()
  if impl=='kit':
   subprocess.run([sys.executable,str(root/'tests/replay_scrapyard/prepare_baseline.py'),str(root.parent/'scrapyard'),str(project),str(root)],check=True)
  else:shutil.copytree(root/'examples/replay_scrapyard',project,ignore=shutil.ignore_patterns('.godot','bin','out','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
  p=project/'project.godot';text=p.read_text();text=re.sub(r'config/name="[^"]+"',f'config/name="weapon_authoring_{out.name}_{impl}_{variant}"',text);text=text.replace('config/custom_user_dir_name="replay_scrapyard"',f'config/custom_user_dir_name="weapon_authoring_{out.name}_{impl}_{variant}"');p.write_text(text)
  # Framework installation is setup, before measuring the authored feature.
  # Keep the installed sources in the snapshot so later unexpected edits fail.
  subprocess.run([sys.executable,str(root/'replay/editor/install.py'),str(project)],check=True)
  before=snapshot(project);(base/'before.json').write_text(json.dumps(before,indent=2)+'\n')
  feature=base/'feature';feature.mkdir()
  if variant=='new':
   destination=project/'data/guns/stapler.tres';assert not destination.exists();shutil.copy2(here/'stapler.tres',destination);shutil.copy2(destination,feature/'stapler.tres')
  after=snapshot(project);changes={name:{'before':before.get(name),'after':after.get(name)} for name in sorted(set(before)|set(after)) if before.get(name)!=after.get(name)}
  assert set(changes)==({'data/guns/stapler.tres'} if variant=='new' else set()),changes
  (feature/'changes.json').write_text(json.dumps({'implementation':impl,'variant':variant,'changes':changes,'handwritten_gameplay_files':0,'handwritten_network_files':0,'authored_resource_files':int(variant=='new')},indent=2)+'\n')
  # Keep training-target changes separate from the authored weapon addition.
  fixture_before=snapshot(project)
  for p in (project/'data/mobs').glob('*.tres'):
   if re.search(r'^id = 1$',p.read_text(),re.M):
    text=p.read_text()
    for key,value in [('speed','0.0'),('bite','0')]:text,n=re.subn(r'^'+key+r' = .+$',key+' = '+value,text,flags=re.M);assert n==1
    p.write_text(text);break
  else:raise AssertionError('heavy target not found')
  fixture_after=snapshot(project)
  (base/'fixture-changes.json').write_text(json.dumps({name:{'before':fixture_before.get(name),'after':fixture_after.get(name)} for name in fixture_after if fixture_before.get(name)!=fixture_after[name]},indent=2)+'\n')
  catalog=base/'catalog';catalog.mkdir()
  if impl=='replay':
   for name in CATALOG_FILES:shutil.copy2(project/name,catalog/('before-'+Path(name).name))
  shutil.copy2(here/'driver.gd',project/'weapon_authoring.gd');shutil.copy2(here/(impl+'_adapter.odin'),project/'scripts/weapon_authoring.odin')
  (base/'inputs.json').write_text(json.dumps(snapshot(project),indent=2)+'\n')
shutil.copy2(here/'contract.json',out/'contract.json')
metadata={'platform':platform.platform(),'machine':platform.machine(),'godot_binary':os.environ['GODOT'],'godot_version':subprocess.check_output([os.environ['GODOT'],'--version'],text=True).strip(),'framework_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'original_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root.parent/'scrapyard',text=True).strip() if 'kit' in implementations else None,'implementations':implementations,'human_authoring_timed':False,'render':'headless; gl_compatibility; max-fps 60'}
if sys.platform=='darwin':
 for key,name in [('cpu','machdep.cpu.brand_string'),('memory_bytes','hw.memsize')]:metadata[key]=subprocess.check_output(['sysctl','-n',name],text=True).strip()
(out/'environment.json').write_text(json.dumps(metadata,indent=2)+'\n')
for name,repo in [('framework',root)]+([('original',root.parent/'scrapyard')] if 'kit' in implementations else []):
 (out/(name+'-status.txt')).write_bytes(subprocess.check_output(['git','status','--short'],cwd=repo));(out/(name+'-diff.patch')).write_bytes(subprocess.check_output(['git','diff','--binary','--no-ext-diff'],cwd=repo))
paths=subprocess.check_output(['rg','--files','core','godot','gdext','runtime','kit','play','replay','authoring','build','scriptgen'],cwd=root,text=True).splitlines();(out/'framework-source.json').write_text(json.dumps({p:digest(root/p) for p in sorted(paths) if Path(p).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
print('REPLAY_WEAPON_AUTHORING_PREPARED implementations='+','.join(implementations))
