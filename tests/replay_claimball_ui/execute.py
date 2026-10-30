from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];ext='dylib' if sys.platform=='darwin' else 'so';out=Path(sys.argv[1]).resolve();label=sys.argv[2] if len(sys.argv)>2 else 'run';folder=out/label;folder.mkdir(exist_ok=False);project=out/'project'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
if (out/'framework.json').exists():
 for name,digest in json.loads((out/'framework.json').read_text()).items():assert sha(root/name)==digest,name
dedicated=len(sys.argv)>3 and sys.argv[3]=='rounds-dedicated'
rounds=dedicated or len(sys.argv)>3 and sys.argv[3]=='rounds'
if rounds:
 base=(root/'tests/replay_claimball_ui/drive.gd').read_text().split('func run():',1)[0]
 (folder/'driver.gd').write_text(base+(root/'tests/replay_claimball_ui/rounds.gd').read_text())
else:shutil.copy2(root/'tests/replay_claimball_ui/drive.gd',folder/'driver.gd')
if dedicated:(folder/'server.gd').write_text(base+(root/'tests/replay_claimball_ui/round_server.gd').read_text())
(folder/'binaries.json').write_text(json.dumps({p.name:sha(p) for p in (project/'bin').glob('*.'+ext)},indent=2)+'\n')
(folder/'driver-sha256.txt').write_text(sha(folder/'driver.gd')+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
children=[];logs=[];codes={}
try:
 for role in (('server','host','client','observer') if dedicated else ('host','client','observer')):
  env=os.environ.copy();env.update(RCB_UI_ROLE=role,RCB_UI_DIR=str(folder),RCB_UI_DEDICATED='1' if dedicated else '0',RCB_ROLE='server' if role=='server' else '',RCB_PORT=str(port),RCB_TOKEN='claimball-ui-'+label+'-'+role,RCB_PERSIST='0',RCB_PLAYERS='2',RCB_GOALS='1',RCB_TEST='0',RCB_BOT='',RCB_LATENCY='120',RCB_JITTER='0',RCB_LOSS='0',RCB_DUPLICATE='0',RCB_TEST_SECONDS='0',RCB_COORD_PORT='0',ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)))
  rendered=role=='host' and os.environ.get('RCB_UI_RENDERED')=='1'
  if rendered:env['RCB_UI_CAPTURE']=str(folder/'scoreboard.png')
  log=(folder/(role+'.log')).open('w');logs.append(log)
  child=subprocess.Popen([env['GODOT']]+([] if rendered else ['--headless'])+['--max-fps','60','--path',str(project),'--script',str(folder/('server.gd' if role=='server' else 'driver.gd'))],env=env,stdout=log,stderr=subprocess.STDOUT);children.append((role,child))
 deadline=time.monotonic()+100
 while any(child.poll() is None for _,child in children):
  if time.monotonic()>deadline:raise RuntimeError('UI cohort timeout')
  for role,child in children:
   text=(folder/(role+'.log')).read_text()
   if re.search(r'CLAIMBALL_UI_FAIL|REPLAY_CLAIMBALL_FAIL|SCRIPT ERROR|ERROR:',text):raise RuntimeError(role+': '+text[-2000:])
  time.sleep(.1)
 for role,child in children:
  codes[role]=child.returncode;assert child.returncode==0,role
  text=(folder/(role+'.log')).read_text();assert 'REPLAY_CLAIMBALL_UI_PEER_OK role='+role in text and not re.search(r'instances were leaked|resources still in use',text),role
 if rounds:
  rows=[json.loads((folder/('result-'+role+'.json')).read_text()) for role in ('host','client','observer')]
  for row in rows:
   assert row['round']==2 and row['winner']>0 and row['started'] and row['kicks']>0,row
   assert all(row[key]==rows[0][key] for key in ('round','winner','left','right','kicks','spikes')),rows
  assert [r['seat'] for r in rows]==[1,2,0],rows
  if dedicated:
   server=json.loads((folder/'result-server.json').read_text())
   assert all(server[key]==rows[0][key] for key in ('round','winner','left','right','kicks','spikes')),server
   assert rows[0]['members']==1 and rows[1]['members']==1 and rows[2]['members']==0,rows
  print('REPLAY_CLAIMBALL_ROUND_OK')
 else:print('REPLAY_CLAIMBALL_UI_OK')
finally:
 for _,child in children:
  if child.poll() is None:child.terminate()
 for role,child in children:
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
  codes[role]=child.returncode
 for log in logs:log.close()
 (folder/'exits.json').write_text(json.dumps(codes,indent=2)+'\n')
