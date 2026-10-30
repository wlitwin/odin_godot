"""Exercise the shared actor scene in real network peers after the local UI gate."""
from pathlib import Path
import os,re,socket,subprocess,sys,time
out=Path(sys.argv[1]).resolve();ext=sys.argv[2];project=out/'project';folder=out/'network';folder.mkdir(exist_ok=False)
env=os.environ.copy();env['ODIN_SCRIPTS_DLL']=str(project/('bin/libodinscripts.'+ext));env['REPLAY_LATENCY']='120'
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:sock.bind(('127.0.0.1',0));env['REPLAY_PORT']=str(sock.getsockname()[1])
children=[];files=[]
try:
 for label in ('server','a','b','observer'):
  scope=env.copy();scope['REPLAY_ROLE']='client' if label in ('a','b') else label;scope['REPLAY_TOKEN']='scrubber-network-'+label
  log=(folder/(label+'.log')).open('w');files.append(log)
  children.append(subprocess.Popen([env['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script','network_test.gd'],env=scope,stdout=log,stderr=subprocess.STDOUT))
  if label=='server':
   deadline=time.monotonic()+10
   while 'REPLAY_NETWORK_HOST_READY' not in (folder/'server.log').read_text():
    assert children[-1].poll() is None and time.monotonic()<deadline,'server startup'
    time.sleep(.05)
 for child in children:assert child.wait(timeout=30)==0,'network process exit'
 for label in ('server','a','b','observer'):
  text=(folder/(label+'.log')).read_text();kind='CLIENT' if label in ('a','b') else label.upper()
  assert 'REPLAY_NETWORK_'+kind+'_OK' in text and not re.search(r'SCRIPT ERROR|ERROR:|FAIL|instances were leaked|resources still in use',text),label
 print('REPLAY_SCRUBBER_NETWORK_OK')
finally:
 for child in children:
  if child.poll() is None:child.terminate()
 for child in children:
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
 for log in files:log.close()
