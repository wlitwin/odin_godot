from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];prepared=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();mode=sys.argv[3];out.mkdir(parents=True,exist_ok=False)
project=prepared/'project';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in json.loads((prepared/'prepared.json').read_text()).items():assert sha(project/n)==h,n
for n,h in json.loads((prepared/'framework.json').read_text()).items():assert sha(root/n)==h,n
ext='dylib' if sys.platform=='darwin' else 'so'
(out/'binaries.json').write_text(json.dumps({p.name:sha(p) for p in (project/'bin').glob('*.'+ext)},indent=2)+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
driver=out/'driver.gd';shutil.copy2(root/'tests/replay_cave_owner/flow.gd' if mode=='flow' else project/'network_test.gd',driver)
if mode=='fault':
 text=driver.read_text();anchor=next(line for line in text.splitlines() if 'print("REPLAY_CAVE_NETWORK_", role.to_upper(), "_OK")' in line)
 indent=anchor[:len(anchor)-len(anchor.lstrip())]
 checks=['var drops := int(game.campaign_probe("fault_drops",0))','var duplicates := int(game.campaign_probe("fault_duplicates",0))','if drops <= 0 or duplicates <= 0: return fail("faults not observed")','print("CAVE_OWNER_FAULTS drops=",drops," duplicates=",duplicates)']
 driver.write_text(text.replace(anchor,'\n'.join(indent+line for line in checks)+'\n'+anchor))
roles=['host','client','observer'] if mode=='flow' else ['host','client'];children=[];logs=[]
env=os.environ.copy();env.update(ODIN_GODOT_ROOT=str(root),ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)),REPLAY_CAVE_PORT=str(port),REPLAY_CAVE_LATENCY='120',CAVE_OWNER_DIR=str(out))
if mode in {'flow','fault'}:env.update(REPLAY_CAVE_JITTER='20',REPLAY_CAVE_LOSS='1000',REPLAY_CAVE_DUPLICATE='1000')
try:
 for role in roles:
  log=(out/f'{role}.log').open('w');logs.append(log)
  child=subprocess.Popen([env['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',str(driver)],env=env|{'REPLAY_CAVE_ROLE':role,'REPLAY_CAVE_TOKEN':'owner-'+role},stdout=log,stderr=subprocess.STDOUT);children.append(child)
  if role=='host':
   deadline=time.monotonic()+10
   while 'REPLAY_CAVE_READY' not in (out/'host.log').read_text():assert child.poll() is None and time.monotonic()<deadline;time.sleep(.05)
 deadline=time.monotonic()+65
 while time.monotonic()<deadline:
  if all(c.poll() is not None for c in children):break
  if any(c.poll() not in (None,0) for c in children):break
  time.sleep(.05)
 statuses=[c.poll() for c in children];(out/'result.json').write_text(json.dumps({'mode':mode,'exits':statuses},indent=2)+'\n')
 assert statuses==[0]*len(roles),statuses
 for role in roles:
  text=(out/f'{role}.log').read_text();assert not re.search(r'ERROR:|FAIL|instances were leaked|resources still in use',text),text
  assert ('REPLAY_CAVE_OWNER_FLOW_OK' if mode=='flow' else f'REPLAY_CAVE_NETWORK_{role.upper()}_OK') in text
  if mode=='fault':
   found=re.search(r'CAVE_OWNER_FAULTS drops=(\d+) duplicates=(\d+)',text);assert found and int(found[1])>0 and int(found[2])>0
  if mode=='flow':
   receipt=json.loads((out/f'{role}.json').read_text());assert receipt['pass'] and receipt['drops']>0 and receipt['duplicates']>0
   rows=receipt['observations'];assert [r['owner'] for r in rows]==[1,1,0,2,2]
   assert rows[0]['revision']==rows[1]['revision']<rows[2]['revision']<rows[3]['revision']==rows[4]['revision']
 print('REPLAY_CAVE_OWNER_CASE_OK',mode)
finally:
 for c in children:
  if c.poll() is None:c.terminate()
 for c in children:
  try:c.wait(timeout=5)
  except subprocess.TimeoutExpired:c.kill();c.wait()
 for log in logs:log.close()
