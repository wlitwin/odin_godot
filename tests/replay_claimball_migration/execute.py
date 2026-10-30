from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];app=Path(sys.argv[1]).resolve();coord=Path(sys.argv[2]).resolve();out=Path(sys.argv[3]).resolve();out.mkdir(parents=True,exist_ok=False);modes=sys.argv[4:] or ['planned','crash'];ext='dylib' if sys.platform=='darwin' else 'so'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for prepared in [app,coord]:
 for name,digest in json.loads((prepared/'prepared.json').read_text()).items():assert sha(prepared/'project'/name)==digest,(prepared,name)
for name,digest in json.loads((app/'framework.json').read_text()).items():assert sha(root/name)==digest,name
(out/'binaries.json').write_text(json.dumps({label:{p.name:sha(p) for p in (base/'project/bin').glob('*.'+ext)} for label,base in [('app',app),('coordinator',coord)]},indent=2)+'\n')
for mode in modes:
 assert mode in ('planned','crash'),mode
 folder=out/mode;folder.mkdir();driver=folder/'driver.gd';shutil.copy2(Path(__file__).with_name('drive.gd'),driver)
 (folder/'driver-sha256.txt').write_text(sha(driver)+'\n')
 # Reserve a coordinator/game port range long enough to select distinct ports;
 # each child then binds its own authenticated fixture endpoint.
 for _ in range(100):
  sockets=[]
  try:
   first=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);first.bind(('127.0.0.1',0));sockets.append(first);port=first.getsockname()[1]
   if port>64996:continue
   for n in range(1,4):
    sock=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);sockets.append(sock);sock.bind(('127.0.0.1',port+n))
   break
  except OSError:pass
  finally:
   for sock in sockets:sock.close()
 else:raise RuntimeError('no local fixture port range')
 children=[];logs=[];exits={};killed=False
 def launch(name,base,env,script=None,render=False):
  env.update(ODIN_SCRIPTS_DLL=str(base/'project/bin'/('libodinscripts.'+ext)))
  log=(folder/(name+'.log')).open('w');logs.append(log)
  command=[env['GODOT']]+([] if render else ['--headless'])+['--max-fps','60','--path',str(base/'project')]
  if script:command+=['--script',str(script)]
  child=subprocess.Popen(command,env=env,stdout=log,stderr=subprocess.STDOUT);children.append((name,child));return child
 def check_errors():
  for name,_ in children:
   text=(folder/(name+'.log')).read_text()
   if re.search(r'CLAIMBALL_MIGRATION_FAIL|REPLAY_CLAIMBALL_FAIL|REPLAY_MIGRATION_FAIL|SCRIPT ERROR|ERROR:',text):raise RuntimeError(name+': '+text[-3000:])
 try:
  env=os.environ.copy();env.update(REPLAY_MIGRATION_GAME='claimball',REPLAY_MIGRATION_PORT=str(port),REPLAY_MIGRATION_DB=str(folder/'room.sqlite'),REPLAY_MIGRATION_TRACE='1')
  service=launch('coordinator',coord,env)
  deadline=time.monotonic()+15
  while 'REPLAY_MIGRATION_COORDINATOR_READY room=50 content=52434c41494d4233' not in (folder/'coordinator.log').read_text():
   check_errors();assert service.poll() is None and time.monotonic()<deadline,'coordinator startup';time.sleep(.05)
  for member in (1,2,3):
   env=os.environ.copy();env.update(REPLAY_MIGRATION_MODE=mode,REPLAY_MIGRATION_DIR=str(folder),RCB_ROLE='host' if member==1 else 'client',RCB_MEMBER=str(member),RCB_INCARNATION=str(100+member),RCB_COORD_PORT=str(port),RCB_COORD_KEY=f'{member+20:02x}'+'0'*62,RCB_TOKEN=f'migration-{member}',RCB_NAME=f'member-{member}',RCB_PERSIST='0',RCB_PLAYERS='3',RCB_GOALS='9',RCB_LATENCY='120',RCB_JITTER='0',RCB_LOSS='0',RCB_DUPLICATE='0',RCB_TEST='0',RCB_BOT='idle',RCB_PROBE='1',RCB_SAVE=str(folder/f'forbidden-member-{member}.replay'))
   launch('member-'+str(member),app,env,driver,os.environ.get('RCB_MIGRATION_RENDER')=='1');time.sleep(.4)
  deadline=time.monotonic()+85
  while any(child.poll() is None for name,child in children if name!='coordinator'):
   check_errors();assert service.poll() is None,'coordinator exited';assert time.monotonic()<deadline,'migration cohort deadline'
   if mode=='crash' and not killed and (folder/'kill-owner.json').exists():
    owner=next(child for name,child in children if name=='member-1');assert owner.poll() is None,'owner exited before injection';owner.kill();owner.wait();killed=True
   time.sleep(.05)
  check_errors()
  for name,child in children:
   if name=='coordinator':continue
   exits[name]=child.returncode
   if name=='member-1' and mode=='crash':assert killed and child.returncode<0;continue
   text=(folder/(name+'.log')).read_text();member=name[-1]
   assert child.returncode==0 and f'REPLAY_CLAIMBALL_MIGRATION_PEER_OK member={member}' in text,(name,text[-3000:])
   assert not re.search(r'instances were leaked|resources still in use',text),name
  rows={member:json.loads((folder/f'done-{member}.json').read_text()) for member in ([1,2,3] if mode=='planned' else [2,3])}
  assert rows[2]['exact'] and rows[2]['moving'] and rows[2]['complete'],rows
  assert all(row['epoch']==2 and row['hash']==rows[2]['hash'] and row['tick']==rows[2]['tick'] for row in rows.values()),rows
  assert all(row['members']==1 for member,row in rows.items() if member!=2),rows
  assert not list(folder.glob('forbidden-member-*.replay')),'room wrote a direct save'
  restored=json.loads((folder/'restored.json').read_text());assert restored['complete'] and restored['members']==3,restored
  (folder/'report.json').write_text(json.dumps({'pass':True,'mode':mode,'owner_killed':killed,'restored':restored,'peers':rows},indent=2)+'\n')
  print('REPLAY_CLAIMBALL_MIGRATION_PHASE_OK',mode)
 finally:
  for _,child in children:
   if child.poll() is None:child.terminate()
  for name,child in children:
   try:child.wait(timeout=5)
   except subprocess.TimeoutExpired:child.kill();child.wait()
   exits[name]=child.returncode
  for log in logs:log.close()
  (folder/'exits.json').write_text(json.dumps(exits,indent=2)+'\n')
print('REPLAY_CLAIMBALL_MIGRATION_OK')
