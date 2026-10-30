from pathlib import Path
import hashlib,json,os,shutil,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];prepared=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();mode=sys.argv[3];out.mkdir(parents=True,exist_ok=False)
assert mode in ('planned','crash','save')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in json.loads((prepared/'prepared.json').read_text()).items():assert sha(prepared/n)==h,n
for n,h in json.loads((prepared/'framework.json').read_text()).items():assert sha(root/n)==h,n
project=prepared/'project';server_project=prepared/'server';ext='dylib' if sys.platform=='darwin' else 'so'
(out/'inputs.json').write_text(json.dumps({'mode':mode,'export':{p.name:sha(p) for p in (project/'out').iterdir() if p.is_file()},'server':{p.name:sha(p) for p in (server_project/'bin').glob('*.'+ext)}},indent=2)+'\n')
def port():
 with socket.socket() as s:s.bind(('127.0.0.1',0));return s.getsockname()[1]
http_port,control=port(),port();children=[];handles=[]
def start(args,log,env):
 h=(out/log).open('w');handles.append(h);p=subprocess.Popen(args,env=env,stdout=h,stderr=subprocess.STDOUT);children.append(p);return p
try:
 env=os.environ.copy();env['ODIN_GODOT_ROOT']=str(root)
 http=start(['bash',str(root/'tests/web/serve.sh'),str(project/'out'),str(http_port)],'http.log',env)
 if mode!='save':
  server=start([env['GODOT'],'--headless','--path',str(server_project)],'server.log',env|{'RWA_SIGNAL':'1','RWA_GAME':'cave-owned','RWA_PORT':str(control),'RWA_DB':str(out/'authority.sqlite'),'RWA_DONE':str(out/'done'),'ODIN_SCRIPTS_DLL':str(server_project/('bin/libodinscripts.'+ext))})
  deadline=time.monotonic()+12
  while 'WEB_AUTHORITY_SERVER_READY' not in (out/'server.log').read_text():assert server.poll() is None and time.monotonic()<deadline;time.sleep(.05)
 driver=root/'tests/replay_cave_owner'/('browser_save.mjs' if mode=='save' else 'browser.mjs');shutil.copy2(driver,out/'driver.mjs')
 args=['node',str(driver),f'http://127.0.0.1:{http_port}/index.html']
 if mode=='save':args+=[str(out/'browser')]
 else:args+=[f'ws://127.0.0.1:{control}/control',mode]
 with (out/'driver.log').open('w') as log:
  result=subprocess.run(args,env=env|{'RCB_SOCIAL':'1','RCB_LOBBY':'1','RCB_LOGS':str(out/'browser'),'RCB_PROFILE_ROOT':str(out/'profiles')},stdout=log,stderr=subprocess.STDOUT,timeout=360)
 assert result.returncode==0,(out/'driver.log').read_text()[-7000:]
 if mode!='save':
  (out/'done').touch();assert server.wait(timeout=15)==0
  assert not any(s in (out/'server.log').read_text() for s in ['WEB_AUTHORITY_FAIL','SCRIPT ERROR','ERROR:','instances were leaked'])
 print('REPLAY_CAVE_OWNER_BROWSER_CASE_OK',mode)
finally:
 for child in children:
  if child.poll() is None:child.terminate()
 for child in children:
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
 for h in handles:h.close()
