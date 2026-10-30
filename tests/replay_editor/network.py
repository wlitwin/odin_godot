from pathlib import Path
import json,os,socket,subprocess,sys,time
work=Path(sys.argv[1]).resolve();project=work/'project';out=work/'revive';out.mkdir(exist_ok=False)
ext='dylib' if sys.platform=='darwin' else 'so'
with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
env=os.environ|{'ODIN_SCRIPTS_DLL':str(project/f'bin/libodinscripts.{ext}'),'RSY_PERSIST':'0','RSY_RUN':'0','RSY_REQUIRE_STOCK':'1','RSY_MOBS':'1','RSY_PORT':str(port),'RSY_LATENCY':'120','RSY_SEED':'1337','RSY_RESULT_DIR':str(out),'RSY_SETTINGS_PATH':str(out/'settings.json')}
peers=[]
try:
 for role in ['host','client','observer']:
  log=(out/f'{role}.log').open('w');p=subprocess.Popen([os.environ['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script','revive_test.gd'],env=env|{'RSY_ROLE':role,'RSY_NAME':role,'RSY_TOKEN':'editor-'+role},stdout=log,stderr=subprocess.STDOUT);peers.append((role,p,log));time.sleep(.3)
 for role,p,log in peers:
  assert p.wait(timeout=70)==0,role;log.close();text=(out/f'{role}.log').read_text()
  assert 'RSY_REVIVE_RESULT' in text,role
  assert not any(token in text for token in ['ERROR:','SCRIPT ERROR','_FAIL','instances were leaked','resources still in use']),role
 subprocess.run(['node',str(project/'revive_check.mjs'),str(out)],check=True)
finally:
 for _,p,log in peers:
  if p.poll() is None:p.terminate();p.wait(timeout=5)
  log.close()
(out/'result.json').write_text(json.dumps({'pass':True,'latency_ms':120,'roles':['host','client','observer']},indent=2)+'\n')
print('REPLAY_EDITOR_REVIVE_OK')
