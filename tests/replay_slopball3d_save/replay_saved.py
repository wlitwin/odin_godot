"""Replay one retained native checkpoint with its original test profiles.
Usage: replay_saved.py PREPARED_APP SOURCE_SAVE_DIRECTORY FRESH_OUTPUT
This does not generate, overwrite or repair the source checkpoint.
"""
from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];prepared=Path(sys.argv[1]).resolve();source=Path(sys.argv[2]).resolve();out=Path(sys.argv[3]).resolve();out.mkdir();os.chmod(out,0o700);game=prepared/'project';ext='dylib' if sys.platform=='darwin' else 'so';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((prepared/'prepared.json').read_text()).items():assert sha(game/name)==digest,name
names=['pitch.replay','saved.json','host-identity','host-identity.name','client-identity','client-identity.name'];before={n:sha(source/n) for n in names}
for name in names:shutil.copy2(source/name,out/name)
shutil.copy2(root/'tests/replay_slopball3d_save/drive.gd',out/'driver.gd')
(out/'source-hashes.json').write_text(json.dumps(before,indent=2)+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
children=[];logs=[]
try:
 for role in ['host','client']:
  env=os.environ.copy();env.update(RS3_SAVE_STAGE='read',RS3_SAVE_ROLE=role,RS3_SAVE_DIR=str(out),RS3_ROLE='',RS3_TOKEN='',RS3_NAME='',RS3_BOT='',RS3_PERSIST='1',RS3_PROFILE=str(out/(role+'-identity')),RS3_SAVE=str(out/('pitch.replay' if role=='host' else 'guest.replay')),RS3_PORT=str(port),RS3_GOALS='2',RS3_PLAYERS='2',RS3_LATENCY='120',RS3_COORD_PORT='0',RS3_TEST='0',ODIN_SCRIPTS_DLL=str(game/('bin/libodinscripts.'+ext)))
  log=(out/(role+'.log')).open('w');logs.append(log);p=subprocess.Popen([env['GODOT'],'--headless','--max-fps','60','--path',str(game),'--script',str(out/'driver.gd')],env=env,stdout=log,stderr=subprocess.STDOUT);children.append((role,p))
 deadline=time.monotonic()+110
 while any(p.poll() is None for _,p in children):
  assert time.monotonic()<deadline,'replay deadline'
  for role,p in children:assert not re.search(r'REPLAY_SLOPBALL3D_FAIL|RS3_SAVE_FAIL|SCRIPT ERROR|ERROR:',(out/(role+'.log')).read_text()),role
  time.sleep(.05)
 for role,p in children:assert p.returncode==0 and 'RS3_SAVE_OK read '+role in (out/(role+'.log')).read_text(),role
 print('REPLAY_SLOPBALL3D_SAVED_REPLAY_OK')
finally:
 for _,p in children:
  if p.poll() is None:p.terminate()
 for _,p in children:
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for log in logs:log.close()
 assert before=={n:sha(source/n) for n in names},'source changed'
 (out/'builds.json').write_text(json.dumps({'binaries':{p.name:sha(p) for p in (game/'bin').glob('*.'+ext)},'driver':sha(out/'driver.gd'),'exits':{role:p.returncode for role,p in children}},indent=2)+'\n')
