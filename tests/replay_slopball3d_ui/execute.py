from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];ext='dylib' if sys.platform=='darwin' else 'so';out=Path(sys.argv[1]).resolve();label=sys.argv[2] if len(sys.argv)>2 else 'run';folder=out/label;folder.mkdir(exist_ok=False);project=out/'project'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
if (out/'framework.json').exists():
 for name,digest in json.loads((out/'framework.json').read_text()).items():assert sha(root/name)==digest,name
rounds=len(sys.argv)>3 and sys.argv[3]=='rounds'
if rounds:
 base=(root/'tests/replay_slopball3d_ui/drive.gd').read_text().split('func run():',1)[0]
 (folder/'driver.gd').write_text(base+(root/'tests/replay_slopball3d_ui/rounds.gd').read_text())
else:shutil.copy2(root/'tests/replay_slopball3d_ui/drive.gd',folder/'driver.gd')
(folder/'binaries.json').write_text(json.dumps({p.name:sha(p) for p in (project/'bin').glob('*.'+ext)},indent=2)+'\n')
(folder/'driver-sha256.txt').write_text(sha(folder/'driver.gd')+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
children=[];logs=[];codes={}
try:
 for role in ('host','client','observer'):
  env=os.environ.copy();env.update(RS3_UI_ROLE=role,RS3_UI_DIR=str(folder),RS3_ROLE='',RS3_PORT=str(port),RS3_TOKEN='slopball3d-ui-'+label+'-'+role,RS3_PERSIST='0',RS3_PLAYERS='2',RS3_GOALS='1',RS3_TEST='0',RS3_BOT='',RS3_LATENCY='120',RS3_JITTER='0',RS3_LOSS='0',RS3_DUPLICATE='0',RS3_TEST_SECONDS='0',RS3_COORD_PORT='0',ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)))
  rendered=role=='host' and os.environ.get('RS3_UI_RENDERED')=='1'
  if rendered:env['RS3_UI_CAPTURE']=str(folder/'scoreboard.png')
  log=(folder/(role+'.log')).open('w');logs.append(log)
  child=subprocess.Popen([env['GODOT']]+([] if rendered else ['--headless'])+['--max-fps','60','--path',str(project),'--script',str(folder/'driver.gd')],env=env,stdout=log,stderr=subprocess.STDOUT);children.append((role,child))
 deadline=time.monotonic()+100
 while any(child.poll() is None for _,child in children):
  if time.monotonic()>deadline:raise RuntimeError('UI cohort timeout')
  for role,child in children:
   text=(folder/(role+'.log')).read_text()
   if re.search(r'SLOPBALL3D_UI_FAIL|REPLAY_SLOPBALL3D_FAIL|SCRIPT ERROR|ERROR:',text):raise RuntimeError(role+': '+text[-2000:])
  time.sleep(.1)
 for role,child in children:
  codes[role]=child.returncode;assert child.returncode==0,role
  text=(folder/(role+'.log')).read_text();assert 'REPLAY_SLOPBALL3D_UI_PEER_OK role='+role in text and not re.search(r'instances were leaked|resources still in use',text),role
 if rounds:
  rows=[json.loads((folder/('result-'+role+'.json')).read_text()) for role in ('host','client','observer')]
  assert all(row['round']==2 and row['winner']>0 for row in rows),rows
  assert all(all(row[k]==rows[0][k] for k in ['round','left','right','winner']) for row in rows),rows
  assert [row['seat'] for row in rows]==[1,2,0],rows
  print('REPLAY_SLOPBALL3D_ROUND_OK')
 else:print('REPLAY_SLOPBALL3D_UI_OK')
finally:
 for _,child in children:
  if child.poll() is None:child.terminate()
 for role,child in children:
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
  codes[role]=child.returncode
 for log in logs:log.close()
 (folder/'exits.json').write_text(json.dumps(codes,indent=2)+'\n')
