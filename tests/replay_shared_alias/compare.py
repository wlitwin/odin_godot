from pathlib import Path
import hashlib,json,shutil,subprocess,sys
root=Path(__file__).resolve().parents[2];old,new=map(lambda p:Path(p).resolve(),sys.argv[1:3]);out=Path(sys.argv[3]).resolve();out.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();results=[]
for name in ['cavecrawl','quickdraw','speedball']:
 project=out/name
 shutil.copytree(root/'examples'/name,project,ignore=shutil.ignore_patterns('.godot','bin','out','addons','node_modules','*.gen.odin','*.uid','*.import','__pycache__'))
 snapshots={}
 for label,generator in [('before',old),('after',new)]:
  run=subprocess.run([str(generator),str(project/'scripts'),'-godot:'+str(root)],capture_output=True,text=True,timeout=45)
  (out/(name+'-'+label+'.log')).write_text(run.stdout+run.stderr);assert run.returncode==0,(name,label,run.stdout,run.stderr)
  snapshots[label]={str(p.relative_to(project)):sha(p) for p in project.rglob('*.gen.odin')}
 assert snapshots['before']==snapshots['after'],name
 results.append({'project':name,'identical':True,'generated':snapshots['after']})
(out/'result.json').write_text(json.dumps({'pass':True,'old_generator':sha(old),'new_generator':sha(new),'projects':results},indent=2)+'\n');print('REPLAY_SHARED_ALIAS_UNCHANGED_KIT_OUTPUT_OK')
