"""Prepare preserved originals, feature-only diffs, then independent test adapters."""
from pathlib import Path
import hashlib,json,shutil,subprocess,sys,platform,re,os
from feature import install
root=Path(__file__).resolve().parents[2]; here=Path(__file__).resolve().parent
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=True)
assert not (out/'kit').exists() and not (out/'replay').exists(),out
subprocess.run([sys.executable,str(root/'tests/replay_scrapyard/prepare_baseline.py'),str(root.parent/'scrapyard'),str(out/'kit/project'),str(root)],check=True)
subprocess.run([sys.executable,str(root/'tests/replay_scrapyard/baseline_cleanup.py'),str(out/'kit/project')],check=True)
shutil.copytree(root/'examples/replay_scrapyard',out/'replay/project',ignore=shutil.ignore_patterns('.godot','bin','out','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
for implementation in ('kit','replay'):
    project=out/implementation/'project';p=project/'project.godot';s=p.read_text()
    s=re.sub(r'config/name="[^"]+"',f'config/name="paid_revive_{out.name}_{implementation}"',s)
    s=s.replace('config/custom_user_dir_name="replay_scrapyard"',f'config/custom_user_dir_name="paid_revive_{out.name}_{implementation}"');p.write_text(s)
    install(project,implementation,out/implementation/'feature')
    shutil.copy2(here/'driver.gd',project/'authoring.gd')
    shutil.copy2(here/(implementation+'_adapter.odin'),project/'scripts/authoring.odin')
    files=[p for p in project.rglob('*') if p.is_file() and p.suffix in ('.odin','.gd','.tscn','.tres','.png','.wav','.mp3') and not p.name.endswith('.gen.odin')]
    (out/implementation/'source.json').write_text(json.dumps({str(p.relative_to(project)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(files)},indent=2)+'\n')
shutil.copy2(here/'contract.json',out/'contract.json')
info={'platform':platform.platform(),'framework_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'original_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root.parent/'scrapyard',text=True).strip(),'authoring_timed':False,'baseline_overlay':'Existing explicit ownership cleanup; applied before feature diffs and excluded from feature counts.'}
info['godot_binary']=os.environ.get('GODOT','godot')
info['godot_version']=subprocess.check_output([info['godot_binary'],'--version'],text=True).strip()
info['machine']=platform.machine();info['render']='headless; gl_compatibility; max-fps 60'
if sys.platform=='darwin':
    for key,setting in [('cpu','machdep.cpu.brand_string'),('memory_bytes','hw.memsize')]:
        info[key]=subprocess.check_output(['sysctl','-n',setting],text=True).strip()
(out/'environment.json').write_text(json.dumps(info,indent=2)+'\n')
for name,repo in [('framework',root),('original',root.parent/'scrapyard')]:
    (out/(name+'-status.txt')).write_bytes(subprocess.check_output(['git','status','--short'],cwd=repo))
    (out/(name+'-diff.patch')).write_bytes(subprocess.check_output(['git','diff','--binary','--no-ext-diff'],cwd=repo))
paths=subprocess.check_output(['rg','--files','core','godot','gdext','runtime','kit','play','replay','build','scriptgen'],cwd=root,text=True).splitlines()
(out/'framework-source.json').write_text(json.dumps({name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in sorted(paths) if Path(name).suffix in ('.odin','.sh','.py','.nix')},indent=2)+'\n')
print('REPLAY_AUTHORING_PREPARED')
