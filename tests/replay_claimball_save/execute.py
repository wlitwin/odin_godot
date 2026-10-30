from pathlib import Path
import hashlib,json,os,re,shutil,socket,subprocess,sys,time
root=Path(__file__).resolve().parents[2];out=Path(sys.argv[1]).resolve();folder=out/(sys.argv[2] if len(sys.argv)>2 else 'save');folder.mkdir(exist_ok=False);project=out/'project';ext='dylib' if sys.platform=='darwin' else 'so'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,digest in json.loads((out/'prepared.json').read_text()).items():assert sha(project/name)==digest,name
for name,digest in json.loads((out/'framework.json').read_text()).items():assert sha(root/name)==digest,name
shutil.copy2(root/'tests/replay_claimball_save/drive.gd',folder/'driver.gd')
(folder/'builds.json').write_text(json.dumps({'binaries':{p.name:sha(p) for p in (project/'bin').glob('*.'+ext)},'driver_sha256':sha(folder/'driver.gd')},indent=2)+'\n')
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
children=[];logs=[];exits={}
def launch(stage,role,profile=None,save=None):
 profile=profile or folder/(role+'-identity');save=save or folder/'pitch.replay'
 env=os.environ.copy();env.update(RCB_SAVE_STAGE=stage,RCB_SAVE_ROLE=role,RCB_SAVE_DIR=str(folder),RCB_ROLE='',RCB_TOKEN='',RCB_NAME='',RCB_BOT='',RCB_PERSIST='1',RCB_PROFILE=str(profile),RCB_SAVE=str(save),RCB_PORT=str(port),RCB_GOALS='2',RCB_PLAYERS='2',RCB_LATENCY='120',RCB_COORD_PORT='1' if stage=='room' else '0',RCB_TEST='0',ODIN_SCRIPTS_DLL=str(project/('bin/libodinscripts.'+ext)))
 log=(folder/(stage+'-'+role+'.log')).open('w');logs.append(log)
 child=subprocess.Popen([env['GODOT'],'--headless','--max-fps','60','--path',str(project),'--script',str(folder/'driver.gd')],env=env,stdout=log,stderr=subprocess.STDOUT)
 children.append((stage+'-'+role,child));return child
def errors():
 for name,_ in children:
  text=(folder/(name+'.log')).read_text()
  if re.search(r'RCB_SAVE_FAIL|REPLAY_CLAIMBALL_FAIL|SCRIPT ERROR|ERROR:',text):raise RuntimeError(name+': '+text[-3000:])
def wait_all():
 deadline=time.monotonic()+110
 while any(child.poll() is None for _,child in children):
  errors();assert time.monotonic()<deadline,'save cohort deadline';time.sleep(.05)
 errors()
 for name,child in children:
  exits[name]=child.returncode;assert child.returncode==0,name
  text=(folder/(name+'.log')).read_text();assert 'RCB_SAVE_OK' in text and not re.search(r'instances were leaked|resources still in use',text),name
 children.clear()
try:
 launch('write','host');launch('write','client',save=folder/'guest.replay')
 deadline=time.monotonic()+50
 while not (folder/'saved-ready.json').exists():
  errors();assert all(child.poll() is None for _,child in children),'writer exited';assert time.monotonic()<deadline,'save receipt deadline';time.sleep(.05)
 for name,child in children:child.kill();child.wait();exits[name]=child.returncode
 children.clear()
 saved=folder/'pitch.replay';damaged=folder/'damaged.replay';damaged.write_bytes(saved.read_bytes()[:len(saved.read_bytes())//2])
 verifier=folder/'verify-archive'
 subprocess.run(['odin','build',str(root/'tests/replay_claimball_save/verify'),'-collection:godot='+str(root),'-out:'+str(verifier)],check=True)
 with (folder/'archive-verification.log').open('w') as log:subprocess.run([str(verifier),str(saved),str(folder/'policy.replay'),str(folder/'exhausted.replay')],stdout=log,stderr=subprocess.STDOUT,check=True)
 preserved={name:sha(folder/name) for name in ('pitch.replay','damaged.replay','policy.replay','exhausted.replay','host-identity','client-identity','host-identity.name','client-identity.name')}
 (folder/'preservation.json').write_text(json.dumps(preserved,indent=2)+'\n')
 for stage in ('wrong-owner','damaged','missing','policy','exhausted','room','solo'):
  profile=folder/('client-identity' if stage=='wrong-owner' else 'host-identity')
  save=folder/({'damaged':'damaged.replay','missing':'missing.replay','policy':'policy.replay','exhausted':'exhausted.replay'}.get(stage,'pitch.replay'))
  launch(stage,'host',profile,save);wait_all()
 for name,digest in preserved.items():assert sha(folder/name)==digest,name
 launch('read','host');launch('read','client',save=folder/'guest.replay');wait_all()
 for name,digest in preserved.items():
  if name!='pitch.replay':assert sha(folder/name)==digest,name
 assert sha(saved)!=preserved['pitch.replay'],'continued save did not replace initial archive'
 with (folder/'continued-verification.log').open('w') as log:subprocess.run([str(verifier),'--continued',str(saved)],stdout=log,stderr=subprocess.STDOUT,check=True)
 again=json.loads((folder/'saved-again.json').read_text());assert again['round']==2 and again['epoch']==2
 continued=(folder/'continued-verification.log').read_text();assert 'tick='+str(again['tick'])+' ' in continued,continued
 assert not (folder/'guest.replay').exists() and not (folder/'missing.replay').exists()
 before=json.loads((folder/'saved.json').read_text());restored=json.loads((folder/'restored.json').read_text());assert before['tick']==restored['tick'] and before['hash']==restored['hash'] and restored['epoch']==2
 report={'pass':True,'saved':before,'restored':restored,'negative_cases_preserved_files':True,'profiles_preserved':True,'successful_replacement':{'receipt':again,'initial_sha256':preserved['pitch.replay'],'current_sha256':sha(saved)},'fresh_processes':True,'peers':{role:json.loads((folder/('done-'+role+'.json')).read_text()) for role in ('host','client')}}
 assert all(peer['round']==2 and peer['final']['round']==2 and peer['final']['tick']>=peer['round_floor'] for peer in report['peers'].values()),report
 (folder/'report.json').write_text(json.dumps(report,indent=2)+'\n');print('REPLAY_CLAIMBALL_SAVE_OK')
finally:
 for _,child in children:
  if child.poll() is None:child.terminate()
 for name,child in children:
  try:child.wait(timeout=5)
  except subprocess.TimeoutExpired:child.kill();child.wait()
  exits[name]=child.returncode
 for log in logs:log.close()
 (folder/'exits.json').write_text(json.dumps(exits,indent=2)+'\n')
