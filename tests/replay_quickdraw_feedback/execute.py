from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();label=sys.argv[2] if len(sys.argv)>2 else 'feedback';folder=out/label;folder.mkdir(exist_ok=False);project=out/'project';ext='dylib' if sys.platform=='darwin' else 'so'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
shutil.copy2(root/'tests/replay_quickdraw_feedback/drive.gd',folder/'driver.gd')
(folder/'builds.json').write_text(json.dumps({'binaries':{p.name:sha(p) for p in (project/'bin').glob('*.'+ext)},'driver_sha256':sha(folder/'driver.gd')},indent=2)+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
children=[];logs=[];codes={}
try:
 for role in ('host','client','observer'):
  env=os.environ.copy();env.update(RQ_FEEDBACK_ROLE=role,RQ_FEEDBACK_DIR=str(folder),RQ_ROLE=role,RQ_PORT=str(port),RQ_TOKEN='feedback-'+role,RQ_NAME=role,RQ_PERSIST='0',RQ_GOLD='0',RQ_BOT='',RQ_LATENCY='120',RQ_JITTER='0',RQ_LOSS='0',RQ_DUPLICATE='0',RQ_TEST_SECONDS='0',RQ_COORD_PORT='0',ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)))
  rendered=role=='host' and os.environ.get('RQ_FEEDBACK_RENDERED')=='1'
  if rendered:env['RQ_FEEDBACK_CAPTURE']=str(folder/'landing.png')
  log=(folder/(role+'.log')).open('w');logs.append(log)
  child=subprocess.Popen([env['GODOT']]+([] if rendered else ['--headless'])+['--max-fps','60','--path',str(project),'--script',str(folder/'driver.gd')],env=env,stdout=log,stderr=subprocess.STDOUT);children.append((role,child))
  if role=='host':
   deadline=time.monotonic()+10
   while 'REPLAY_QUICKDRAW_READY' not in (folder/'host.log').read_text():
    assert child.poll() is None and time.monotonic()<deadline,'host startup'
    time.sleep(.05)
 deadline=time.monotonic()+90
 while any(child.poll() is None for _,child in children):
  if time.monotonic()>deadline:raise RuntimeError('feedback timeout')
  for role,child in children:
   text=(folder/(role+'.log')).read_text()
   if re.search(r'RQ_FEEDBACK_FAIL|REPLAY_QUICKDRAW_FAIL|SCRIPT ERROR|ERROR:',text):raise RuntimeError(role+': '+text[-2500:])
  time.sleep(.05)
 for role,child in children:
  assert child.returncode==0,role
  text=(folder/(role+'.log')).read_text();assert 'RQ_FEEDBACK_OK '+role in text and not re.search(r'instances were leaked|resources still in use',text),role
 print('REPLAY_QUICKDRAW_FEEDBACK_OK')
finally:
 for _,child in children:
  if child.poll() is None:child.terminate()
 for role,child in children:
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
  codes[role]=child.returncode
 for log in logs:log.close()
 (folder/'exits.json').write_text(json.dumps(codes,indent=2)+'\n')
