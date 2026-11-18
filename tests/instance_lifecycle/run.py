from pathlib import Path
import os, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[2]
WORK=Path(tempfile.mkdtemp(prefix='odin-instance-lifecycle-')).resolve()
PROJECT=WORK/'project'
shutil.copytree(Path(__file__).parent,PROJECT,ignore=shutil.ignore_patterns('__pycache__','bin','.godot','*.gen.odin'))
env={k:v for k,v in os.environ.items() if k not in ['ODIN_SCRIPTS_DLL','ODIN_GODOT_ROOT'] and not k.startswith('BOX3D_')}
godot=env.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')
print('Instance lifecycle evidence:',WORK,flush=True)
def run(name,args,marker=None):
 log=WORK/(name+'.log')
 with log.open('w') as stream:r=subprocess.run([str(x) for x in args],cwd=ROOT,env=env,stdout=stream,stderr=subprocess.STDOUT,timeout=120)
 text=log.read_text(errors='replace');clean=text
 if name=='negative':
  for label,diagnostic in [('PREDELETE','ODIN_FINALIZE_QUARANTINED'),('QUARANTINE','ODIN_FINALIZE_QUARANTINED')]:
   begin='EXPECTED_FINALIZE_'+label+'_BEGIN';end='EXPECTED_FINALIZE_'+label+'_END'
   if text.count(begin)!=1 or text.count(end)!=1:raise RuntimeError('missing negative boundary: '+str(log))
   part=clean.split(begin,1)[1].split(end,1)[0]
   if part.count(diagnostic)!=1 or part.count('ERROR:')!=1 or 'SCRIPT ERROR' in part:raise RuntimeError('wrong denial: '+str(log))
   clean=clean.split(begin,1)[0]+clean.split(end,1)[1]
  # This misuse deliberately retains one script instance and its exported data;
  # only this negative process is allowed to report its retained ObjectDB data.
  clean='\n'.join(line for line in clean.splitlines() if not ('ObjectDB' in line and 'leaked at exit' in line) and 'resources still in use at exit' not in line)
 if r.returncode or (marker and marker not in text) or any(x in clean for x in ['SCRIPT ERROR','\nERROR:','ODIN_SCRIPT_PANIC','ODIN_GODOT_CRASH','leaked at exit','resources still in use']):
  print(text[-6000:]);raise RuntimeError(name+' failed: '+str(log))
 print(name,'PASS',flush=True)
run('build',['bash',ROOT/'build/build_scripts.sh',PROJECT],'Built:')
run('import',[godot,'--headless','--editor','--path',PROJECT,'--quit-after','60'])
run('runtime',[godot,'--headless','--path',PROJECT,'--script','test.gd'],'INSTANCE_LIFETIME_OK')
run('negative',[godot,'--headless','--path',PROJECT,'--script','negative.gd'],'INSTANCE_QUARANTINE_OK')
print('INSTANCE_LIFECYCLE_OK',WORK)
