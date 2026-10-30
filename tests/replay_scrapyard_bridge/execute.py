from pathlib import Path
import os,subprocess,sys,json,socket,time,shutil
root=Path(__file__).resolve().parents[2];work=Path(sys.argv[1]).resolve();project=work/'project';out=work/'checks';out.mkdir(parents=True,exist_ok=False)
shutil.copy2(root/'tests/replay_scrapyard_bridge/audio.gd',project/'bridge_audio.gd')
ext='dylib' if sys.platform=='darwin' else 'so'
env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{ext}'),'RSY_PERSIST':'0','RSY_SETTINGS_PATH':str(out/'settings.json')}
def check(path,marker):
 text=path.read_text();assert marker in text,path
 assert not any(s in text for s in ['SCRIPT ERROR','ERROR:','_FAIL','instances were leaked','resources still in use']),path
for driver,marker in [('actors_test.gd','REPLAY_ACTOR_VIEW_OK'),('feedback_test.gd','REPLAY_FEEDBACK_OK'),('bridge_audio.gd','REPLAY_SCRAP_BRIDGE_AUDIO_OK')]:
 path=out/(driver+'.log')
 with path.open('w') as log:subprocess.run([os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',driver],env=env,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=90)
 check(path,marker);print(marker,flush=True)
network=out/'network';network.mkdir(exist_ok=True)
with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
peers=[]
try:
 for role in ['host','client','observer']:
  e=env|{'RSY_ROLE':role,'RSY_NAME':role,'RSY_TOKEN':'bridge-'+role,'RSY_PORT':str(port),'RSY_MOBS':'4','RSY_RUN':'0','RSY_REQUIRE_STOCK':'1','RSY_LATENCY':'120','RSY_SEED':'1337','RSY_RESULT_DIR':str(network)}
  log=(network/f'{role}.log').open('w');p=subprocess.Popen([os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script','combat_test.gd'],env=e,stdout=log,stderr=subprocess.STDOUT);peers.append((role,p,log));time.sleep(.3)
 for role,p,log in peers:assert p.wait(timeout=65)==0,role;log.close();check(network/f'{role}.log','REPLAY_SCRAPYARD_COMBAT')
 subprocess.run(['node',str(project/'combat_check.mjs'),str(network)],check=True)
finally:
 for _,p,log in peers:
  if p.poll() is None:p.terminate();p.wait(timeout=5)
  log.close()
(out/'result.json').write_text(json.dumps({'pass':True,'actors':True,'feedback':True,'audio':True,'network':['host','client','observer'],'latency_ms':120},indent=2)+'\n')
print('REPLAY_SCRAP_BRIDGE_OK')
