from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time,uuid
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();run=out/(sys.argv[2] if len(sys.argv)>2 else 'run');run.mkdir(exist_ok=False);project=out/'project'
ext='dylib' if sys.platform=='darwin' else 'so';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
for name,digest in json.loads((out/'framework.json').read_text()).items():assert sha(root/name)==digest,name
shutil.copy2(root/'tests/replay_cave_social/driver.gd',run/'driver.gd')
(run/'inputs.json').write_text(json.dumps({'driver':sha(run/'driver.gd'),'binaries':{p.name:sha(p) for p in (project/'bin').glob('*.'+ext)}},indent=2)+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
# Real keyboard input in the name field, including the F ping binding.
shutil.copy2(root/'tests/replay_cave_social/name_input.gd',run/'name_input.gd')
name_env=os.environ.copy();name_env.update(REPLAY_CAVE_ROLE='solo',REPLAY_CAVE_LOBBY='1',REPLAY_CAVE_NAME='Keyboard',REPLAY_CAVE_TOKEN='name-input-'+uuid.uuid4().hex,REPLAY_CAVE_PERSIST='0',ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)))
with (run/'name-input.log').open('w') as log:
 result=subprocess.run([name_env['GODOT'],'--headless','--fixed-fps','60','--path',str(project),'--script',str(run/'name_input.gd')],env=name_env,stdout=log,stderr=subprocess.STDOUT,timeout=30)
text=(run/'name-input.log').read_text();assert result.returncode==0 and 'CAVE_NAME_INPUT_OK' in text and not re.search(r'ERROR:|SCRIPT ERROR|FAIL',text),text
token='cave-social-'+uuid.uuid4().hex;children=[];logs=[];configs={}
try:
 for role in ('host','client','observer'):
  env=os.environ.copy();env.update(REPLAY_CAVE_ROLE=role,REPLAY_CAVE_LOBBY='1',REPLAY_CAVE_NAME={'host':'Alpha','client':'Beta','observer':'Watcher'}[role],REPLAY_CAVE_TOKEN=token+'-'+role,REPLAY_CAVE_PERSIST='0',REPLAY_CAVE_LATENCY='120',REPLAY_CAVE_PORT=str(port),CAVE_SOCIAL_OUT=str(run),ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)))
  rendered=role=='host' and os.environ.get('CAVE_SOCIAL_RENDERED')=='1'
  if rendered:env['CAVE_SOCIAL_CAPTURE']=str(run/'scoreboard.png')
  configs[role]={k:v for k,v in env.items() if k.startswith(('REPLAY_CAVE_','CAVE_SOCIAL_'))}
  log=(run/(role+'.log')).open('w');logs.append(log)
  children.append(subprocess.Popen([env['GODOT']]+([] if rendered else ['--headless'])+['--max-fps','60','--path',str(project),'--script',str(run/'driver.gd')],env=env,stdout=log,stderr=subprocess.STDOUT))
  time.sleep(.2)
 (run/'environment.json').write_text(json.dumps(configs,indent=2)+'\n')
 for child in children:assert child.wait(timeout=45)==0,'scene failed'
 for role in ('host','client','observer'):
  text=(run/(role+'.log')).read_text();assert 'REPLAY_CAVE_SOCIAL_DETAIL_OK' in text and not re.search(r'SCRIPT ERROR|ERROR:|FAIL|instances were leaked|resources still in use',text),(role,text[-2000:])
  assert json.loads((run/(role+'-result.json')).read_text())['pass']
 print('REPLAY_CAVE_SOCIAL_DETAIL_OK')
finally:
 for child in children:
  if child.poll() is None:child.terminate()
 for child in children:
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
 for log in logs:log.close()
