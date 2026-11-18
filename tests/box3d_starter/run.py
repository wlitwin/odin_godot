"""Build/play/export the packaged offline starter with a separate acceptance probe."""
from pathlib import Path
import argparse,json,os,shutil,subprocess,tempfile

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--sdk',type=Path,required=True)
p.add_argument('--native-library',type=Path,required=True)
p.add_argument('--export',action='store_true')
p.add_argument('--visual',action='store_true',help='Render and capture the real starter viewport during the gameplay check')
p.add_argument('--out',type=Path)
a=p.parse_args()
work=(a.out or Path(tempfile.mkdtemp(prefix='odin-box3d-starter-'))).resolve()
if a.out:work.mkdir(parents=True,exist_ok=False)
project=work/'project'
shutil.copytree(a.sdk/'addons/odin_godot/template/box3d',project)
project.chmod(project.stat().st_mode|0o200)
shutil.copytree(a.sdk/'addons',project/'addons')
for f in project.rglob('*'):f.chmod(f.stat().st_mode|0o200)
# Test-only instrumentation is absent from the shipped template and game script.
shutil.copy2(Path(__file__).with_name('probe.odin'),project/'scripts/probe.odin')
shutil.copy2(Path(__file__).with_name('acceptance.gd'),project/'acceptance.gd')
shutil.copy2(Path(__file__).with_name('body_trap.gd'),project/'body_trap.gd')
with (project/'project.godot').open('a') as f:f.write('\n[autoload]\nAcceptance="*res://acceptance.gd"\n')
engine=work/'engine';engine.mkdir()
original=Path(os.environ.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')).resolve()
if original.parent.name=='MacOS' and original.parent.parent.name=='Contents':
 subprocess.run(['/bin/cp','-c','-R',str(original.parents[2]),str(engine/'Godot.app')],check=True)
 godot=engine/'Godot.app/Contents/MacOS'/original.name
else:
 godot=engine/original.name;shutil.copy2(original,godot)
(engine/'_sc_').touch()
env={k:v for k,v in os.environ.items() if not k.startswith('BOX3D_') and k not in ['ODIN_GODOT_ROOT','ODIN_SCRIPTS_DLL','SCRIPT_BUILD_FLAGS','SKIP_CORE']}
env.update(GODOT=str(godot),ODIN_GODOT_ROOT=str(project/'addons/odin_godot'),BOX3D_NATIVE_LIBRARY=str(a.native_library.resolve()))
if a.visual:env['BOX3D_STARTER_CAPTURE']=str(work/'starter.png')
rows=[]
print('Offline starter evidence:',work,flush=True)
def run(name,argv,marker=None,environment=None):
 log=work/(name+'.log')
 with log.open('w') as stream:r=subprocess.run([str(x) for x in argv],cwd=work,env=environment or env,stdout=stream,stderr=subprocess.STDOUT,timeout=300)
 text=log.read_text(errors='replace')
 passed=r.returncode==0 and (marker is None or marker in text) and not any(x in text for x in ['SCRIPT ERROR','\nERROR:','leaked at exit','resources still in use','ODIN_SCRIPT_PANIC'])
 rows.append(dict(step=name,exit=r.returncode,passed=passed,log=str(log)))
 (work/'report.json').write_text(json.dumps(rows,indent=2)+'\n')
 print(name,'PASS' if passed else 'FAIL',flush=True)
 if not passed:print(text[-9000:]);raise SystemExit(1)
run('build',['bash',project/'addons/odin_godot/build/build_scripts.sh',project],'Built:')
run('import',[godot,'--headless','--editor','--path',project,'--quit-after','120'])
run('play',[godot,*([] if a.visual else ['--headless']),'--path',project],'BOX3D_STARTER_OK')
if a.export:
 if os.uname().sysname!='Darwin':raise SystemExit('This export gate currently qualifies macOS arm64 only.')
 # Isolated editors need access to the installed matching official templates.
 template_source=Path.home()/'Library/Application Support/Godot/export_templates'
 template_target=engine/'editor_data/export_templates'
 shutil.copytree(template_source,template_target,dirs_exist_ok=True)
 bundle=work/'Box3DStarter.app'
 clean={k:v for k,v in env.items() if not k.startswith(('BOX3D_','NIX_')) and k not in ['ODIN','ODIN_GODOT_ROOT','GODOT','DEVELOPER_DIR','SDKROOT','IN_NIX_SHELL']}
 clean['PATH']='/usr/bin:/bin:/usr/sbin:/sbin'
 run('export',[godot,'--headless','--path',project,'--export-release','macOS arm64',bundle],environment=clean)
 run('codesign',['/usr/bin/codesign','--verify','--deep','--strict',bundle])
 executables=[f for f in (bundle/'Contents/MacOS').iterdir() if f.is_file()]
 assert len(executables)==1,executables
 run('exported-play',[executables[0],'--headless'],'BOX3D_STARTER_OK',clean)
print('BOX3D_STARTER_OK',work)
