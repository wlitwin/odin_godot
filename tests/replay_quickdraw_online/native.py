"""Reuse the direct UI scenario through the native Party/Room entry points."""
from pathlib import Path
import os,re,sys,socket,subprocess,time,json,hashlib
root=Path(__file__).resolve().parents[2];game=Path(sys.argv[1]).resolve()/'project';service=Path(sys.argv[2]).resolve()/'project';out=Path(sys.argv[3]).resolve();out.mkdir(exist_ok=False);ext='dylib' if sys.platform=='darwin' else 'so'
s=(root/'tests/replay_quickdraw_ui/drive.gd').read_text()
s=s.replace(' if p("ready")!=0 or not game.get_node("UI/Lobby").visible:', ' if not await until(func():return game.party_probe("recent")==1 and game.party_probe("profile_ready")==1):await finish(1,"party readiness");return\n if p("ready")!=0 or not game.get_node("UI/Lobby").visible:',1)
s=s.replace('write("host-open",{"ready":true})', 'if not await until(func():return game.party_probe("invited")==1):await finish(1,"invite creation");return\n  write("host-open",{"ready":true,"invite":str(game.get_node("UI/Lobby/Column/Party/Code").text)})')
s=s.replace('  await click("UI/Lobby/Column/Buttons/Join")','  game.get_node("UI/Lobby/Column/Party/Code").text=JSON.parse_string(FileAccess.get_file_as_string(folder+"/host-open.json")).invite\n  await click("UI/Lobby/Column/Buttons/Join")',1)
s=s.replace('  await click("UI/Lobby/Column/Buttons/Watch")','  game.get_node("UI/Lobby/Column/Party/Code").text=JSON.parse_string(FileAccess.get_file_as_string(folder+"/host-open.json")).invite\n  game.get_node("UI/Lobby/Column/Party/Choices/Watch").button_pressed=true\n  await click("UI/Lobby/Column/Buttons/Join")')
s=s.replace('  await click("UI/Lobby/Column/Buttons/Join")\n  if not await until(func():return p("seat")==2', '  await click("UI/Lobby/Column/Party/Choices/Rejoin")\n  if not await until(func():return p("seat")==2')
s=s.replace(' record("admitted")',' if game.party_probe("separate")!=1:await finish(1,"personal/party identity separation");return\n record("admitted")')
(out/'driver.gd').write_text(s)
with socket.socket(socket.AF_INET,socket.SOCK_STREAM) as sock:sock.bind(('127.0.0.1',0));control=sock.getsockname()[1]
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
children=[];logs=[];exits={}
try:
 env=os.environ.copy();env.update(REPLAY_ROOM_CONTENT='0x52515549434b4432',REPLAY_ROOM_PORT=str(control),REPLAY_ROOM_DB=str(out/'service.sqlite3'),REPLAY_ROOM_CREATE_DB='1',REPLAY_ROOM_LOCAL_DEVELOPMENT='1',ODIN_SCRIPTS_DLL=str(service/('bin/libodinscripts.'+ext)))
 log=(out/'service.log').open('w');logs.append(log);server=subprocess.Popen([env['GODOT'],'--headless','--max-fps','120','--path',str(service)],env=env,stdout=log,stderr=subprocess.STDOUT);children.append(('service',server))
 deadline=time.monotonic()+10
 while 'REPLAY_ROOM_SERVICE_READY' not in (out/'service.log').read_text():assert server.poll() is None and time.monotonic()<deadline;time.sleep(.05)
 for role in ('host','guest','observer'):
  env=os.environ.copy();env.update(RQ_UI_ROLE=role,RQ_UI_DIR=str(out),RQ_ROOM_SERVICE='ws://127.0.0.1:'+str(control),RQ_ROOM_LOCAL='1',RQ_ROOMS_DB=str(out/(role+'-rooms.sqlite3')),RQ_ROLE='',RQ_TOKEN='native-party-'+role,RQ_PERSIST='0',RQ_GOLD='1',RQ_BOT='',RQ_PORT=str(port),RQ_LATENCY='120',RQ_COORD_PORT='0',ODIN_SCRIPTS_DLL=str(game/('bin/libodinscripts.'+ext)))
  log=(out/(role+'.log')).open('w');logs.append(log);child=subprocess.Popen([env['GODOT'],'--headless','--max-fps','60','--path',str(game),'--script',str(out/'driver.gd')],env=env,stdout=log,stderr=subprocess.STDOUT);children.append((role,child))
 deadline=time.monotonic()+90
 while any(child.poll() is None for _,child in children[1:]):
  assert time.monotonic()<deadline,'native party deadline'
  for role,_ in children:
   text=(out/(role+'.log')).read_text();assert not re.search(r'RQ_UI_FAIL|REPLAY_QUICKDRAW_FAIL|REPLAY_ROOM_SERVICE_FAIL|SCRIPT ERROR|ERROR:',text),(role,text[-2500:])
  time.sleep(.05)
 for role,child in children[1:]:assert child.returncode==0 and 'RQ_UI_OK '+role in (out/(role+'.log')).read_text(),role
 print('REPLAY_QUICKDRAW_ONLINE_NATIVE_OK')
finally:
 for _,child in children:
  if child.poll() is None:child.terminate()
 for role,child in children:
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
  exits[role]=child.returncode
 for log in logs:log.close()
 (out/'exits.json').write_text(json.dumps(exits,indent=2)+'\n')
