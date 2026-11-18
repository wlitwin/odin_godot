"""Actual Core/meter/capability lifecycle gate for the standard physics owners."""
from pathlib import Path
import argparse,json,os,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--native-library',type=Path,required=True)
a=p.parse_args()
work=Path(tempfile.mkdtemp(prefix='odin-complete-owner-')).resolve();project=work/'project'
shutil.copytree(Path(__file__).with_name('project'),project)
shutil.copytree(ROOT/'addons/box3d_authoring',project/'addons/box3d_authoring')
shutil.copytree(ROOT/'examples/box3d_authoring_shared/content',project/'content')
env={k:v for k,v in os.environ.items() if not k.startswith('BOX3D_') and k not in ['ODIN_GODOT_ROOT','ODIN_SCRIPTS_DLL']}
env.update(ODIN_GODOT_ROOT=str(ROOT),BOX3D_NATIVE_LIBRARY=str(a.native_library.resolve()))
godot=env.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot');rows=[]
print('Complete owner evidence:',work,flush=True)
for name,argv,marker in [('build',['bash',ROOT/'build/build_scripts.sh',project],'Built:'),('import',[godot,'--headless','--editor','--path',project,'--quit-after','120'],None),('runtime',[godot,'--headless','--path',project,'--script','test.gd'],'COMPLETE_PHYSICS_OWNER_OK')]:
 log=work/(name+'.log')
 with log.open('w') as f:r=subprocess.run(list(map(str,argv)),cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=300)
 text=log.read_text(errors='replace');passed=r.returncode==0 and (marker is None or marker in text) and not any(x in text for x in ['SCRIPT ERROR','\nERROR:','leaked at exit','resources still in use','ODIN_SCRIPT_PANIC'])
 rows.append(dict(step=name,exit=r.returncode,passed=passed,log=str(log)));(work/'report.json').write_text(json.dumps(rows,indent=2)+'\n')
 print(name,'PASS' if passed else 'FAIL',flush=True)
 if not passed:print(text[-8000:]);raise SystemExit(1)
print('COMPLETE_PHYSICS_OWNER_OK',work)
