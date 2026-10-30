from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];prepared=Path(sys.argv[1]).resolve();variant=sys.argv[2];out=Path(sys.argv[3]).resolve();out.mkdir(parents=True,exist_ok=False)
assert variant in ('kit','server','owner')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();project=prepared/variant/'project';ext='dylib' if sys.platform=='darwin' else 'so'
for n,h in json.loads((prepared/variant/'prepared.json').read_text()).items():assert sha(project/n)==h,n
for n,h in json.loads((prepared/'framework.json').read_text()).items():assert sha(root/n)==h,n
driver=out/'driver.gd';shutil.copy2(root/'tests/replay_cave_comparison/driver.gd',driver)
(out/'inputs.json').write_text(json.dumps({'variant':variant,'driver':sha(driver),'binaries':{p.name:sha(p) for p in (project/'bin').glob('*.'+ext)}},indent=2)+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
env=os.environ.copy();env.update(ODIN_GODOT_ROOT=str(root),ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)),CAVE_COMPARE_DIR=str(out),CAVE_COMPARE_VARIANT=variant,CAVE_PORT=str(port),CAVE_LATENCY='120',CAVE_STEAM='0',CAVE_SAVE=str(out/'unused-save'),REPLAY_CAVE_PORT=str(port),REPLAY_CAVE_LATENCY='120',REPLAY_CAVE_BACKUP='1',REPLAY_CAVE_PERSIST='0')
children=[];logs=[]
try:
 for role in ['host','client']:
  h=(out/f'{role}.log').open('w');logs.append(h)
  local=env|{'CAVE_COMPARE_ROLE':role,'CAVE_NAME':role,'CAVE_TOKEN':'compare-'+role,'REPLAY_CAVE_ROLE':role,'REPLAY_CAVE_NAME':role,'REPLAY_CAVE_TOKEN':'compare-'+role}
  child=subprocess.Popen([env['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',str(driver)],env=local,stdout=h,stderr=subprocess.STDOUT);children.append(child)
  if role=='host':
   marker='CAVE_HOSTING' if variant=='kit' else 'REPLAY_CAVE_READY';deadline=time.monotonic()+12
   while marker not in (out/'host.log').read_text():assert child.poll() is None and time.monotonic()<deadline,(out/'host.log').read_text();time.sleep(.05)
 deadline=time.monotonic()+65
 while time.monotonic()<deadline:
  if all(p.poll() is not None for p in children) or any(p.poll() not in (None,0) for p in children):break
  time.sleep(.05)
 exits=[p.poll() for p in children];(out/'exits.json').write_text(json.dumps(exits)+'\n');assert exits==[0,0],exits
 for role in ['host','client']:
  text=(out/f'{role}.log').read_text();assert 'REPLAY_CAVE_COMPARE_PROCESS_OK' in text and not re.search(r'FAIL|ERROR:|instances were leaked',text),text
  d=json.loads((out/f'{role}.json').read_text());assert d['pass'] and d['callback_dropped']==0 and len(d['callback_us'])>=800 and d['duration_ms']>=16000
 print('REPLAY_CAVE_COMPARE_CASE_OK',variant)
finally:
 for p in children:
  if p.poll() is None:p.terminate()
 for p in children:
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for h in logs:h.close()
