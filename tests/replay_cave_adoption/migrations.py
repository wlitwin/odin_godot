from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time

root=Path(__file__).resolve().parents[2]
out=Path(sys.argv[1]).resolve()
run=out/(sys.argv[2] if len(sys.argv)>2 else 'migrations')
run.mkdir(exist_ok=False)
project=out/'project';coord=root/'tests/replay_migration'
ext='dylib' if sys.platform=='darwin' else 'so'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
for name,digest in json.loads((out/'framework.json').read_text()).items():assert sha(root/name)==digest,name
shutil.copy2(root/'tests/replay_cave_adoption/migration.gd',run/'driver.gd')
(run/'inputs.json').write_text(json.dumps({'driver':sha(run/'driver.gd'),'game':{p.name:sha(p) for p in (project/'bin').glob('*.'+ext)},'coordinator':{p.name:sha(p) for p in (coord/'bin').glob('*.'+ext)}},indent=2)+'\n')
for mode,carrier in [('planned',1),('crash',1)]:
 case=run/f'{mode}-{carrier}';case.mkdir();children=[];handles=[];killed=False
 # Reserve a contiguous four-port block while selecting this isolated room.
 for _ in range(100):
  holders=[]
  try:
   first=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);first.bind(('127.0.0.1',0));port=first.getsockname()[1];holders.append(first)
   if port>65000:continue
   for n in range(1,4):
    holder=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);holders.append(holder);holder.bind(('127.0.0.1',port+n))
   break
  except OSError:pass
  finally:
   for holder in holders:holder.close()
 else:raise RuntimeError('no free contiguous port block')
 env=os.environ.copy();env.update(REPLAY_MIGRATION_PORT=str(port),REPLAY_MIGRATION_DB=str(case/'room.sqlite3'),REPLAY_MIGRATION_DIR=str(case),REPLAY_MIGRATION_MODE=mode,REPLAY_MIGRATION_GAME='cave',CAVE_CARRIER_MEMBER=str(carrier),REPLAY_CAVE_PERSIST='0')
 def start(path,logname,extra,script=None):
  local=env|extra|{'ODIN_SCRIPTS_DLL':str(path/('bin/libodinscripts.'+ext))}
  handle=(case/logname).open('w');handles.append(handle)
  args=[local['GODOT'],'--headless','--max-fps','60','--path',str(path)]
  if script:args+=['--script',str(script)]
  child=subprocess.Popen(args,env=local,stdout=handle,stderr=subprocess.STDOUT);children.append(child);return child
 try:
  service=start(coord,'coordinator.log',{})
  deadline=time.monotonic()+10
  while 'REPLAY_MIGRATION_COORDINATOR_READY' not in (case/'coordinator.log').read_text():
   assert service.poll() is None and time.monotonic()<deadline,'coordinator did not start'
   time.sleep(.05)
  members=[]
  for member in range(1,4):
   members.append(start(project,f'member-{member}.log',{'REPLAY_CAVE_MEMBER':str(member),'REPLAY_CAVE_INCARNATION':str(100+member),'REPLAY_CAVE_COORD_KEY':f'{20+member:02x}'+'0'*62,'REPLAY_CAVE_COORD_PORT':str(port),'REPLAY_CAVE_TOKEN':f'migration-{member}','REPLAY_CAVE_LATENCY':'120'},run/'driver.gd'))
   admitted=time.monotonic()+12
   while not (case/f'admitted-{member}').exists():
    assert members[-1].poll() is None and time.monotonic()<admitted,f'member {member} admission'
    time.sleep(.05)
  deadline=time.monotonic()+42
  while time.monotonic()<deadline:
   if mode=='crash' and not killed and (case/'kill_owner').exists():members[0].kill();members[0].wait();killed=True
   survivors=members if mode=='planned' else members[1:]
   for index,child in enumerate(members,1):
    if index==1 and killed:continue
    assert child.poll() in (None,0),f'{case.name}: member {index} failed'
   if all(child.poll()==0 for child in survivors):break
   time.sleep(.05)
  else:raise RuntimeError(f'{case.name}: migration timed out')
  assert mode!='crash' or killed
  for member in ([1,2,3] if mode=='planned' else [2,3]):
   text=(case/f'member-{member}.log').read_text()
   assert 'CAVE_ADOPTION_MIGRATION_OK' in text and not re.search(r'ERROR:|SCRIPT ERROR|FAIL|instances were leaked|resources still in use',text),text
   result=json.loads((case/f'member-{member}.json').read_text());assert result['pass']
   labels={entry['label']:entry for entry in result['observations']}
   assert labels['recovered']['carrier']==2 and labels['continued carrying']['carrier']==2
   assert labels['released in new epoch']['carrier']==0 and labels['released in new epoch']['version']==labels['before handoff']['version']+2
  print('CAVE_ADOPTION_MIGRATION_CASE_OK',mode,carrier,flush=True)
 finally:
  for child in children:
   if child.poll() is None:child.terminate()
  for child in children:
   try:child.wait(timeout=5)
   except subprocess.TimeoutExpired:child.kill();child.wait()
  for handle in handles:handle.close()
print('REPLAY_CAVE_ADOPTION_MIGRATIONS_OK')
