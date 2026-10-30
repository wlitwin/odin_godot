from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];prepared=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();out.mkdir(parents=True,exist_ok=False)
project=prepared/'project';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in json.loads((prepared/'prepared.json').read_text()).items():assert sha(project/n)==h,n
for n,h in json.loads((prepared/'framework.json').read_text()).items():assert sha(root/n)==h,n
ext='dylib' if sys.platform=='darwin' else 'so'
shutil.copy2(root/'tests/replay_cave_context/drive.gd',out/'driver.gd')
(out/'inputs.json').write_text(json.dumps({'driver':sha(out/'driver.gd'),'binaries':{p.name:sha(p) for p in (project/'bin').glob('*.'+ext)}},indent=2)+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
env=os.environ.copy();env.update(ODIN_GODOT_ROOT=str(root),ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)),REPLAY_CAVE_PORT=str(port),REPLAY_CAVE_LATENCY='120',CAVE_CONTEXT_DIR=str(out))
children=[];logs=[]
try:
 for role in ['host','client','observer']:
  log=(out/f'{role}.log').open('w');logs.append(log)
  child=subprocess.Popen([env['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',str(out/'driver.gd')],env=env|{'REPLAY_CAVE_ROLE':role,'REPLAY_CAVE_TOKEN':'context-'+role},stdout=log,stderr=subprocess.STDOUT);children.append(child)
  if role=='host':
   until=time.monotonic()+10
   while 'REPLAY_CAVE_READY' not in (out/'host.log').read_text():assert child.poll() is None and time.monotonic()<until;time.sleep(.05)
 until=time.monotonic()+65
 while time.monotonic()<until:
  if all(p.poll() is not None for p in children) or any(p.poll() not in (None,0) for p in children):break
  time.sleep(.05)
 exits=[p.poll() for p in children];(out/'exits.json').write_text(json.dumps(exits)+'\n');assert exits==[0,0,0],exits
 receipts={}
 for role in ['host','client','observer']:
  text=(out/f'{role}.log').read_text();assert 'REPLAY_CAVE_CONTEXT_OK' in text and not re.search(r'FAIL|ERROR:|instances were leaked',text),text
  data=json.loads((out/f'{role}.json').read_text());assert data['pass'] and data['bag']==3 and data['position_while_blocked']<=110 and abs(data['position_after_unblock']-300)<2
  receipts[role]=data
 assert receipts['client']['legacy_refused'] and receipts['client']['blocked_packets']>=10 and abs(receipts['client']['local_x']-300)<1
 (out/'verified.json').write_text(json.dumps(receipts,indent=2)+'\n');print('REPLAY_CAVE_ACTION_CONTEXT_NATIVE_OK')
finally:
 for p in children:
  if p.poll() is None:p.terminate()
 for p in children:
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for f in logs:f.close()
