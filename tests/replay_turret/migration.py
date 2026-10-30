from pathlib import Path
import json,os,signal,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2]
project,coordinator,out=map(lambda p:Path(p).resolve(),sys.argv[1:]);out.mkdir(parents=True,exist_ok=False)
ext='dylib' if sys.platform=='darwin' else 'so'
with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
env=os.environ|{'REPLAY_MIGRATION_GAME':'scrapyard','REPLAY_MIGRATION_MODE':'crash','REPLAY_MIGRATION_DIR':str(out),'REPLAY_MIGRATION_DB':str(out/'room.sqlite3'),'REPLAY_MIGRATION_PORT':str(port),
 'RSY_DEV':'1','RSY_PERSIST':'0','RSY_RUN':'0','RSY_ENCOUNTER':'turret','RSY_LATENCY':'120','RSY_SETTINGS_PATH':str(out/'settings.json')}
processes=[]
def launch(label,path,extra,script=None):
 log=(out/(label+'.log')).open('w');cmd=[os.environ['GODOT'],'--headless','--max-fps','60','--path',str(path)]
 if script:cmd+=['--script',script]
 proc=subprocess.Popen(cmd,env=env|{'ODIN_SCRIPTS_DLL':str(path/f'bin/libodinscripts.{ext}')}|extra,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
 processes.append((label,proc,log));return proc
try:
 launch('coordinator',coordinator,{})
 deadline=time.monotonic()+8
 while 'REPLAY_MIGRATION_COORDINATOR_READY' not in (out/'coordinator.log').read_text() and time.monotonic()<deadline:time.sleep(.05)
 assert 'REPLAY_MIGRATION_COORDINATOR_READY' in (out/'coordinator.log').read_text()
 for member in [1,2,3]:
  launch('member-'+str(member),project,{'RSY_ROLE':'host','RSY_MEMBER':str(member),'RSY_INCARNATION':str(100+member),'RSY_COORD_KEY':f'{member+20:02x}'+('0'*62),'RSY_COORD_PORT':str(port),'RSY_TOKEN':'migration-'+str(member)},'turret_peers.gd')
  time.sleep(.3)
 deadline=time.monotonic()+70;killed=False
 while time.monotonic()<deadline:
  if not killed and (out/'kill_owner.json').exists():processes[1][1].kill();processes[1][1].wait();killed=True
  if all(p.poll() is not None for _,p,_ in processes[2:]):break
  if any(p.poll() not in [None,0] for _,p,_ in processes[2:]):break
  time.sleep(.05)
 assert killed,'occupied backup never triggered host crash'
 hashes=[]
 import re
 for label,proc,log in processes[2:]:
  assert proc.wait(timeout=3)==0,label;log.flush();text=(out/(label+'.log')).read_text()
  assert 'TURRET_OCCUPIED_RESTORED' in text and 'REPLAY_TURRET_PEER_OK' in text and 'REPLAY_SCRAPYARD_COMBAT_PEER_OK' in text,(label,text[-4000:])
  assert not any(x in text for x in ['SCRIPT ERROR','ERROR:','_FAIL','instances were leaked','resources still in use'])
  hashes.append(re.search(r'RSY_COMBAT_HASH role=\w+ tick=(\d+) hash=(\d+)',text).groups())
 assert len(set(hashes))==1,hashes
 (out/'result.json').write_text(json.dumps({'pass':True,'occupied_host_crash':True,'survivors':[2,3],'hash':hashes[0],'occupied':json.loads((out/'occupied.json').read_text())},indent=2)+'\n')
 print('REPLAY_TURRET_OCCUPIED_MIGRATION_OK',hashes[0])
finally:
 for _,proc,log in processes:
  if proc.poll() is None:
   try:os.killpg(proc.pid,signal.SIGTERM)
   except (ProcessLookupError,PermissionError):proc.terminate()
   try:proc.wait(timeout=3)
   except subprocess.TimeoutExpired:proc.kill();proc.wait(timeout=3)
  log.close()
