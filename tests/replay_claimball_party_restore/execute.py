from pathlib import Path
import os,re,socket,subprocess,sys,time,json
root=Path(__file__).resolve().parents[2];web=Path(sys.argv[1]).resolve()/'project/out';service=Path(sys.argv[2]).resolve()/'project';out=Path(sys.argv[3]).resolve();out.mkdir(exist_ok=False);(out/'browser').mkdir();ext='dylib' if sys.platform=='darwin' else 'so'
ports=[]
for _ in range(2):
 with socket.socket(socket.AF_INET,socket.SOCK_STREAM) as sock:sock.bind(('127.0.0.1',0));ports.append(sock.getsockname()[1])
control,http=ports;children=[];logs=[];server=None
verifier=out/'verify-publication'
subprocess.run(['odin','build',str(root/'tests/replay_claimball_party_restore/verify'),'-collection:godot='+str(root),'-out:'+str(verifier)],check=True)

def start_service(create):
 env=os.environ.copy();env.update(REPLAY_ROOM_CONTENT='0x52434c41494d4233',REPLAY_ROOM_CHECKPOINT_MODEL='claimball',REPLAY_ROOM_PORT=str(control),REPLAY_ROOM_DB=str(out/'service.sqlite3'),REPLAY_ROOM_CREATE_DB=str(create),REPLAY_ROOM_LOCAL_DEVELOPMENT='1',ODIN_SCRIPTS_DLL=str(service/('bin/libodinscripts.'+ext)))
 log=(out/('service-'+str(create)+'.log')).open('w');logs.append(log);child=subprocess.Popen([env['GODOT'],'--headless','--max-fps','120','--path',str(service)],env=env,stdout=log,stderr=subprocess.STDOUT);children.append(child)
 deadline=time.monotonic()+15
 while 'REPLAY_ROOM_SERVICE_READY' not in (out/('service-'+str(create)+'.log')).read_text():assert child.poll() is None and time.monotonic()<deadline,'service startup';time.sleep(.05)
 return child
try:
 server=start_service(1)
 log=(out/'http.log').open('w');logs.append(log);children.append(subprocess.Popen(['bash',str(root/'tests/web/serve.sh'),str(web),str(http)],stdout=log,stderr=subprocess.STDOUT))
 log=(out/'driver.log').open('w');logs.append(log);driver=subprocess.Popen(['node',str(root/'tests/replay_claimball_party_restore/browser.mjs'),'http://127.0.0.1:'+str(http)+'/index.html','ws://127.0.0.1:'+str(control),str(out/'browser')],stdout=log,stderr=subprocess.STDOUT);children.append(driver)
 deadline=time.monotonic()+240
 while not (out/'browser/source-stopped').exists():assert driver.poll() is None and time.monotonic()<deadline,'source phase';time.sleep(.1)
 with (out/'source-verification.log').open('w') as log:subprocess.run([str(verifier),str(out/'service.sqlite3'),'source'],stdout=log,stderr=subprocess.STDOUT,check=True)
 saved=json.loads((out/'browser/saved.json').read_text());source=(out/'source-verification.log').read_text();assert 'tick='+str(saved['tick'])+' ' in source and 'hash='+saved['hash']+' ' in source,source
 server.kill();server.wait();server=start_service(0);(out/'browser/service-restarted').write_text('done')
 assert driver.wait(timeout=180)==0,(out/'driver.log').read_text()[-4000:]
 assert 'REPLAY_CLAIMBALL_PARTY_RESTORE_WEB_OK' in (out/'driver.log').read_text()
 for p in out.glob('service-*.log'):assert not re.search(r'SCRIPT ERROR|ERROR:|REPLAY_ROOM_SERVICE_FAIL',p.read_text()),p
 with (out/'continued-verification.log').open('w') as log:subprocess.run([str(verifier),str(out/'service.sqlite3'),'continued'],stdout=log,stderr=subprocess.STDOUT,check=True)
 print('REPLAY_CLAIMBALL_PARTY_RESTORE_OK')
finally:
 for child in children:
  if child.poll() is None:child.terminate()
 for child in children:
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
 for log in logs:log.close()
