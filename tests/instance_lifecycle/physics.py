from pathlib import Path
import argparse,os,shutil,subprocess,tempfile
parser=argparse.ArgumentParser();parser.add_argument('--native-library',type=Path,required=True);parser.add_argument('--out',type=Path);args=parser.parse_args()
ROOT=Path(__file__).resolve().parents[2];WORK=(args.out or Path(tempfile.mkdtemp(prefix='odin-lifetime-physics-'))).resolve();PROJECT=WORK/'project'
if args.out:WORK.mkdir(parents=True,exist_ok=False)
shutil.copytree(Path(__file__).with_name('physics'),PROJECT)
env={k:v for k,v in os.environ.items() if k not in ['ODIN_SCRIPTS_DLL','ODIN_GODOT_ROOT'] and not k.startswith('BOX3D_')}
env['BOX3D_NATIVE_LIBRARY']=str(args.native_library.resolve());godot=env.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')
print('Physics lifetime evidence:',WORK,flush=True)
for name,command,marker in [('build',['bash',ROOT/'build/build_scripts.sh',PROJECT],'Built:'),('import',[godot,'--headless','--editor','--path',PROJECT,'--quit-after','60'],None),('positive',[godot,'--headless','--path',PROJECT,'--script','test.gd'],'PHYSICS_LIFETIME_OK'),('negative',[godot,'--headless','--path',PROJECT,'--script','test.gd'],'PHYSICS_QUARANTINE_OK')]:
 log=WORK/(name+'.log')
 with log.open('w') as stream:r=subprocess.run([str(x) for x in command],cwd=ROOT,env=dict(env,LIFETIME_NEGATIVE='1' if name=='negative' else '0'),stdout=stream,stderr=subprocess.STDOUT,timeout=180)
 text=log.read_text(errors='replace');clean=text
 if name=='negative':
  begin,end='EXPECTED_PHYSICS_QUARANTINE_BEGIN','EXPECTED_PHYSICS_QUARANTINE_END'
  if text.count(begin)!=1 or text.count(end)!=1:raise RuntimeError('missing quarantine boundary')
  expected=text.split(begin,1)[1].split(end,1)[0]
  if expected.count('ODIN_FINALIZE_QUARANTINED')!=1 or expected.count('ERROR:')!=1:raise RuntimeError('unexpected quarantine diagnostic')
  clean=text.split(begin,1)[0]+text.split(end,1)[1]
  if 'ODIN_BOX3D_SHUTDOWN_LIVE_NATIVE' not in clean or 'ODIN_BOX3D_SHUTDOWN_NOT_EMPTY' not in clean:raise RuntimeError('quarantine was misreported as successful cleanup')
  clean='\n'.join(line for line in clean.splitlines() if not any(x in line for x in ['ODIN_BOX3D_SHUTDOWN_LIVE_NATIVE','ODIN_BOX3D_SHUTDOWN_NOT_EMPTY','ObjectDB instance','resources still in use at exit']))
 if r.returncode or (marker and marker not in text) or any(x in clean for x in ['SCRIPT ERROR','\nERROR:','ODIN_SCRIPT_PANIC','leaked at exit','resources still in use','PHYSICS_FINALIZE_BAD']):
  print(text[-6000:]);raise RuntimeError(name+' failed: '+str(log))
 print(name,'PASS',flush=True)
print('PHYSICS_INSTANCE_LIFECYCLE_OK',WORK)
