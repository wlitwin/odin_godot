from pathlib import Path
import hashlib,json,os,subprocess,sys
out=Path(sys.argv[1]).resolve();save=out/(sys.argv[2] if len(sys.argv)>2 else 'save');folder=save/'rendered';folder.mkdir(exist_ok=False);project=out/'project';ext='dylib' if sys.platform=='darwin' else 'so'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
before={n:sha(save/n) for n in ['pitch.replay','host-identity','host-identity.name']}
env=os.environ.copy();env.update(RS3_ROLE='',RS3_BOT='',RS3_TOKEN='',RS3_NAME='',RS3_PERSIST='1',RS3_PROFILE=str(save/'host-identity'),RS3_SAVE=str(save/'pitch.replay'),RS3_CAPTURE_DIR=str(folder),ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)))
script=Path(__file__).with_name('capture.gd');(folder/'driver.gd').write_bytes(script.read_bytes())
with (folder/'run.log').open('w') as log:
 child=subprocess.Popen([env['GODOT'],'--max-fps','60','--path',str(project),'--script',str(folder/'driver.gd')],env=env,stdout=log,stderr=subprocess.STDOUT)
 try:code=child.wait(timeout=30)
 finally:
  if child.poll() is None:
   child.terminate()
   try:child.wait(timeout=5)
   except subprocess.TimeoutExpired:child.kill();child.wait()
text=(folder/'run.log').read_text();assert code==0 and 'REPLAY_SLOPBALL3D_SAVE_RENDER_OK' in text,text
assert all(x not in text for x in ['SCRIPT ERROR','ERROR:','instances were leaked','resources still in use']),text
for n,digest in before.items():assert sha(save/n)==digest,n
(folder/'report.json').write_text(json.dumps({'pass':True,'files_preserved':before,'screenshots':{p.name:sha(p) for p in folder.glob('*.png')},'driver_sha256':sha(folder/'driver.gd')},indent=2)+'\n');print('REPLAY_SLOPBALL3D_SAVE_RENDER_OK')
