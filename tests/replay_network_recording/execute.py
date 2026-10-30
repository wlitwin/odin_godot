from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time,uuid
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();project=out/'project';run=out/(sys.argv[2] if len(sys.argv)>2 else 'run');run.mkdir(exist_ok=False)
ext='dylib' if sys.platform=='darwin' else 'so'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
for name,digest in json.loads((out/'framework.json').read_text()).items():assert sha(root/name)==digest,name
shutil.copy2(root/'tests/replay_network_recording/driver.gd',run/'driver.gd')
(run/'binaries.json').write_text(json.dumps({p.name:sha(p) for p in (project/'bin').glob('*.'+ext)},indent=2)+'\n')
(run/'driver-sha256.txt').write_text(sha(run/'driver.gd')+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
token='recording-'+uuid.uuid4().hex;children=[];logs=[];environments={}
try:
 for role in ('host','client'):
  env=os.environ.copy();env.update(ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)),RSY_ROLE=role,RSY_PORT=str(port),RSY_NAME=role,RSY_TOKEN=token+'-'+role,RSY_PERSIST='0',RSY_AUDIO='0',RSY_DEV='1',RSY_RUN='0',RSY_ENCOUNTER='migration',RSY_RESUME='0',RSY_LATENCY='120',RSY_JITTER='0',RSY_LOSS='0',RSY_DUPLICATE='0',RSY_MODS_DIR=str(run/'no-mods'),RSY_SPRAY=str(run/'no-spray'),RSY_RESULT_DIR=str(run),RSY_RECORDING_PATH=str(run/(role+'.rplrec')))
  environments[role]={k:v for k,v in env.items() if k.startswith('RSY_')}
  log=(run/(role+'.log')).open('w');logs.append(log)
  children.append(subprocess.Popen([env['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',str(run/'driver.gd')],env=env,stdout=log,stderr=subprocess.STDOUT))
  if role=='host':time.sleep(.3)
 (run/'environment.json').write_text(json.dumps(environments,indent=2)+'\n')
 for child in children:assert child.wait(timeout=40)==0,'game process failed'
 for role in ('host','client'):
  text=(run/(role+'.log')).read_text();assert 'RSY_NETWORK_RECORDING_OK' in text and not re.search(r'SCRIPT ERROR|ERROR:|FAIL|instances were leaked|resources still in use',text),(role,text[-3000:])
  verified=subprocess.run([str(out/'verify_recording'),str(run/(role+'.rplrec'))],capture_output=True,text=True,timeout=30)
  (run/(role+'-verify.log')).write_text(verified.stdout+verified.stderr)
  assert verified.returncode==0,verified.stderr
  fields={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',verified.stdout)}
  assert fields['steps']>0 and fields['shots']>0 and fields['casts']>=4,fields
  if role=='host':assert fields['steps']>=70 and fields['applied']>=3 and fields['rejected']>=1 and fields['gameplay']>0 and fields['historical']>0,fields
  print(role,verified.stdout.strip(),flush=True)
 print('REPLAY_NETWORK_RECORDING_OK')
finally:
 for child in children:
  if child.poll() is None:child.terminate()
 for child in children:
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
 for log in logs:log.close()
