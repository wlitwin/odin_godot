from pathlib import Path
import hashlib,json,os,re,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];build=Path(sys.argv[1]).resolve();out=Path(sys.argv[2]).resolve();mode=sys.argv[3];out.mkdir(parents=True,exist_ok=False)
assert mode in ('repeat','return')
project,coord=build/'project',build/'coordinator';ext='dylib' if sys.platform=='darwin' else 'so';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for n,h in json.loads((build/'prepared.json').read_text()).items():assert sha(project/n)==h,n
for n,h in json.loads((build/'framework.json').read_text()).items():assert sha(root/n)==h,n
for _ in range(100):
 holders=[]
 try:
  s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.bind(('127.0.0.1',0));port=s.getsockname()[1];holders.append(s)
  if port>65000:continue
  for i in range(1,4):s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);holders.append(s);s.bind(('127.0.0.1',port+i))
  break
 except OSError:pass
 finally:
  for s in holders:s.close()
else:raise RuntimeError('no port block')
env=os.environ|{'ODIN_GODOT_ROOT':str(root),'REPLAY_MIGRATION_PORT':str(port),'REPLAY_MIGRATION_DB':str(out/'room.sqlite3'),'REPLAY_MIGRATION_DIR':str(out),'REPLAY_MIGRATION_MODE':mode,'REPLAY_MIGRATION_GAME':'cave','STEAM_VIRTUAL_PORT':'65535'}
children=[];handles=[]
def start(path,name,member=0,returned=False):
 local=env|{'ODIN_SCRIPTS_DLL':str(path/('bin/libodinscripts.'+ext))};args=[local['GODOT'],'--headless','--max-fps','60','--path',str(path)]
 if member:
  local|={'REPLAY_CAVE_MEMBER':str(member),'REPLAY_CAVE_INCARNATION':str(100+member),'REPLAY_CAVE_COORD_KEY':f'{20+member:02x}'+'0'*62,'REPLAY_CAVE_COORD_PORT':str(port),'REPLAY_CAVE_TOKEN':f'migration-{member}','REPLAY_CAVE_PERSIST':'0','REPLAY_CAVE_LATENCY':'120','REPLAY_MIGRATION_RETURNED':'1' if returned else '0'}
  args+=['--script','migration_test.gd']
 h=(out/(name+'.log')).open('w');handles.append(h);p=subprocess.Popen(args,env=local,stdout=h,stderr=subprocess.STDOUT);children.append(p);return p
try:
 service=start(coord,'coordinator');deadline=time.monotonic()+15
 while 'REPLAY_MIGRATION_COORDINATOR_READY' not in (out/'coordinator.log').read_text():assert service.poll() is None and time.monotonic()<deadline;time.sleep(.05)
 members=[]
 for member in [1,2,3]:members.append(start(project,f'member-{member}',member));time.sleep(.5)
 deadline=time.monotonic()+70;killed=False;returned=None
 while time.monotonic()<deadline:
  if mode=='return' and not killed and (out/'kill_owner').exists():members[0].kill();members[0].wait();killed=True
  if mode=='return' and returned is None and (out/'guest_after_migration').exists():returned=start(project,'returned',1,True)
  active=members if mode=='repeat' else members[1:]+([returned] if returned else [])
  for p in active:assert p.poll() in (None,0),p.returncode
  if all(p.poll()==0 for p in active) and (mode=='repeat' or returned):break
  time.sleep(.05)
 else:raise RuntimeError('extended recovery timeout')
 records={}
 for name in (['member-1','member-2','member-3'] if mode=='repeat' else ['member-2','member-3','returned']):
  text=(out/(name+'.log')).read_text();assert not re.search(r'SCRIPT ERROR|ERROR:|REPLAY_MIGRATION_FAIL|instances were leaked',text),text[-3000:]
  assert ('REPLAY_MIGRATION_GUEST_OK' if name=='member-3' else 'REPLAY_MIGRATION_RETURNED_OK' if name=='returned' else 'REPLAY_MIGRATION_MEMBER_OK') in text,text[-3000:]
  if mode=='repeat':assert 'count=3' in text and 'epoch=3' in text,(name,text[-3000:])
  clients=re.findall(r'STEAM_ROOM_CLIENT member=(\d+) target=(\d+) virtual_port=(\d+)',text)
  if mode=='repeat' and name in ['member-2','member-3']:assert clients[-1][1:]==('76561198000000001','65535')
  if name=='returned':assert clients[-1][1:]==('76561198000000002','65535')
  records[name]={'client_calls':clients,'factory_calls':re.findall(r'STEAM_ROOM_FACTORY member=(\d+) count=(\d+)',text)}
 (out/'result.json').write_text(json.dumps({'pass':True,'mode':mode,'virtual_port':65535,'records':records,'transport':'API contract over local ENet'},indent=2)+'\n');print('REPLAY_STEAM_ROOM_EXTENDED_OK',mode)
finally:
 for p in children:
  if p.poll() is None:p.terminate()
 for p in children:
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill();p.wait()
 for h in handles:h.close()
 (out/'exits.json').write_text(json.dumps([p.returncode for p in children])+'\n')
